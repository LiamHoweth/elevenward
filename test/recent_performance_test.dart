import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/recent_performance_strip.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the latest five appearances and displays them oldest first', () {
    final career = CareerSnapshot.newCareer().copyWith(
      matchJournal: [
        _match('omitted', week: 10, appeared: false),
        for (var week = 9; week >= 1; week--)
          _match('match-$week', week: week, rating: week.toDouble()),
      ],
    );
    final before = career.encode();

    expect(recentPlayedMatches(career).map((match) => match.id), [
      'match-5',
      'match-6',
      'match-7',
      'match-8',
      'match-9',
    ]);
    expect(career.encode(), before);
  });

  test('omissions within the journal do not displace played matches', () {
    final career = CareerSnapshot.newCareer().copyWith(
      matchJournal: [
        for (var week = 10; week >= 1; week--)
          _match('match-$week', week: week, appeared: week.isEven),
      ],
    );

    expect(recentPlayedMatches(career).map((match) => match.week), [
      2,
      4,
      6,
      8,
      10,
    ]);
  });

  test('postseason matchday resets preserve committed appearance order', () {
    final career = CareerSnapshot.newCareer().copyWith(
      matchJournal: [
        _match('new-season', season: 2, week: 1),
        _match('national-final', week: 3),
        _match('national-group', week: 1),
        _match('club-final', week: 38),
        _match('club-previous', week: 37),
      ],
    );

    expect(recentPlayedMatches(career).map((match) => match.id), [
      'club-previous',
      'club-final',
      'national-group',
      'national-final',
      'new-season',
    ]);
  });

  test('empty and legacy journals do not manufacture historic ratings', () {
    final base = CareerSnapshot.newCareer();
    final legacy = base.copyWith(
      player: base.player.copyWith(appearances: 120),
    );

    expect(recentPlayedMatches(base), isEmpty);
    expect(recentPlayedMatches(legacy), isEmpty);
    expect(
      recentPlayedMatches(
        base.copyWith(matchJournal: [_match('omitted', appeared: false)]),
      ),
      isEmpty,
    );
    expect(
      recentPlayedMatches(base.copyWith(matchJournal: [_match('only')]))
          .map((match) => match.id),
      ['only'],
    );
  });

  testWidgets('empty state explains how ratings are recorded', (tester) async {
    await tester.pumpWidget(_app(CareerSnapshot.newCareer()));

    expect(
      find.text('Ratings appear here after your next appearance.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('recent-rating-trend')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one rating has an honest state and accessible match details', (
    tester,
  ) async {
    final career = CareerSnapshot.newCareer().copyWith(
      matchJournal: [_match('only', week: 8, rating: 6.8)],
    );
    await tester.pumpWidget(_app(career));

    expect(
      find.text('One recorded appearance. Play another match to see a trend.'),
      findsOneWidget,
    );
    expect(find.text('6.8'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('recent-performance-strip')),
    );
    expect(
      semantics.properties.label,
      contains(
        'Appearance 1, season 1, week 8, against Rival only: 6.8 out of 10',
      ),
    );
    expect(find.byKey(const Key('recent-rating-trend')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${locale.toLanguageTag()} ${brightness.name} fits 320px at 200% text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final career = CareerSnapshot.newCareer().copyWith(
            matchJournal: [
              _match('omitted', appeared: false),
              for (var week = 5; week > 0; week--)
                _match('played-$week', week: week, rating: 10),
            ],
          );

          await tester.pumpWidget(
            _app(career, locale: locale, brightness: brightness),
          );

          expect(find.byKey(const Key('recent-rating-omitted')), findsNothing);
          for (var week = 1; week <= 5; week++) {
            expect(
              find.byKey(Key('recent-rating-played-$week')),
              findsOneWidget,
            );
          }
          final semantics = tester.widget<Semantics>(
            find.byKey(const Key('recent-performance-strip')),
          );
          expect(semantics.properties.label, isNot(contains('Rival omitted')));
          expect(semantics.properties.label, isNot(contains('{count}')));
          if (locale.languageCode != 'en') {
            expect(semantics.properties.label, isNot(contains('Recent match')));
            expect(find.text('1 · 10,0'), findsOneWidget);
          } else {
            expect(find.text('1 · 10.0'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Widget _app(
  CareerSnapshot career, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
}) {
  ElevenwardColors.use(brightness);
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildElevenwardTheme('graphite', brightness),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RecentPerformanceStrip(career: career),
      ),
    ),
  );
}

MatchJournalEntry _match(
  String id, {
  int season = 1,
  int week = 1,
  double rating = 7,
  bool appeared = true,
}) => MatchJournalEntry(
  id: id,
  season: season,
  week: week,
  clubName: 'Player Club',
  opponentName: 'Rival $id',
  isHome: true,
  homeScore: 1,
  awayScore: 0,
  rating: rating,
  goals: 0,
  assists: 0,
  appeared: appeared,
  headline: 'Committed result',
  report: 'Committed report',
  roleStats: const RoleStats(),
);
