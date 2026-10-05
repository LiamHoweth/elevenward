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
import 'package:elevenward/src/training_preset.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String databasePath;
  late _PreferenceFixture fixture;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('elevenward-polish-');
    databasePath = '${directory.path}/preferences.sqlite';
    fixture = await _PreferenceFixture.open(databasePath);
    await fixture.controller.refreshSlots();
  });

  tearDown(() async {
    await fixture.close();
    await directory.delete(recursive: true);
  });

  test('training presets validate enum names and round-trip', () {
    for (final focus in PlayerAttribute.values) {
      for (final intensity in TrainingIntensity.values) {
        final preset = TrainingPreset(focus: focus, intensity: intensity);
        expect(TrainingPreset.fromJson(preset.toJson()), preset);
      }
    }
    for (final value in <Object?>[
      null,
      'passing',
      [],
      {},
      {'focus': 'passing'},
      {'focus': 'passing', 'intensity': 'unknown'},
      {'focus': 'unknown', 'intensity': 'balanced'},
      {'focus': 1, 'intensity': 'balanced'},
      {'focus': 'passing', 'intensity': true},
    ]) {
      expect(TrainingPreset.fromJson(value), isNull);
    }
  });

  test(
    'preferences survive restart without changing saved career or focus',
    () async {
      const preset = TrainingPreset(
        focus: PlayerAttribute.passing,
        intensity: TrainingIntensity.light,
      );
      final career = CareerSnapshot.newCareer(careerId: 'polish-career');
      await fixture.store.saveSlot(0, career);
      await fixture.store.saveWeeklyFocus(
        career.careerId,
        PlayerAttribute.stamina,
      );
      fixture.controller.activeWeeklyFocus = PlayerAttribute.stamina;

      await fixture.controller.saveTrainingPreset(preset);
      await fixture.controller.toggleFavoriteClub('club-a');
      await fixture.controller.toggleFavoriteLeague('league-a');
      expect(fixture.controller.activeWeeklyFocus, PlayerAttribute.stamina);
      expect((await fixture.store.loadSlot(0))!.encode(), career.encode());

      await fixture.close();
      fixture = await _PreferenceFixture.open(databasePath);
      await fixture.controller.refreshSlots();
      expect(fixture.controller.trainingPreset, preset);
      expect(fixture.controller.favoriteClubIds, {'club-a'});
      expect(fixture.controller.favoriteLeagueIds, {'league-a'});
      expect(
        await fixture.store.loadWeeklyFocus(career.careerId),
        PlayerAttribute.stamina,
      );
      expect((await fixture.store.loadSlot(0))!.encode(), career.encode());

      await fixture.controller.clearTrainingPreset();
      await fixture.close();
      fixture = await _PreferenceFixture.open(databasePath);
      await fixture.controller.refreshSlots();
      expect(fixture.controller.trainingPreset, isNull);
      expect(fixture.controller.favoriteClubIds, {'club-a'});
      expect(fixture.controller.favoriteLeagueIds, {'league-a'});
    },
  );

  test(
    'refresh ignores malformed preferences and retains valid favorite IDs',
    () async {
      await fixture.store.setPreference('ui.trainingPreset', {
        'focus': 'unknown',
        'intensity': 'balanced',
      });
      await fixture.store.setPreference('ui.favoriteClubIds', [
        'club-a',
        7,
        null,
        '',
        ' ',
        'club-a',
        'future-content-club',
      ]);
      await fixture.store.setPreference('ui.favoriteLeagueIds', {
        'league-a': true,
      });
      await fixture.controller.refreshSlots();
      expect(fixture.controller.trainingPreset, isNull);
      expect(fixture.controller.favoriteClubIds, {
        'club-a',
        'future-content-club',
      });
      expect(fixture.controller.favoriteLeagueIds, isEmpty);
      expect(
        () => fixture.controller.favoriteClubIds.add('club-b'),
        throwsUnsupportedError,
      );
      expect(
        () => fixture.controller.favoriteLeagueIds.add('league-b'),
        throwsUnsupportedError,
      );

      await _executeRaw(databasePath, '''
      UPDATE app_preferences SET value_json = 'broken json'
      WHERE key IN ('ui.trainingPreset', 'ui.favoriteClubIds', 'ui.favoriteLeagueIds')
    ''');
      await fixture.controller.refreshSlots();
      expect(fixture.controller.trainingPreset, isNull);
      expect(fixture.controller.favoriteClubIds, isEmpty);
      expect(fixture.controller.favoriteLeagueIds, isEmpty);
    },
  );

  test(
    'rapid toggles and preset save-clear updates preserve call order',
    () async {
      const first = TrainingPreset(
        focus: PlayerAttribute.pace,
        intensity: TrainingIntensity.intensive,
      );
      const last = TrainingPreset(
        focus: PlayerAttribute.composure,
        intensity: TrainingIntensity.balanced,
      );
      final operations = <Future<void>>[
        fixture.controller.toggleFavoriteClub('club-a'),
        fixture.controller.toggleFavoriteClub('club-b'),
        fixture.controller.toggleFavoriteClub('club-a'),
        fixture.controller.toggleFavoriteLeague('league-a'),
        fixture.controller.toggleFavoriteLeague('league-b'),
        fixture.controller.toggleFavoriteLeague('league-a'),
        fixture.controller.saveTrainingPreset(first),
        fixture.controller.clearTrainingPreset(),
        fixture.controller.saveTrainingPreset(last),
        fixture.controller.refreshSlots(),
      ];
      expect(fixture.controller.trainingPreset, isNull);
      expect(fixture.controller.favoriteClubIds, isEmpty);
      expect(fixture.controller.favoriteLeagueIds, isEmpty);
      await Future.wait(operations);
      expect(fixture.controller.trainingPreset, last);
      expect(fixture.controller.favoriteClubIds, {'club-b'});
      expect(fixture.controller.favoriteLeagueIds, {'league-b'});
      expect(
        await fixture.store.getPreference('ui.trainingPreset'),
        last.toJson(),
      );
      expect(await fixture.store.getPreference('ui.favoriteClubIds'), [
        'club-b',
      ]);
      expect(await fixture.store.getPreference('ui.favoriteLeagueIds'), [
        'league-b',
      ]);
    },
  );

  test(
    'failed writes publish no changes and do not stall later updates',
    () async {
      const original = TrainingPreset(
        focus: PlayerAttribute.stamina,
        intensity: TrainingIntensity.light,
      );
      const replacement = TrainingPreset(
        focus: PlayerAttribute.strength,
        intensity: TrainingIntensity.intensive,
      );
      await fixture.controller.saveTrainingPreset(original);
      await fixture.controller.toggleFavoriteClub('club-a');
      var publications = 0;
      fixture.controller.addListener(() => publications += 1);
      await _executeRaw(databasePath, '''
      CREATE TRIGGER reject_polish_write BEFORE INSERT ON app_preferences
      WHEN NEW.key IN ('ui.trainingPreset', 'ui.favoriteClubIds')
      BEGIN SELECT RAISE(ABORT, 'simulated preference failure'); END
    ''');
      await expectLater(
        fixture.controller.saveTrainingPreset(replacement),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        fixture.controller.toggleFavoriteClub('club-b'),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        fixture.controller.clearTrainingPreset(),
        throwsA(isA<DatabaseException>()),
      );
      expect(fixture.controller.trainingPreset, original);
      expect(fixture.controller.favoriteClubIds, {'club-a'});
      expect(publications, 0);
      expect(
        await fixture.store.getPreference('ui.trainingPreset'),
        original.toJson(),
      );
      expect(await fixture.store.getPreference('ui.favoriteClubIds'), [
        'club-a',
      ]);

      await _executeRaw(databasePath, 'DROP TRIGGER reject_polish_write');
      await fixture.controller.saveTrainingPreset(replacement);
      await fixture.controller.toggleFavoriteClub('club-b');
      expect(fixture.controller.trainingPreset, replacement);
      expect(fixture.controller.favoriteClubIds, {'club-a', 'club-b'});
      expect(publications, 2);
    },
  );

  test(
    'blank favorite IDs are rejected without changing preferences',
    () async {
      await expectLater(
        fixture.controller.toggleFavoriteClub(''),
        throwsArgumentError,
      );
      await expectLater(
        fixture.controller.toggleFavoriteLeague('  '),
        throwsArgumentError,
      );
      expect(fixture.controller.favoriteClubIds, isEmpty);
      expect(fixture.controller.favoriteLeagueIds, isEmpty);
      expect(await fixture.store.getPreference('ui.favoriteClubIds'), isNull);
      expect(await fixture.store.getPreference('ui.favoriteLeagueIds'), isNull);
    },
  );
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

final class _PreferenceFixture {
  _PreferenceFixture(this.store, this.api, this.content, this.controller);

  final CareerStore store;
  final ElevenwardApi api;
  final ContentService content;
  final AppController controller;
  bool _closed = false;

  static Future<_PreferenceFixture> open(String path) async {
    final store = await CareerStore.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    final api = ElevenwardApi(accessToken: credentials.readAccountToken);
    final content = ContentService(api: api, store: store);
    final controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    return _PreferenceFixture(store, api, content, controller);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  }
}
