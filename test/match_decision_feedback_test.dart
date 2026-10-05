import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/match_feedback.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward/src/widgets/match_decision_feedback.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feedback reads the committed preview without altering its result', () {
    for (final seed in [1, 5, 9, 14]) {
      final result = _result(seed: seed);
      final encoded = result.snapshot.encode();
      final factors = result.preview.factors.toList();
      expect(result.selection.status, isNot(SelectionStatus.omitted));
      for (final locale in ['en', 'es', 'pt-BR', 'fr']) {
        final summary = matchDecisionSummary(result, locale);
        expect(
          summary.probability,
          contains('${result.preview.chanceLow}–${result.preview.chanceHigh}%'),
        );
        expect(
          summary.outcome,
          uiCopy(
            locale,
            result.spotlightSucceeded
                ? 'spotlightOutcomeSuccess'
                : 'spotlightOutcomeFailure',
          ),
        );
        expect(summary.influences.length, lessThanOrEqualTo(2));
        expect(summary.influences, isNotEmpty);
      }
      expect(result.snapshot.encode(), encoded);
      expect(result.preview.factors, factors);
    }
  });

  test('omitted players get selection evidence and no invented spotlight', () {
    final result = _result(omitted: true);
    expect(result.selection.status, SelectionStatus.omitted);
    for (final locale in ['en', 'es', 'pt-BR', 'fr']) {
      final summary = matchDecisionSummary(result, locale);
      expect(summary.probability, isNull);
      expect(summary.outcome, playerMatchLine(result, locale));
      expect(
        summary.influences.join(' '),
        contains(localizedFactor(locale, 'Manager trust')),
      );
    }
    final headline = matchHeadline(result, 'en', result.snapshot.clubName);
    expect(headline, startsWith('${result.snapshot.clubName}:'));
    expect(headline, isNot(contains(result.snapshot.player.name)));
    final match = result.snapshot.matchJournal.first;
    expect(journalMatchHeadline(match, 'en'), startsWith('${match.clubName}:'));
  });

  test(
    'English cup reports describe the result without awarding league points',
    () {
      final result = _result(kind: CompetitionKind.domesticCup);
      final report = matchReport(result, 'en', result.snapshot.clubName);
      expect(report, contains(matchNumbers(result, 'en')));
      expect(report, isNot(contains('three points')));
      expect(report, isNot(contains('shared the points')));
    },
  );

  testWidgets('decision recap fits 320px at 200% in all locales and modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      ElevenwardColors.use(brightness);
      for (final locale in AppLocalizations.supportedLocales) {
        for (final omitted in [false, true]) {
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildElevenwardTheme('graphite', brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MatchDecisionFeedback(
                    result: _result(omitted: omitted),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$locale $brightness');
          expect(
            find.byKey(const Key('match-decision-feedback')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('match-decision-probability')),
            omitted ? findsNothing : findsOneWidget,
          );
        }
      }
    }
    ElevenwardColors.use(Brightness.dark);
  });
}

WeeklyResult _result({
  bool omitted = false,
  int seed = 1,
  CompetitionKind kind = CompetitionKind.league,
}) {
  final base = CareerSnapshot.newCareer(seed: seed);
  final career = base.copyWith(
    player: base.player.copyWith(
      managerTrust: omitted ? 0 : 90,
      form: omitted ? 0 : 90,
      fitness: omitted ? 10 : 85,
    ),
  );
  final normalOpponent = const WorldSimulator().opponentFor(career);
  final opponent = OpponentContext(
    clubId: normalOpponent.clubId,
    clubName: normalOpponent.clubName,
    quality: normalOpponent.quality,
    tacticalFit: normalOpponent.tacticalFit,
    isHome: normalOpponent.isHome,
    competitionId: normalOpponent.competitionId,
    competitionKind: kind,
  );
  return const WeeklySimulator().advance(
    snapshot: career,
    choice: const WeeklyChoice(
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.balanced,
      spotlightApproach: SpotlightApproach.bold,
    ),
    opponent: opponent,
    updatedAt: DateTime.utc(2026, 10, 1),
  );
}
