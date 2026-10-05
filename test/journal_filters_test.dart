import 'dart:ui' show CheckedState;

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
import 'package:flutter/rendering.dart';
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

MatchJournalEntry _match(
  String id,
  String? competition, {
  bool appeared = true,
}) => MatchJournalEntry(
  id: id,
  season: 1,
  week: 3,
  clubName: 'Recorded home club',
  opponentName: 'Recorded opponent $id',
  isHome: true,
  homeScore: 2,
  awayScore: 1,
  rating: appeared ? 7.4 : 0,
  goals: appeared ? 1 : 0,
  assists: 0,
  appeared: appeared,
  headline: 'Recorded headline',
  report: 'Recorded match report',
  roleStats: const RoleStats(),
  competitionId: competition,
);

const _decision = DecisionJournalEntry(
  eventId: 'fixture-event',
  choiceId: 'fixture-choice',
  season: 1,
  week: 2,
  title: 'Recorded career decision',
  choiceLabel: 'Recorded choice',
  outcome: 'Recorded consequence',
);

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 15000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _expectCompleteCompetitionLabel(
  WidgetTester tester,
  String key,
  String text, {
  bool requireMultiline = true,
}) async {
  await _tap(tester, key);
  final control = find.byKey(Key(key));
  final label = find.descendant(of: control, matching: find.text(text));
  expect(label, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(label);
  expect(paragraph.text.toPlainText(), text);
  expect(paragraph.maxLines, isNull);
  expect(paragraph.didExceedMaxLines, isFalse);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  // These full names require multiple lines at 320px/200%; a one-line chip
  // can have a valid label rectangle while still fading most of its text.
  if (requireMultiline) {
    expect(boxes.length, greaterThan(1));
  } else {
    expect(boxes, isNotEmpty);
  }
  final controlBounds = tester.getRect(control);
  expect(controlBounds.height, greaterThanOrEqualTo(48));
  // Flutter's text painter permits trailing line-end spaces to extend past
  // paint bounds. Check each painted word without those blank selection areas.
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final wordBoxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    // The test font uses square glyphs; a single long word can exceed the
    // entire 320px surface at 200%. Native captures review actual-font wrapping.
    expect(wordBoxes, isNotEmpty, reason: 'Visible word: ${word.group(0)}');
    for (final box in wordBoxes) {
      final start = paragraph.localToGlobal(box.toRect().topLeft);
      final end = paragraph.localToGlobal(box.toRect().bottomRight);
      expect(start.dx, greaterThanOrEqualTo(controlBounds.left));
      expect(end.dx, lessThanOrEqualTo(controlBounds.right));
      expect(start.dy, greaterThanOrEqualTo(controlBounds.top));
      expect(end.dy, lessThanOrEqualTo(controlBounds.bottom));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;
  late CareerSnapshot fixture;
  late String cupId;
  late String internationalId;

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
    cupId = buildLatestContent().world.domesticCups.first.id;
    internationalId =
        buildLatestContent().world.internationalClubCompetition.id;
    fixture = CareerSnapshot.newCareer().copyWith(
      matchJournal: [
        _match('league', 'england-first'),
        _match('cup', cupId),
        _match('international', internationalId),
        _match('omitted', null, appeared: false),
        _match('unknown', 'archived-competition'),
      ],
      decisionJournal: [_decision],
    );
    controller.activeCareer = fixture;
  });
  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  testWidgets(
    'All preserves mixed history and filters show the selected kind',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final committedJson = fixture.encode();
      await tester.pumpWidget(
        _app(CareerJournalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('journal-filter-all')))
            .selected,
        isTrue,
      );
      expect(find.byKey(const Key('journal-match-league')), findsOneWidget);
      expect(find.text('Recorded career decision'), findsOneWidget);
      expect(find.byKey(const Key('journal-competition-all')), findsNothing);

      await _tap(tester, 'journal-filter-matches');
      expect(find.byKey(const Key('journal-match-cup')), findsOneWidget);
      expect(find.text('Recorded career decision'), findsNothing);
      expect(find.byKey(const Key('journal-competition-all')), findsOneWidget);

      await _tap(tester, 'journal-filter-decisions');
      expect(find.byKey(const Key('journal-match-league')), findsNothing);
      expect(find.text('Recorded career decision'), findsOneWidget);
      expect(find.byKey(const Key('journal-competition-all')), findsNothing);

      await _tap(tester, 'journal-filter-all');
      expect(find.byKey(const Key('journal-match-league')), findsOneWidget);
      expect(find.text('Recorded career decision'), findsOneWidget);
      expect(controller.activeCareer!.encode(), committedJson);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'competition filters preserve omitted and archived unknown matches',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(CareerJournalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'journal-filter-matches');
      await _tap(tester, 'journal-competition-england-first');
      expect(find.byKey(const Key('journal-match-league')), findsOneWidget);
      expect(find.byKey(const Key('journal-match-cup')), findsNothing);
      expect(find.byKey(const Key('journal-match-omitted')), findsNothing);
      await _tap(tester, 'journal-competition-$cupId');
      expect(find.byKey(const Key('journal-match-cup')), findsOneWidget);
      expect(find.byKey(const Key('journal-match-league')), findsNothing);
      await _tap(tester, 'journal-competition-other');
      expect(find.byKey(const Key('journal-match-omitted')), findsOneWidget);
      expect(find.byKey(const Key('journal-match-unknown')), findsOneWidget);
      expect(find.byKey(const Key('journal-match-league')), findsNothing);
      expect(find.textContaining('Did not appear'), findsOneWidget);
      expect(find.textContaining('archived-competition'), findsNothing);
      await _tap(tester, 'journal-competition-all');
      expect(find.byKey(const Key('journal-match-league')), findsOneWidget);
      expect(find.byKey(const Key('journal-match-cup')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pruned history clears unavailable competition without hiding matches',
    (tester) async {
      await tester.pumpWidget(
        _app(CareerJournalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'journal-filter-matches');
      await _tap(tester, 'journal-competition-england-first');
      controller.activeCareer = fixture.copyWith(
        matchJournal: [_match('cup', cupId)],
        revision: fixture.revision + 1,
      );
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('journal-competition-england-first')),
        findsNothing,
      );
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.byKey(const Key('journal-competition-all')),
            )
            .selected,
        isTrue,
      );
      expect(find.byKey(const Key('journal-match-cup')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching career resets filters and archives use their own journal',
    (tester) async {
      await tester.pumpWidget(
        _app(CareerJournalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'journal-filter-decisions');
      controller.activeCareer = CareerSnapshot.newCareer(careerId: 'new-career')
          .copyWith(matchJournal: [_match('new', 'england-first')]);
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('journal-filter-all')))
            .selected,
        isTrue,
      );
      expect(find.byKey(const Key('journal-match-new')), findsOneWidget);
      final archive = CareerSnapshot.newCareer(careerId: 'archived-career')
          .copyWith(
            retired: true,
            phase: CareerPhase.retired,
            matchJournal: [_match('archive', null)],
            decisionJournal: fixture.decisionJournal,
          );
      await tester.pumpWidget(
        _app(
          CareerJournalScreen(controller: controller, archivedCareer: archive),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'journal-filter-matches');
      await _tap(tester, 'journal-competition-other');
      expect(find.byKey(const Key('journal-match-archive')), findsOneWidget);
      expect(find.byKey(const Key('journal-match-new')), findsNothing);
      await _tap(tester, 'journal-match-archive');
      expect(find.byKey(const Key('journal-match-screen')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty filtered kind explains how to add entries and restores history',
    (tester) async {
      controller.activeCareer = fixture.copyWith(decisionJournal: []);
      await tester.pumpWidget(
        _app(CareerJournalScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'journal-filter-decisions');
      expect(find.byKey(const Key('journal-filter-empty')), findsOneWidget);
      expect(find.textContaining('Confirmed career choices'), findsOneWidget);
      await _tap(tester, 'journal-show-all');
      expect(find.byKey(const Key('journal-match-league')), findsOneWidget);
      controller.activeCareer = fixture.copyWith(matchJournal: []);
      controller.notifyListeners();
      await tester.pumpAndSettle();
      await _tap(tester, 'journal-filter-matches');
      expect(find.textContaining('Completed matches'), findsOneWidget);
      expect(find.byKey(const Key('journal-competition-all')), findsNothing);
      await _tap(tester, 'journal-show-all');
      expect(find.text('Recorded career decision'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (locale, allLabel, allCompetitionsLabel) in const [
    (Locale('en'), 'All', 'All competitions'),
    (Locale('es'), 'Todas', 'Todas las competiciones'),
    (Locale('pt', 'BR'), 'Todas', 'Todas as competições'),
    (Locale('fr'), 'Toutes', 'Toutes les compétitions'),
  ]) {
    testWidgets(
      'journal filters fit 320px at 200% in ${locale.toLanguageTag()}',
      (tester) async {
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
          await _tap(tester, 'journal-filter-matches');
          await _expectCompleteCompetitionLabel(
            tester,
            'journal-competition-all',
            allLabel,
            requireMultiline: false,
          );
          final selectedAll = tester
              .getSemantics(find.byKey(const Key('journal-competition-all')))
              .getSemanticsData();
          expect(selectedAll.label, allCompetitionsLabel);
          expect(selectedAll.flagsCollection.isChecked, CheckedState.isTrue);
          expect(
            selectedAll.flagsCollection.isInMutuallyExclusiveGroup,
            isTrue,
          );
          final world = buildLatestContent().world;
          await _expectCompleteCompetitionLabel(
            tester,
            'journal-competition-$cupId',
            world.domesticCups.first.name,
          );
          await _expectCompleteCompetitionLabel(
            tester,
            'journal-competition-$internationalId',
            world.internationalClubCompetition.name,
          );
          await _expectCompleteCompetitionLabel(
            tester,
            'journal-competition-england-first',
            'English Premier Division',
          );
          await _tap(tester, 'journal-match-league');
          expect(find.byKey(const Key('journal-match-screen')), findsOneWidget);
          final backButton = find.byType(BackButton);
          expect(backButton, findsOneWidget);
          await tester.tap(backButton);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('journal-match-screen')), findsNothing);
          expect(
            find.byKey(const Key('career-journal-screen')),
            findsOneWidget,
          );
          await _tap(tester, 'journal-filter-decisions');
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, -1000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
