import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = buildLaunchWorld();

  testWidgets('all 48 national teams resolve to Natural Earth geometry', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);

    expect(data, isNotNull);
    expect(data!.features, hasLength(greaterThan(200)));
    for (final country in world.countries) {
      expect(
        data.features.where((feature) => feature.countryId == country.id),
        isNotEmpty,
        reason: '${country.id} must map to Natural Earth geometry',
      );
    }
  });

  testWidgets('nationality is Home and all league countries are playable', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    final states = <String, WorldMapFeatureState>{
      for (final feature in data!.features)
        if (feature.countryId != null)
          feature.countryId!: worldMapFeatureState(
            feature: feature,
            homeCountryId: 'england',
          ),
    };

    expect(
      states.entries
          .where((entry) => entry.value == WorldMapFeatureState.home)
          .map((entry) => entry.key),
      ['england'],
    );
    expect(
      states.entries
          .where((entry) => entry.value == WorldMapFeatureState.playable)
          .map((entry) => entry.key)
          .toSet(),
      world.countries
          .where((country) => country.hasLeague && country.id != 'england')
          .map((country) => country.id)
          .toSet(),
    );

    final canadaStates = <String, WorldMapFeatureState>{
      for (final feature in data.features)
        if (feature.countryId != null)
          feature.countryId!: worldMapFeatureState(
            feature: feature,
            definition: world,
            homeCountryId: 'canada',
          ),
    };
    expect(canadaStates['canada'], WorldMapFeatureState.home);
    expect(canadaStates['england'], WorldMapFeatureState.playable);
  });

  testWidgets('selection outline does not replace the green Home state', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    final england = data!.features.firstWhere(
      (feature) => feature.countryId == 'england',
    );
    final spain = data.features.firstWhere(
      (feature) => feature.countryId == 'spain',
    );

    expect(
      worldMapFeatureState(
        feature: england,
        homeCountryId: 'england',
        selectedCountryId: 'england',
      ),
      WorldMapFeatureState.home,
    );
    expect(
      worldMapFeatureIsSelected(feature: england, selectedCountryId: 'england'),
      isTrue,
    );
    expect(
      worldMapFeatureState(
        feature: spain,
        homeCountryId: 'england',
        selectedCountryId: 'spain',
      ),
      WorldMapFeatureState.selected,
    );
  });

  testWidgets('legacy definitions do not expose expanded league countries', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    final legacy = buildLegacyLaunchWorld();
    final italy = data!.features.firstWhere(
      (feature) => feature.countryId == 'italy',
    );
    final states = <String, WorldMapFeatureState>{
      for (final feature in data.features)
        if (feature.countryId != null)
          feature.countryId!: worldMapFeatureState(
            feature: feature,
            definition: legacy,
            homeCountryId: 'england',
          ),
    };

    expect(states['italy'], WorldMapFeatureState.unavailable);
    expect(
      states.entries
          .where((entry) => entry.value == WorldMapFeatureState.playable)
          .map((entry) => entry.key)
          .toSet(),
      {'spain', 'france', 'germany', 'brazil', 'united-states'},
    );
    expect(
      worldMapFeatureState(
        feature: italy,
        definition: legacy,
        homeCountryId: 'england',
      ),
      WorldMapFeatureState.unavailable,
    );
  });

  testWidgets(
    'Japan nationality and Spain club retain independent active-world roles',
    (tester) async {
      final data = await tester.runAsync(WorldMapData.load);
      final japan = data!.features.firstWhere(
        (feature) => data.countryIdFor(feature, world) == 'japan',
      );
      final spain = data.features.firstWhere(
        (feature) => data.countryIdFor(feature, world) == 'spain',
      );
      final playable = world.leagues.map((league) => league.countryId).toSet();

      final japanRoles = worldMapFeatureRoles(
        feature: japan,
        definition: world,
        nationalityCountryId: 'japan',
        currentClubCountryId: 'spain',
        playableCountryIds: playable,
      );
      final spainRoles = worldMapFeatureRoles(
        feature: spain,
        definition: world,
        nationalityCountryId: 'japan',
        currentClubCountryId: 'spain',
        playableCountryIds: playable,
      );

      expect(japanRoles.isNationality, isTrue);
      expect(japanRoles.isCurrentClub, isFalse);
      expect(japanRoles.isPlayable, isTrue);
      expect(spainRoles.isNationality, isFalse);
      expect(spainRoles.isCurrentClub, isTrue);
      expect(spainRoles.isPlayable, isTrue);
    },
  );

  testWidgets('same-country nationality and club roles are both retained', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    final japan = data!.features.firstWhere(
      (feature) => data.countryIdFor(feature, world) == 'japan',
    );
    final roles = worldMapFeatureRoles(
      feature: japan,
      definition: world,
      nationalityCountryId: 'japan',
      currentClubCountryId: 'japan',
      playableCountryIds: {'japan'},
      selectedCountryId: 'japan',
    );

    expect(roles.isNationality, isTrue);
    expect(roles.isCurrentClub, isTrue);
    expect(roles.isPlayable, isTrue);
    expect(roles.isSelected, isTrue);
  });

  testWidgets('geometry stays independent while each pinned world sets roles', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    final italy = data!.features.firstWhere((feature) => feature.code == 'ITA');
    final legacy = buildLegacyLaunchWorld();

    expect(data.countryIdFor(italy, world), 'italy');
    expect(data.countryIdFor(italy, legacy), 'italy');
    expect(
      worldMapFeatureRoles(
        feature: italy,
        definition: world,
        nationalityCountryId: 'japan',
        playableCountryIds: world.leagues
            .map((league) => league.countryId)
            .toSet(),
      ).isPlayable,
      isTrue,
    );
    expect(
      worldMapFeatureRoles(
        feature: italy,
        definition: legacy,
        nationalityCountryId: 'japan',
        playableCountryIds: legacy.leagues
            .map((league) => league.countryId)
            .toSet(),
      ).isPlayable,
      isFalse,
    );
  });
}
