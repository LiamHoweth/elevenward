import 'dart:async';
import 'dart:convert';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/online_copy.dart';
import 'package:elevenward/src/screens/friends_screen.dart';
import 'package:elevenward/src/screens/support_screen.dart';
import 'package:elevenward/src/screens/weekly_challenge_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/api_models.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late CareerStore store;
  late AppController controller;
  late ElevenwardApi api;
  late ContentService content;
  late Future<http.Response> Function(http.Request) respond;
  final requests = <http.Request>[];
  setUp(() async {
    requests.clear();
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Elevenward',
      packageName: 'test',
      version: '1.1.0',
      buildNumber: '5',
      buildSignature: 'test',
    );
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    respond = (_) async => http.Response('{}', 200);
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => 'fixture-token',
      client: MockClient((request) {
        requests.add(request);
        return respond(request);
      }),
    );
    final credentials = SecureCredentials();
    content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    await controller.refreshSlots();
  });
  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  test(
    'cloud restoration cannot overwrite a career created during the request',
    () async {
      final response = Completer<http.Response>();
      final requested = Completer<void>();
      respond = (_) {
        requested.complete();
        return response.future;
      };
      final work = controller.sync.synchronize(publishLeaderboard: false);
      await requested.future;
      final local = CareerSnapshot.newCareer(careerId: 'new-local');
      await store.saveSlot(0, local);
      final remote = CareerSnapshot.newCareer(careerId: 'cloud');
      response.complete(
        http.Response(
          jsonEncode({
            'slots': [
              {
                'slotIndex': 0,
                'snapshot': remote.toJson(),
                'revision': 5,
                'checksum': 'a' * 64,
              },
            ],
          }),
          200,
        ),
      );
      expect((await work).downloaded, 0);
      expect((await store.loadSlot(0))!.encode(), local.encode());
      expect((await store.listSlots()).first.syncState, SlotSyncState.queued);
    },
  );

  test('Hall cache reads without waiting for unavailable cloud and imports notify once', () async {
    controller.account = const ElevenwardAccount(
      id: 'a',
      alias: 'Me',
      provider: 'apple',
    );
    final local = CareerSnapshot.newCareer(careerId: 'retired-local')
        .copyWith(retired: true, phase: CareerPhase.retired);
    final cloud = CareerSnapshot.newCareer(careerId: 'retired-cloud')
        .copyWith(retired: true, phase: CareerPhase.retired);
    await store.saveArchive(local);
    final pending = Completer<http.Response>();
    respond = (_) => pending.future;
    final refresh = controller.refreshHallOfFame();
    expect(
      (await controller.localHallOfFame()).single.careerId,
      local.careerId,
    );
    pending.complete(
      http.Response(
        jsonEncode({
          'archives': [
            {'snapshot': cloud.toJson()},
          ],
        }),
        200,
      ),
    );
    await refresh;
    expect(await controller.localHallOfFame(), hasLength(2));
    expect(controller.archiveGeneration, 1);
    respond = (_) async => http.Response(
      jsonEncode({
        'archives': [
          {'snapshot': cloud.toJson()},
        ],
      }),
      200,
    );
    await controller.refreshHallOfFame();
    expect(controller.archiveGeneration, 1);
  });

  test(
    'obsolete generation cannot commit over a selected cloud replacement',
    () async {
      final current = CareerSnapshot.newCareer(careerId: 'current');
      controller.activeSlotIndex = 0;
      controller.activeCareer = current;
      controller.activeCareerGeneration = 2;
      await store.saveSlot(0, current);
      await expectLater(
        controller.saveCareer(current.copyWith(week: 5), expectedGeneration: 1),
        throwsStateError,
      );
      expect((await store.loadSlot(0))!.week, 1);
    },
  );

  test('upload acknowledgement keeps newer local progress queued with the correct cloud base', () async {
    final original = CareerSnapshot.newCareer(careerId: 'same-career');
    await store.saveSlot(0, original);
    final uploading = Completer<void>();
    final response = Completer<http.Response>();
    respond = (request) {
      if (request.url.path.endsWith('/career-slots')) {
        return Future.value(http.Response('{"slots":[]}', 200));
      }
      uploading.complete();
      return response.future;
    };
    final work = controller.sync.synchronize(publishLeaderboard: false);
    await uploading.future;
    final advanced = original.copyWith(
      revision: original.revision + 1,
      week: 2,
    );
    await store.saveSlot(0, advanced);
    response.complete(
      http.Response(
        jsonEncode({
          'slot': {
            'slotIndex': 0,
            'snapshot': original.toJson(),
            'revision': 7,
            'checksum': 'a' * 64,
          },
        }),
        200,
      ),
    );
    await work;
    final slot = (await store.listSlots()).first;
    expect(slot.snapshot!.encode(), advanced.encode());
    expect(slot.serverRevision, 7);
    expect(slot.syncState, SlotSyncState.queued);
  });

  test('old upload cannot mark a replacement career with the same local revision as synced', () async {
    final old = CareerSnapshot.newCareer(careerId: 'old');
    await store.saveSlot(0, old);
    await store.saveSlot(0, CareerSnapshot.newCareer(careerId: 'replacement'));
    await store.markSynced(
      0,
      old.revision,
      7,
      expectedCareerId: old.careerId,
      expectedServerRevision: 0,
    );
    final slot = (await store.listSlots()).first;
    expect(slot.snapshot!.careerId, 'replacement');
    expect(slot.serverRevision, 0);
    expect(slot.syncState, SlotSyncState.queued);
  });

  test('a changed account aborts restoration before writing or sending another request', () async {
    var current = true;
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    respond = (_) {
      requested.complete();
      return response.future;
    };
    final work = controller.sync.synchronize(
      publishLeaderboard: false,
      isCurrentSession: () => current,
    );
    await requested.future;
    current = false;
    response.complete(
      http.Response(
        jsonEncode({
          'slots': [
            {
              'slotIndex': 0,
              'snapshot': CareerSnapshot.newCareer(careerId: 'private-a')
                  .toJson(),
              'revision': 1,
              'checksum': 'a' * 64,
            },
          ],
        }),
        200,
      ),
    );
    await expectLater(work, throwsStateError);
    expect(await store.loadSlot(0), isNull);
    expect(requests, hasLength(1));
  });

  test(
    'an in-flight Hall refresh cannot resurrect an archive just deleted',
    () async {
      controller.account = const ElevenwardAccount(
        id: 'a',
        alias: 'Me',
        provider: 'apple',
      );
      final retired = CareerSnapshot.newCareer(careerId: 'removed')
          .copyWith(retired: true, phase: CareerPhase.retired);
      await store.saveArchive(retired, accountId: 'a', cloudSynced: true);
      final fetched = Completer<void>();
      final response = Completer<http.Response>();
      respond = (request) {
        if (request.method == 'DELETE') {
          return Future.value(http.Response('', 204));
        }
        fetched.complete();
        return response.future;
      };
      final refresh = controller.refreshHallOfFame();
      await fetched.future;
      await controller.deleteArchivedCareer(retired.careerId);
      response.complete(
        http.Response(
          jsonEncode({
            'archives': [
              {'snapshot': retired.toJson()},
            ],
          }),
          200,
        ),
      );
      await refresh;
      expect(await store.listArchives(), isEmpty);
    },
  );

  test(
    'removing another accounts cached archive never sends a cloud delete',
    () async {
      controller.account = const ElevenwardAccount(
        id: 'b',
        alias: 'Me',
        provider: 'apple',
      );
      final retired = CareerSnapshot.newCareer(careerId: 'other-owner')
          .copyWith(retired: true, phase: CareerPhase.retired);
      await store.saveArchive(retired, accountId: 'a', cloudSynced: true);
      await controller.deleteArchivedCareer(retired.careerId);
      expect(requests, isEmpty);
      expect(await store.listArchives(), isEmpty);
    },
  );

  test('cloud account changes preserve local careers and reset account-specific bases', () async {
    await store.adoptCloudAccount('a');
    final career = CareerSnapshot.newCareer(careerId: 'device-career');
    await store.saveSlot(0, career);
    await store.markSynced(0, career.revision, 9);
    await store.adoptCloudAccount('b');
    final slot = (await store.listSlots()).first;
    expect(slot.snapshot!.encode(), career.encode());
    expect(slot.serverRevision, 0);
    expect(slot.syncState, SlotSyncState.queued);
  });

  test('keeping local at remote revision zero sends current progress rather than the old conflict copy', () async {
    controller.account = const ElevenwardAccount(
      id: 'a',
      alias: 'Me',
      provider: 'apple',
    );
    final stale = CareerSnapshot.newCareer(careerId: 'continued');
    final latest = stale.copyWith(
      revision: stale.revision + 3,
      week: 4,
      seed: 1234,
    );
    await store.saveSlot(0, latest);
    await store.preserveConflict(
      local: stale,
      remote: stale,
      createdAt: DateTime.utc(2026, 10),
      remoteConflictId: 'remote-conflict',
      remoteRevision: 0,
    );
    respond = (request) async {
      final body = jsonDecode(request.body) as Map;
      final snapshot = body['localSnapshot'] ?? stale.toJson();
      return http.Response(
        jsonEncode({
          'slot': {
            'slotIndex': 0,
            'snapshot': snapshot,
            'revision': 1,
            'checksum': 'a' * 64,
          },
        }),
        200,
      );
    };
    await controller.resolveConflict(
      (await store.listConflicts()).single,
      keepLocal: true,
    );
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['expectedRemoteRevision'], 0);
    expect(body['localSnapshot'], latest.toJson());
    expect((await store.loadSlot(0))!.encode(), latest.encode());
    expect(await store.listConflicts(), isEmpty);
  });

  testWidgets(
    'guest feedback retains its ID through failure and retries with reviewed diagnostics',
    (tester) async {
      var fail = true;
      respond = (_) async => http.Response(
        fail ? '{"error":"offline"}' : '{"received":true}',
        fail ? 503 : 201,
      );
      await tester.pumpWidget(_app(SupportScreen(controller: controller)));
      await _settleIo(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        'The match button is not responding.',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.ensureVisible(find.byKey(const Key('feedback-send')));
      await tester.tap(find.byKey(const Key('feedback-send')));
      await _settleIo(tester);
      expect(requests, hasLength(1));
      final original = jsonDecode(requests.first.body) as Map;
      expect(requests.first.headers.containsKey('authorization'), isFalse);
      expect(original['diagnostics'], {'locale': 'en', 'syncState': 'idle'});
      expect(original.containsKey('snapshot'), isFalse);
      expect(
        await tester.runAsync(() => store.getPreference('ui.supportDraft')),
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
      controller.syncStatus = SyncUiStatus.complete;
      controller.locale = const Locale('fr');
      controller.activeCareer = CareerSnapshot.newCareer(
        careerId: 'another-career',
      );
      await tester.pumpWidget(_app(SupportScreen(controller: controller)));
      await _settleIo(tester);
      fail = false;
      await tester.ensureVisible(find.byKey(const Key('feedback-send')));
      await tester.tap(find.byKey(const Key('feedback-send')));
      await _settleIo(tester);
      expect(
        jsonDecode(requests.last.body)['submissionId'],
        original['submissionId'],
      );
      expect(jsonDecode(requests.last.body), original);
      expect(
        await tester.runAsync(() => store.getPreference('ui.supportDraft')),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'challenge resumes durable choices and submits exactly eight without altering career slots',
    (tester) async {
      controller.account = const ElevenwardAccount(
        id: 'a',
        alias: 'Me',
        provider: 'apple',
      );
      final regular = CareerSnapshot.newCareer(careerId: 'regular');
      await tester.runAsync(() => store.saveSlot(0, regular));
      final challenge = _challenge();
      final attempt = {
        'attemptId': 'attempt',
        'seed': 14,
        'careerId': 'weekly',
        'status': 'enrolled',
        'enrolledAt': DateTime.utc(2026, 10, 1).toIso8601String(),
      };
      respond = (request) async {
        if (request.url.path.endsWith('/submit')) {
          return http.Response('{"accepted":true,"score":100}', 200);
        }
        return http.Response(
          jsonEncode({
            'challenge': challenge,
            'attempt': attempt,
            'entries': [],
          }),
          200,
        );
      };
      await tester.pumpWidget(
        _app(WeeklyChallengeScreen(controller: controller)),
      );
      await _settleIo(tester);
      for (var i = 0; i < 3; i++) {
        await _reveal(tester, find.byKey(const Key('challenge-next')));
        await tester.tap(find.byKey(const Key('challenge-next')));
        await _settleIo(tester);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(WeeklyChallengeScreen(controller: controller)),
      );
      await _settleIo(tester);
      expect(find.text('Matches: 3 / 8'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await _reveal(tester, find.byKey(const Key('challenge-next')));
        await tester.tap(find.byKey(const Key('challenge-next')));
        await _settleIo(tester);
      }
      expect(find.byKey(const Key('challenge-next')), findsNothing);
      await _reveal(tester, find.byKey(const Key('challenge-submit')));
      await tester.tap(find.byKey(const Key('challenge-submit')));
      await _settleIo(tester);
      final submission = jsonDecode(
        requests.firstWhere((r) => r.url.path.endsWith('/submit')).body,
      ) as Map;
      expect(submission.keys, unorderedEquals(['attemptId', 'actions']));
      expect(submission['actions'], hasLength(8));
      expect(
        (await tester.runAsync(() => store.loadSlot(0)))!.encode(),
        regular.encode(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'active career feedback sends a bounded uppercase code and natural multiline report',
    (tester) async {
      controller.activeCareer = CareerSnapshot.newCareer(
        careerId: 'active-report',
      );
      respond = (request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['supportCode'], matches(RegExp(r'^[A-F0-9]{8}$')));
        expect(
          body['message'],
          'The score looks wrong.\nHere are the steps:\n1. Play a match.',
        );
        return http.Response('{"received":true}', 201);
      };
      await tester.pumpWidget(_app(SupportScreen(controller: controller)));
      await _settleIo(tester);
      await tester.enterText(
        find.byKey(const Key('feedback-message')),
        'The score looks wrong.\nHere are the steps:\n1. Play a match.',
      );
      await _reveal(tester, find.byKey(const Key('feedback-send')));
      await tester.tap(find.byKey(const Key('feedback-send')));
      await _settleIo(tester);
      expect(requests, hasLength(1));
      expect(
        await tester.runAsync(() => store.getPreference('ui.supportDraft')),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late feedback acknowledgement preserves a newer failed report', (
    tester,
  ) async {
    final firstResponse = Completer<http.Response>();
    respond = (request) async {
      if (requests.length == 1) return firstResponse.future;
      return http.Response('{"error":"unavailable"}', 503);
    };
    await tester.pumpWidget(_app(SupportScreen(controller: controller)));
    await _settleIo(tester);
    await tester.enterText(
      find.byKey(const Key('feedback-message')),
      'First report waiting for a response.',
    );
    await _reveal(tester, find.byKey(const Key('feedback-send')));
    await tester.tap(find.byKey(const Key('feedback-send')));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    expect(requests, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(SupportScreen(controller: controller)));
    await _settleIo(tester);
    await tester.enterText(
      find.byKey(const Key('feedback-message')),
      'A newer report that must survive the first acknowledgement.',
    );
    await _reveal(tester, find.byKey(const Key('feedback-send')));
    await tester.tap(find.byKey(const Key('feedback-send')));
    await _settleIo(tester);
    expect(requests, hasLength(2));
    final secondBody = jsonDecode(requests.last.body) as Map;
    expect(
      secondBody['submissionId'],
      isNot((jsonDecode(requests.first.body) as Map)['submissionId']),
    );
    firstResponse.complete(http.Response('{"received":true}', 201));
    await _settleIo(tester);
    final draft = await tester.runAsync(
      () => store.getPreference('ui.supportDraft'),
    ) as Map;
    expect(draft['submissionId'], secondBody['submissionId']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(SupportScreen(controller: controller)));
    await _settleIo(tester);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('feedback-message')))
          .controller!
          .text,
      secondBody['message'],
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    testWidgets(
      'online screens fit 320px at 200 percent in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        controller.account = const ElevenwardAccount(
          id: 'a',
          alias: 'Me',
          provider: 'apple',
        );
        respond = (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/friends')
                ? {
                    'comparisonSharingEnabled': false,
                    'friends': [
                      {
                        'profileId': 'friend',
                        'alias': 'AnotherPlayer',
                        'comparisonAvailable': false,
                        'careers': [],
                      },
                    ],
                    'incomingRequests': [],
                    'outgoingRequests': [],
                    'blocked': [],
                  }
                : {'challenge': _challenge(), 'attempt': null, 'entries': []},
          ),
          200,
        );
        for (final screen in [
          SupportScreen(controller: controller),
          FriendsScreen(controller: controller),
          WeeklyChallengeScreen(controller: controller),
        ]) {
          await tester.pumpWidget(_app(screen, locale: locale));
          await _settleIo(tester);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -2000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  test('all online user-facing strings have four locale translations', () {
    for (final entry in onlineTranslations.entries) {
      expect(
        entry.value.keys,
        containsAll(['en', 'es', 'pt-BR', 'fr']),
        reason: entry.key,
      );
      expect(
        entry.value.values.every((text) => text.trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
    }
  });
}

Map<String, Object?> _challenge() => {
  'id': 'week',
  'startsAt': DateTime.now()
      .toUtc()
      .subtract(const Duration(days: 1))
      .toIso8601String(),
  'endsAt': DateTime.now()
      .toUtc()
      .add(const Duration(days: 7))
      .toIso8601String(),
  'rulesVersion': WeeklyChallenge.rulesVersion,
  'contentVersion': WeeklyChallenge.contentVersion,
  'matchCount': 8,
  'configuration': {},
};

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> _settleIo(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
