import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  final world = buildLaunchWorld();

  test('launch world has the expanded competition scale', () {
    expect(
        world.countries.where((country) => country.hasLeague), hasLength(26));
    expect(world.clubs, hasLength(520));
    expect(world.clubs.map((club) => club.id).toSet(), hasLength(520));
    expect(world.leagues, hasLength(52));
    expect(world.domesticCups, hasLength(26));
    expect(world.nationalTeams, hasLength(48));
    expect(world.internationalClubCompetition.participantIds, hasLength(32));
  });

  test('every league has ten clubs and an eighteen-match schedule', () {
    final fixtureIds = <String>{};
    for (final league in world.leagues) {
      expect(league.clubIds, hasLength(10));
      expect(league.fixtures, hasLength(90));
      expect(league.matchweeks, 18);
      for (final fixture in league.fixtures) {
        expect(fixtureIds.add(fixture.id), isTrue, reason: fixture.id);
      }
      for (final clubId in league.clubIds) {
        final games = league.fixtures.where(
            (fixture) => fixture.homeId == clubId || fixture.awayId == clubId);
        expect(games, hasLength(18));
      }
    }
  });

  test('table applies results and sorts by points then goal difference', () {
    final league = world.leagues.first;
    final played = [
      league.fixtures[0].withScore(3, 0),
      league.fixtures[1].withScore(1, 1),
    ];
    final table = tableFromFixtures(league.clubIds, played);
    expect(table, hasLength(10));
    expect(table.first.points, 3);
    expect(table.first.goalDifference, 3);
    expect(table.fold<int>(0, (sum, row) => sum + row.played), 4);
  });

  test('promotion and relegation move exactly two clubs', () {
    final first = List.generate(10, (index) => StandingRow(clubId: 'f$index'));
    final second = List.generate(10, (index) => StandingRow(clubId: 's$index'));
    final movement = promotionAndRelegation(
      firstDivision: first,
      secondDivision: second,
    );
    expect(movement.promoted, ['s0', 's1']);
    expect(movement.relegated, ['f8', 'f9']);
  });

  test('major national tournament returns every fourth season', () {
    expect(isMajorNationalTournamentSeason(3), isFalse);
    expect(isMajorNationalTournamentSeason(4), isTrue);
    expect(isMajorNationalTournamentSeason(8), isTrue);
  });
}
