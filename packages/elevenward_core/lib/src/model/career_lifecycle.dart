import 'career_snapshot.dart';
import 'career_types.dart';

bool canChooseRetirement(CareerSnapshot snapshot) =>
    !snapshot.retired &&
    snapshot.phase == CareerPhase.offseason &&
    (snapshot.player.age >= 32 || snapshot.season >= 16);

bool mustRetire(CareerSnapshot snapshot) =>
    !snapshot.retired &&
    snapshot.phase == CareerPhase.offseason &&
    (snapshot.season >= 20 || snapshot.player.age > 36);

LegacyVerdict calculateLegacyVerdict(CareerSnapshot snapshot) {
  final player = snapshot.player;
  final trophies = snapshot.seasonHistory.fold<int>(
    0,
    (sum, season) => sum + season.trophies.length,
  );
  final averageRating = snapshot.seasonHistory.isEmpty
      ? 0.0
      : snapshot.seasonHistory.fold<double>(
            0,
            (sum, season) => sum + season.averageRating,
          ) /
          snapshot.seasonHistory.length;
  final score = (player.appearances * 4 +
          player.goals * 12 +
          player.assists * 8 +
          trophies * 180 +
          player.reputation * 9 +
          player.overall * 5 +
          averageRating * 75)
      .round();
  final tier = score >= 6000
      ? LegacyTier.immortal
      : score >= 4200
          ? LegacyTier.worldGreat
          : score >= 2600
              ? LegacyTier.nationalStar
              : score >= 1400
                  ? LegacyTier.clubIcon
                  : LegacyTier.localFavorite;
  final headline = switch (tier) {
    LegacyTier.localFavorite => 'A career the local support will remember.',
    LegacyTier.clubIcon => 'Your name belongs to the club now.',
    LegacyTier.nationalStar => 'You changed how a country saw the game.',
    LegacyTier.worldGreat => 'An era of football carries your signature.',
    LegacyTier.immortal => 'The game will keep telling your story.',
  };
  return LegacyVerdict(
    score: score,
    tier: tier,
    headline: headline,
    reasons: [
      '${player.appearances} senior appearances',
      '${player.goals} goals and ${player.assists} assists',
      '$trophies major trophies',
      '${player.reputation}/100 reputation',
    ],
  );
}

CareerSnapshot retireCareer(CareerSnapshot snapshot, DateTime updatedAt) {
  if (!canChooseRetirement(snapshot) && !mustRetire(snapshot)) {
    throw StateError('Retirement is not available yet.');
  }
  final verdict = calculateLegacyVerdict(snapshot);
  return snapshot.copyWith(
    revision: snapshot.revision + 1,
    updatedAt: updatedAt,
    phase: CareerPhase.retired,
    retired: true,
    legacyScore: verdict.score,
  );
}

String explainRejectedTransfer({
  required int clubQuality,
  required int playerOverall,
  required int reputation,
  required int tacticalFit,
}) {
  final gaps = <(int, String)>[
    (
      clubQuality - playerOverall,
      'Your current level is below the club’s target.'
    ),
    (55 - reputation, 'The club wants a more established profile.'),
    (60 - tacticalFit, 'The manager sees a weak tactical fit.'),
  ]..sort((left, right) => right.$1.compareTo(left.$1));
  return gaps.first.$1 > 0
      ? gaps.first.$2
      : 'The club filled the available squad role before talks concluded.';
}
