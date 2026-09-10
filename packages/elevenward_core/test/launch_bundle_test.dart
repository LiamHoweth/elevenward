import 'dart:convert';
import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  test('legacy launch bundle decodes and retains its original world', () {
    final source =
        File('../../assets/content/launch-2026.2.0.json').readAsStringSync();
    final bundle = (jsonDecode(source) as Map).cast<String, Object?>();
    final catalog = ContentCatalog.fromBundle(bundle);

    expect(catalog.version, '2026.2.0');
    expect(catalog.matchSituations, hasLength(160));
    expect(catalog.careerEvents, hasLength(200));
    expect(catalog.lifestyleItems, hasLength(120));
    expect(catalog.world.clubs, hasLength(120));
    expect(catalog.world.leagues, hasLength(12));
    expect(catalog.world.nationalTeams, hasLength(24));
    expect(
      catalog.world.internationalClubCompetition.participantIds,
      hasLength(12),
    );
    expect(validateContentCatalog(catalog), isEmpty);

    const simulator = WorldSimulator();
    var state = CareerWorldState.initial(catalog.world);
    while (state.season < 4) {
      state = simulator.beginNextSeason(
        state,
        2026,
        definition: catalog.world,
      );
    }
    expect(
      state.competitions['world-champions-series']!.participantIds,
      hasLength(12),
    );
    expect(
      state.competitions['major-national-tournament']!.participantIds,
      hasLength(24),
    );
  });

  test('expanded launch bundle has the complete immutable world catalog', () {
    final file = File('../../assets/content/launch-2026.3.0.json');
    final source = file.readAsStringSync();
    final bundle = (jsonDecode(source) as Map).cast<String, Object?>();
    final catalog = ContentCatalog.fromBundle(bundle);

    expect(catalog.version, '2026.3.0');
    expect(catalog.world.countries, hasLength(48));
    expect(catalog.world.nationalTeams, hasLength(48));
    expect(
      catalog.world.countries.where((country) => country.hasLeague),
      hasLength(26),
    );
    expect(catalog.world.leagues, hasLength(52));
    expect(catalog.world.clubs, hasLength(520));
    expect(catalog.world.domesticCups, hasLength(26));
    expect(
      catalog.world.internationalClubCompetition.participantIds,
      hasLength(32),
    );
    expect(source.length, lessThan(5 * 1024 * 1024));
    expect(validateContentCatalog(catalog), isEmpty);
  });

  test('expanded bundle preserves all six original systems by id and name', () {
    ContentCatalog read(String version) {
      final source = File(
        '../../assets/content/launch-$version.json',
      ).readAsStringSync();
      return ContentCatalog.fromBundle(
        (jsonDecode(source) as Map).cast<String, Object?>(),
      );
    }

    final legacy = read('2026.2.0');
    final expanded = read('2026.3.0');
    const countries = {
      'england',
      'spain',
      'france',
      'germany',
      'brazil',
      'united-states',
    };
    Map<String, String> clubs(ContentCatalog catalog) => {
          for (final club in catalog.world.clubs)
            if (countries.contains(club.countryId)) club.id: club.name,
        };
    Map<String, String> leagues(ContentCatalog catalog) => {
          for (final league in catalog.world.leagues)
            if (countries.contains(league.countryId)) league.id: league.name,
        };

    expect(clubs(expanded), clubs(legacy));
    expect(leagues(expanded), leagues(legacy));
  });
}
