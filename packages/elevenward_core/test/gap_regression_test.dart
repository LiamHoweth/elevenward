import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const weekly = WeeklySimulator();
  const world = WorldSimulator();
  const engine = CareerEngine();
  final now = DateTime.utc(2026, 9, 4);
  WeeklyResult advance(CareerSnapshot snapshot) => weekly.advance(
        snapshot: snapshot,
        choice: const WeeklyChoice(
            focus: PlayerAttribute.passing,
            intensity: TrainingIntensity.balanced,
            spotlightApproach: SpotlightApproach.safe),
        opponent: world.opponentFor(snapshot),
        updatedAt: now,
      );

  test('actual contract wage and appearance bonus fund the receipt', () {
    final snapshot = CareerSnapshot.newCareer().copyWith(
      contract: const ContractState(weeklyWage: 3456, appearanceBonus: 123),
    );
    final result = advance(snapshot);
    final expected =
        3456 + (result.selection.status == SelectionStatus.omitted ? 0 : 123);
    expect(result.deltas.money, expected);
    expect(result.snapshot.player.money - snapshot.player.money, expected);
  });

  test('sponsor earns the final installment before expiring', () {
    var snapshot = CareerSnapshot.newCareer();
    snapshot = snapshot.copyWith(
        player: snapshot.player.copyWith(reputation: 40),
        sponsorContracts: const [
          SponsorContract(
              id: 'test',
              weeksRemaining: 1,
              weeklyPayout: 250,
              obligation: 'maintain-reputation-35')
        ]);
    final sponsored = advance(snapshot);
    final plain = advance(snapshot.copyWith(sponsorContracts: []));
    expect(sponsored.deltas.money - plain.deltas.money, 250);
    expect(sponsored.sponsorPayout, 250);
    expect(sponsored.endedSponsorIds, ['test']);
    expect(sponsored.snapshot.sponsorContracts, isEmpty);
  });

  test('equipped lifestyle and relationships create ongoing weekly effects',
      () {
    final base = CareerSnapshot.newCareer(seed: 550).copyWith(
      wellness: 50,
      relationships: const RelationshipState(
        manager: 20,
        teammates: 50,
        agent: 50,
        family: 80,
        community: 80,
      ),
      player: CareerSnapshot.newCareer().player.copyWith(
            fitness: 50,
            form: 60,
            managerTrust: 60,
          ),
    );
    final equipped = base.copyWith(
      equippedItemIds: const {
        'home': 'home-test',
        'transportation': 'transport-test',
        'style': 'style-test',
        'wellness': 'wellness-test',
      },
    );
    final plainResult = advance(base);
    final equippedResult = advance(equipped);
    expect(
      equippedResult.snapshot.player.fitness,
      plainResult.snapshot.player.fitness + 3,
    );
    expect(
      equippedResult.snapshot.wellness,
      plainResult.snapshot.wellness + 4,
    );
    expect(
      equippedResult.factors.map((factor) => factor.label),
      contains('Equipped lifestyle'),
    );

    final supportiveManager = weekly.previewSelection(
      snapshot: base.copyWith(
        relationships: base.relationships.copyWith(manager: 90),
      ),
      opponent: world.opponentFor(base),
    );
    final strainedManager = weekly.previewSelection(
      snapshot: base,
      opponent: world.opponentFor(base),
    );
    expect(supportiveManager.score, greaterThan(strainedManager.score));

    final legacyJson = equipped.toJson()..['rulesVersion'] = '2026.1';
    final legacyEquipped = CareerSnapshot.fromJson(legacyJson);
    final legacyPlain = legacyEquipped.copyWith(equippedItemIds: const {});
    expect(
      advance(legacyEquipped).snapshot.player.fitness,
      advance(legacyPlain).snapshot.player.fitness,
    );
    expect(
      advance(legacyEquipped).snapshot.wellness,
      legacyEquipped.wellness,
    );
  });

  test('receipts agree with saved cup results and league points all season',
      () {
    var snapshot = CareerSnapshot.newCareer(seed: 4321);
    while (snapshot.phase == CareerPhase.inSeason) {
      final result = advance(snapshot);
      final competition =
          result.snapshot.world.competitions[result.opponent.competitionId];
      if (competition != null) {
        final fixture = competition.fixtures.firstWhere((fixture) =>
            fixture.matchweek == snapshot.week &&
            (fixture.homeId == snapshot.clubId ||
                fixture.awayId == snapshot.clubId));
        expect(result.homeScore, fixture.homeGoals);
        expect(result.awayScore, fixture.awayGoals);
      }
      snapshot = result.snapshot;
      final record = snapshot.world
          .table(snapshot.world.leagueIdForClub(snapshot.clubId))
          .firstWhere((record) => record.clubId == snapshot.clubId);
      expect(snapshot.points, record.points);
    }
    expect(() => advance(snapshot), throwsStateError);
  });

  test('knockout tiebreak method is saved and survives serialization', () {
    var foundDecision = false;
    for (var seed = 1; seed <= 80 && !foundDecision; seed++) {
      var snapshot = CareerSnapshot.newCareer(seed: seed);
      while (snapshot.phase == CareerPhase.inSeason) {
        final result = advance(snapshot);
        if (result.fixtureDecision != FixtureDecision.regulation) {
          final restored = CareerSnapshot.decode(result.snapshot.encode());
          final fixture = restored
              .world.competitions[result.opponent.competitionId]!.fixtures
              .firstWhere(
            (item) =>
                item.matchweek == snapshot.week &&
                (item.homeId == snapshot.clubId ||
                    item.awayId == snapshot.clubId),
          );
          expect(fixture.decision, result.fixtureDecision);
          foundDecision = true;
        }
        snapshot = result.snapshot;
      }
    }
    expect(foundDecision, isTrue);
  });

  test('event cooldown crosses seasons and never bypasses sponsor eligibility',
      () {
    final catalog = buildLaunchContent();
    final family = catalog.careerEvents
        .firstWhere((event) => event.category == CareerEventCategory.family);
    var snapshot = CareerSnapshot.newCareer()
        .copyWith(season: 2, week: 1, resolvedEventIds: ['1:18:${family.id}']);
    expect(
        engine
            .eligibleEvents(snapshot, catalog)
            .any((event) => event.category == CareerEventCategory.family),
        isFalse);
    snapshot = snapshot.copyWith(week: 4);
    expect(
        engine
            .eligibleEvents(snapshot, catalog)
            .any((event) => event.category == CareerEventCategory.family),
        isTrue);
    expect(
        engine
            .eligibleEvents(snapshot, catalog)
            .any((event) => event.category == CareerEventCategory.sponsor),
        isFalse);
  });

  test(
      'forged contract terms are rejected, one genuine negotiation is accepted',
      () {
    var snapshot = CareerSnapshot.newCareer(seed: 765);
    while (snapshot.phase == CareerPhase.inSeason) {
      snapshot = advance(snapshot).snapshot;
    }
    final offer = engine.contractOffers(snapshot).first;
    final forged = ContractOffer(
        clubId: offer.clubId,
        seasons: offer.seasons,
        weeklyWage: offer.weeklyWage * 100,
        appearanceBonus: offer.appearanceBonus,
        promisedRole: offer.promisedRole,
        tacticalFit: offer.tacticalFit,
        interestReason: '');
    expect(
        () => engine.completeOffseason(snapshot,
            updatedAt: now, acceptedOffer: forged),
        throwsStateError);
    final negotiated = engine.negotiateOffer(
        snapshot: snapshot, offer: offer, priority: NegotiationPriority.wage);
    expect(
        engine
            .completeOffseason(snapshot,
                updatedAt: now, acceptedOffer: negotiated)
            .contract
            .weeklyWage,
        negotiated.weeklyWage);
  });

  test('expired low-interest careers always receive a free-agency route', () {
    var snapshot = CareerSnapshot.newCareer(seed: 17).copyWith(
      phase: CareerPhase.offseason,
      contract: const ContractState(
        seasonsRemaining: 1,
        roleSatisfaction: 0,
      ),
      player: CareerSnapshot.newCareer().player.copyWith(
            reputation: 0,
            managerTrust: 1,
            attributes: PlayerAttributes({
              for (final attribute in PlayerAttribute.values) attribute: 1,
            }),
          ),
    );
    expect(engine.renewalOffer(snapshot), isNull);
    final offers = engine.contractOffers(snapshot);
    expect(offers, hasLength(3));
    expect(offers.every((offer) => offer.seasons == 1), isTrue);
    snapshot = engine.completeOffseason(
      snapshot,
      updatedAt: now,
      acceptedOffer: offers.first,
    );
    expect(snapshot.phase, CareerPhase.inSeason);
    expect(snapshot.contract.clubId, offers.first.clubId);
  });

  test('national call-ups require a decision and persist international caps',
      () {
    var worldState = CareerWorldState.initial();
    for (var season = 2; season <= 4; season++) {
      worldState = world.beginNextSeason(worldState, 919 + season);
    }
    final strongPlayer = CareerSnapshot.newCareer().player.copyWith(
          attributes: PlayerAttributes({
            for (final attribute in PlayerAttribute.values) attribute: 82,
          }),
          reputation: 82,
          managerTrust: 90,
          form: 90,
          fitness: 90,
        );
    var snapshot = CareerSnapshot.newCareer(seed: 919).copyWith(
      season: 4,
      world: worldState,
      player: strongPlayer,
    );
    final tournament =
        snapshot.world.competitions['major-national-tournament']!;
    final firstNationalFixture = tournament.fixtures.firstWhere(
      (fixture) =>
          fixture.homeId == snapshot.player.nationalTeamId ||
          fixture.awayId == snapshot.player.nationalTeamId,
    );
    snapshot = snapshot.copyWith(week: firstNationalFixture.matchweek);

    expect(engine.hasNationalTeamInvitation(snapshot), isTrue);
    final declined = engine.decideNationalTeamCallUp(
      snapshot: snapshot,
      accept: false,
      updatedAt: now,
    );
    expect(
      world.opponentFor(declined).competitionKind,
      isNot(CompetitionKind.nationalTournament),
    );

    snapshot = engine.decideNationalTeamCallUp(
      snapshot: snapshot,
      accept: true,
      updatedAt: now,
    );
    expect(engine.hasNationalTeamInvitation(snapshot), isFalse);
    final opponent = world.opponentFor(snapshot);
    expect(opponent.competitionKind, CompetitionKind.nationalTournament);
    final result = weekly.advance(
      snapshot: snapshot,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.passing,
        intensity: TrainingIntensity.light,
        spotlightApproach: SpotlightApproach.safe,
      ),
      opponent: opponent,
      updatedAt: now,
    );
    expect(result.selection.status, isNot(SelectionStatus.omitted));
    expect(result.snapshot.nationalTeam.caps, 1);
    expect(
      CareerSnapshot.decode(result.snapshot.encode()).nationalTeam.caps,
      1,
    );
  });
}
