import 'package:elevenward_core/elevenward_core.dart';

const _leagueAliases = <String, List<String>>{
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

/// Returns the familiar user-facing label for a shipped domestic league while
/// retaining authored names for custom or otherwise unknown competitions.
String leagueDisplayName(LeagueDefinition league) {
  if (league.id != '${league.countryId}-${league.division.name}') {
    return league.name;
  }
  final aliases = _leagueAliases[league.countryId];
  return aliases?[league.division.index] ?? league.name;
}

bool leagueMatchesSearch(LeagueDefinition league, String normalizedTerm) {
  if (normalizedTerm.isEmpty) return true;
  return leagueDisplayName(league).toLowerCase().contains(normalizedTerm) ||
      league.name.toLowerCase().contains(normalizedTerm);
}
