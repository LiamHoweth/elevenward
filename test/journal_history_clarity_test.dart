import 'dart:ui' show Tristate;

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/career_journal_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
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
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite', Brightness.dark),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

MatchJournalEntry _match(String id, {required int season, required int week}) =>
    MatchJournalEntry(
      id: id,
      season: season,
      week: week,
      clubName: 'Recorded home club',
      opponentName: 'Recorded opponent $id',
      isHome: true,
      homeScore: 2,
      awayScore: 1,
      rating: 7.4,
      goals: 1,
      assists: 0,
      appeared: true,
      headline: 'Recorded headline',
      report: 'Recorded match report',
      roleStats: const RoleStats(),
      competitionId: 'england-first',
    );

DecisionJournalEntry _decision({
  required int season,
  String title = 'Recorded decision',
  Map<String, num> effects = const {},
}) => DecisionJournalEntry(
  eventId: 'fixture-event-$season',
  choiceId: 'fixture-choice',
  season: season,
  week: 2,
  title: title,
  choiceLabel: 'Recorded choice',
  outcome: 'Recorded narrative consequence',
  effects: effects,
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.drag(find.byType(Scrollable).last, const Offset(0, 10000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).last,
    maxScrolls: 60,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;
  late CareerSnapshot fixture;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    ElevenwardColors.use(Brightness.dark);
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => null,
      client: MockClient((_) async => http.Response('{}', 404)),
    );
    content = ContentService(api: api, store: store);
    final credentials = SecureCredentials();
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    fixture = CareerSnapshot.newCareer().copyWith(
      matchJournal: [
        _match('new-season', season: 2, week: 1),
        _match('national-final', season: 1, week: 3),
        _match('national-group', season: 1, week: 1),
        _match('club-final', season: 1, week: 38),
      ],
      decisionJournal: [
        _decision(season: 2, title: 'New season decision'),
        _decision(season: 1, title: 'Earlier decision'),
      ],
    );
    controller.activeCareer = fixture;
  });
  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  testWidgets('season filter keeps exact committed postseason chronology', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final before = fixture.encode();
    await tester.pumpWidget(_app(CareerJournalScreen(controller: controller)));
    await tester.pumpAndSettle();
    await _tap(tester, 'journal-season-1');

    expect(find.byKey(const Key('journal-match-new-season')), findsNothing);
    expect(find.text('New season decision'), findsNothing);
    expect(find.text('Earlier decision'), findsOneWidget);
    expect(find.text('Matches: 3 · Decisions: 1'), findsOneWidget);
    final ids = ['national-final', 'national-group', 'club-final'];
    final positions = [
      for (final id in ids)
        tester.getTopLeft(find.byKey(Key('journal-match-$id'))).dy,
    ];
    expect(positions[0], lessThan(positions[1]));
    expect(positions[1], lessThan(positions[2]));
    await _tap(tester, 'journal-season-all');
    expect(find.text('Matches: 4 · Decisions: 2'), findsOneWidget);
    expect(find.byKey(const Key('journal-match-new-season')), findsOneWidget);
    expect(controller.activeCareer!.encode(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters explain empty subsets and clear season with show all', (
    tester,
  ) async {
    controller.activeCareer = fixture.copyWith(
      decisionJournal: [_decision(season: 2)],
    );
    await tester.pumpWidget(_app(CareerJournalScreen(controller: controller)));
    await tester.pumpAndSettle();
    await _tap(tester, 'journal-season-1');
    await _tap(tester, 'journal-filter-decisions');
    await _reveal(tester, find.byKey(const Key('journal-filter-empty')));
    expect(
      find.textContaining('No entries match these filters'),
      findsOneWidget,
    );
    await _tap(tester, 'journal-show-all');
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('journal-season-all')))
          .selected,
      isTrue,
    );
    await _reveal(tester, find.text('Recorded decision'));
    expect(find.text('Recorded decision'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('career replacement and evicted seasons reset stale selection', (
    tester,
  ) async {
    await tester.pumpWidget(_app(CareerJournalScreen(controller: controller)));
    await tester.pumpAndSettle();
    await _tap(tester, 'journal-season-1');
    controller.activeCareer = fixture.copyWith(
      matchJournal: [_match('season-3', season: 3, week: 1)],
      decisionJournal: [_decision(season: 2)],
    );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('journal-season-all')))
          .selected,
      isTrue,
    );
    await _tap(tester, 'journal-season-2');
    await _tap(tester, 'journal-filter-decisions');
    controller.activeCareer =
        CareerSnapshot.newCareer(careerId: 'replacement-career').copyWith(
          matchJournal: fixture.matchJournal,
          decisionJournal: fixture.decisionJournal,
        );
    controller.notifyListeners();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('journal-season-all')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('journal-filter-all')))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recorded narrative accompanies actual effects and zero effects',
    (tester) async {
      controller.activeCareer = fixture.copyWith(
        matchJournal: [],
        decisionJournal: [
          _decision(season: 2, effects: {'reputation': 2}),
        ],
      );
      await tester.pumpWidget(
        _app(CareerJournalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recorded narrative consequence'), findsOneWidget);
      expect(find.text('reputation: +2'), findsOneWidget);
      expect(find.text('Saved effects'), findsOneWidget);
      controller.activeCareer = fixture.copyWith(
        matchJournal: [],
        decisionJournal: [
          _decision(season: 2, effects: {'reputation': 0}),
        ],
      );
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Recorded narrative consequence'), findsOneWidget);
      expect(find.text('No stat changes from this choice.'), findsOneWidget);
      expect(find.text('Saved effects'), findsNothing);
      expect(find.text('reputation: +0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (locale, allSeasons, seasonLabel) in const [
    (Locale('en'), 'All seasons', 'Season 1'),
    (Locale('es'), 'Todas las temporadas', 'Temporada 1'),
    (Locale('pt', 'BR'), 'Todas as temporadas', 'Temporada 1'),
    (Locale('fr'), 'Toutes les saisons', 'Saison 1'),
  ]) {
    testWidgets('season controls fit 320px/200% in $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _app(CareerJournalScreen(controller: controller), locale: locale),
        );
        await tester.pumpAndSettle();
        await _reveal(tester, find.byKey(const Key('journal-season-all')));
        expect(
          tester
              .getSemantics(find.byKey(const Key('journal-season-all')))
              .label,
          allSeasons,
        );
        await _tap(tester, 'journal-season-1');
        final selection = tester
            .getSemantics(find.byKey(const Key('journal-season-1')))
            .getSemanticsData();
        expect(selection.label, seasonLabel);
        expect(selection.flagsCollection.isSelected, Tristate.isTrue);
        final control = tester.getRect(
          find.byKey(const Key('journal-season-1')),
        );
        expect(control.left, greaterThanOrEqualTo(0));
        expect(control.right, lessThanOrEqualTo(320));
        expect(control.height, greaterThanOrEqualTo(48));
        await _reveal(
          tester,
          find.byKey(const Key('journal-match-national-final')),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
