import 'dart:io';

import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String path;
  late CareerStore store;
  late AppController controller;
  late CareerSnapshot initial;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('elevenward-gameplay-');
    path = '${directory.path}/career.sqlite';
    store = await CareerStore.open(path: path, factory: databaseFactoryFfi);
    final credentials = SecureCredentials();
    final api = ElevenwardApi(accessToken: credentials.readAccountToken);
    final content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    initial = CareerSnapshot.newCareer(careerId: 'persisted-focus');
    await store.saveSlot(0, initial);
    await store.saveWeeklyFocus(initial.careerId, PlayerAttribute.stamina);
    await controller.openSlot(0);
    addTearDown(() async {
      controller.dispose();
      content.close();
      api.close();
      await store.close();
      await directory.delete(recursive: true);
    });
  });

  test(
    'failed focus save retains durable choice and permits a retry',
    () async {
      await _executeRaw(path, '''
      CREATE TRIGGER reject_focus BEFORE INSERT ON app_preferences
      WHEN NEW.key = 'career.persisted-focus.weeklyFocus'
      BEGIN SELECT RAISE(ABORT, 'simulated focus failure'); END
    ''');
      final changing = controller.changeWeeklyFocus(PlayerAttribute.passing);
      expect(controller.activeWeeklyFocus, PlayerAttribute.stamina);
      await expectLater(changing, throwsA(isA<DatabaseException>()));
      expect(controller.activeWeeklyFocus, PlayerAttribute.stamina);
      expect(
        await store.loadWeeklyFocus(initial.careerId),
        PlayerAttribute.stamina,
      );
      expect((await store.loadSlot(0))!.encode(), initial.encode());

      await _executeRaw(path, 'DROP TRIGGER reject_focus');
      await controller.changeWeeklyFocus(PlayerAttribute.passing);
      expect(controller.activeWeeklyFocus, PlayerAttribute.passing);
      expect(
        await store.loadWeeklyFocus(initial.careerId),
        PlayerAttribute.passing,
      );
    },
  );

  test(
    'rapid focus saves retain call order without rewriting the career',
    () async {
      await Future.wait([
        controller.changeWeeklyFocus(PlayerAttribute.passing),
        controller.changeWeeklyFocus(PlayerAttribute.composure),
        controller.changeWeeklyFocus(PlayerAttribute.pace),
      ]);
      expect(controller.activeWeeklyFocus, PlayerAttribute.pace);
      expect(
        await store.loadWeeklyFocus(initial.careerId),
        PlayerAttribute.pace,
      );
      expect((await store.loadSlot(0))!.encode(), initial.encode());
    },
  );

  test('queued focus cannot publish after leaving its career', () async {
    final changing = controller.changeWeeklyFocus(PlayerAttribute.passing);
    controller.showCareerSlots();
    await expectLater(changing, throwsStateError);
    expect(controller.activeCareer, isNull);
    expect(controller.activeWeeklyFocus, PlayerAttribute.finishing);
    expect(
      await store.loadWeeklyFocus(initial.careerId),
      PlayerAttribute.stamina,
    );
  });

  test('queued reviewed choice cannot overwrite an intervening save', () async {
    final first = initial.copyWith(revision: initial.revision + 1, seed: 123);
    final stale = initial.copyWith(revision: initial.revision + 1, seed: 456);
    final accepted = controller.saveCareer(
      first,
      expectedCareerId: initial.careerId,
      expectedRevision: initial.revision,
      expectedGeneration: controller.activeCareerGeneration,
    );
    final rejected = controller.saveCareer(
      stale,
      expectedCareerId: initial.careerId,
      expectedRevision: initial.revision,
      expectedGeneration: controller.activeCareerGeneration,
    );
    await Future.wait([accepted, expectLater(rejected, throwsStateError)]);
    expect(controller.activeCareer!.encode(), first.encode());
    expect((await store.loadSlot(0))!.encode(), first.encode());

    final next = first.copyWith(revision: first.revision + 1, seed: 789);
    await controller.saveCareer(
      next,
      expectedCareerId: first.careerId,
      expectedRevision: first.revision,
    );
    expect((await store.loadSlot(0))!.encode(), next.encode());
  });

  test('review identity guard rejects a different current career', () async {
    await expectLater(
      controller.saveCareer(
        initial.copyWith(revision: initial.revision + 1),
        expectedCareerId: 'another-career',
        expectedRevision: initial.revision,
      ),
      throwsStateError,
    );
    expect((await store.loadSlot(0))!.encode(), initial.encode());
  });
}

Future<void> _executeRaw(String path, String statement) async {
  final database = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  try {
    await database.execute(statement);
  } finally {
    await database.close();
  }
}
