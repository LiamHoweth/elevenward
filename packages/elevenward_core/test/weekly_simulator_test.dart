import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const simulator = WeeklySimulator();
  const opponent = OpponentContext(
    clubId: 'eng2-harbour',
    clubName: 'Harbour Rovers',
    quality: 64,
    tacticalFit: 72,
    isHome: true,
  );
  const choice = WeeklyChoice(
    focus: PlayerAttribute.finishing,
    intensity: TrainingIntensity.balanced,
    spotlightApproach: SpotlightApproach.balanced,
  );
  final updatedAt = DateTime.utc(2026, 9, 10);

  test('same snapshot and inputs produce byte-identical durable state', () {
    final snapshot = CareerSnapshot.newCareer(seed: 44221);
    final first = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    final second = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );

    expect(first.snapshot.encode(), second.snapshot.encode());
    expect(first.roll, second.roll);
    expect(first.spotlightSucceeded, second.spotlightSucceeded);
    expect(first.homeScore, second.homeScore);
    expect(first.awayScore, second.awayScore);
  });

  test('snapshot JSON round-trips without changing canonical output', () {
    final snapshot = CareerSnapshot.newCareer(seed: 9);
    final decoded = CareerSnapshot.decode(snapshot.encode());
    expect(decoded.encode(), snapshot.encode());
  });

  test('preview and receipt use the same success threshold', () {
    final snapshot = CareerSnapshot.newCareer(seed: 721);
    final preview = simulator.previewSpotlight(
      snapshot: snapshot,
      focus: choice.focus,
      intensity: choice.intensity,
      approach: choice.spotlightApproach,
      opponent: opponent,
    );
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    expect(result.preview.chance, preview.chance);
    expect(result.spotlightSucceeded, result.roll < preview.chance);
  });

  test('risk choices materially change preview odds', () {
    final snapshot = CareerSnapshot.newCareer();
    final safe = simulator.previewSpotlight(
      snapshot: snapshot,
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.balanced,
      approach: SpotlightApproach.safe,
      opponent: opponent,
    );
    final bold = simulator.previewSpotlight(
      snapshot: snapshot,
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.balanced,
      approach: SpotlightApproach.bold,
      opponent: opponent,
    );
    expect(safe.chance - bold.chance, greaterThanOrEqualTo(15));
  });

  test('weekly advance trains focus and moves the career forward', () {
    final snapshot = CareerSnapshot.newCareer();
    final before = snapshot.player.attributes[PlayerAttribute.finishing];
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    expect(
      result.snapshot.player.attributes[PlayerAttribute.finishing],
      before + 1,
    );
    expect(result.snapshot.week, 2);
    expect(result.snapshot.revision, 1);
    expect(result.factors, isNotEmpty);
    expect(result.metrics.possession, inInclusiveRange(32, 68));
    expect(
        result.metrics.shotsOnTarget, lessThanOrEqualTo(result.metrics.shots));
    expect(result.matchReport.split('. ').length, greaterThanOrEqualTo(5));
    expect(result.newsStories, hasLength(3));
    expect(result.snapshot.newsFeed, hasLength(3));
  });

  test('match report engine supports well over 5000 descriptions', () {
    expect(
        MatchReportGenerator.possibleDescriptions, greaterThanOrEqualTo(5000));
    expect(MatchReportGenerator.possibleDescriptions, 46656);
  });

  test('paid agents charge every fourth week', () {
    final base = CareerSnapshot.newCareer(seed: 381).copyWith(
      week: 4,
      activeAgentId: 'agent-negotiator',
    );
    final result = simulator.advance(
      snapshot: base,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );

    expect(result.agentFee, 750);
    expect(result.agentReleased, isFalse);
    expect(result.snapshot.activeAgentId, 'agent-negotiator');
    expect(
      result.snapshot.player.money - base.player.money,
      result.deltas.money,
    );
  });

  test('unaffordable monthly agent fee ends the agreement safely', () {
    final initial = CareerSnapshot.newCareer(seed: 912);
    final base = initial.copyWith(
      week: 4,
      activeAgentId: 'agent-global-network',
      player: initial.player.copyWith(money: 100),
      contract: const ContractState(weeklyWage: 0, appearanceBonus: 0),
    );
    final result = simulator.advance(
      snapshot: base,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );

    expect(result.agentFee, 100);
    expect(result.agentReleased, isTrue);
    expect(result.snapshot.activeAgentId, 'agent-independent');
    expect(result.snapshot.player.money, 0);
    expect(result.newsStories.any((story) => story.category == 'business'),
        isTrue);
  });

  test('league results remain available in the player fixture ledger', () {
    final snapshot = CareerSnapshot.newCareer(seed: 811);
    final scheduledOpponent = const WorldSimulator().opponentFor(snapshot);
    expect(scheduledOpponent.competitionKind, CompetitionKind.league);
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: scheduledOpponent,
      updatedAt: updatedAt,
    );

    final fixture = result.snapshot.world.playerLeagueFixtures.single;
    expect(fixture.competitionId, scheduledOpponent.competitionId);
    expect(fixture.homeGoals, result.homeScore);
    expect(fixture.awayGoals, result.awayScore);
    expect(
      CareerSnapshot.decode(result.snapshot.encode())
          .world
          .playerLeagueFixtures
          .single
          .toJson(),
      fixture.toJson(),
    );
  });

  test('week 18 enters an explicit offseason without skipping decisions', () {
    final initial = CareerSnapshot.newCareer();
    final snapshot = initial.copyWith(
      revision: 17,
      week: 18,
      points: 30,
    );
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    expect(result.snapshot.week, 18);
    expect(result.snapshot.season, 1);
    expect(result.snapshot.player.age, 17);
    expect(result.snapshot.phase, CareerPhase.offseason);
  });

  test('500 seeded seasons all advance without an invalid state', () {
    for (var seed = 1; seed <= 500; seed++) {
      var snapshot = CareerSnapshot.newCareer(seed: seed);
      for (var week = 1; week <= 18; week++) {
        final approach = SpotlightApproach.values[(seed + week) % 3];
        final result = simulator.advance(
          snapshot: snapshot,
          choice: WeeklyChoice(
            focus: PlayerAttribute.values[(seed + week) % 8],
            intensity: TrainingIntensity.values[(seed + week) % 3],
            spotlightApproach: approach,
          ),
          opponent: opponent,
          updatedAt: updatedAt.add(Duration(days: week * 7)),
        );
        snapshot = result.snapshot;
        expect(snapshot.player.fitness, inInclusiveRange(1, 100));
        expect(snapshot.player.managerTrust, inInclusiveRange(1, 100));
        expect(result.preview.chance, inInclusiveRange(15, 90));
      }
      expect(snapshot.season, 1);
      expect(snapshot.week, 18);
      expect(snapshot.phase, CareerPhase.offseason);
      expect(snapshot.revision, 18);
    }
  });

  test('VIP fractional development carries exactly into the next week', () {
    final first = simulator.advance(
      snapshot: CareerSnapshot.newCareer(seed: 38),
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
      modifiers: const RewardModifiers(
        developmentMultiplier: 1.5,
        moneyMultiplier: 1.5,
        sourceIds: ['vip'],
      ),
    );
    expect(first.developmentGain, 1);
    expect(first.developmentRemainder, 0.5);
    expect(
      first.snapshot.developmentProgress[PlayerAttribute.finishing],
      0.5,
    );

    final second = simulator.advance(
      snapshot: first.snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt.add(const Duration(days: 7)),
      modifiers: const RewardModifiers(
        developmentMultiplier: 1.5,
        moneyMultiplier: 1.5,
        sourceIds: ['vip'],
      ),
    );
    expect(second.developmentGain, 2);
    expect(second.developmentRemainder, 0);
    expect(
      second.snapshot.developmentProgress[PlayerAttribute.finishing],
      isNull,
    );
    expect(second.snapshot.boostIdsUsed, ['vip']);
  });

  test('2x and 3x profiles apply exact weekly development', () {
    final snapshot = CareerSnapshot.newCareer(seed: 51);
    final doubled = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
      modifiers: const RewardModifiers(developmentMultiplier: 2),
    );
    final tripled = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
      modifiers: const RewardModifiers(developmentMultiplier: 3),
    );
    expect(doubled.developmentGain, 2);
    expect(tripled.developmentGain, 3);
  });

  test('positive money rounds once while deductions are never multiplied', () {
    const vip = RewardModifiers(moneyMultiplier: 1.5);
    const doubled = RewardModifiers(moneyMultiplier: 2);
    const tripled = RewardModifiers(moneyMultiplier: 3);
    expect(vip.applyPositiveMoney(101), 152);
    expect(doubled.applyPositiveMoney(101), 202);
    expect(tripled.applyPositiveMoney(101), 303);
    expect(tripled.applyPositiveMoney(-101), -101);
    expect(tripled.applyPositiveMoney(0), 0);
  });

  test(
      'weekly wages use the active money profile without changing starting cash',
      () {
    final snapshot = CareerSnapshot.newCareer().copyWith(
      contract: const ContractState(weeklyWage: 101, appearanceBonus: 0),
    );
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
      modifiers: const RewardModifiers(moneyMultiplier: 1.5),
    );
    expect(result.deltas.money, 152);
    expect(result.snapshot.player.money, snapshot.player.money + 152);
  });

  test('development caps at 99 and discards unusable fractional carry', () {
    final snapshot = CareerSnapshot.newCareer().copyWith(
      player: CareerSnapshot.newCareer().player.copyWith(
            attributes: PlayerAttributes({
              for (final attribute in PlayerAttribute.values)
                attribute: attribute == PlayerAttribute.finishing ? 98 : 50,
            }),
          ),
    );
    final result = simulator.advance(
      snapshot: snapshot,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.intensive,
        spotlightApproach: SpotlightApproach.balanced,
      ),
      opponent: opponent,
      updatedAt: updatedAt,
      modifiers: const RewardModifiers(developmentMultiplier: 3),
    );
    expect(result.snapshot.player.attributes[PlayerAttribute.finishing], 99);
    expect(result.developmentGain, 1);
    expect(result.developmentRemainder, 0);
  });

  test('schema 9 careers migrate with empty fractional progress', () {
    final json = CareerSnapshot.newCareer().toJson()
      ..['schemaVersion'] = 9
      ..['rulesVersion'] = '2026.2'
      ..remove('developmentProgress')
      ..remove('boostIdsUsed');
    final migrated = CareerSnapshot.fromJson(json);
    expect(migrated.schemaVersion, CareerSnapshot.currentSchemaVersion);
    expect(migrated.rulesVersion, '2026.2');
    expect(migrated.developmentProgress, isEmpty);
    expect(migrated.boostIdsUsed, isEmpty);
  });

  test('invalid fractional development cannot enter a career snapshot', () {
    final json = CareerSnapshot.newCareer().toJson()
      ..['developmentProgress'] = {'finishing': 1.0};
    expect(() => CareerSnapshot.fromJson(json), throwsFormatException);
  });
}
