import '../content/content_models.dart';
import '../model/career_snapshot.dart';
import '../model/career_types.dart';
import '../model/enums.dart';
import '../model/json_helpers.dart';
import '../model/player_state.dart';
import '../model/weekly_models.dart';
import '../world/world_models.dart';
import 'world_simulator.dart';

final class WeeklySimulator {
  const WeeklySimulator();

  static const _worldSimulator = WorldSimulator();

  SpotlightPreview previewSpotlight({
    required CareerSnapshot snapshot,
    required PlayerAttribute focus,
    required TrainingIntensity intensity,
    required SpotlightApproach approach,
    required OpponentContext opponent,
    SituationOption? situationOption,
  }) {
    final trained = _applyTraining(snapshot.player, focus, intensity);
    return _preview(
      trained,
      approach,
      opponent,
      snapshot.difficulty,
      situationOption: situationOption,
    );
  }

  SelectionExplanation previewSelection({
    required CareerSnapshot snapshot,
    required OpponentContext opponent,
    PlayerAttribute? focus,
    TrainingIntensity intensity = TrainingIntensity.balanced,
  }) {
    final expandedLifeRules =
        snapshot.rulesVersion == CareerSnapshot.currentRulesVersion;
    final player = focus == null
        ? snapshot.player
        : _applyTraining(snapshot.player, focus, intensity);
    final reasons = <OutcomeFactor>[
      OutcomeFactor(
        label: 'Manager trust',
        detail: '${player.managerTrust}/100',
        impact: (player.managerTrust - 50) * 0.30,
      ),
      if (expandedLifeRules)
        OutcomeFactor(
          label: 'Manager relationship',
          detail: '${snapshot.relationships.manager}/100',
          impact: (snapshot.relationships.manager - 50) * 0.12,
        ),
      OutcomeFactor(
        label: 'Current form',
        detail: '${player.form}/100',
        impact: (player.form - 50) * 0.24,
      ),
      OutcomeFactor(
        label: 'Match fitness',
        detail: '${player.fitness}/100',
        impact: (player.fitness - 50) * 0.20,
      ),
      OutcomeFactor(
        label: 'Tactical fit',
        detail: '${opponent.tacticalFit}/100',
        impact: (opponent.tacticalFit - 50) * 0.18,
      ),
      OutcomeFactor(
        label: 'Player level',
        detail: '${player.overall} OVR',
        impact: (player.overall - 50) * 0.18,
      ),
    ];
    final score =
        50 + reasons.fold<double>(0, (sum, item) => sum + item.impact);
    final status = score >= 60
        ? SelectionStatus.starter
        : score >= 48
            ? SelectionStatus.bench
            : SelectionStatus.omitted;
    return SelectionExplanation(
      status: status,
      score: roundTo(score.clamp(0, 100).toDouble(), 1),
      reasons: List.unmodifiable(reasons),
    );
  }

  WeeklyResult advance({
    required CareerSnapshot snapshot,
    required WeeklyChoice choice,
    required OpponentContext opponent,
    required DateTime updatedAt,
    SituationOption? situationOption,
  }) {
    if (snapshot.phase != CareerPhase.inSeason) {
      throw StateError('Only an active season can advance a matchweek.');
    }
    if (situationOption != null &&
        situationOption.approach != choice.spotlightApproach) {
      throw ArgumentError(
          'The authored option must match the chosen approach.');
    }
    final playerAfterTraining = _applyTraining(
      snapshot.player,
      choice.focus,
      choice.intensity,
    );
    final selection = previewSelection(
      snapshot: snapshot,
      opponent: opponent,
      focus: choice.focus,
      intensity: choice.intensity,
    );
    final preview = _preview(
      playerAfterTraining,
      choice.spotlightApproach,
      opponent,
      snapshot.difficulty,
      situationOption: situationOption,
    );
    final rng = _DeterministicRandom(snapshot.seed ^ snapshot.revision);
    final expandedLifeRules =
        snapshot.rulesVersion == CareerSnapshot.currentRulesVersion;
    final roll = roundTo(rng.nextDouble() * 100, 1);
    final selected = selection.status != SelectionStatus.omitted;
    final success = selected && roll < preview.chance;

    final rating = selection.status == SelectionStatus.omitted
        ? 5.8
        : roundTo(
            (success ? 7.65 : 6.15) +
                (success ? situationOption?.ratingUpside ?? 0 : 0) +
                (choice.spotlightApproach == SpotlightApproach.bold
                    ? 0.15
                    : 0) +
                (rng.nextDouble() - 0.5) * 0.5,
            1,
          ).clamp(5.0, 9.8).toDouble();

    final goalChance = success
        ? switch (choice.spotlightApproach) {
            SpotlightApproach.safe => 0.40,
            SpotlightApproach.balanced => 0.62,
            SpotlightApproach.bold => 0.82,
          }
        : 0.05;
    final goals = selected && rng.nextDouble() < goalChance ? 1 : 0;
    final assists =
        selected && success && goals == 0 && rng.nextDouble() < 0.38 ? 1 : 0;

    final authoredTrust = situationOption?.trustRisk ?? 0;
    final trustDelta = selection.status == SelectionStatus.omitted
        ? -1
        : success
            ? 3 + authoredTrust.clamp(0, 2)
            : -1 + authoredTrust.clamp(-2, 0);
    final hasHome =
        expandedLifeRules && snapshot.equippedItemIds.containsKey('home');
    final hasTransportation = expandedLifeRules &&
        snapshot.equippedItemIds.containsKey('transportation');
    final hasStyle =
        expandedLifeRules && snapshot.equippedItemIds.containsKey('style');
    final hasWellness =
        expandedLifeRules && snapshot.equippedItemIds.containsKey('wellness');
    final communityBoost =
        expandedLifeRules && snapshot.relationships.community >= 75 ? 1 : 0;
    final reputationDelta =
        success ? 2 + goals + (hasStyle ? 1 : 0) + communityBoost : 0;
    final formDelta = success ? 3 : -2;
    final moneyDelta = snapshot.contract.weeklyWage +
        (selected ? snapshot.contract.appearanceBonus : 0);
    // This is the net post-match load after ordinary between-week recovery.
    // The training load has already been applied to [playerAfterTraining].
    final postMatchFitnessDelta = switch (selection.status) {
      SelectionStatus.starter => -1,
      SelectionStatus.bench => 3,
      SelectionStatus.omitted => 6,
    };
    final lifestyleFitnessRecovery =
        (hasTransportation ? 1 : 0) + (hasWellness ? 2 : 0);
    final familyFitnessRecovery =
        expandedLifeRules && snapshot.relationships.family >= 75 ? 1 : 0;
    final finalFitness = (playerAfterTraining.fitness +
            postMatchFitnessDelta +
            lifestyleFitnessRecovery +
            familyFitnessRecovery)
        .clamp(1, 100);
    final fitnessDelta = finalFitness - snapshot.player.fitness;
    final roleSatisfactionDelta = switch (snapshot.contract.promisedRole) {
      'important' => selection.status == SelectionStatus.starter ? 3 : -6,
      'rotation' => selection.status == SelectionStatus.omitted ? -3 : 2,
      _ => selection.status == SelectionStatus.omitted ? 0 : 2,
    };
    final payableSponsors = snapshot.sponsorContracts
        .where(
          (contract) =>
              contract.weeksRemaining > 0 &&
              !(contract.obligation == 'maintain-reputation-35' &&
                  snapshot.player.reputation < 35),
        )
        .toList(growable: false);
    final sponsorContracts = payableSponsors
        .where((contract) => contract.weeksRemaining > 1)
        .map(
          (contract) => contract.copyWith(
            weeksRemaining: contract.weeksRemaining - 1,
          ),
        )
        .toList(growable: false);
    final sponsorPayout = payableSponsors.fold<int>(
      0,
      (sum, contract) => sum + contract.weeklyPayout,
    );
    final payableSponsorIds = payableSponsors.map((item) => item.id).toSet();
    final endedSponsorIds = snapshot.sponsorContracts
        .where(
          (contract) =>
              !payableSponsorIds.contains(contract.id) ||
              contract.weeksRemaining == 1,
        )
        .map((contract) => contract.id)
        .toList(growable: false);

    final teamWinChance = (51 +
            (opponent.tacticalFit - opponent.quality) * 0.28 +
            (success ? 10 : -3) +
            (opponent.isHome ? 4 : -2) +
            (expandedLifeRules
                ? (snapshot.relationships.teammates - 50) * 0.08
                : 0))
        .clamp(18, 82)
        .toDouble();
    final teamRoll = rng.nextDouble() * 100;
    TeamResult teamResult;
    if (teamRoll < teamWinChance) {
      teamResult = TeamResult.win;
    } else if (teamRoll < teamWinChance + 24) {
      teamResult = TeamResult.draw;
    } else {
      teamResult = TeamResult.loss;
    }
    final opponentGoals = rng.nextInt(3);
    final playerClubGoals = (switch (teamResult) {
      TeamResult.win => opponentGoals + 1 + rng.nextInt(2),
      TeamResult.draw => opponentGoals,
      TeamResult.loss => (opponentGoals - 1).clamp(0, 4),
    })
        .clamp(goals, 10);
    var rivalGoals =
        teamResult == TeamResult.draw ? playerClubGoals : opponentGoals;
    if (teamResult == TeamResult.loss && rivalGoals <= playerClubGoals) {
      rivalGoals = playerClubGoals + 1;
    }
    var homeScore = opponent.isHome ? playerClubGoals : rivalGoals;
    var awayScore = opponent.isHome ? rivalGoals : playerClubGoals;
    var fixtureDecision = FixtureDecision.regulation;
    final offPitch = _offPitchEvent(success, choice.intensity, rng.nextInt(3));

    final wellnessDelta = expandedLifeRules
        ? (hasHome ? 2 : 0) +
            (hasWellness ? 2 : 0) +
            (snapshot.relationships.family >= 75
                ? 1
                : snapshot.relationships.family < 30
                    ? -2
                    : 0) +
            switch (choice.intensity) {
              TrainingIntensity.light => 1,
              TrainingIntensity.balanced => 0,
              TrainingIntensity.intensive => -2,
            }
        : 0;

    final seasonComplete = snapshot.week == 18;
    final nextWeek = seasonComplete ? 18 : snapshot.week + 1;
    final nextSeason = snapshot.season;
    final nextAge = snapshot.player.age;
    final nextPlayer = playerAfterTraining.copyWith(
      age: nextAge,
      fitness: finalFitness,
      form: (playerAfterTraining.form + formDelta).clamp(1, 100),
      managerTrust: (playerAfterTraining.managerTrust + trustDelta).clamp(
        1,
        100,
      ),
      reputation: (playerAfterTraining.reputation + reputationDelta).clamp(
        0,
        100,
      ),
      money: playerAfterTraining.money + moneyDelta + sponsorPayout,
      appearances: playerAfterTraining.appearances + (selected ? 1 : 0),
      goals: playerAfterTraining.goals + goals,
      assists: playerAfterTraining.assists + assists,
    );
    final nextPerformance = snapshot.seasonPerformance.add(
      appeared: selected,
      goals: goals,
      assists: assists,
      rating: rating,
    );
    final isNationalAppearance =
        opponent.competitionKind == CompetitionKind.nationalTournament &&
            selected;
    final nextNationalTeam = isNationalAppearance
        ? snapshot.nationalTeam.copyWith(
            caps: snapshot.nationalTeam.caps + 1,
            goals: snapshot.nationalTeam.goals + goals,
            assists: snapshot.nationalTeam.assists + assists,
          )
        : snapshot.nationalTeam;
    final nextWorld = _worldSimulator.advanceMatchweek(
      snapshot: snapshot,
      playerHomeScore: homeScore,
      playerAwayScore: awayScore,
    );
    // Knockout ties are resolved by the world engine. The receipt must show
    // the same decisive score as the saved bracket, not the pre-tiebreak draw.
    final competition = nextWorld.competitions[opponent.competitionId];
    if (competition != null) {
      final playerId = competition.kind == CompetitionKind.nationalTournament
          ? snapshot.player.nationalTeamId
          : snapshot.clubId;
      final fixture = competition.fixtures
          .where((fixture) =>
              fixture.matchweek == snapshot.week &&
              (fixture.homeId == playerId || fixture.awayId == playerId))
          .firstOrNull;
      if (fixture != null && fixture.isPlayed) {
        homeScore = fixture.homeGoals!;
        awayScore = fixture.awayGoals!;
        fixtureDecision = fixture.decision;
        final difference =
            opponent.isHome ? homeScore - awayScore : awayScore - homeScore;
        teamResult = difference > 0
            ? TeamResult.win
            : difference < 0
                ? TeamResult.loss
                : TeamResult.draw;
      }
    }
    final nextSnapshot = snapshot.copyWith(
      seed: rng.state,
      revision: snapshot.revision + 1,
      updatedAt: updatedAt.toUtc(),
      season: nextSeason,
      week: nextWeek,
      points: nextWorld
          .table(nextWorld.leagueIdForClub(snapshot.clubId))
          .firstWhere((record) => record.clubId == snapshot.clubId)
          .points,
      player: nextPlayer,
      phase: seasonComplete ? CareerPhase.offseason : CareerPhase.inSeason,
      world: nextWorld,
      seasonPerformance: nextPerformance,
      nationalTeam: nextNationalTeam,
      wellness: (snapshot.wellness + wellnessDelta).clamp(0, 100),
      contract: snapshot.contract.copyWith(
        roleSatisfaction:
            snapshot.contract.roleSatisfaction + roleSatisfactionDelta,
      ),
      sponsorContracts: sponsorContracts,
      sponsorIds: sponsorContracts
          .map((contract) => contract.id)
          .toList(growable: false),
      relationships: snapshot.relationships.copyWith(
        manager: snapshot.relationships.manager + trustDelta,
        teammates: snapshot.relationships.teammates +
            switch (teamResult) {
              TeamResult.win => 2,
              TeamResult.draw => 0,
              TeamResult.loss => -1,
            },
      ),
    );

    final factors = [
      ...preview.factors,
      if (lifestyleFitnessRecovery > 0)
        OutcomeFactor(
          label: 'Equipped lifestyle',
          detail: '+$lifestyleFitnessRecovery fitness recovery',
          impact: lifestyleFitnessRecovery.toDouble(),
        ),
      if (communityBoost > 0)
        const OutcomeFactor(
          label: 'Community support',
          detail: 'Strong local reputation network',
          impact: 1,
        ),
    ]..sort((a, b) => b.impact.abs().compareTo(a.impact.abs()));
    final resultLabel =
        success ? 'made the moment count' : 'couldn\'t force it';

    return WeeklyResult(
      snapshot: nextSnapshot,
      opponent: opponent,
      selection: selection,
      preview: preview,
      spotlightSucceeded: success,
      roll: roll,
      teamResult: teamResult,
      homeScore: homeScore,
      awayScore: awayScore,
      deltas: StatDeltas(
        rating: rating,
        trust: trustDelta,
        reputation: reputationDelta,
        money: moneyDelta + sponsorPayout,
        fitness: fitnessDelta,
        form: formDelta,
        goals: goals,
        assists: assists,
      ),
      factors: List.unmodifiable(factors.take(7)),
      headline: '${snapshot.player.name} $resultLabel under the lights.',
      offPitchTitle: offPitch.$1,
      offPitchBody: offPitch.$2,
      sponsorPayout: sponsorPayout,
      endedSponsorIds: List.unmodifiable(endedSponsorIds),
      fixtureDecision: fixtureDecision,
    );
  }

  PlayerState _applyTraining(
    PlayerState player,
    PlayerAttribute focus,
    TrainingIntensity intensity,
  ) {
    final gain = switch (intensity) {
      TrainingIntensity.light => 0,
      TrainingIntensity.balanced => 1,
      TrainingIntensity.intensive => 2,
    };
    final fitnessChange = switch (intensity) {
      TrainingIntensity.light => 6,
      TrainingIntensity.balanced => -2,
      TrainingIntensity.intensive => -8,
    };
    return player.copyWith(
      attributes: player.attributes.improve(focus, gain),
      fitness: (player.fitness + fitnessChange).clamp(1, 100),
    );
  }

  SpotlightPreview _preview(PlayerState player, SpotlightApproach approach,
      OpponentContext opponent, Difficulty difficulty,
      {SituationOption? situationOption}) {
    final defaultAttributes = switch (player.position) {
      PositionFamily.striker => switch (approach) {
          SpotlightApproach.safe => [
              PlayerAttribute.technique,
              PlayerAttribute.composure
            ],
          SpotlightApproach.balanced => [
              PlayerAttribute.finishing,
              PlayerAttribute.technique
            ],
          SpotlightApproach.bold => [
              PlayerAttribute.finishing,
              PlayerAttribute.composure
            ],
        },
      PositionFamily.winger => switch (approach) {
          SpotlightApproach.safe => [
              PlayerAttribute.passing,
              PlayerAttribute.composure
            ],
          SpotlightApproach.balanced => [
              PlayerAttribute.pace,
              PlayerAttribute.technique
            ],
          SpotlightApproach.bold => [
              PlayerAttribute.technique,
              PlayerAttribute.finishing
            ],
        },
      PositionFamily.midfielder => switch (approach) {
          SpotlightApproach.safe => [
              PlayerAttribute.passing,
              PlayerAttribute.composure
            ],
          SpotlightApproach.balanced => [
              PlayerAttribute.technique,
              PlayerAttribute.passing
            ],
          SpotlightApproach.bold => [
              PlayerAttribute.stamina,
              PlayerAttribute.technique
            ],
        },
      PositionFamily.defender => switch (approach) {
          SpotlightApproach.safe => [
              PlayerAttribute.defending,
              PlayerAttribute.composure
            ],
          SpotlightApproach.balanced => [
              PlayerAttribute.defending,
              PlayerAttribute.strength
            ],
          SpotlightApproach.bold => [
              PlayerAttribute.pace,
              PlayerAttribute.defending
            ],
        },
    };
    final attributes = situationOption != null &&
            situationOption.approach == approach &&
            situationOption.primaryAttributes.length >= 2
        ? situationOption.primaryAttributes.take(2).toList(growable: false)
        : defaultAttributes;
    final relevantValue = player.attributes[attributes[0]] * 0.56 +
        player.attributes[attributes[1]] * 0.44;
    final riskImpact = switch (approach) {
          SpotlightApproach.safe => 9.0,
          SpotlightApproach.balanced => 0.0,
          SpotlightApproach.bold => -11.0,
        } +
        (situationOption?.trustRisk ?? 0) * .8 +
        (situationOption?.ratingUpside ?? 0) * 2;
    final factors = <OutcomeFactor>[
      OutcomeFactor(
        label: 'Key attributes',
        detail:
            '${_title(attributes[0].name)} ${player.attributes[attributes[0]]} · '
            '${_title(attributes[1].name)} ${player.attributes[attributes[1]]}',
        impact: (relevantValue - 50) * 0.72,
      ),
      OutcomeFactor(
        label: 'Match fitness',
        detail: '${player.fitness}/100',
        impact: (player.fitness - 50) * 0.16,
      ),
      OutcomeFactor(
        label: 'Current form',
        detail: '${player.form}/100',
        impact: (player.form - 50) * 0.14,
      ),
      OutcomeFactor(
        label: 'Tactical fit',
        detail: '${opponent.tacticalFit}/100',
        impact: (opponent.tacticalFit - 50) * 0.14,
      ),
      OutcomeFactor(
        label: 'Opponent quality',
        detail: '${opponent.quality}/100',
        impact: -(opponent.quality - 50) * 0.22,
      ),
      OutcomeFactor(
        label: 'Chosen risk',
        detail: _title(approach.name),
        impact: riskImpact,
      ),
      OutcomeFactor(
        label: 'Difficulty',
        detail: _title(difficulty.name),
        impact: switch (difficulty) {
          Difficulty.story => 6,
          Difficulty.professional => 0,
          Difficulty.worldClass => -6,
        },
      ),
      OutcomeFactor(
        label: opponent.isHome ? 'Home support' : 'Away pressure',
        detail: opponent.isHome ? '+2 advantage' : '-2 pressure',
        impact: opponent.isHome ? 2 : -2,
      ),
    ];
    final chance = roundTo(
      (38 + factors.fold<double>(0, (sum, item) => sum + item.impact))
          .clamp(15, 90)
          .toDouble(),
      1,
    );
    return SpotlightPreview(
      approach: approach,
      chance: chance,
      chanceLow: (chance - 4).clamp(10, 90).round(),
      chanceHigh: (chance + 4).clamp(10, 90).round(),
      primaryAttributes: List.unmodifiable(attributes),
      factors: List.unmodifiable(factors),
    );
  }

  (String, String) _offPitchEvent(
    bool success,
    TrainingIntensity intensity,
    int variant,
  ) {
    if (intensity == TrainingIntensity.intensive) {
      return (
        'Recovery comes first',
        'The physio holds you back after training. You choose an early night over the team dinner.',
      );
    }
    if (success && variant.isEven) {
      return (
        'A shirt for the academy',
        'You stay after the whistle to meet a youth player. The small gesture travels around town.',
      );
    }
    return (
      'Eyes back on the work',
      'A reporter asks about your future. You keep the answer on the club and the next match.',
    );
  }

  String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}

final class _DeterministicRandom {
  _DeterministicRandom(int seed) : _state = seed & 0x7fffffff {
    if (_state == 0) _state = 0x13579b;
  }

  int _state;

  int get state => _state;

  double nextDouble() {
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state / 0x80000000;
  }

  int nextInt(int maxExclusive) => (nextDouble() * maxExclusive).floor();
}
