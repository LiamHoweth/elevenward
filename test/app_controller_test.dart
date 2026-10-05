import 'dart:async';
import 'dart:convert';

import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/feature_copy.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/api_models.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('career opens only with its exact content release', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final credentials = SecureCredentials();
    final api = ElevenwardApi(accessToken: credentials.readAccountToken);
    addTearDown(api.close);
    final content = ContentService(api: api, store: store);
    addTearDown(content.close);
    final controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    addTearDown(controller.dispose);
    await store.setPreference('onboarding.completed', true);
    await store.setPreference('language.selected', true);
    await store.saveSlot(
      0,
      CareerSnapshot.newCareer(
        careerId: 'unknown-content',
        contentVersion: '2099.1.0',
      ),
    );
    await controller.initialize();

    await controller.openSlot(0);
    expect(controller.stage, AppStage.careerSlots);
    expect(controller.activeCareer, isNull);
    expect(controller.lastMessage, contains('2099.1.0'));

    await store.saveSlot(
      0,
      CareerSnapshot.newCareer(
        careerId: 'compatible-content',
        contentVersion: '2026.1.0',
      ),
    );
    await store.saveWeeklyFocus('compatible-content', PlayerAttribute.pace);
    await controller.openSlot(0);
    expect(controller.stage, AppStage.playing);
    expect(controller.activeCareer?.careerId, 'compatible-content');
    expect(controller.activeContent?.version, '2026.1.0');
    expect(controller.activeWeeklyFocus, PlayerAttribute.pace);

    await controller.changeWeeklyFocus(PlayerAttribute.passing);
    expect(
      await store.loadWeeklyFocus('compatible-content'),
      PlayerAttribute.passing,
    );

    controller.showCareerSlots();
    expect(controller.activeContent?.version, '2026.4.0');

    await controller.openSlot(0);
    expect(controller.activeWeeklyFocus, PlayerAttribute.passing);
    await controller.deleteSlot(0);
    expect(
      await store.getPreference(weeklyFocusPreferenceKey('compatible-content')),
      isNull,
    );
  });

  test('pending conflicts prevent deletion and replacement while allowing career saves', () async {
    final controller = await _controllerForSlotTests();
    controller.locale = const Locale('es');
    final local = CareerSnapshot.newCareer(careerId: 'pending-delete-guard');
    await controller.store.saveSlot(0, local);
    await controller.store.preserveConflict(
      local: local,
      remote: null,
      createdAt: DateTime.utc(2026, 10, 1),
      remoteConflictId: 'pending-conflict-delete',
    );
    await controller.deleteSlot(
      0,
      expectedCareerId: local.careerId,
      expectedRevision: local.revision,
    );
    expect((await controller.store.loadSlot(0))?.encode(), local.encode());
    expect(controller.lastMessage, featureCopy('es', 'resolveConflictFirst'));
    await _createInSlot(controller, 0);
    expect((await controller.store.loadSlot(0))?.encode(), local.encode());
    controller.activeSlotIndex = 0;
    controller.activeCareer = local;
    final progressed = local.copyWith(revision: local.revision + 1, seed: 99);
    await controller.saveCareer(progressed);
    expect((await controller.store.loadSlot(0))?.encode(), progressed.encode());
  });

  test('deletion waits for in-flight conflict detection without blocking sync completion', () async {
    final getStarted = Completer<void>();
    final cloudList = Completer<http.Response>();
    late CareerSnapshot local;
    final controller = await _controllerForSlotTests(
      signedIn: true,
      client: MockClient((request) {
        if (request.method == 'GET') {
          getStarted.complete();
          return cloudList.future;
        }
        return Future.value(
          http.Response(
            jsonEncode({
              'conflict': {
                'conflictId': 'in-flight-conflict',
                'slotIndex': 0,
                'localSnapshot': local.toJson(),
                'remoteSnapshot': null,
                'remoteRevision': 0,
              },
            }),
            409,
          ),
        );
      }),
    );
    local = CareerSnapshot.newCareer(careerId: 'wait-for-sync-conflict');
    await controller.store.saveSlot(0, local);
    await controller.store.markSynced(0, local.revision, 5);
    final syncing = controller.synchronize();
    await getStarted.future;
    var deleted = false;
    final deleting = controller
        .deleteSlot(
          0,
          expectedCareerId: local.careerId,
          expectedRevision: local.revision,
        )
        .then((_) => deleted = true);
    await Future<void>.delayed(Duration.zero);
    expect(deleted, isFalse);
    cloudList.complete(http.Response('{"slots":[]}', 200));
    await Future.wait([syncing, deleting]).timeout(const Duration(seconds: 10));
    expect((await controller.store.loadSlot(0))?.encode(), local.encode());
    expect(controller.lastMessage, featureCopy('en', 'resolveConflictFirst'));
    expect(await controller.store.listConflicts(), hasLength(1));
  });

  test(
    'the creator cannot replace a slot restored by an already running sync',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final cloud = CareerSnapshot.newCareer(careerId: 'newly-restored-slot');
      final controller = await _controllerForSlotTests(
        signedIn: true,
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final syncing = controller.synchronize();
      await started.future;
      final creating = _createInSlot(controller, 0);
      response.complete(
        http.Response(
          jsonEncode({
            'slots': [
              {
                'slotIndex': 0,
                'snapshot': cloud.toJson(),
                'revision': 3,
                'checksum': List.filled(64, 'a').join(),
              },
            ],
          }),
          200,
        ),
      );
      await Future.wait([syncing, creating])
          .timeout(const Duration(seconds: 10));
      expect((await controller.store.loadSlot(0))?.encode(), cloud.encode());
      expect(controller.lastMessage, featureCopy('en', 'slotOccupied'));
      expect(controller.activeCareer, isNull);
    },
  );

  test('a sync requested during slot creation starts after that mutation publishes', () async {
    final controller = await _controllerForSlotTests(signedIn: true);
    Future<void>? syncing;
    AppStage? stageAtSyncStart;
    var requested = false;
    controller.addListener(() {
      if (!requested &&
          controller.slots.firstOrNull?.snapshot != null &&
          controller.activeCareer == null) {
        requested = true;
        syncing = controller.synchronize();
      }
      if (controller.syncStatus == SyncUiStatus.running) {
        stageAtSyncStart ??= controller.stage;
      }
    });
    await _createInSlot(controller, 0).timeout(const Duration(seconds: 10));
    expect(requested, isTrue);
    await syncing!.timeout(const Duration(seconds: 10));
    expect(stageAtSyncStart, AppStage.playing);
    expect(controller.syncStatus, SyncUiStatus.complete);
    expect(
      (await controller.store.listSlots()).first.syncState,
      SlotSyncState.synced,
    );
  });

  test(
    'destructive slot operations queue in order without a sync deadlock',
    () async {
      final controller = await _controllerForSlotTests();
      final old = CareerSnapshot.newCareer(careerId: 'queued-old-career');
      await controller.store.saveSlot(0, old);
      final deleting = controller.deleteSlot(0);
      final creating = _createInSlot(controller, 0);
      await Future.wait([deleting, creating])
          .timeout(const Duration(seconds: 10));
      final current = await controller.store.loadSlot(0);
      expect(current, isNotNull);
      expect(current?.careerId, isNot(old.careerId));
      expect(controller.activeCareer?.careerId, current?.careerId);
    },
  );

  test('a confirmed synced deletion can be reused offline with its known cloud base', () async {
    final controller = await _controllerForSlotTests();
    final old = CareerSnapshot.newCareer(careerId: 'offline-synced-old');
    await controller.store.saveSlot(0, old);
    await controller.store.markSynced(0, old.revision, 7);
    await controller.deleteSlot(
      0,
      expectedCareerId: old.careerId,
      expectedRevision: old.revision,
    );
    expect((await controller.store.listSlots()).first.isTombstone, isTrue);
    await _createInSlot(controller, 0);
    final saved = (await controller.store.listSlots()).first;
    expect(saved.snapshot, isNotNull);
    expect(saved.snapshot?.careerId, isNot(old.careerId));
    expect(saved.serverRevision, 7);
    expect(saved.isTombstone, isFalse);
    expect(saved.syncState, SlotSyncState.queued);
    expect(controller.activeCareer?.careerId, saved.snapshot?.careerId);
  });

  for (final replaced in [false, true]) {
    test(
      'delete confirmation preserves a ${replaced ? 'replacement' : 'newer'} career',
      () async {
        final controller = await _controllerForSlotTests();
        final reviewed = CareerSnapshot.newCareer(careerId: 'reviewed-career');
        await controller.store.saveSlot(0, reviewed);
        final current = replaced
            ? CareerSnapshot.newCareer(careerId: 'replacement-after-dialog')
            : reviewed.copyWith(revision: reviewed.revision + 1);
        await controller.store.saveSlot(0, current);
        await controller.deleteSlot(
          0,
          expectedCareerId: reviewed.careerId,
          expectedRevision: reviewed.revision,
        );
        expect(
          (await controller.store.loadSlot(0))?.encode(),
          current.encode(),
        );
        expect(
          controller.lastMessage,
          featureCopy('en', 'careerChangedBeforeDeletion'),
        );
      },
    );
  }
}

Future<AppController> _controllerForSlotTests({
  bool signedIn = false,
  http.Client? client,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  final store = await CareerStore.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfi,
  );
  addTearDown(store.close);
  final credentials = SecureCredentials();
  if (signedIn) await credentials.writeAccountToken('token');
  final api = ElevenwardApi(
    baseUri: Uri.parse('https://api.example.test'),
    accessToken: credentials.readAccountToken,
    client:
        client ??
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"slots":[]}', 200);
          }
          final uploaded = jsonDecode(request.body)['snapshot'];
          return http.Response(
            jsonEncode({
              'slot': {
                'slotIndex': 0,
                'snapshot': uploaded,
                'revision': 1,
                'checksum': List.filled(64, 'a').join(),
              },
            }),
            200,
          );
        }),
  );
  addTearDown(api.close);
  final content = ContentService(api: api, store: store);
  addTearDown(content.close);
  final controller = AppController(
    store: store,
    auth: AuthService(api: api, credentials: credentials),
    entitlements: EntitlementService(credentials: credentials, store: store),
    sync: SyncService(api, store),
    analytics: AnalyticsService(api, store),
    content: content,
  )..stage = AppStage.careerSlots;
  if (signedIn) {
    controller.account = const ElevenwardAccount(
      id: 'account-a',
      alias: 'Alias A',
      provider: 'apple',
    );
  }
  addTearDown(controller.dispose);
  return controller;
}

Future<void> _createInSlot(AppController controller, int slotIndex) =>
    controller.createCareer(
      slotIndex: slotIndex,
      firstName: 'Mika',
      lastName: 'Vale',
      archetype: Archetype.poacher,
      nationalTeamId: 'united-states',
      portraitId: 'portrait-01',
      club: buildLaunchWorld().club('england-northstar-athletic'),
      difficulty: Difficulty.professional,
    );
