import 'dart:convert';
import 'dart:io';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

const simulator = WeeklySimulator();
const engine = CareerEngine();
const worldSimulator = WorldSimulator();
const matchChoice = WeeklyChoice(
    focus: PlayerAttribute.passing,
    intensity: TrainingIntensity.balanced,
    spotlightApproach: SpotlightApproach.safe);
final date = DateTime.utc(2026, 10, 1);

CareerSnapshot published(String rules, {int seed = 38}) =>
    CareerSnapshot.fromJson({
      ...CareerSnapshot.newCareer(seed: seed).toJson(),
      'rulesVersion': rules,
      'contentVersion': '2026.3.0'
    });
WeeklyResult play(CareerSnapshot snapshot,
        {ContentCatalog? catalog, WeeklyChoice choice = matchChoice}) =>
    simulator.advance(
        snapshot: snapshot,
        choice: choice,
        opponent: worldSimulator.opponentFor(snapshot),
        updatedAt: snapshot.updatedAt.add(const Duration(days: 7)),
        catalog: catalog);
CareerSnapshot fullSeason(CareerSnapshot snapshot) {
  while (snapshot.phase == CareerPhase.inSeason) {
    snapshot = play(snapshot).snapshot;
  }
  if (snapshot.phase == CareerPhase.internationalCallup)
    snapshot = engine.decideNationalTeamCallUp(
        snapshot: snapshot, accept: false, updatedAt: date);
  return snapshot;
}

void main() {
  test(
      'schema14 migration preserves all published rules and defaults features without invented history',
      () {
    for (final rules in ['2026.1', '2026.2', '2026.3', '2026.4']) {
      final json = published(rules).toJson()..['schemaVersion'] = 13;
      for (final key in [
        'roleStats',
        'matchJournal',
        'decisionJournal',
        'storyFlags',
        'careerGoal',
        'activeLoan',
        'pendingEventId'
      ]) {
        json.remove(key);
      }
      final migrated = CareerSnapshot.fromJson(json);
      expect(migrated.rulesVersion, rules);
      expect(migrated.schemaVersion, 14);
      expect(migrated.matchJournal, isEmpty);
      expect(migrated.storyFlags, isEmpty);
      expect(migrated.activeLoan, isNull);
      expect(migrated.roleStats.tackles, 0);
      expect(
          CareerSnapshot.decode(migrated.encode()).encode(), migrated.encode());
    }
  });

  test(
      'age development and reward previews equal committed gains for every age/load/profile',
      () {
    for (final age in [17, 21, 25, 29, 33, 36]) {
      for (final intensity in TrainingIntensity.values) {
        for (final multiplier in [1.0, 1.5, 2.0, 3.0]) {
          final initial = CareerSnapshot.newCareer(seed: 200);
          final snapshot =
              initial.copyWith(player: initial.player.copyWith(age: age));
          final modifiers = RewardModifiers(developmentMultiplier: multiplier);
          final preview = simulator.previewTraining(
              snapshot: snapshot,
              focus: PlayerAttribute.finishing,
              intensity: intensity,
              modifiers: modifiers);
          final result = simulator.advance(
              snapshot: snapshot,
              choice: WeeklyChoice(
                  focus: PlayerAttribute.finishing,
                  intensity: intensity,
                  spotlightApproach: SpotlightApproach.safe),
              opponent: worldSimulator.opponentFor(snapshot),
              updatedAt: date,
              modifiers: modifiers);
          expect(result.developmentGain, preview.gain);
          expect(result.developmentRemainder, preview.remainder);
          expect(result.snapshot.player.attributes[PlayerAttribute.finishing],
              preview.attributeAfter);
          final base = switch (intensity) {
            TrainingIntensity.light => 0,
            TrainingIntensity.balanced => 1,
            TrainingIntensity.intensive => 2
          };
          expect(preview.gain,
              (base * multiplier * ageDevelopmentMultiplier(age)).floor());
        }
      }
    }
    for (final rules in ['2026.1', '2026.2', '2026.3', '2026.4']) {
      final preview = simulator.previewTraining(
          snapshot: published(rules),
          focus: PlayerAttribute.finishing,
          intensity: TrainingIntensity.balanced);
      expect(preview.gain, 1);
      expect(preview.remainder, 0);
    }
  });

  test(
      'personal goals and assists always fit committed team score across positions and venues',
      () {
    var goals = 0, assists = 0, tackles = 0, creations = 0;
    for (final archetype in Archetype.values) {
      for (var seed = 1; seed <= 90; seed++) {
        final snapshot = CareerSnapshot.newCareer(
            seed: seed,
            player: PlayerState.newCareer(
                id: 'test', name: 'Test', archetype: archetype));
        final result = play(snapshot);
        final score =
            result.opponent.isHome ? result.homeScore : result.awayScore;
        expect(result.deltas.goals + result.deltas.assists,
            lessThanOrEqualTo(score));
        if (score == 0) expect(result.deltas.assists, 0);
        final receipt = result.snapshot.matchJournal.single;
        expect(receipt.assists, result.deltas.assists);
        expect(receipt.goals, result.deltas.goals);
        expect(receipt.homeScore, result.homeScore);
        expect(receipt.awayScore, result.awayScore);
        goals += result.deltas.goals;
        assists += result.deltas.assists;
        tackles += receipt.roleStats.tackles;
        creations += receipt.roleStats.chancesCreated;
        if (snapshot.player.position == PositionFamily.defender &&
            receipt.appeared) {
          expect(
              receipt.roleStats.cleanSheets,
              result.opponent.isHome
                  ? result.awayScore == 0
                      ? 1
                      : 0
                  : result.homeScore == 0
                      ? 1
                      : 0);
        }
      }
    }
    expect(goals, greaterThan(0));
    expect(assists, greaterThan(0));
    expect(tackles, greaterThan(0));
    expect(creations, greaterThan(0));
  });

  test(
      'omitted players have no modern rating and cannot inflate season averages',
      () {
    final fresh = CareerSnapshot.newCareer();
    final omitted = fresh.copyWith(
        player: fresh.player.copyWith(managerTrust: 1, fitness: 1, form: 1),
        relationships: const RelationshipState(manager: 0));
    final result = play(omitted);
    expect(result.selection.status, SelectionStatus.omitted);
    expect(result.deltas.rating, 0);
    expect(result.snapshot.seasonPerformance.ratingTenths, 0);
    expect(result.snapshot.seasonPerformance.ratedMatches, 0);
    expect(result.snapshot.seasonPerformance.averageRating, 0);
    final old = CareerSnapshot.fromJson(
        {...omitted.toJson(), 'rulesVersion': '2026.4'});
    expect(play(old).deltas.rating, 5.8);
    expect(play(old).snapshot.seasonPerformance.ratingTenths, 58);
  });

  test('published2026.4 deterministic receipt remains frozen', () {
    final snapshot = published('2026.4', seed: 38);
    final result = play(snapshot);
    expect(result.roll, 52.7);
    expect(result.snapshot.seed, 1202545393);
    expect((result.homeScore, result.awayScore), (0, 0));
    expect((result.deltas.goals, result.deltas.assists), (0, 1));
  });

  test(
      'named styles and one shared fit supply league cup and transfer previews',
      () {
    final snapshot = CareerSnapshot.newCareer();
    final world = buildLaunchWorld();
    final club = world.clubs.firstWhere((club) => club.id == snapshot.clubId);
    expect(worldSimulator.opponentFor(snapshot).tacticalFit,
        calculateTacticalFit(snapshot, club));
    final week6 = snapshot.copyWith(week: 6);
    expect(worldSimulator.opponentFor(week6).tacticalFit,
        calculateTacticalFit(week6, club));
    for (final offer in engine.contractOffers(snapshot)) {
      final destination =
          world.clubs.firstWhere((club) => club.id == offer.clubId);
      expect(offer.tacticalFit, calculateTacticalFit(snapshot, destination));
    }
    expect(world.clubs.map((club) => club.playingStyle).toSet(), hasLength(5));
    expect(club.playingStyle.label, isNotEmpty);
  });

  test(
      'position-sensitive legacy credits defending and creation with exact breakdown sum',
      () {
    final defender = CareerSnapshot.newCareer(
        player: PlayerState.newCareer(
            id: 'def', name: 'Def', archetype: Archetype.stopper));
    final decorated = defender.copyWith(
        roleStats: const RoleStats(
            tackles: 100,
            interceptions: 60,
            cleanSheets: 25,
            playerOfMatchAwards: 5));
    expect(
        calculateLegacyVerdict(decorated).score -
            calculateLegacyVerdict(defender).score,
        230);
    expect(
        calculateLegacyVerdict(decorated).score,
        legacyScoreContributions(decorated)
            .values
            .fold<num>(0, (sum, value) => sum + value)
            .round());
    final old = CareerSnapshot.fromJson(
        {...decorated.toJson(), 'rulesVersion': '2026.4'});
    expect(legacyScoreContributions(old)['roleContributions'], 0);
  });

  test(
      'a chosen ambition survives reload and completes exactly on its milestone',
      () {
    var snapshot = engine.chooseCareerGoal(
        snapshot: CareerSnapshot.newCareer(),
        kind: CareerGoalKind.appearances,
        target: 1,
        updatedAt: date);
    snapshot = CareerSnapshot.decode(snapshot.encode());
    snapshot = play(snapshot).snapshot;
    expect(snapshot.careerGoal!.completed, isTrue);
    expect(snapshot.careerGoal!.progress(snapshot), 1);
    expect(
        () => engine.chooseCareerGoal(
            snapshot: snapshot,
            kind: CareerGoalKind.assists,
            target: 0,
            updatedAt: date),
        throwsArgumentError);
    final prior =
        snapshot.copyWith(nationalTeam: const NationalTeamCareerState(caps: 1));
    expect(
        () => engine.chooseCareerGoal(
            snapshot: prior,
            kind: CareerGoalKind.nationalSelection,
            updatedAt: date),
        throwsStateError);
  });

  test(
      'wage trade and family promises change actual contract and relationships with durable effects',
      () {
    final latest = buildLatestContent();
    final snapshot = CareerSnapshot.newCareer().copyWith(week: 11);
    final trade = latest.careerEvents
        .firstWhere((event) => event.id == 'career-contract-01');
    final next = engine.applyEventChoice(
        snapshot: snapshot,
        event: trade,
        choice: trade.choices.first,
        updatedAt: date);
    expect(next.contract.weeklyWage, 960);
    expect(next.contract.appearanceBonus, 1150);
    expect(next.decisionJournal.single.effects['weeklyWage'], -240);
    expect(next.decisionJournal.single.effects['appearanceBonus'], 900);
    final family = latest.careerEvents
        .firstWhere((event) => event.category == CareerEventCategory.family);
    final helped = engine.applyEventChoice(
        snapshot: next,
        event: family,
        choice: family.choices.first,
        updatedAt: date);
    expect(helped.relationships.family, next.relationships.family + 5);
    final legacy = published('2026.4').copyWith(week: 11);
    final old = engine.applyEventChoice(
        snapshot: legacy,
        event: trade,
        choice: trade.choices.first,
        updatedAt: date);
    expect(old.contract.toJson(), legacy.contract.toJson());
  });

  test(
      'family payments are explicit affordable deductions unaffected by rewards',
      () {
    final event = buildLatestContent()
        .careerEvents
        .firstWhere((event) => event.id == 'career-family-03');
    final snapshot = CareerSnapshot.newCareer().copyWith(week: 11);
    final next = engine.applyEventChoice(
        snapshot: snapshot,
        event: event,
        choice: event.choices.first,
        updatedAt: date,
        modifiers: const RewardModifiers(moneyMultiplier: 3));
    expect(next.player.money, snapshot.player.money - 1000);
    expect(next.decisionJournal.first.effects['money'], -1000);
    expect(event.choices.first.label.forLocale('en'), contains('£1000'));
    final poor =
        snapshot.copyWith(player: snapshot.player.copyWith(money: 500));
    expect(
        () => engine.applyEventChoice(
            snapshot: poor,
            event: event,
            choice: event.choices.first,
            updatedAt: date),
        throwsStateError);
    expect(
        engine
            .applyEventChoice(
                snapshot: poor,
                event: event,
                choice: event.choices.last,
                updatedAt: date)
            .player
            .money,
        500);
  });

  test(
      'mentor arc has durable divergent routes and exact meaningful final effects',
      () {
    final catalog = buildLatestContent();
    for (final firstChoice in ['share', 'solo']) {
      var snapshot = CareerSnapshot.newCareer().copyWith(week: 3);
      final first = engine.eventById('mentor-01-introduction', catalog)!;
      snapshot = engine.applyEventChoice(
          snapshot: snapshot,
          event: first,
          choice: first.choices.firstWhere((c) => c.id == firstChoice),
          updatedAt: date);
      snapshot = CareerSnapshot.decode(snapshot.encode()).copyWith(week: 6);
      final second = engine.eventById('mentor-02-pressure', catalog)!;
      snapshot = engine.applyEventChoice(
          snapshot: snapshot,
          event: second,
          choice: second.choices.first,
          updatedAt: date);
      snapshot = CareerSnapshot.decode(snapshot.encode()).copyWith(week: 9);
      final finalId =
          firstChoice == 'share' ? 'mentor-03-shared' : 'mentor-03-solo';
      final finale = engine.eventById(finalId, catalog)!;
      expect(engine.eligibleEvents(snapshot, catalog).map((event) => event.id),
          contains(finalId));
      final before = snapshot;
      snapshot = engine.applyEventChoice(
          snapshot: snapshot,
          event: finale,
          choice: finale.choices.first,
          updatedAt: date);
      expect(snapshot.storyFlags['mentor.stage'], '3');
      expect(snapshot.storyFlags['mentor.outcome'], 'alliance');
      expect(
          snapshot.player.fitness, (before.player.fitness + 3).clamp(1, 100));
      expect(snapshot.relationships.teammates,
          (before.relationships.teammates + 6).clamp(0, 100));
      expect(snapshot.decisionJournal, hasLength(3));
      expect(
          engine
              .eligibleEvents(snapshot.copyWith(week: 15), catalog)
              .where((event) => event.id.startsWith('mentor-')),
          isEmpty);
      expect(
          () => engine.applyEventChoice(
              snapshot: snapshot,
              event: first,
              choice: first.choices.first,
              updatedAt: date),
          throwsStateError);
    }
  });

  test('pending story is durable and cannot be bypassed by advancing a match',
      () {
    final catalog = buildLatestContent();
    var snapshot = play(CareerSnapshot.newCareer(), catalog: catalog).snapshot;
    expect(snapshot.pendingEventId, isNotNull);
    snapshot = CareerSnapshot.decode(snapshot.encode());
    final pending = engine.pendingEvent(snapshot, catalog)!;
    expect(() => play(snapshot, catalog: catalog), throwsStateError);
    snapshot = engine.applyEventChoice(
        snapshot: snapshot,
        event: pending,
        choice: pending.choices.first,
        updatedAt: date);
    expect(snapshot.pendingEventId, isNull);
    expect(() => play(snapshot, catalog: catalog), returnsNormally);
  });

  test(
      'one-season loan pays existing terms and returns to a valid parent contract after reload',
      () {
    var snapshot = fullSeason(CareerSnapshot.newCareer()
        .copyWith(contract: const ContractState(seasonsRemaining: 3)));
    final parent = snapshot.clubId;
    final wage = snapshot.contract.weeklyWage;
    final loan = engine.loanOffers(snapshot).first;
    snapshot =
        engine.completeOffseason(snapshot, acceptedLoan: loan, updatedAt: date);
    expect(snapshot.clubId, loan.clubId);
    expect(snapshot.activeLoan!.parentClubId, parent);
    expect(snapshot.activeLoan!.hostWageSharePercent, 100);
    expect(snapshot.contract.weeklyWage, wage);
    expect(snapshot.activeLoan!.parentContract.seasonsRemaining, 2);
    expect(engine.loanOffers(snapshot), isEmpty);
    expect(engine.contractOffers(snapshot), isEmpty);
    snapshot = fullSeason(CareerSnapshot.decode(snapshot.encode()));
    snapshot = engine.completeOffseason(snapshot, updatedAt: date);
    expect(snapshot.clubId, parent);
    expect(snapshot.activeLoan, isNull);
    expect(snapshot.contract.clubId, parent);
    expect(snapshot.contract.seasonsRemaining, 1);
    expect(snapshot.contract.weeklyWage, wage);
    expect(engine.loanOffers(snapshot.copyWith(phase: CareerPhase.offseason)),
        isEmpty);
  });

  test(
      'bounded journals survive several seasons without growing the save indefinitely',
      () {
    var snapshot = CareerSnapshot.newCareer()
        .copyWith(contract: const ContractState(seasonsRemaining: 5));
    for (var season = 0; season < 3; season++) {
      snapshot = fullSeason(snapshot);
      snapshot = engine.completeOffseason(snapshot, updatedAt: date);
    }
    expect(snapshot.matchJournal, hasLength(40));
    expect(
        CareerSnapshot.decode(snapshot.encode()).encode(), snapshot.encode());
    expect(snapshot.matchJournal.first.season, 3);
    expect(snapshot.matchJournal.last.season, 1);
  });

  test(
      'weekly challenge replays resumed transcripts exactly and isolates normal career boosts',
      () async {
    const challenge = WeeklyChallenge();
    final actions = List<WeeklyChoice>.filled(8, matchChoice);
    final first = challenge.replay(
        seed: 100,
        choices: actions,
        careerId: 'challenge-uuid',
        updatedAt: date);
    final resumed = challenge.replay(
        seed: 100,
        choices: actions.take(3).toList(),
        careerId: 'challenge-uuid',
        updatedAt: date);
    expect(resumed.matchesPlayed, 3);
    expect(resumed.complete, isFalse);
    final second = challenge.replay(
        seed: 100,
        choices: actions.map((a) => WeeklyChoice.fromJson(a.toJson())).toList(),
        careerId: 'challenge-uuid',
        updatedAt: date);
    expect(first.snapshot.encode(), second.snapshot.encode());
    expect(first.score, second.score);
    expect(first.complete, isTrue);
    expect(first.snapshot.boostIdsUsed, isEmpty);
    expect(first.snapshot.pendingEventId, isNull);
    expect(
        first.score,
        first.snapshot.points * 100 +
            first.results.fold<int>(
                0, (sum, result) => sum + (result.deltas.rating * 10).round()) +
            first.snapshot.player.goals * 15 +
            first.snapshot.player.assists * 10);
    expect(
        () => challenge.replay(seed: 100, choices: [...actions, matchChoice]),
        throwsArgumentError);
    final process = await Process.start(Platform.resolvedExecutable,
        ['run', 'bin/replay_weekly_challenge.dart']);
    process.stdin.write(jsonEncode({
      'seed': 100,
      'careerId': 'challenge-uuid',
      'enrolledAt': date.toIso8601String(),
      'choices': actions.map((a) => a.toJson()).toList()
    }));
    await process.stdin.close();
    final output = await process.stdout.transform(utf8.decoder).join();
    final error = await process.stderr.transform(utf8.decoder).join();
    expect(await process.exitCode, 0, reason: error);
    final receipt = jsonDecode(output) as Map;
    expect(receipt['valid'], isTrue);
    expect(receipt['score'], first.score);
    expect(receipt['rulesVersion'], '2026.5');
    expect(output.length, lessThan(1000));
  });
}
