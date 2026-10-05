import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const weekly = WeeklySimulator();
  const engine = CareerEngine();
  const worldSimulator = WorldSimulator();

  CareerSnapshot playSeason(CareerSnapshot snapshot) {
    while (snapshot.phase == CareerPhase.inSeason ||
        snapshot.phase == CareerPhase.internationalCallup ||
        snapshot.phase == CareerPhase.internationalTournament) {
      if (snapshot.phase == CareerPhase.internationalCallup) {
        snapshot = engine.decideNationalTeamCallUp(
          snapshot: snapshot,
          accept: true,
          updatedAt: snapshot.updatedAt.add(const Duration(minutes: 1)),
        );
        continue;
      }
      final opponent = worldSimulator.opponentFor(snapshot);
      snapshot = weekly
          .advance(
            snapshot: snapshot,
            choice: WeeklyChoice(
              focus: PlayerAttribute.values[(snapshot.seed + snapshot.week) %
                  PlayerAttribute.values.length],
              intensity: TrainingIntensity.values[
                  (snapshot.season + snapshot.week) %
                      TrainingIntensity.values.length],
              spotlightApproach: SpotlightApproach.values[
                  (snapshot.seed + snapshot.revision) %
                      SpotlightApproach.values.length],
            ),
            opponent: opponent,
            updatedAt: snapshot.updatedAt.add(const Duration(days: 7)),
          )
          .snapshot;
    }
    return snapshot;
  }

  test('every archetype starts with one family and all eight valid attributes',
      () {
    for (final archetype in Archetype.values) {
      final player = PlayerState.newCareer(
        id: 'player-${archetype.name}',
        name: 'Player',
        archetype: archetype,
      );
      expect(player.position, archetype.positionFamily);
      for (final attribute in PlayerAttribute.values) {
        expect(player.attributes[attribute], inInclusiveRange(1, 99));
      }
    }
  });

  test('selected portrait survives player updates and career serialization',
      () {
    final player = PlayerState.newCareer(
      id: 'portrait-player',
      name: 'Portrait Player',
      archetype: Archetype.poacher,
      portraitId: 'player_21',
    );
    final career = CareerSnapshot.newCareer(player: player.copyWith(age: 18));
    final restored = CareerSnapshot.decode(career.encode());
    expect(restored.player.portraitId, 'player_21');
    expect(restored.player.age, 18);

    final legacyJson = Map<String, Object?>.from(player.toJson())
      ..remove('portraitId');
    expect(PlayerState.fromJson(legacyJson).portraitId, isNull);
    expect(PlayerState.fromJson(legacyJson).toJson(), legacyJson);
  });

  test('new careers bind the contract and active content to the chosen club',
      () {
    final snapshot = CareerSnapshot.newCareer(
      clubId: 'spain-solmera-cf',
      clubName: 'Solmera CF',
      contentVersion: '2026.2.0',
    );
    expect(snapshot.contract.clubId, snapshot.clubId);
    expect(snapshot.contentVersion, '2026.2.0');
    expect(snapshot.schemaVersion, CareerSnapshot.currentSchemaVersion);
  });

  test('version-three snapshots migrate the known default-contract defect', () {
    final json = CareerSnapshot.newCareer(
      clubId: 'spain-solmera-cf',
      clubName: 'Solmera CF',
    ).toJson()
      ..['schemaVersion'] = 3
      ..['contract'] = const ContractState().toJson();
    final migrated = CareerSnapshot.fromJson(json);
    expect(migrated.schemaVersion, CareerSnapshot.currentSchemaVersion);
    expect(migrated.contract.clubId, 'spain-solmera-cf');
  });

  test('version-seven snapshots add durable national-team state', () {
    final json = CareerSnapshot.newCareer().toJson()
      ..['schemaVersion'] = 7
      ..remove('nationalTeam');
    final migrated = CareerSnapshot.fromJson(json);
    expect(migrated.nationalTeam.decision, NationalTeamDecision.undecided);
    expect(migrated.nationalTeam.caps, 0);
    expect(migrated.schemaVersion, CareerSnapshot.currentSchemaVersion);
  });

  test('version-eight snapshots add an empty player league fixture ledger', () {
    final json = CareerSnapshot.newCareer().toJson()..['schemaVersion'] = 8;
    final world = (json['world'] as Map<String, Object?>)
      ..remove('playerLeagueFixtures');
    json['world'] = world;
    final migrated = CareerSnapshot.fromJson(json);
    expect(migrated.world.playerLeagueFixtures, isEmpty);
    expect(migrated.schemaVersion, CareerSnapshot.currentSchemaVersion);
  });

  test('version-twelve snapshots add empty transfer-request state', () {
    final json = CareerSnapshot.newCareer().toJson()
      ..['schemaVersion'] = 12
      ..remove('transferRequest')
      ..remove('transferRequestTrustPenaltySeason');
    final migrated = CareerSnapshot.fromJson(json);
    expect(migrated.transferRequest, isNull);
    expect(migrated.transferRequestTrustPenaltySeason, isNull);
    expect(migrated.schemaVersion, CareerSnapshot.currentSchemaVersion);
  });

  test('every historical field schema has a deterministic golden migration',
      () {
    const introducedAt = <String, int>{
      'difficulty': 2,
      'phase': 2,
      'wellness': 2,
      'relationships': 3,
      'contract': 3,
      'ownedItemIds': 3,
      'seasonHistory': 3,
      'retired': 3,
      'legacyScore': 3,
      'world': 3,
      'seasonPerformance': 3,
      'activeAgentId': 3,
      'sponsorIds': 3,
      'resolvedEventIds': 3,
      'equippedItemIds': 5,
      'sponsorContracts': 7,
      'nationalTeam': 8,
      'transferRequest': 13,
      'transferRequestTrustPenaltySeason': 13,
    };
    for (var version = 1; version <= 8; version++) {
      final json = CareerSnapshot.newCareer(
        clubId: 'spain-solmera-cf',
        clubName: 'Solmera CF',
      ).toJson()
        ..['schemaVersion'] = version;
      for (final entry in introducedAt.entries) {
        if (entry.value > version) json.remove(entry.key);
      }
      if (version == 3) {
        json['contract'] = const ContractState().toJson();
      }
      final migrated = CareerSnapshot.fromJson(json);
      expect(migrated.schemaVersion, CareerSnapshot.currentSchemaVersion,
          reason: 'schema $version');
      expect(migrated.contract.clubId, 'spain-solmera-cf',
          reason: 'schema $version');
      expect(migrated.nationalTeam.caps, 0, reason: 'schema $version');
      expect(
          CareerSnapshot.decode(migrated.encode()).encode(), migrated.encode(),
          reason: 'schema $version');
    }
  });

  test('pre-world midseason saves fail safely instead of inventing results',
      () {
    final json = CareerSnapshot.newCareer().toJson()
      ..['schemaVersion'] = 2
      ..['week'] = 7
      ..remove('world');
    expect(
      () => CareerSnapshot.fromJson(json),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('cannot be reconstructed'),
        ),
      ),
    );
  });

  test('pre-world opening saves reconstruct only the legacy 120-club world',
      () {
    final json = CareerSnapshot.newCareer(
      contentVersion: '2026.2.0',
    ).toJson()
      ..['schemaVersion'] = 2
      ..remove('world');
    final migrated = CareerSnapshot.fromJson(json);

    expect(migrated.world.leagueParticipants, hasLength(12));
    expect(
      migrated.world.leagueParticipants.values.expand((ids) => ids).toSet(),
      hasLength(120),
    );
  });

  test('event income is boosted while penalties remain exact', () {
    final snapshot = CareerSnapshot.newCareer(seed: 7001);
    final events = buildLaunchContent().careerEvents;
    final template = events.first;
    final penalty = EventChoiceDefinition(
      id: 'pay-penalty',
      label: template.choices.first.label,
      trustDelta: 0,
      reputationDelta: 0,
      moneyDelta: -751,
      wellnessDelta: 0,
    );
    final negativeEvent = CareerEventDefinition(
      id: 'test-penalty',
      category: CareerEventCategory.reputation,
      title: template.title,
      body: template.body,
      choices: [penalty],
    );
    final afterPenalty = engine.applyEventChoice(
      snapshot: snapshot,
      event: negativeEvent,
      choice: penalty,
      updatedAt: snapshot.updatedAt,
      modifiers: const RewardModifiers(
        moneyMultiplier: 3,
        sourceIds: ['allAccess'],
      ),
    );
    expect(
      afterPenalty.player.money,
      (snapshot.player.money + penalty.moneyDelta).clamp(0, 1 << 52),
    );
    expect(afterPenalty.boostIdsUsed, isEmpty);

    final positiveEvent = events.firstWhere(
      (event) => event.choices.any((choice) => choice.moneyDelta > 0),
    );
    final income = positiveEvent.choices.firstWhere(
      (choice) => choice.moneyDelta > 0,
    );
    final afterIncome = engine.applyEventChoice(
      snapshot: snapshot,
      event: positiveEvent,
      choice: income,
      updatedAt: snapshot.updatedAt,
      modifiers: const RewardModifiers(
        moneyMultiplier: 1.5,
        sourceIds: ['vip'],
      ),
    );
    expect(
      afterIncome.player.money,
      snapshot.player.money + (income.moneyDelta * 1.5).round(),
    );
    expect(afterIncome.boostIdsUsed, ['vip']);
  });

  test('world week produces complete tables and a deterministic opponent', () {
    final initial = CareerSnapshot.newCareer(seed: 9031);
    final opponent = worldSimulator.opponentFor(initial);
    final first = weekly.advance(
      snapshot: initial,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.passing,
        intensity: TrainingIntensity.balanced,
        spotlightApproach: SpotlightApproach.safe,
      ),
      opponent: opponent,
      updatedAt: initial.updatedAt.add(const Duration(days: 7)),
    );
    final second = weekly.advance(
      snapshot: initial,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.passing,
        intensity: TrainingIntensity.balanced,
        spotlightApproach: SpotlightApproach.safe,
      ),
      opponent: opponent,
      updatedAt: initial.updatedAt.add(const Duration(days: 7)),
    );
    expect(first.snapshot.world.toJson(), second.snapshot.world.toJson());
    for (final league in first.snapshot.world.leagueRecords.values) {
      expect(league.values.every((record) => record.played == 1), true);
    }
  });

  test('offseason records history, moves two clubs, and accepts a real offer',
      () {
    var snapshot = playSeason(CareerSnapshot.newCareer(seed: 771));
    final before = snapshot.world.leagueParticipants;
    final offers = engine.contractOffers(snapshot);
    expect(offers, isNotEmpty);
    snapshot = engine.completeOffseason(
      snapshot,
      acceptedOffer: offers.first,
      updatedAt: snapshot.updatedAt.add(const Duration(days: 21)),
    );
    expect(snapshot.season, 2);
    expect(snapshot.week, 1);
    expect(snapshot.player.age, 18);
    expect(snapshot.seasonHistory, hasLength(1));
    expect(snapshot.clubId, offers.first.clubId);
    expect(snapshot.contract.clubId, offers.first.clubId);
    final world = buildLaunchWorld();
    for (final country
        in world.countries.where((country) => country.hasLeague)) {
      final first = world.leagues.firstWhere(
        (league) =>
            league.countryId == country.id &&
            league.division == DivisionLevel.first,
      );
      expect(
        before[first.id]!
            .toSet()
            .difference(snapshot.world.leagueParticipants[first.id]!.toSet()),
        hasLength(2),
      );
    }
  });

  test('off-pitch choices, agents, and lifestyle purchases are durable', () {
    final catalog = buildLaunchContent();
    var snapshot = CareerSnapshot.newCareer().copyWith(
      player: CareerSnapshot.newCareer().player.copyWith(money: 100000),
    );
    final event = catalog.careerEvents.first;
    snapshot = engine.applyEventChoice(
      snapshot: snapshot,
      event: event,
      choice: event.choices.first,
      updatedAt: snapshot.updatedAt.add(const Duration(hours: 1)),
    );
    expect(snapshot.resolvedEventIds, hasLength(1));
    expect(snapshot.revision, 1);
    snapshot = engine.chooseAgent(
      snapshot: snapshot,
      agentId: 'agent-player-first',
      updatedAt: snapshot.updatedAt.add(const Duration(hours: 1)),
    );
    final item = catalog.lifestyleItems.first;
    final money = snapshot.player.money;
    snapshot = engine.purchaseLifestyleItem(
      snapshot: snapshot,
      item: item,
      updatedAt: snapshot.updatedAt.add(const Duration(hours: 1)),
    );
    expect(snapshot.activeAgentId, 'agent-player-first');
    expect(snapshot.ownedItemIds, contains(item.id));
    expect(snapshot.player.money, money - item.price);
    expect(
        CareerSnapshot.decode(snapshot.encode()).encode(), snapshot.encode());
  });

  test('agent tradeoffs affect offers and rejected interest is explained', () {
    final base = CareerSnapshot.newCareer(seed: 431).copyWith(
      player: CareerSnapshot.newCareer().player.copyWith(reputation: 20),
    );
    final independent = engine.contractOffers(base);
    final global = engine.contractOffers(
      base.copyWith(activeAgentId: 'agent-global-network'),
    );
    final negotiator = engine.contractOffers(
      base.copyWith(activeAgentId: 'agent-negotiator'),
    );
    expect(global.length, greaterThanOrEqualTo(independent.length));
    if (independent.isNotEmpty && negotiator.isNotEmpty) {
      expect(
        negotiator.first.weeklyWage,
        greaterThan(independent.first.weeklyWage),
      );
    }
    final report = engine.transferMarketReport(base);
    expect(report, hasLength(519));
    expect(report.every((entry) => entry.reason.isNotEmpty), isTrue);
    expect(report.where((entry) => !entry.accepted), isNotEmpty);
  });

  test('transfer requests persist and charge manager trust once per season',
      () {
    final initial = CareerSnapshot.newCareer(seed: 881);
    final targetLeague = buildLaunchWorld().leagues.firstWhere(
          (league) =>
              league.id != initial.world.leagueIdForClub(initial.clubId),
        );
    final preferredClubId =
        initial.world.leagueParticipants[targetLeague.id]!.first;
    final filed = engine.fileTransferRequest(
      snapshot: initial,
      targetLeagueId: targetLeague.id,
      preferredClubId: preferredClubId,
      updatedAt: initial.updatedAt.add(const Duration(minutes: 1)),
    );
    expect(
      filed.player.managerTrust,
      initial.player.managerTrust -
          CareerEngine.transferRequestManagerTrustPenalty,
    );
    expect(filed.transferRequest?.preferredClubId, preferredClubId);
    expect(filed.transferRequestTrustPenaltySeason, initial.season);
    final edited = engine.fileTransferRequest(
      snapshot: filed,
      targetLeagueId: targetLeague.id,
      updatedAt: filed.updatedAt.add(const Duration(minutes: 1)),
    );
    expect(edited.player.managerTrust, filed.player.managerTrust);
    final cancelled = engine.cancelTransferRequest(
      snapshot: edited,
      updatedAt: edited.updatedAt.add(const Duration(minutes: 1)),
    );
    expect(cancelled.transferRequest, isNull);
    expect(cancelled.player.managerTrust, filed.player.managerTrust);
    final refiled = engine.fileTransferRequest(
      snapshot: cancelled,
      targetLeagueId: targetLeague.id,
      preferredClubId: preferredClubId,
      updatedAt: cancelled.updatedAt.add(const Duration(minutes: 1)),
    );
    expect(refiled.player.managerTrust, filed.player.managerTrust);
    expect(
      CareerSnapshot.decode(refiled.encode()).transferRequest?.toJson(),
      refiled.transferRequest?.toJson(),
    );
  });

  test('transfer requests validate the target league and preferred club', () {
    final snapshot = CareerSnapshot.newCareer();
    expect(
      () => engine.fileTransferRequest(
        snapshot: snapshot,
        targetLeagueId: 'missing-league',
        updatedAt: snapshot.updatedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.fileTransferRequest(
        snapshot: snapshot,
        targetLeagueId: snapshot.world.leagueIdForClub(snapshot.clubId),
        preferredClubId: snapshot.clubId,
        updatedAt: snapshot.updatedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.fileTransferRequest(
        snapshot: snapshot,
        targetLeagueId: snapshot.world.leagueIdForClub(snapshot.clubId),
        preferredClubId: 'missing-club',
        updatedAt: snapshot.updatedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => engine.fileTransferRequest(
        snapshot: snapshot.copyWith(
          retired: true,
          phase: CareerPhase.retired,
        ),
        targetLeagueId: snapshot.world.leagueParticipants.keys.first,
        updatedAt: snapshot.updatedAt,
      ),
      throwsStateError,
    );
    expect(
      () => engine.cancelTransferRequest(
        snapshot: snapshot.copyWith(
          retired: true,
          phase: CareerPhase.retired,
          transferRequest: TransferRequest(
            targetLeagueId: snapshot.world.leagueIdForClub(snapshot.clubId),
            filedSeason: snapshot.season,
            filedWeek: snapshot.week,
          ),
        ),
        updatedAt: snapshot.updatedAt,
      ),
      throwsStateError,
    );
  });

  test('a realistic requested league and club lead the offseason offers', () {
    var snapshot = playSeason(
      CareerSnapshot.newCareer(seed: 551).copyWith(
        player: CareerSnapshot.newCareer().player.copyWith(
              attributes: PlayerAttributes({
                for (final attribute in PlayerAttribute.values) attribute: 82,
              }),
              reputation: 80,
            ),
      ),
    );
    final world = buildLaunchWorld();
    final nextWorld = worldSimulator.beginNextSeason(
      snapshot.world,
      snapshot.seed,
      definition: world,
    );
    final targetLeague = world.leagues.firstWhere(
      (league) => league.id != nextWorld.leagueIdForClub(snapshot.clubId),
    );
    final preferredClubId = nextWorld.leagueParticipants[targetLeague.id]!
        .firstWhere((clubId) => clubId != snapshot.clubId);
    snapshot = engine.fileTransferRequest(
      snapshot: snapshot,
      targetLeagueId: targetLeague.id,
      preferredClubId: preferredClubId,
      updatedAt: snapshot.updatedAt.add(const Duration(minutes: 1)),
      definition: world,
    );
    final offers = engine.contractOffers(snapshot, definition: world);
    expect(offers, isNotEmpty);
    expect(offers.first.clubId, preferredClubId);
    expect(
      nextWorld.leagueParticipants[targetLeague.id],
      contains(offers.first.clubId),
    );
    expect(
      engine
          .contractOffers(snapshot, definition: world)
          .map((offer) => offer.clubId),
      offers.map((offer) => offer.clubId),
    );
  });

  test('cancelled requests retain the no-request offer ordering', () {
    final base = CareerSnapshot.newCareer(seed: 6671);
    final baseline = engine.contractOffers(base);
    final targetLeagueId = base.world.leagueParticipants.keys.firstWhere(
      (leagueId) => leagueId != base.world.leagueIdForClub(base.clubId),
    );
    final filed = engine.fileTransferRequest(
      snapshot: base,
      targetLeagueId: targetLeagueId,
      updatedAt: base.updatedAt.add(const Duration(minutes: 1)),
    );
    final cancelled = engine.cancelTransferRequest(
      snapshot: filed,
      updatedAt: filed.updatedAt.add(const Duration(minutes: 1)),
    );

    expect(
      engine.contractOffers(cancelled).map(
            (offer) => (
              offer.clubId,
              offer.seasons,
              offer.weeklyWage,
              offer.appearanceBonus,
              offer.promisedRole,
              offer.tacticalFit,
              offer.interestReason,
            ),
          ),
      baseline.map(
        (offer) => (
          offer.clubId,
          offer.seasons,
          offer.weeklyWage,
          offer.appearanceBonus,
          offer.promisedRole,
          offer.tacticalFit,
          offer.interestReason,
        ),
      ),
    );
  });

  test('completing the offseason clears transfer-request state', () {
    var snapshot = playSeason(CareerSnapshot.newCareer(seed: 7701));
    final world = buildLaunchWorld();
    final nextWorld = worldSimulator.beginNextSeason(
      snapshot.world,
      snapshot.seed,
      definition: world,
    );
    final targetLeagueId = nextWorld.leagueParticipants.keys.firstWhere(
      (leagueId) => leagueId != nextWorld.leagueIdForClub(snapshot.clubId),
    );
    snapshot = engine.fileTransferRequest(
      snapshot: snapshot,
      targetLeagueId: targetLeagueId,
      updatedAt: snapshot.updatedAt.add(const Duration(minutes: 1)),
      definition: world,
    );
    final next = engine.completeOffseason(
      snapshot,
      updatedAt: snapshot.updatedAt.add(const Duration(days: 21)),
      definition: world,
    );
    expect(next.transferRequest, isNull);
    expect(next.transferRequestTrustPenaltySeason, isNull);
  });

  test('career completes exactly 20 seasons and produces a legacy verdict', () {
    var snapshot = CareerSnapshot.newCareer(seed: 991);
    while (!snapshot.retired) {
      snapshot = playSeason(snapshot);
      snapshot = engine.completeOffseason(
        snapshot,
        updatedAt: snapshot.updatedAt.add(const Duration(days: 21)),
      );
    }
    expect(snapshot.seasonHistory, hasLength(20));
    expect(snapshot.player.age, 36);
    expect(snapshot.phase, CareerPhase.retired);
    expect(snapshot.legacyScore, greaterThan(0));
    expect(calculateLegacyVerdict(snapshot).score, snapshot.legacyScore);
  });

  test('cups, international play, and the four-year tournament are durable',
      () {
    var snapshot = CareerSnapshot.newCareer(seed: 1204).copyWith(
      player: CareerSnapshot.newCareer().player.copyWith(
            attributes: PlayerAttributes({
              for (final attribute in PlayerAttribute.values) attribute: 80,
            }),
            reputation: 80,
          ),
    );
    for (var season = 1; season <= 4; season++) {
      snapshot = playSeason(snapshot);
      final cup = snapshot.world.competitions['england-cup'];
      expect(cup, isNotNull);
      expect(cup!.winnerId, isNotNull);
      expect(cup.fixtures.where((fixture) => fixture.isPlayed), hasLength(19));
      final international =
          snapshot.world.competitions['world-champions-series'];
      expect(international?.winnerId, isNotNull);
      if (season == 4) {
        final national =
            snapshot.world.competitions['world-nations-championship'];
        expect(national?.winnerId, isNotNull);
        expect(
          CareerSnapshot.decode(snapshot.encode())
              .world
              .competitions['world-nations-championship']
              ?.winnerId,
          national?.winnerId,
        );
      }
      snapshot = engine.completeOffseason(
        snapshot,
        updatedAt: snapshot.updatedAt.add(const Duration(days: 21)),
      );
    }
    expect(snapshot.world.nationalTournamentWinner, isNotNull);
  });
}
