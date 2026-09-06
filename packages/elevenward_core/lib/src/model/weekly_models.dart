import '../world/world_models.dart';
import 'career_snapshot.dart';
import 'enums.dart';

final class WeeklyChoice {
  const WeeklyChoice({
    required this.focus,
    required this.intensity,
    required this.spotlightApproach,
  });

  final PlayerAttribute focus;
  final TrainingIntensity intensity;
  final SpotlightApproach spotlightApproach;
}

final class OpponentContext {
  const OpponentContext({
    required this.clubId,
    required this.clubName,
    required this.quality,
    required this.tacticalFit,
    required this.isHome,
    this.competitionId,
    this.competitionKind = CompetitionKind.league,
  });

  final String clubId;
  final String clubName;
  final int quality;
  final int tacticalFit;
  final bool isHome;
  final String? competitionId;
  final CompetitionKind competitionKind;
}

final class OutcomeFactor {
  const OutcomeFactor({
    required this.label,
    required this.detail,
    required this.impact,
  });

  final String label;
  final String detail;
  final double impact;
}

final class SpotlightPreview {
  const SpotlightPreview({
    required this.approach,
    required this.chance,
    required this.chanceLow,
    required this.chanceHigh,
    required this.primaryAttributes,
    required this.factors,
  });

  final SpotlightApproach approach;
  final double chance;
  final int chanceLow;
  final int chanceHigh;
  final List<PlayerAttribute> primaryAttributes;
  final List<OutcomeFactor> factors;
}

final class SelectionExplanation {
  const SelectionExplanation({
    required this.status,
    required this.score,
    required this.reasons,
  });

  final SelectionStatus status;
  final double score;
  final List<OutcomeFactor> reasons;
}

final class StatDeltas {
  const StatDeltas({
    required this.rating,
    required this.trust,
    required this.reputation,
    required this.money,
    required this.fitness,
    required this.form,
    required this.goals,
    required this.assists,
  });

  final double rating;
  final int trust;
  final int reputation;
  final int money;
  final int fitness;
  final int form;
  final int goals;
  final int assists;
}

final class WeeklyResult {
  const WeeklyResult({
    required this.snapshot,
    required this.opponent,
    required this.selection,
    required this.preview,
    required this.spotlightSucceeded,
    required this.roll,
    required this.teamResult,
    required this.homeScore,
    required this.awayScore,
    required this.deltas,
    required this.factors,
    required this.headline,
    required this.offPitchTitle,
    required this.offPitchBody,
    required this.sponsorPayout,
    required this.endedSponsorIds,
    required this.fixtureDecision,
  });

  final CareerSnapshot snapshot;
  final OpponentContext opponent;
  final SelectionExplanation selection;
  final SpotlightPreview preview;
  final bool spotlightSucceeded;
  final double roll;
  final TeamResult teamResult;
  final int homeScore;
  final int awayScore;
  final StatDeltas deltas;
  final List<OutcomeFactor> factors;
  final String headline;
  final String offPitchTitle;
  final String offPitchBody;
  final int sponsorPayout;
  final List<String> endedSponsorIds;
  final FixtureDecision fixtureDecision;
}
