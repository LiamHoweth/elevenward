import 'dart:convert';
import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';

const _locales = ['en', 'es', 'pt-BR', 'fr'];

Map<String, String> _sameText(String value) => {
      for (final locale in _locales) locale: value,
    };

Map<String, Object?> _club(ClubDefinition club) => {
      ...club.toJson(),
      'text': _sameText(club.name),
    };

Map<String, Object?> _nationalTeam(NationalTeamDefinition team) => {
      ...team.toJson(),
      'text': _sameText(team.countryName),
    };

Map<String, Object?> _situation(MatchSituationDefinition situation) => {
      ...situation.toJson(),
      'text': situation.prompt.toJson(),
    };

Map<String, Object?> _event(CareerEventDefinition event) => {
      ...event.toJson(),
      'text': event.title.toJson(),
    };

Map<String, Object?> _item(LifestyleItemDefinition item) => {
      ...item.toJson(),
      'text': item.name.toJson(),
    };

void main(List<String> arguments) {
  final destination = arguments.isEmpty
      ? 'assets/content/launch-2026.2.0.json'
      : arguments.single;
  final world = buildLaunchWorld();
  final content = buildLaunchContent();
  final bundle = <String, Object?>{
    'metadata': {
      'releaseVersion': content.version,
      'minClientVersion': '0.1.0',
      'maxClientVersion': '1.99.99',
      'rulesVersion': CareerSnapshot.currentRulesVersion,
      'generatedAt': '2026-09-03T00:00:00.000Z',
    },
    'clubs': world.clubs.map(_club).toList(),
    'nationalTeams': world.nationalTeams.map(_nationalTeam).toList(),
    'matchSituations': content.matchSituations.map(_situation).toList(),
    'events': content.careerEvents.map(_event).toList(),
    'lifestyleItems': content.lifestyleItems.map(_item).toList(),
    'leagues': world.leagues
        .map((league) => {
              'id': league.id,
              'name': league.name,
              'nation': league.nation.name,
              'division': league.division.name,
              'clubIds': league.clubIds,
            })
        .toList(),
    'fixtures': world.leagues
        .expand((league) => league.fixtures)
        .map((fixture) => fixture.toJson())
        .toList(),
    'domesticCups': world.domesticCups
        .map((cup) => {
              'id': cup.id,
              'name': cup.name,
              'participantIds': cup.participantIds,
              'openingFixtures':
                  cup.fixtures.map((fixture) => fixture.toJson()).toList(),
            })
        .toList(),
    'internationalClubCompetition': {
      'id': world.internationalClubCompetition.id,
      'name': world.internationalClubCompetition.name,
      'participantIds': world.internationalClubCompetition.participantIds,
      'fixtures': world.internationalClubCompetition.fixtures
          .map((fixture) => fixture.toJson())
          .toList(),
    },
  };
  final file = File(destination);
  file.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(bundle)}\n');
  stdout.writeln(
    'Wrote $destination (${world.clubs.length} clubs, '
    '${content.matchSituations.length} situations, '
    '${content.careerEvents.length} events).',
  );
}
