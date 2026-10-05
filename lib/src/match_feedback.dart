import 'package:elevenward_core/elevenward_core.dart';

import 'ui_copy.dart';

String journalMatchHeadline(MatchJournalEntry match, String locale) {
  if (locale == 'en' && match.appeared) return match.headline;
  final forScore = match.isHome ? match.homeScore : match.awayScore;
  final againstScore = match.isHome ? match.awayScore : match.homeScore;
  return formatUiCopy(locale, 'matchHeadline', {
    'team': match.clubName,
    'result': uiCopy(
      locale,
      forScore == againstScore
          ? 'matchDraw'
          : forScore > againstScore
          ? 'matchWin'
          : 'matchLoss',
    ),
    'opponent': match.opponentName,
  });
}

String journalMatchReport(
  MatchJournalEntry match,
  String locale,
  String playerName,
) {
  if (locale == 'en') return match.report;
  final metrics = match.metrics;
  return [
    journalMatchHeadline(match, locale),
    if (metrics['possession'] is num &&
        metrics['shots'] is num &&
        metrics['shotsOnTarget'] is num &&
        metrics['expectedGoals'] is num &&
        metrics['opponentExpectedGoals'] is num)
      formatUiCopy(locale, 'matchNumbers', {
        'possession': metrics['possession']!,
        'shots': metrics['shots']!,
        'target': metrics['shotsOnTarget']!,
        'xg': (metrics['expectedGoals'] as num).toStringAsFixed(1),
        'opponentXg': (metrics['opponentExpectedGoals'] as num).toStringAsFixed(
          1,
        ),
      }),
    match.appeared
        ? formatUiCopy(locale, 'matchPlayerLine', {
            'player': playerName,
            'goals': match.goals,
            'assists': match.assists,
            'rating': match.rating.toStringAsFixed(1),
          })
        : formatUiCopy(locale, 'matchOmittedLine', {'player': playerName}),
    if (metrics['comeback'] == true) uiCopy(locale, 'matchComeback'),
    if (metrics['lateDrama'] == true) uiCopy(locale, 'matchLateDrama'),
  ].join(' ');
}

// Display copy is derived from the committed result, never from a second roll.
// Authored league reports stay available; cup recaps avoid claims about points.
String matchHeadline(WeeklyResult result, String locale, String team) =>
    locale == 'en' && result.selection.status != SelectionStatus.omitted
    ? result.headline
    : formatUiCopy(locale, 'matchHeadline', {
        'team': team,
        'result': uiCopy(locale, switch (result.teamResult) {
          TeamResult.win => 'matchWin',
          TeamResult.draw => 'matchDraw',
          TeamResult.loss => 'matchLoss',
        }),
        'opponent': result.opponent.clubName,
      });

String matchNumbers(WeeklyResult result, String locale) =>
    formatUiCopy(locale, 'matchNumbers', {
      'possession': result.metrics.possession,
      'shots': result.metrics.shots,
      'target': result.metrics.shotsOnTarget,
      'xg': result.metrics.expectedGoals.toStringAsFixed(1),
      'opponentXg': result.metrics.opponentExpectedGoals.toStringAsFixed(1),
    });

String playerMatchLine(WeeklyResult result, String locale) =>
    result.selection.status == SelectionStatus.omitted
    ? formatUiCopy(locale, 'matchOmittedLine', {
        'player': result.snapshot.player.name,
      })
    : formatUiCopy(locale, 'matchPlayerLine', {
        'player': result.snapshot.player.name,
        'goals': result.deltas.goals,
        'assists': result.deltas.assists,
        'rating': result.deltas.rating.toStringAsFixed(1),
      });

String matchReport(WeeklyResult result, String locale, String team) {
  if (locale == 'en' &&
      result.opponent.competitionKind == CompetitionKind.league) {
    return result.matchReport;
  }
  return [
    matchHeadline(result, locale, team),
    matchNumbers(result, locale),
    playerMatchLine(result, locale),
    if (result.selection.status != SelectionStatus.omitted)
      uiCopy(
        locale,
        result.spotlightSucceeded
            ? 'spotlightOutcomeSuccess'
            : 'spotlightOutcomeFailure',
      ),
    if (result.metrics.comeback) uiCopy(locale, 'matchComeback'),
    if (result.metrics.lateDrama) uiCopy(locale, 'matchLateDrama'),
  ].join(' ');
}

typedef MatchDecisionSummary = ({
  String title,
  String outcome,
  String? probability,
  List<String> influences,
  String context,
});

/// Explains the committed decision using its original preview. The strongest
/// positive/negative factors describe chance or selection, never a match cause.
MatchDecisionSummary matchDecisionSummary(WeeklyResult result, String locale) {
  final omitted = result.selection.status == SelectionStatus.omitted;
  final factors = omitted ? result.selection.reasons : result.preview.factors;
  OutcomeFactor? helpful;
  OutcomeFactor? challenging;
  for (final factor in factors) {
    if (!factor.impact.isFinite) continue;
    if (factor.impact > 0 &&
        (helpful == null || factor.impact > helpful.impact)) {
      helpful = factor;
    }
    if (factor.impact < 0 &&
        (challenging == null || factor.impact < challenging.impact)) {
      challenging = factor;
    }
  }
  return (
    title: matchFeedbackCopy(locale, omitted ? 'selection' : 'decision'),
    outcome: omitted
        ? playerMatchLine(result, locale)
        : uiCopy(
            locale,
            result.spotlightSucceeded
                ? 'spotlightOutcomeSuccess'
                : 'spotlightOutcomeFailure',
          ),
    probability: omitted
        ? null
        : '${uiCopy(locale, switch (result.preview.approach) {
                SpotlightApproach.safe => 'lowRisk',
                SpotlightApproach.balanced => 'balanced',
                SpotlightApproach.bold => 'highRisk',
              })} · '
              '${result.preview.chanceLow}–${result.preview.chanceHigh}% '
              '${matchFeedbackCopy(locale, 'spotlightChance')}',
    influences: List.unmodifiable([
      if (helpful != null)
        '${matchFeedbackCopy(locale, 'helped')}: '
            '${localizedFactor(locale, helpful.label)}',
      if (challenging != null)
        '${matchFeedbackCopy(locale, 'challenged')}: '
            '${localizedFactor(locale, challenging.label)}',
    ]),
    context: matchFeedbackCopy(
      locale,
      omitted ? 'selectionContext' : 'chanceContext',
    ),
  );
}

String matchFeedbackCopy(String locale, String key) {
  final index = switch (locale) {
    'es' => 1,
    'pt-BR' || 'pt' => 2,
    'fr' => 3,
    _ => 0,
  };
  return _matchFeedbackTranslations[key]![index];
}

const _matchFeedbackTranslations = <String, List<String>>{
  'decision': [
    'Your spotlight decision',
    'Tu decisión en la jugada clave',
    'Sua decisão no lance de destaque',
    'Votre décision dans l’action décisive',
  ],
  'selection': [
    'Your selection',
    'Tu convocatoria',
    'Sua escalação',
    'Votre sélection',
  ],
  'spotlightChance': [
    'spotlight chance',
    'de probabilidad en la jugada clave',
    'de chance no lance de destaque',
    'de chances dans l’action décisive',
  ],
  'helped': [
    'Strongest advantage',
    'Mayor ventaja',
    'Maior vantagem',
    'Principal avantage',
  ],
  'challenged': [
    'Strongest challenge',
    'Mayor dificultad',
    'Maior dificuldade',
    'Principal obstacle',
  ],
  'chanceContext': [
    'These factors shaped the spotlight odds, not the team’s chance of winning.',
    'Estos factores influyeron en la probabilidad de la jugada clave, no en la probabilidad de victoria del equipo.',
    'Esses fatores influenciaram a chance no lance de destaque, não a chance de vitória da equipe.',
    'Ces facteurs ont influencé les chances de l’action décisive, pas la probabilité de victoire de l’équipe.',
  ],
  'selectionContext': [
    'These factors shaped the manager’s selection before the match.',
    'Estos factores influyeron en la convocatoria del entrenador antes del partido.',
    'Esses fatores influenciaram a escalação do treinador antes da partida.',
    'Ces facteurs ont influencé la sélection de l’entraîneur avant le match.',
  ],
};

({String title, String body}) matchNews(
  CareerNewsItem story,
  WeeklyResult result,
  String locale,
  String team,
) {
  if (locale == 'en') return (title: story.title, body: story.body);
  return switch (story.category) {
    'match' => (
      title: matchHeadline(result, locale, team),
      body: matchNumbers(result, locale),
    ),
    'player' => (
      title: formatUiCopy(locale, 'newsPlayerTitle', {
        'player': result.snapshot.player.name,
      }),
      body:
          '${playerMatchLine(result, locale)} ${formatUiCopy(locale, 'newsPlayerBody', {'form': result.snapshot.player.form, 'trust': result.snapshot.player.managerTrust})}',
    ),
    'business' => (
      title: uiCopy(locale, 'newsAgentTitle'),
      body: uiCopy(locale, 'newsAgentBody'),
    ),
    _ => (
      title: formatUiCopy(locale, 'newsWorldTitle', {
        'team': result.snapshot.clubName,
        'rank':
            result.snapshot.world
                .table(
                  result.snapshot.world.leagueIdForClub(result.snapshot.clubId),
                )
                .indexWhere((row) => row.clubId == result.snapshot.clubId) +
            1,
      }),
      body: uiCopy(locale, 'newsWorldBody'),
    ),
  };
}
