import '../world/world_generator.dart';
import '../world/world_models.dart';

final class CompetitionProgress {
  const CompetitionProgress({
    required this.id,
    required this.kind,
    required this.participantIds,
    required this.fixtures,
    this.stage = 0,
    this.winnerId,
  });

  factory CompetitionProgress.fromJson(Map<String, Object?> json) =>
      CompetitionProgress(
        id: json['id'] as String,
        kind: CompetitionKind.values.byName(json['kind'] as String),
        participantIds:
            (json['participantIds'] as List<Object?>).cast<String>(),
        fixtures: (json['fixtures'] as List<Object?>)
            .map(
              (value) =>
                  Fixture.fromJson((value as Map).cast<String, Object?>()),
            )
            .toList(growable: false),
        stage: json['stage'] as int? ?? 0,
        winnerId: json['winnerId'] as String?,
      );

  final String id;
  final CompetitionKind kind;
  final List<String> participantIds;
  final List<Fixture> fixtures;
  final int stage;
  final String? winnerId;

  bool get isComplete => winnerId != null;

  CompetitionProgress copyWith({
    List<Fixture>? fixtures,
    int? stage,
    String? winnerId,
  }) =>
      CompetitionProgress(
        id: id,
        kind: kind,
        participantIds: participantIds,
        fixtures: fixtures ?? this.fixtures,
        stage: stage ?? this.stage,
        winnerId: winnerId ?? this.winnerId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'participantIds': participantIds,
        'fixtures': fixtures.map((fixture) => fixture.toJson()).toList(),
        'stage': stage,
        'winnerId': winnerId,
      };
}

final class ClubSeasonRecord {
  const ClubSeasonRecord({
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
  });

  factory ClubSeasonRecord.fromJson(Map<String, Object?> json) =>
      ClubSeasonRecord(
        played: json['played'] as int? ?? 0,
        won: json['won'] as int? ?? 0,
        drawn: json['drawn'] as int? ?? 0,
        lost: json['lost'] as int? ?? 0,
        goalsFor: json['goalsFor'] as int? ?? 0,
        goalsAgainst: json['goalsAgainst'] as int? ?? 0,
      );

  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  int get points => won * 3 + drawn;
  int get goalDifference => goalsFor - goalsAgainst;

  ClubSeasonRecord record(int scored, int conceded) => ClubSeasonRecord(
        played: played + 1,
        won: won + (scored > conceded ? 1 : 0),
        drawn: drawn + (scored == conceded ? 1 : 0),
        lost: lost + (scored < conceded ? 1 : 0),
        goalsFor: goalsFor + scored,
        goalsAgainst: goalsAgainst + conceded,
      );

  Map<String, Object?> toJson() => {
        'played': played,
        'won': won,
        'drawn': drawn,
        'lost': lost,
        'goalsFor': goalsFor,
        'goalsAgainst': goalsAgainst,
      };
}

final class SeasonPerformance {
  const SeasonPerformance({
    this.appearances = 0,
    this.goals = 0,
    this.assists = 0,
    this.ratingTenths = 0,
    this.ratedMatches = 0,
  });

  factory SeasonPerformance.fromJson(Map<String, Object?> json) =>
      SeasonPerformance(
        appearances: json['appearances'] as int? ?? 0,
        goals: json['goals'] as int? ?? 0,
        assists: json['assists'] as int? ?? 0,
        ratingTenths: json['ratingTenths'] as int? ?? 0,
        ratedMatches: json['ratedMatches'] as int? ?? 0,
      );

  final int appearances;
  final int goals;
  final int assists;
  final int ratingTenths;
  final int ratedMatches;

  double get averageRating =>
      ratedMatches == 0 ? 0 : ratingTenths / ratedMatches / 10;

  SeasonPerformance add({
    required bool appeared,
    required int goals,
    required int assists,
    required double rating,
  }) =>
      SeasonPerformance(
        appearances: appearances + (appeared ? 1 : 0),
        goals: this.goals + goals,
        assists: this.assists + assists,
        ratingTenths: ratingTenths + (rating * 10).round(),
        ratedMatches: ratedMatches + (appeared ? 1 : 0),
      );

  Map<String, Object?> toJson() => {
        'appearances': appearances,
        'goals': goals,
        'assists': assists,
        'ratingTenths': ratingTenths,
        'ratedMatches': ratedMatches,
      };
}

/// Durable competition state. The bundled world definition supplies static club
/// metadata; this structure stores only the mutable season assignments/results.
final class CareerWorldState {
  const CareerWorldState({
    required this.season,
    required this.leagueParticipants,
    required this.leagueRecords,
    this.domesticCupWinners = const {},
    this.internationalClubWinner,
    this.nationalTournamentWinner,
    this.competitions = const {},
  });

  factory CareerWorldState.initial([WorldDefinition? definition]) {
    final world = definition ?? buildLaunchWorld();
    final competitions = <String, CompetitionProgress>{
      for (final cup in world.domesticCups)
        cup.id: CompetitionProgress(
          id: cup.id,
          kind: cup.kind,
          participantIds: cup.participantIds,
          fixtures: cup.fixtures,
        ),
      world.internationalClubCompetition.id: CompetitionProgress(
        id: world.internationalClubCompetition.id,
        kind: CompetitionKind.internationalClub,
        participantIds: world.internationalClubCompetition.participantIds,
        fixtures: world.internationalClubCompetition.fixtures,
      ),
    };
    if (isMajorNationalTournamentSeason(1)) {
      final ids = world.nationalTeams.map((team) => team.id).toList();
      competitions['major-national-tournament'] = CompetitionProgress(
        id: 'major-national-tournament',
        kind: CompetitionKind.nationalTournament,
        participantIds: ids,
        fixtures: buildNationalGroupSchedule(ids),
      );
    }
    return CareerWorldState(
      season: 1,
      leagueParticipants: {
        for (final league in world.leagues)
          league.id: List<String>.unmodifiable(league.clubIds),
      },
      leagueRecords: {
        for (final league in world.leagues)
          league.id: {
            for (final clubId in league.clubIds)
              clubId: const ClubSeasonRecord(),
          },
      },
      competitions: Map.unmodifiable(competitions),
    );
  }

  factory CareerWorldState.fromJson(Map<String, Object?> json) {
    final participantsRaw = json['leagueParticipants'];
    final recordsRaw = json['leagueRecords'];
    if (participantsRaw is! Map<String, Object?> ||
        recordsRaw is! Map<String, Object?>) {
      throw const FormatException('Invalid world career state.');
    }
    return CareerWorldState(
      season: json['season'] as int? ?? 1,
      leagueParticipants: {
        for (final entry in participantsRaw.entries)
          entry.key: List<String>.unmodifiable(
            (entry.value as List<Object?>).cast<String>(),
          ),
      },
      leagueRecords: {
        for (final leagueEntry in recordsRaw.entries)
          leagueEntry.key: {
            for (final clubEntry
                in (leagueEntry.value as Map<String, Object?>).entries)
              clubEntry.key: ClubSeasonRecord.fromJson(
                clubEntry.value as Map<String, Object?>,
              ),
          },
      },
      domesticCupWinners:
          (json['domesticCupWinners'] as Map<String, Object?>? ?? const {})
              .map((key, value) => MapEntry(key, value as String)),
      internationalClubWinner: json['internationalClubWinner'] as String?,
      nationalTournamentWinner: json['nationalTournamentWinner'] as String?,
      competitions:
          (json['competitions'] as Map<String, Object?>? ?? const {}).map(
        (key, value) => MapEntry(
          key,
          CompetitionProgress.fromJson(
            (value as Map).cast<String, Object?>(),
          ),
        ),
      ),
    );
  }

  final int season;
  final Map<String, List<String>> leagueParticipants;
  final Map<String, Map<String, ClubSeasonRecord>> leagueRecords;
  final Map<String, String> domesticCupWinners;
  final String? internationalClubWinner;
  final String? nationalTournamentWinner;
  final Map<String, CompetitionProgress> competitions;

  String leagueIdForClub(String clubId) => leagueParticipants.entries
      .firstWhere(
        (entry) => entry.value.contains(clubId),
        orElse: () =>
            throw StateError('Club $clubId is not assigned to a league.'),
      )
      .key;

  List<StandingRow> table(String leagueId) {
    final records = leagueRecords[leagueId];
    if (records == null) throw StateError('Unknown league $leagueId.');
    final rows = records.entries
        .map(
          (entry) => StandingRow(
            clubId: entry.key,
            played: entry.value.played,
            won: entry.value.won,
            drawn: entry.value.drawn,
            lost: entry.value.lost,
            goalsFor: entry.value.goalsFor,
            goalsAgainst: entry.value.goalsAgainst,
          ),
        )
        .toList();
    rows.sort((left, right) {
      final points = right.points.compareTo(left.points);
      if (points != 0) return points;
      final difference = right.goalDifference.compareTo(left.goalDifference);
      if (difference != 0) return difference;
      final goals = right.goalsFor.compareTo(left.goalsFor);
      if (goals != 0) return goals;
      return left.clubId.compareTo(right.clubId);
    });
    return List.unmodifiable(rows);
  }

  CareerWorldState copyWith({
    int? season,
    Map<String, List<String>>? leagueParticipants,
    Map<String, Map<String, ClubSeasonRecord>>? leagueRecords,
    Map<String, String>? domesticCupWinners,
    String? internationalClubWinner,
    String? nationalTournamentWinner,
    bool clearNationalTournamentWinner = false,
    Map<String, CompetitionProgress>? competitions,
  }) =>
      CareerWorldState(
        season: season ?? this.season,
        leagueParticipants: leagueParticipants ?? this.leagueParticipants,
        leagueRecords: leagueRecords ?? this.leagueRecords,
        domesticCupWinners: domesticCupWinners ?? this.domesticCupWinners,
        internationalClubWinner:
            internationalClubWinner ?? this.internationalClubWinner,
        nationalTournamentWinner: clearNationalTournamentWinner
            ? null
            : nationalTournamentWinner ?? this.nationalTournamentWinner,
        competitions: competitions ?? this.competitions,
      );

  Map<String, Object?> toJson() => {
        'season': season,
        'leagueParticipants': leagueParticipants,
        'leagueRecords': {
          for (final league in leagueRecords.entries)
            league.key: {
              for (final club in league.value.entries)
                club.key: club.value.toJson(),
            },
        },
        'domesticCupWinners': domesticCupWinners,
        'internationalClubWinner': internationalClubWinner,
        'nationalTournamentWinner': nationalTournamentWinner,
        'competitions': {
          for (final entry in competitions.entries)
            entry.key: entry.value.toJson(),
        },
      };
}
