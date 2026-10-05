import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/feature_copy.dart';
import 'package:elevenward/src/screens/hall_of_fame_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => null,
      client: MockClient((_) async => http.Response('{}', 404)),
    );
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
    ElevenwardColors.use(Brightness.dark);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final copyLocale = locale.languageCode == 'pt'
        ? 'pt-BR'
        : locale.languageCode;
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets(
        'archived totals and season records wrap at 200% in $locale $brightness',
        (tester) async {
          _smallLargeText(tester);
          final career = _retiredCareer();
          await tester.pumpWidget(
            _app(
              ArchivedCareerScreen(controller: controller, career: career),
              locale: locale,
              brightness: brightness,
            ),
          );
          await tester.pumpAndSettle();
          await _reveal(
            tester,
            find.byKey(const Key('archived-career-totals')),
          );
          final totals = find.byKey(const Key('archived-career-totals'));
          expect(
            find.descendant(of: totals, matching: find.text('72')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: totals, matching: find.text('32')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: totals, matching: find.text('24')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: totals, matching: find.text('3')),
            findsOneWidget,
          );
          await _reveal(tester, find.byKey(const Key('archived-season-2')));
          final season = find.byKey(const Key('archived-season-2'));
          expect(
            find.descendant(of: season, matching: find.text('7.6')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: season, matching: find.text('1')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: season,
              matching: find.text(uiCopy(copyLocale, 'trophies')),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'archive removal reviews identity and cancel preserves $locale',
      (tester) async {
        _smallLargeText(tester);
        final career = _retiredCareer();
        await tester.runAsync(() => store.saveArchive(career));
        await tester.pumpWidget(
          _app(HallOfFameScreen(controller: controller), locale: locale),
        );
        await tester.runAsync(controller.localHallOfFame);
        await tester.pumpAndSettle();
        final remove = find.byKey(
          Key('remove-archived-career-${career.careerId}'),
        );
        await _reveal(tester, remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(of: dialog, matching: find.text(career.player.name)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text(career.clubName)),
          findsOneWidget,
        );
        final cancelLabel = MaterialLocalizations.of(tester.element(dialog))
            .cancelButtonLabel;
        await tester.tap(find.widgetWithText(TextButton, cancelLabel));
        await tester.pumpAndSettle();
        final archives = await tester.runAsync(controller.localHallOfFame);
        expect(archives?.single.encode(), career.encode());
        expect(tester.widget<TextButton>(remove).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('archive journal navigation uses the reviewed archived career', (
    tester,
  ) async {
    final career = _retiredCareer();
    controller.activeCareer = CareerSnapshot.newCareer(
      careerId: 'a-different-active-career',
      player: PlayerState.newCareer(
        id: 'active-player',
        name: 'Active Player',
        archetype: Archetype.poacher,
      ),
    );
    await tester.pumpWidget(
      _app(ArchivedCareerScreen(controller: controller, career: career)),
    );
    await tester.pumpAndSettle();
    final history = find.widgetWithText(
      OutlinedButton,
      featureCopy('en', 'history'),
    );
    await _reveal(tester, history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-journal-screen')), findsOneWidget);
    expect(
      find.byKey(const Key('journal-match-archived-fixture')),
      findsOneWidget,
    );
    expect(find.text('Active Player'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

CareerSnapshot _retiredCareer() {
  final base = CareerSnapshot.newCareer(
    careerId: 'archived-career-for-layout',
    clubName: 'A Club With a Long Name for Archive Layout',
    player: PlayerState.newCareer(
      id: 'archived-player',
      name: 'Alexandra de la Fontaine',
      archetype: Archetype.poacher,
    ).copyWith(appearances: 72, goals: 32, assists: 24),
  );
  return base.copyWith(
    retired: true,
    phase: CareerPhase.retired,
    seasonHistory: [
      const SeasonSummary(
        season: 1,
        age: 18,
        clubId: 'england-northstar-athletic',
        appearances: 36,
        goals: 12,
        assists: 10,
        averageRating: 7.1,
        trophies: ['League', 'Cup'],
      ),
      const SeasonSummary(
        season: 2,
        age: 19,
        clubId: 'england-northstar-athletic',
        appearances: 36,
        goals: 20,
        assists: 14,
        averageRating: 7.6,
        trophies: ['League'],
      ),
    ],
    matchJournal: [
      const MatchJournalEntry(
        id: 'archived-fixture',
        season: 2,
        week: 4,
        opponentName: 'Archive United',
        clubName: 'Northstar Athletic',
        homeScore: 2,
        awayScore: 1,
        isHome: true,
        appeared: true,
        goals: 1,
        assists: 0,
        rating: 8.2,
        headline: 'Archive victory',
        report: 'An archived match report.',
        roleStats: RoleStats(),
      ),
    ],
  );
}

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite', brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) {
    ElevenwardColors.use(Theme.of(context).brightness);
    return child!;
  },
  home: child,
);

void _smallLargeText(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}
