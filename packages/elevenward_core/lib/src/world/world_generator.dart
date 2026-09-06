import 'world_models.dart';

const _nationNames = <FootballNation, String>{
  FootballNation.england: 'England',
  FootballNation.spain: 'Spain',
  FootballNation.france: 'France',
  FootballNation.germany: 'Germany',
  FootballNation.brazil: 'Brazil',
  FootballNation.unitedStates: 'United States',
};

const _leagueNames = <FootballNation, List<String>>{
  FootballNation.england: ['Crown Division', 'Crown Division II'],
  FootballNation.spain: ['Liga del Sol', 'Liga del Sol II'],
  FootballNation.france: ['Championnat Lumière', 'Championnat Lumière II'],
  FootballNation.germany: ['Bundeskrone', 'Bundeskrone II'],
  FootballNation.brazil: ['Série Horizonte', 'Série Horizonte II'],
  FootballNation.unitedStates: ['Continental League', 'Continental League II'],
};

const _clubNames = <FootballNation, List<String>>{
  FootballNation.england: [
    'Northstar Athletic',
    'Harbour Rovers',
    'Wrenford City',
    'Kingsmere Athletic',
    'Redwick Borough',
    'Alderwick United',
    'Calder Vale',
    'Eastmarch FC',
    'Whitecap Town',
    'Forgechester',
    'Copperhill FC',
    'Orchard Vale',
    'Ironbridge 04',
    'Beacon Town',
    'Ashcombe Union',
    'Moorland Rovers',
    'Rosebury City',
    'Foxmere Athletic',
    'Greyhaven FC',
    'Westbarrow',
  ],
  FootballNation.spain: [
    'Solmera CF',
    'Puerto Cobalto',
    'Sierra Dorada',
    'Ciudad Azahar',
    'Marisma Azul',
    'Valdeoro CF',
    'Estrella Norte',
    'Río Claro',
    'Costa Brava Unión',
    'Llanura Roja',
    'Bahía Serena',
    'Monteverde CF',
    'Alba Levante',
    'Castillo Sur',
    'Viento Cádiz',
    'Olivo Central',
    'Campo Realengo',
    'Luna Blanca',
    'Piedra Alta',
    'Naranjal CF',
  ],
  FootballNation.france: [
    'Étoile d’Aubrac',
    'Rivage Olympique',
    'Union Clairmont',
    'Montfleury FC',
    'Azur Saint-Rémy',
    'Racing Valoise',
    'Lumière AC',
    'Côte d’Argent',
    'Stade Bellande',
    'Rougefort',
    'Ardenne Sporting',
    'Marais Vendôme',
    'Belle-Rive FC',
    'Aurore Dijon',
    'Lorraine Union',
    'Vallon Bleu',
    'Cercle d’Orléans',
    'Grand Pin FC',
    'Océanique',
    'Vigne Rouge',
  ],
  FootballNation.germany: [
    'Rheinstadt 09',
    'Eisenwald SV',
    'Nordhafen',
    'Grünberg 03',
    'Adlerheim',
    'Blaukirchen',
    'Rotfels Union',
    'Sonnenfeld',
    'Westtor 11',
    'Mainbrücke',
    'Silbersee SV',
    'Hohenwald 06',
    'Falkenstadt',
    'Elbauen',
    'Kronental',
    'Berglicht 08',
    'Wiesengrund',
    'Ostmarke FC',
    'Tannenhof',
    'Donauwerk',
  ],
  FootballNation.brazil: [
    'Aurora Paulista',
    'Estrela do Mar',
    'União Serrana',
    'Atlético Ipê',
    'Horizonte Azul',
    'Ferroviário Central',
    'Ponte Dourada',
    'Vale Verde EC',
    'Nação Carioca',
    'Bravos do Sul',
    'Litoral FC',
    'Raio Mineiro',
    'Palmeira Nova',
    'Vitória do Norte',
    'Cerrado Clube',
    'Ribeira Atlético',
    'Jardim Imperial',
    'Oeste Rubro',
    'Canário Real',
    'Porto da Lua',
  ],
  FootballNation.unitedStates: [
    'Bay City Atlas',
    'Chicago Lakes',
    'Austin Sol',
    'Brooklyn Borough',
    'Cascadia Pines',
    'Miami Current',
    'Nashville Gold',
    'Phoenix Union',
    'Denver Summit',
    'Boston Lanterns',
    'San Diego Tide',
    'Detroit Forge',
    'Carolina Flight',
    'Portland Evergreen',
    'Las Vegas Neon',
    'St. Louis Archers',
    'Minnesota North',
    'New Orleans Crescent',
    'Sacramento Republica',
    'Baltimore Fleet',
  ],
};

const _palettes = <List<int>>[
  [0xffb7f34a, 0xff07110c],
  [0xff75c8e8, 0xff10231a],
  [0xffffc65b, 0xff421d16],
  [0xffff806b, 0xff241015],
  [0xfff3f0e5, 0xff244735],
  [0xff9b8cff, 0xff17122f],
  [0xff50d3a5, 0xff09251c],
  [0xffff9bc2, 0xff321321],
  [0xffe7d36f, 0xff1b2a48],
  [0xffd3e0ea, 0xff27334a],
];

const _nationalTeams = <(String, String, int)>[
  ('Argentina', 'South America', 88),
  ('Brazil', 'South America', 89),
  ('Canada', 'North America', 75),
  ('Mexico', 'North America', 80),
  ('United States', 'North America', 79),
  ('Costa Rica', 'Central America', 72),
  ('England', 'Europe', 87),
  ('Spain', 'Europe', 88),
  ('France', 'Europe', 89),
  ('Germany', 'Europe', 86),
  ('Italy', 'Europe', 85),
  ('Portugal', 'Europe', 84),
  ('Netherlands', 'Europe', 84),
  ('Croatia', 'Europe', 81),
  ('Morocco', 'Africa', 81),
  ('Nigeria', 'Africa', 78),
  ('Senegal', 'Africa', 80),
  ('Ghana', 'Africa', 75),
  ('Japan', 'Asia', 79),
  ('South Korea', 'Asia', 78),
  ('Saudi Arabia', 'Asia', 72),
  ('Australia', 'Oceania', 74),
  ('New Zealand', 'Oceania', 68),
  ('Uruguay', 'South America', 83),
];

WorldDefinition? _cachedLaunchWorld;

WorldDefinition buildLaunchWorld() =>
    _cachedLaunchWorld ??= _buildLaunchWorld();

WorldDefinition _buildLaunchWorld() {
  final clubs = <ClubDefinition>[];
  final leagues = <LeagueDefinition>[];
  final cups = <CompetitionDefinition>[];

  for (final nation in FootballNation.values) {
    final names = _clubNames[nation]!;
    final nationSlug = _slug(_nationNames[nation]!);
    final nationClubs = <ClubDefinition>[];
    for (var index = 0; index < names.length; index++) {
      final division = index < 10 ? DivisionLevel.first : DivisionLevel.second;
      final localIndex = index % 10;
      final baseQuality = division == DivisionLevel.first ? 73 : 61;
      final palette = _palettes[(index + nation.index * 3) % _palettes.length];
      final club = ClubDefinition(
        id: '$nationSlug-${_slug(names[index])}',
        name: names[index],
        shortName: _shortName(names[index]),
        nation: nation,
        division: division,
        quality: baseQuality + ((localIndex * 7 + nation.index * 2) % 10),
        attack: baseQuality + ((localIndex * 5 + nation.index) % 11),
        defense: baseQuality + ((localIndex * 3 + nation.index * 2) % 11),
        primaryColor: palette[0],
        secondaryColor: palette[1],
      );
      clubs.add(club);
      nationClubs.add(club);
    }

    for (final division in DivisionLevel.values) {
      final divisionClubs = nationClubs
          .where((club) => club.division == division)
          .map((club) => club.id)
          .toList(growable: false);
      final leagueId = '$nationSlug-${division.name}';
      leagues.add(LeagueDefinition(
        id: leagueId,
        name: _leagueNames[nation]![division.index],
        nation: nation,
        division: division,
        clubIds: divisionClubs,
        fixtures: buildDoubleRoundRobinSchedule(
          competitionId: leagueId,
          participantIds: divisionClubs,
        ),
      ));
    }

    final cupIds = nationClubs.map((club) => club.id).toList(growable: false);
    cups.add(CompetitionDefinition(
      id: '$nationSlug-cup',
      name: '${_nationNames[nation]} Unity Cup',
      kind: CompetitionKind.domesticCup,
      participantIds: cupIds,
      fixtures: buildCupOpeningRound('$nationSlug-cup', cupIds),
    ));
  }

  final internationalIds = <String>[];
  for (final nation in FootballNation.values) {
    internationalIds.addAll(clubs
        .where((club) =>
            club.nation == nation && club.division == DivisionLevel.first)
        .take(2)
        .map((club) => club.id));
  }

  return WorldDefinition(
    contentVersion: '2026.2.0',
    clubs: List.unmodifiable(clubs),
    leagues: List.unmodifiable(leagues),
    domesticCups: List.unmodifiable(cups),
    internationalClubCompetition: CompetitionDefinition(
      id: 'world-champions-series',
      name: 'World Champions Series',
      kind: CompetitionKind.internationalClub,
      participantIds: List.unmodifiable(internationalIds),
      fixtures: buildInternationalGroupSchedule(internationalIds),
    ),
    nationalTeams: _nationalTeams
        .map((team) => NationalTeamDefinition(
              id: _slug(team.$1),
              countryName: team.$1,
              region: team.$2,
              quality: team.$3,
            ))
        .toList(growable: false),
  );
}

List<Fixture> buildDoubleRoundRobinSchedule({
  required String competitionId,
  required List<String> participantIds,
}) {
  if (participantIds.length < 2 || participantIds.length.isOdd) {
    throw ArgumentError(
        'A round-robin competition needs an even participant count.');
  }
  final rotating = [...participantIds];
  final firstLeg = <Fixture>[];
  final rounds = rotating.length - 1;
  for (var round = 0; round < rounds; round++) {
    for (var pairing = 0; pairing < rotating.length ~/ 2; pairing++) {
      final left = rotating[pairing];
      final right = rotating[rotating.length - 1 - pairing];
      final swap = (round + pairing).isOdd;
      final home = swap ? right : left;
      final away = swap ? left : right;
      firstLeg.add(Fixture(
        id: '$competitionId-w${round + 1}-m${pairing + 1}',
        competitionId: competitionId,
        matchweek: round + 1,
        homeId: home,
        awayId: away,
      ));
    }
    final tail = rotating.removeLast();
    rotating.insert(1, tail);
  }
  final matchesPerWeek = rotating.length ~/ 2;
  final secondLeg = firstLeg.indexed.map((entry) {
    final index = entry.$1;
    final fixture = entry.$2;
    return Fixture(
      id: '${fixture.competitionId}-w${fixture.matchweek + rounds}'
          '-m${index % matchesPerWeek + 1}',
      competitionId: fixture.competitionId,
      matchweek: fixture.matchweek + rounds,
      homeId: fixture.awayId,
      awayId: fixture.homeId,
    );
  });
  return List.unmodifiable([...firstLeg, ...secondLeg]);
}

List<Fixture> buildCupOpeningRound(String competitionId, List<String> ids) {
  if (ids.length != 20)
    throw ArgumentError('Domestic cups launch with 20 clubs.');
  // Eight clubs contest four preliminary ties; twelve receive a round-of-16 bye.
  return List.generate(
      4,
      (index) => Fixture(
            id: '$competitionId-preliminary-${index + 1}',
            competitionId: competitionId,
            matchweek: 2,
            homeId: ids[12 + index * 2],
            awayId: ids[13 + index * 2],
          ));
}

List<Fixture> buildInternationalGroupSchedule(List<String> ids) {
  if (ids.length != 12)
    throw ArgumentError('International competition needs 12 clubs.');
  final fixtures = <Fixture>[];
  for (var group = 0; group < 3; group++) {
    final teams = ids.sublist(group * 4, group * 4 + 4);
    final groupFixtures = buildDoubleRoundRobinSchedule(
      competitionId: 'world-champions-series-g${group + 1}',
      participantIds: teams,
    ).where((fixture) => fixture.matchweek <= 3);
    fixtures.addAll(
      groupFixtures.map(
        (fixture) => Fixture(
          id: fixture.id,
          competitionId: 'world-champions-series',
          matchweek: const [3, 7, 11][fixture.matchweek - 1],
          homeId: fixture.homeId,
          awayId: fixture.awayId,
        ),
      ),
    );
  }
  return List.unmodifiable(fixtures);
}

List<Fixture> buildNationalGroupSchedule(List<String> ids) {
  if (ids.length != 24) {
    throw ArgumentError('The major national tournament needs 24 teams.');
  }
  final fixtures = <Fixture>[];
  for (var group = 0; group < 6; group++) {
    final teams = ids.sublist(group * 4, group * 4 + 4);
    final groupFixtures = buildDoubleRoundRobinSchedule(
      competitionId: 'major-national-tournament-g${group + 1}',
      participantIds: teams,
    ).where((fixture) => fixture.matchweek <= 3);
    fixtures.addAll(
      groupFixtures.map(
        (fixture) => Fixture(
          id: fixture.id,
          competitionId: 'major-national-tournament',
          matchweek: const [1, 5, 9][fixture.matchweek - 1],
          homeId: fixture.homeId,
          awayId: fixture.awayId,
        ),
      ),
    );
  }
  return List.unmodifiable(fixtures);
}

List<StandingRow> tableFromFixtures(
  List<String> clubIds,
  Iterable<Fixture> fixtures,
) {
  final rows = {for (final id in clubIds) id: StandingRow(clubId: id)};
  for (final fixture in fixtures.where((fixture) => fixture.isPlayed)) {
    final home = rows[fixture.homeId];
    final away = rows[fixture.awayId];
    if (home == null || away == null) {
      throw StateError('Fixture references a club outside its competition.');
    }
    rows[fixture.homeId] = home.record(fixture.homeGoals!, fixture.awayGoals!);
    rows[fixture.awayId] = away.record(fixture.awayGoals!, fixture.homeGoals!);
  }
  final table = rows.values.toList();
  table.sort((left, right) {
    final byPoints = right.points.compareTo(left.points);
    if (byPoints != 0) return byPoints;
    final byDifference = right.goalDifference.compareTo(left.goalDifference);
    if (byDifference != 0) return byDifference;
    final byGoals = right.goalsFor.compareTo(left.goalsFor);
    if (byGoals != 0) return byGoals;
    return left.clubId.compareTo(right.clubId);
  });
  return List.unmodifiable(table);
}

({List<String> promoted, List<String> relegated}) promotionAndRelegation({
  required List<StandingRow> firstDivision,
  required List<StandingRow> secondDivision,
}) {
  if (firstDivision.length != 10 || secondDivision.length != 10) {
    throw ArgumentError(
        'Both divisions must contain ten final standings rows.');
  }
  return (
    promoted: [secondDivision[0].clubId, secondDivision[1].clubId],
    relegated: [firstDivision[8].clubId, firstDivision[9].clubId],
  );
}

bool isMajorNationalTournamentSeason(int season) =>
    season > 0 && season % 4 == 0;

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp('^-|\$'), '');

String _shortName(String name) {
  final words = name.replaceAll(RegExp('[^A-Za-zÀ-ÿ0-9 ]'), '').split(' ');
  if (words.length == 1)
    return words.first
        .substring(0, words.first.length.clamp(1, 4))
        .toUpperCase();
  return words.take(3).map((word) => word[0]).join().toUpperCase();
}
