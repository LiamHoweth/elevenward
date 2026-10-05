import 'package:elevenward_core/elevenward_core.dart';

import 'league_presentation.dart';
import 'ui_copy.dart';

/// Read-only projections of existing records. None of these award rewards or
/// write simulation state, and all work with old career snapshots.
enum CareerMilestoneKind { appearances, goals, assists, caps, trophies }

typedef CareerMilestone = ({CareerMilestoneKind kind, int value});
typedef CareerTarget = ({CareerMilestoneKind kind, int current, int goal});

// Targets and the post-match milestone recap share the same thresholds. Keeping
// them together prevents an automatic target from rolling over unnoticed.
const _careerMilestoneThresholds = {
  CareerMilestoneKind.appearances: [1, 10, 25, 50, 100, 200, 300, 400, 500],
  CareerMilestoneKind.goals: [1, 10, 25, 50, 100, 200, 300],
  CareerMilestoneKind.assists: [1, 10, 25, 50, 100, 200],
  CareerMilestoneKind.caps: [1, 10, 25, 50, 100],
  CareerMilestoneKind.trophies: [1, 5, 10, 20],
};

int _milestoneStep(CareerMilestoneKind kind) => switch (kind) {
  CareerMilestoneKind.appearances ||
  CareerMilestoneKind.goals ||
  CareerMilestoneKind.assists => 100,
  CareerMilestoneKind.caps => 50,
  CareerMilestoneKind.trophies => 10,
};

int _nextMilestoneValue(CareerMilestoneKind kind, int current) {
  final thresholds = _careerMilestoneThresholds[kind]!;
  for (final threshold in thresholds) {
    if (threshold > current) return threshold;
  }
  final step = _milestoneStep(kind);
  return thresholds.last + ((current - thresholds.last) ~/ step + 1) * step;
}

Iterable<int> _crossedMilestoneValues(
  CareerMilestoneKind kind,
  int before,
  int after,
) sync* {
  if (after <= before) return;
  final thresholds = _careerMilestoneThresholds[kind]!;
  for (final value in thresholds) {
    if (before < value && after >= value) yield value;
  }
  final step = _milestoneStep(kind);
  final first = before < thresholds.last
      ? thresholds.last + step
      : thresholds.last + ((before - thresholds.last) ~/ step + 1) * step;
  for (var value = first; value <= after; value += step) {
    yield value;
  }
}

List<String> currentSeasonTrophies(CareerSnapshot career) {
  final clubSeasonComplete = career.phase != CareerPhase.inSeason;
  final leagueId = career.world.leagueIdForClub(career.clubId);
  final table = career.world.table(leagueId);
  return [
    if (clubSeasonComplete &&
        table.first.played > 0 &&
        table.first.clubId == career.clubId)
      'league-title',
    for (final competition in career.world.competitions.values)
      if (competition.kind == CompetitionKind.nationalTournament
          ? competition.winnerId == career.player.nationalTeamId &&
                (competition.id == 'major-national-tournament'
                    ? career.nationalTeam.acceptedFor(career.season)
                    : career.world.nationalTournamentHistory.any(
                        (entry) =>
                            entry.season == career.season &&
                            entry.winnerId == career.player.nationalTeamId &&
                            entry.playerAppearances > 0,
                      ))
          : competition.winnerId == career.clubId)
        competition.id,
  ];
}

int _metric(CareerSnapshot career, CareerMilestoneKind kind) => switch (kind) {
  CareerMilestoneKind.appearances => career.player.appearances,
  CareerMilestoneKind.goals => career.player.goals,
  CareerMilestoneKind.assists => career.player.assists,
  CareerMilestoneKind.caps => career.nationalTeam.caps,
  CareerMilestoneKind.trophies =>
    career.seasonHistory.fold<int>(0, (total, s) => total + s.trophies.length) +
        (career.seasonHistory.any((s) => s.season == career.world.season)
            ? 0
            : currentSeasonTrophies(career).length),
};

CareerTarget? careerTarget(CareerSnapshot career) {
  if (career.retired) return null;
  final kind = career.player.appearances < 1
      ? CareerMilestoneKind.appearances
      : switch (career.player.position) {
          PositionFamily.striker => CareerMilestoneKind.goals,
          PositionFamily.winger ||
          PositionFamily.midfielder => CareerMilestoneKind.assists,
          PositionFamily.defender => CareerMilestoneKind.appearances,
        };
  final current = _metric(career, kind);
  return (
    kind: kind,
    current: current,
    goal: _nextMilestoneValue(kind, current),
  );
}

List<CareerMilestone> careerMilestones(
  CareerSnapshot before,
  CareerSnapshot after,
) {
  if (before.careerId != after.careerId) return const [];
  return [
    for (final kind in CareerMilestoneKind.values)
      for (final value in _crossedMilestoneValues(
        kind,
        _metric(before, kind),
        _metric(after, kind),
      ))
        (kind: kind, value: value),
  ];
}

String milestoneLabel(String locale, CareerMilestoneKind kind) =>
    uiCopy(locale, switch (kind) {
      CareerMilestoneKind.appearances => 'apps',
      CareerMilestoneKind.goals => 'goals',
      CareerMilestoneKind.assists => 'assists',
      CareerMilestoneKind.caps => 'caps',
      CareerMilestoneKind.trophies => 'trophies',
    });

String nextMatchStakes(
  CareerSnapshot career,
  OpponentContext opponent,
  WorldDefinition world,
  String locale,
) {
  final competition = career.world.competitions[opponent.competitionId];
  if (opponent.competitionKind != CompetitionKind.league) {
    final name = switch (opponent.competitionKind) {
      CompetitionKind.domesticCup =>
        world.domesticCups
                .where((c) => c.id == opponent.competitionId)
                .firstOrNull
                ?.name ??
            uiCopy(locale, 'domesticCup'),
      CompetitionKind.internationalClub => uiCopy(locale, 'internationalClub'),
      CompetitionKind.nationalQualifier => uiCopy(locale, 'nationalQualifier'),
      CompetitionKind.nationalTournament => uiCopy(locale, 'worldNationsTitle'),
      CompetitionKind.league => '',
    };
    // Matchweeks encode rounds in domestic cups; continental/national stages
    // have their own schedule, so do not invent a knockout label for them.
    final stage = competition == null
        ? ''
        : competition.kind != CompetitionKind.domesticCup &&
              competition.stage == 0
        ? uiCopy(locale, 'groupStage')
        : '${uiCopy(locale, 'knockoutRound')} ${competition.stage + (competition.kind == CompetitionKind.domesticCup ? 1 : 0)}';
    return [name, if (stage.isNotEmpty) stage].join(' · ');
  }
  final leagueId = career.world.leagueParticipants.entries
      .where((e) => e.value.contains(career.clubId))
      .firstOrNull
      ?.key;
  if (leagueId == null || !career.world.leagueRecords.containsKey(leagueId)) {
    return '';
  }
  final league = world.leagues.where((l) => l.id == leagueId).firstOrNull;
  final table = career.world.table(leagueId);
  final playerIndex = table.indexWhere((row) => row.clubId == career.clubId);
  final rivalIndex = table.indexWhere((row) => row.clubId == opponent.clubId);
  if (playerIndex < 0) return '';
  final details = <String>[
    if (league != null) leagueDisplayName(league),
    '${uiCopy(locale, 'opponentRank')} ${rivalIndex < 0 ? '—' : '#${rivalIndex + 1}'}',
  ];
  if (league?.division == DivisionLevel.second &&
      table.length > 2 &&
      table.any((row) => row.played > 0)) {
    final gap = table[1].points - table[playerIndex].points;
    details.add(
      playerIndex < 2
          ? uiCopy(locale, 'promotionPlaces')
          : '${uiCopy(locale, 'promotionGap')} $gap',
    );
  }
  return details.join(' · ');
}

/// Comparisons stay meaningful even if a player moved clubs between seasons.
String seasonComparison(
  String locale,
  SeasonSummary current,
  SeasonSummary previous,
) {
  String signed(num value) => '${value >= 0 ? '+' : '−'}${value.abs()}';
  return '${uiCopy(locale, 'versusPreviousSeason')} ${previous.season}: '
      '${signed(current.goals - previous.goals)} ${uiCopy(locale, 'goals')} · '
      '${signed(current.assists - previous.assists)} ${uiCopy(locale, 'assists')} · '
      '${signed(double.parse((current.averageRating - previous.averageRating).toStringAsFixed(1)))} ${uiCopy(locale, 'rating')} · '
      '${signed(current.trophies.length - previous.trophies.length)} ${uiCopy(locale, 'trophies')}';
}
