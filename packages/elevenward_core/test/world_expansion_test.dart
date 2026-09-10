import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  final world = buildLaunchWorld();
  const simulator = WorldSimulator();
  const weekly = WeeklySimulator();
  const engine = CareerEngine();

  CareerSnapshot invitedSnapshot({int seed = 4404}) {
    var state = CareerWorldState.initial(world);
    while (state.season < 4) {
      state = simulator.beginNextSeason(state, seed, definition: world);
    }
    final teamId = state.nationalQualification!.qualifiedTeamIds.first;
    final player = PlayerState.newCareer(
      id: 'international-player',
      name: 'International Player',
      archetype: Archetype.poacher,
      nationalTeamId: teamId,
    ).copyWith(
      attributes: PlayerAttributes({
        for (final attribute in PlayerAttribute.values) attribute: 90,
      }),
      reputation: 90,
      form: 90,
      fitness: 90,
      managerTrust: 90,
    );
    return CareerSnapshot.newCareer(
      seed: seed,
      player: player,
      worldDefinition: world,
    ).copyWith(
      season: 4,
      week: 18,
      phase: CareerPhase.internationalCallup,
      world: state,
      sponsorContracts: const [
        SponsorContract(
          id: 'postseason-sponsor',
          weeksRemaining: 5,
          weeklyPayout: 900,
          obligation: 'none',
        ),
      ],
      sponsorIds: const ['postseason-sponsor'],
      activeAgentId: 'agent-negotiator',
    );
  }

  test('expanded catalog has exact systems, divisions, cups, and entrants', () {
    expect(world.contentVersion, '2026.3.0');
    expect(world.nationalTeams, hasLength(48));
    expect(
        world.countries.where((country) => country.hasLeague), hasLength(26));
    expect(world.leagues, hasLength(52));
    expect(world.clubs, hasLength(520));
    expect(world.domesticCups, hasLength(26));
    expect(world.internationalClubCompetition.participantIds, hasLength(32));
    expect(
      world.countries
          .where((country) => country.leagueRank != null)
          .map((country) => country.leagueRank)
          .toSet(),
      {for (var rank = 1; rank <= 25; rank++) rank},
    );
    final rankedCountries = world.countries
        .where((country) => country.leagueRank != null)
        .toList()
      ..sort((left, right) => left.leagueRank!.compareTo(right.leagueRank!));
    expect(
      rankedCountries.map((country) => country.id),
      [
        'england',
        'spain',
        'brazil',
        'italy',
        'germany',
        'france',
        'portugal',
        'argentina',
        'netherlands',
        'colombia',
        'turkey',
        'belgium',
        'saudi-arabia',
        'ecuador',
        'greece',
        'egypt',
        'czechia',
        'japan',
        'paraguay',
        'cyprus',
        'uruguay',
        'mexico',
        'poland',
        'scotland',
        'denmark',
      ],
    );
    final entrants = world.internationalClubCompetition.participantIds
        .map(world.club)
        .toList(growable: false);
    expect(
        entrants.take(26).map((club) => club.countryId).toSet(), hasLength(26));
    expect(
      entrants
          .where(
              (club) => (world.country(club.countryId).leagueRank ?? 99) <= 6)
          .length,
      12,
    );
    final northAmericanSystems = world.countries
        .where(
          (country) =>
              country.hasLeague &&
              country.region == FootballRegion.northAmerica,
        )
        .toList()
      ..sort(
        (left, right) =>
            (left.leagueRank ?? 26).compareTo(right.leagueRank ?? 26),
      );
    expect(
      northAmericanSystems.map((country) => country.id),
      ['mexico', 'united-states'],
    );
    for (final league in world.leagues) {
      expect(league.clubIds, hasLength(10));
      expect(league.fixtures, hasLength(90));
      expect(league.matchweeks, 18);
    }
  });

  test('regional qualification is deterministic with exact allocations', () {
    final first = simulateNationalQualification(world, 4);
    final second = simulateNationalQualification(world, 4);
    expect(first.qualifiedTeamIds, second.qualifiedTeamIds);
    expect(
      first.fixtures.map(
        (key, value) => MapEntry(
          key,
          value.map((fixture) => fixture.toJson()).toList(),
        ),
      ),
      second.fixtures.map(
        (key, value) => MapEntry(
          key,
          value.map((fixture) => fixture.toJson()).toList(),
        ),
      ),
    );
    expect(first.qualifiedTeamIds, hasLength(32));
    for (final allocation in nationalQualificationSlots.entries) {
      final qualified = first.qualifiedTeamIds
          .map(world.nationalTeam)
          .where((team) => team.confederation == allocation.key);
      expect(qualified, hasLength(allocation.value));
      expect(first.tables[allocation.key.name], isNotEmpty);
      expect(first.fixtures[allocation.key.name], isNotEmpty);
    }
    for (final season in [4, 8, 12, 16, 20]) {
      final draw = simulateNationalQualification(world, season);
      for (var groupIndex = 0; groupIndex < 8; groupIndex++) {
        final group = draw.qualifiedTeamIds
            .sublist(groupIndex * 4, groupIndex * 4 + 4)
            .map(world.nationalTeam)
            .toList();
        for (final confederation in FootballConfederation.values) {
          final count =
              group.where((team) => team.confederation == confederation).length;
          expect(
            count,
            lessThanOrEqualTo(
              confederation == FootballConfederation.uefa ? 2 : 1,
            ),
            reason: 'season $season group ${groupIndex + 1}',
          );
        }
      }
    }
  });

  test('call-up formula clamps every national team at documented bounds', () {
    for (final team in world.nationalTeams) {
      final requirements = nationalCallupRequirements(world, team.id);
      expect(
        requirements.overall,
        (team.quality - 8).clamp(66, 82),
      );
      expect(
        requirements.reputation,
        (team.quality - 20).clamp(50, 70),
      );
    }
  });

  test('national postseason updates international stats only', () {
    var snapshot = invitedSnapshot();
    final accepted = engine.decideNationalTeamCallUp(
      snapshot: snapshot,
      accept: true,
      updatedAt: DateTime.utc(2026, 9, 7),
      definition: world,
    );
    expect(accepted.phase, CareerPhase.internationalTournament);
    snapshot = accepted;
    final beforeWorld = snapshot.world.toJson();
    final beforePlayer = snapshot.player;
    final beforeContract = snapshot.contract.toJson();
    final beforeSponsors =
        snapshot.sponsorContracts.map((contract) => contract.toJson()).toList();
    final beforeRelationships = snapshot.relationships.toJson();
    final beforeAttributes = snapshot.player.attributes.toJson();
    final beforeDevelopment = snapshot.developmentProgress;
    final beforeWellness = snapshot.wellness;
    final beforeBoostIds = snapshot.boostIdsUsed;
    final opponent = simulator.opponentFor(snapshot, definition: world);
    final result = weekly.advance(
      snapshot: snapshot,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.intensive,
        spotlightApproach: SpotlightApproach.safe,
      ),
      opponent: opponent,
      updatedAt: DateTime.utc(2026, 9, 14),
      definition: world,
    );

    expect(result.deltas.money, 0);
    expect(result.sponsorPayout, 0);
    expect(result.agentFee, 0);
    expect(result.snapshot.contract.toJson(), beforeContract);
    expect(
      result.snapshot.sponsorContracts
          .map((contract) => contract.toJson())
          .toList(),
      beforeSponsors,
    );
    expect(result.snapshot.relationships.toJson(), beforeRelationships);
    expect(result.snapshot.player.attributes.toJson(), beforeAttributes);
    expect(result.snapshot.developmentProgress, beforeDevelopment);
    expect(result.snapshot.wellness, beforeWellness);
    expect(result.snapshot.boostIdsUsed, beforeBoostIds);
    expect(result.snapshot.player.money, beforePlayer.money);
    expect(result.snapshot.player.appearances, beforePlayer.appearances);
    expect(result.snapshot.player.goals, beforePlayer.goals);
    expect(result.snapshot.player.assists, beforePlayer.assists);
    expect(result.snapshot.nationalTeam.caps, 1);
    expect(result.snapshot.nationalTeam.cycleAppearances, 1);
    expect(result.snapshot.world.toJson()['leagueRecords'],
        beforeWorld['leagueRecords']);
    expect(result.snapshot.world.toJson()['playerLeagueFixtures'],
        beforeWorld['playerLeagueFixtures']);
    for (final entry in snapshot.world.competitions.entries) {
      if (entry.value.kind == CompetitionKind.nationalTournament) continue;
      expect(
        result.snapshot.world.competitions[entry.key]!.toJson(),
        entry.value.toJson(),
      );
    }
  });

  test('declining simulates the event and records a zero-appearance history',
      () {
    final declined = engine.decideNationalTeamCallUp(
      snapshot: invitedSnapshot(seed: 5505),
      accept: false,
      updatedAt: DateTime.utc(2026, 9, 7),
      definition: world,
    );
    expect(declined.phase, CareerPhase.offseason);
    expect(
      declined.world.competitions['world-nations-championship']!.isComplete,
      isTrue,
    );
    expect(
        declined.world.nationalTournamentHistory.single.playerAppearances, 0);
    expect(
      declined.world.nationalTournamentHistory.single.playerFinish,
      'declinedCallup',
    );
  });

  test('season end records qualification and squad-threshold failures', () {
    final base = invitedSnapshot(seed: 7707);
    final qualifiers = base.world.nationalQualification!.qualifiedTeamIds;
    final qualifiedId = qualifiers.first;
    final eliminatedId = world.nationalTeams
        .map((team) => team.id)
        .firstWhere((id) => !qualifiers.contains(id));

    CareerSnapshot completeSeasonAs(String nationalTeamId) {
      final player = PlayerState.fromJson({
        ...base.player.toJson(),
        'nationalTeamId': nationalTeamId,
        'reputation': 0,
      });
      final snapshot = base.copyWith(
        phase: CareerPhase.inSeason,
        player: player,
        nationalTeam: const NationalTeamCareerState(),
      );
      return weekly
          .advance(
            snapshot: snapshot,
            choice: const WeeklyChoice(
              focus: PlayerAttribute.finishing,
              intensity: TrainingIntensity.light,
              spotlightApproach: SpotlightApproach.safe,
            ),
            opponent: simulator.opponentFor(snapshot, definition: world),
            updatedAt: DateTime.utc(2026, 9, 7),
            definition: world,
          )
          .snapshot;
    }

    final missedSquad = completeSeasonAs(qualifiedId);
    expect(missedSquad.phase, CareerPhase.offseason);
    expect(
      missedSquad.world.nationalTournamentHistory.single.playerFinish,
      'missedSquad',
    );

    final didNotQualify = completeSeasonAs(eliminatedId);
    expect(didNotQualify.phase, CareerPhase.offseason);
    expect(
      didNotQualify.world.nationalTournamentHistory.single.playerFinish,
      'didNotQualify',
    );
  });

  test('accepted tournament survives mid-cycle save and completes', () {
    var snapshot = engine.decideNationalTeamCallUp(
      snapshot: invitedSnapshot(seed: 6606),
      accept: true,
      updatedAt: DateTime.utc(2026, 9, 7),
      definition: world,
    );
    var played = 0;
    while (snapshot.phase == CareerPhase.internationalTournament) {
      final opponent = simulator.opponentFor(snapshot, definition: world);
      snapshot = weekly
          .advance(
            snapshot: snapshot,
            choice: const WeeklyChoice(
              focus: PlayerAttribute.composure,
              intensity: TrainingIntensity.light,
              spotlightApproach: SpotlightApproach.safe,
            ),
            opponent: opponent,
            updatedAt: snapshot.updatedAt.add(const Duration(days: 4)),
            definition: world,
          )
          .snapshot;
      played += 1;
      snapshot = CareerSnapshot.decode(snapshot.encode());
    }
    expect(played, inInclusiveRange(3, 7));
    expect(snapshot.phase, CareerPhase.offseason);
    expect(snapshot.world.nationalTournamentHistory, hasLength(1));
    expect(snapshot.world.nationalTournamentHistory.single.playerAppearances,
        played);
    expect(
      snapshot.world.competitions['world-nations-championship']!.winnerId,
      isNotNull,
    );
  });

  test('championship cycles are exactly seasons 4, 8, 12, 16, and 20', () {
    expect(
      [
        for (var season = 1; season <= 20; season++)
          if (isMajorNationalTournamentSeason(season)) season
      ],
      [4, 8, 12, 16, 20],
    );
  });
}
