enum FootballNation { england, spain, france, germany, brazil, unitedStates }

enum DivisionLevel { first, second }

enum CompetitionKind {
  league,
  domesticCup,
  internationalClub,
  nationalTournament
}

enum FixtureDecision { regulation, extraTime, penalties }

final class ClubDefinition {
  const ClubDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.nation,
    required this.division,
    required this.quality,
    required this.attack,
    required this.defense,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String id;
  final String name;
  final String shortName;
  final FootballNation nation;
  final DivisionLevel division;
  final int quality;
  final int attack;
  final int defense;
  final int primaryColor;
  final int secondaryColor;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'nation': nation.name,
        'division': division.name,
        'quality': quality,
        'attack': attack,
        'defense': defense,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
      };
}

final class NationalTeamDefinition {
  const NationalTeamDefinition({
    required this.id,
    required this.countryName,
    required this.region,
    required this.quality,
  });

  final String id;
  final String countryName;
  final String region;
  final int quality;

  Map<String, Object?> toJson() => {
        'id': id,
        'countryName': countryName,
        'region': region,
        'quality': quality,
      };
}

final class Fixture {
  const Fixture({
    required this.id,
    required this.competitionId,
    required this.matchweek,
    required this.homeId,
    required this.awayId,
    this.homeGoals,
    this.awayGoals,
    this.decision = FixtureDecision.regulation,
  });

  factory Fixture.fromJson(Map<String, Object?> json) => Fixture(
        id: json['id'] as String,
        competitionId: json['competitionId'] as String,
        matchweek: json['matchweek'] as int,
        homeId: json['homeId'] as String,
        awayId: json['awayId'] as String,
        homeGoals: json['homeGoals'] as int?,
        awayGoals: json['awayGoals'] as int?,
        decision: FixtureDecision.values.firstWhere(
          (value) => value.name == json['decision'],
          orElse: () => FixtureDecision.regulation,
        ),
      );

  final String id;
  final String competitionId;
  final int matchweek;
  final String homeId;
  final String awayId;
  final int? homeGoals;
  final int? awayGoals;
  final FixtureDecision decision;

  bool get isPlayed => homeGoals != null && awayGoals != null;

  Fixture withScore(
    int home,
    int away, {
    FixtureDecision decision = FixtureDecision.regulation,
  }) =>
      Fixture(
        id: id,
        competitionId: competitionId,
        matchweek: matchweek,
        homeId: homeId,
        awayId: awayId,
        homeGoals: home,
        awayGoals: away,
        decision: decision,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'competitionId': competitionId,
        'matchweek': matchweek,
        'homeId': homeId,
        'awayId': awayId,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'decision': decision.name,
      };
}

final class StandingRow {
  const StandingRow({
    required this.clubId,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  final String clubId;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  int get points => won * 3 + drawn;
  int get goalDifference => goalsFor - goalsAgainst;

  StandingRow record(int scored, int conceded) => StandingRow(
        clubId: clubId,
        played: played + 1,
        won: won + (scored > conceded ? 1 : 0),
        drawn: drawn + (scored == conceded ? 1 : 0),
        lost: lost + (scored < conceded ? 1 : 0),
        goalsFor: goalsFor + scored,
        goalsAgainst: goalsAgainst + conceded,
      );

  Map<String, Object?> toJson() => {
        'clubId': clubId,
        'played': played,
        'won': won,
        'drawn': drawn,
        'lost': lost,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
        'goalDifference': goalDifference,
        'points': points,
      };
}

final class LeagueDefinition {
  const LeagueDefinition({
    required this.id,
    required this.name,
    required this.nation,
    required this.division,
    required this.clubIds,
    required this.fixtures,
  });

  final String id;
  final String name;
  final FootballNation nation;
  final DivisionLevel division;
  final List<String> clubIds;
  final List<Fixture> fixtures;

  int get matchweeks => fixtures.fold<int>(0, (max, fixture) {
        return fixture.matchweek > max ? fixture.matchweek : max;
      });
}

final class CupTie {
  const CupTie({
    required this.id,
    required this.round,
    required this.homeId,
    required this.awayId,
  });

  final String id;
  final int round;
  final String homeId;
  final String awayId;
}

final class CompetitionDefinition {
  const CompetitionDefinition({
    required this.id,
    required this.name,
    required this.kind,
    required this.participantIds,
    required this.fixtures,
  });

  final String id;
  final String name;
  final CompetitionKind kind;
  final List<String> participantIds;
  final List<Fixture> fixtures;
}

final class WorldDefinition {
  const WorldDefinition({
    required this.contentVersion,
    required this.clubs,
    required this.leagues,
    required this.domesticCups,
    required this.internationalClubCompetition,
    required this.nationalTeams,
  });

  final String contentVersion;
  final List<ClubDefinition> clubs;
  final List<LeagueDefinition> leagues;
  final List<CompetitionDefinition> domesticCups;
  final CompetitionDefinition internationalClubCompetition;
  final List<NationalTeamDefinition> nationalTeams;
}
