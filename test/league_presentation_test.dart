import 'package:elevenward/src/league_presentation.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expected = <String, List<String>>{
    'england': ['English Premier Division', 'English Championship'],
    'spain': ['Spanish Primera', 'Spanish Segunda'],
    'brazil': ['Brazilian Série A', 'Brazilian Série B'],
    'italy': ['Italian Serie A', 'Italian Serie B'],
    'germany': ['German Bundesliga', 'German 2. Liga'],
    'france': ['French Ligue One', 'French Ligue Two'],
    'portugal': ['Portuguese Primeira', 'Portuguese Segunda'],
    'argentina': ['Argentine Primera', 'Argentine Nacional'],
    'netherlands': ['Dutch Premier Division', 'Dutch First Division'],
    'colombia': ['Colombian Primera A', 'Colombian Primera B'],
    'turkey': ['Turkish Super Division', 'Turkish First Division'],
    'belgium': ['Belgian Pro Division', 'Belgian Challenger Division'],
    'saudi-arabia': ['Saudi Premier Division', 'Saudi First Division'],
    'ecuador': ['Ecuadorian Serie A', 'Ecuadorian Serie B'],
    'greece': ['Greek Super Division', 'Greek League Two'],
    'egypt': ['Egyptian Premier Division', 'Egyptian Second Division'],
    'czechia': ['Czech First League', 'Czech National League'],
    'japan': ['Japan League One', 'Japan League Two'],
    'paraguay': ['Paraguayan Primera', 'Paraguayan Intermedia'],
    'cyprus': ['Cypriot First Division', 'Cypriot Second Division'],
    'uruguay': ['Uruguayan Primera', 'Uruguayan Segunda'],
    'mexico': ['Mexican Premier Division', 'Mexican Expansion Division'],
    'poland': ['Polish Premier Division', 'Polish First Division'],
    'scotland': ['Scottish Premiership', 'Scottish Championship'],
    'denmark': ['Danish Super Division', 'Danish First Division'],
    'united-states': ['American Major League', 'American Championship'],
  };

  test('all 52 expanded leagues receive the approved presentation alias', () {
    final world = buildLaunchWorld();

    expect(world.leagues, hasLength(52));
    for (final league in world.leagues) {
      expect(
        leagueDisplayName(league),
        expected[league.countryId]![league.division.index],
      );
    }
  });

  test('legacy leagues use aliases without changing IDs or stored names', () {
    final world = buildLegacyLaunchWorld();

    expect(world.leagues, hasLength(12));
    for (final league in world.leagues) {
      expect(leagueDisplayName(league), isNot(league.name));
      expect(leagueMatchesSearch(league, league.name.toLowerCase()), isTrue);
      expect(
        leagueMatchesSearch(league, leagueDisplayName(league).toLowerCase()),
        isTrue,
      );
    }
  });

  test('custom league IDs retain their authored name', () {
    final custom = LeagueDefinition(
      id: 'community-invitational',
      name: 'Community Invitational',
      countryId: 'england',
      systemRank: 1,
      division: DivisionLevel.first,
      clubIds: const [],
      fixtures: const [],
    );

    expect(leagueDisplayName(custom), custom.name);
  });
}
