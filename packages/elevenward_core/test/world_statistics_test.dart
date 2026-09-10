import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const calculator = WorldStatisticsCalculator();

  test('expanded world ranks every club deterministically before kickoff', () {
    final definition = buildLaunchWorld();
    final state = CareerWorldState.initial(definition);

    final first = calculator.calculate(definition: definition, state: state);
    final second = calculator.calculate(definition: definition, state: state);

    expect(first.rankings, hasLength(520));
    expect(
      first.rankings.map((entry) => entry.club.id),
      second.rankings.map((entry) => entry.club.id),
    );
    expect(first.totalMatches, 0);
    expect(first.totalGoals, 0);
    expect(first.averageGoalsPerMatch, 0);
    expect(first.firstDivisionLeaders, hasLength(26));
    expect(
      first.rankings.map((entry) => entry.rank),
      List<int>.generate(520, (index) => index + 1),
    );

    final mexico = first.rankingForClub('mexico-valle-plata-city');
    final unitedStates = first.rankingForClub(
      'united-states-cascadia-pines',
    );
    final poland = first.rankingForClub('poland-amber-coast-sporting');
    expect(mexico.club.quality, unitedStates.club.quality);
    expect(unitedStates.club.quality, poland.club.quality);
    expect(mexico.worldRating, greaterThan(unitedStates.worldRating));
    expect(unitedStates.worldRating, greaterThan(poland.worldRating));
  });

  test('live results update world totals, leaders, and club form', () {
    final definition = buildLaunchWorld();
    final initial = CareerWorldState.initial(definition);
    final league = definition.leagues.firstWhere(
      (league) => league.id == 'england-first',
    );
    final winnerId = initial.leagueParticipants[league.id]!.first;
    final loserId = initial.leagueParticipants[league.id]![1];
    final leagueRecords = {
      for (final entry in initial.leagueRecords.entries)
        entry.key: Map<String, ClubSeasonRecord>.from(entry.value),
    };
    leagueRecords[league.id]![winnerId] = const ClubSeasonRecord(
      played: 2,
      won: 2,
      goalsFor: 5,
      goalsAgainst: 1,
    );
    leagueRecords[league.id]![loserId] = const ClubSeasonRecord(
      played: 2,
      lost: 2,
      goalsFor: 1,
      goalsAgainst: 5,
    );
    final result = calculator.calculate(
      definition: definition,
      state: initial.copyWith(leagueRecords: leagueRecords),
    );

    expect(result.totalMatches, 2);
    expect(result.totalGoals, 6);
    expect(result.averageGoalsPerMatch, 3);
    expect(result.strongestAttack?.club.id, winnerId);
    expect(result.bestDefense?.club.id, winnerId);
    expect(result.mostWins?.club.id, winnerId);
    expect(result.unbeatenClubCount, 1);
    expect(
      result.rankingForClub(winnerId).worldRating,
      greaterThan(result.rankingForClub(loserId).worldRating),
    );
  });

  test('world totals include played cup and international fixtures', () {
    final definition = buildLaunchWorld();
    final initial = CareerWorldState.initial(definition);
    final competition = initial.competitions.values.first;
    final playedFixture = competition.fixtures.first.withScore(2, 1);
    final competitions = Map<String, CompetitionProgress>.from(
      initial.competitions,
    );
    competitions[competition.id] = competition.copyWith(
      fixtures: [playedFixture, ...competition.fixtures.skip(1)],
    );

    final result = calculator.calculate(
      definition: definition,
      state: initial.copyWith(competitions: competitions),
    );

    expect(result.totalMatches, 1);
    expect(result.totalGoals, 3);
    expect(result.averageGoalsPerMatch, 3);
  });

  test('legacy worlds rank only their pinned club catalog', () {
    final definition = buildLegacyLaunchWorld();
    final result = calculator.calculate(
      definition: definition,
      state: CareerWorldState.initial(definition),
    );

    expect(result.rankings, hasLength(120));
    expect(result.firstDivisionLeaders, hasLength(6));
  });
}
