import '../model/career_progress.dart';
import '../model/career_snapshot.dart';
import '../model/weekly_models.dart';
import '../world/world_generator.dart';
import '../world/world_models.dart';

final class WorldSimulator {
  const WorldSimulator();

  static final Map<String, List<Fixture>> _scheduleCache = {};

  List<Fixture> _schedule(String leagueId, List<String> participants) {
    final key = '$leagueId:${participants.join(',')}';
    return _scheduleCache.putIfAbsent(
      key,
      () => buildDoubleRoundRobinSchedule(
        competitionId: leagueId,
        participantIds: participants,
      ),
    );
  }

  OpponentContext opponentFor(
    CareerSnapshot snapshot, {
    WorldDefinition? definition,
  }) {
    final world = definition ?? buildLaunchWorld();
    final state = snapshot.world.leagueParticipants.isEmpty
        ? CareerWorldState.initial(world)
        : snapshot.world;
    final competitions = state.competitions.isEmpty
        ? _newCompetitions(state, world, snapshot.season)
        : state.competitions;
    final selectedForNational =
        snapshot.nationalTeam.acceptedFor(snapshot.season);
    final scheduled = competitions.values
        .expand(
          (competition) => competition.fixtures.where(
            (fixture) =>
                fixture.matchweek == snapshot.week &&
                !fixture.isPlayed &&
                (fixture.homeId == snapshot.clubId ||
                    fixture.awayId == snapshot.clubId ||
                    (selectedForNational &&
                        (fixture.homeId == snapshot.player.nationalTeamId ||
                            fixture.awayId == snapshot.player.nationalTeamId))),
          ),
        )
        .toList()
      ..sort((left, right) {
        int priority(Fixture fixture) =>
            switch (competitions[fixture.competitionId]?.kind) {
              CompetitionKind.nationalTournament => 0,
              CompetitionKind.internationalClub => 1,
              CompetitionKind.domesticCup => 2,
              _ => 3,
            };

        return priority(left).compareTo(priority(right));
      });
    if (scheduled.isNotEmpty) {
      final fixture = scheduled.first;
      final competition = competitions[fixture.competitionId]!;
      final playerId = competition.kind == CompetitionKind.nationalTournament
          ? snapshot.player.nationalTeamId
          : snapshot.clubId;
      final opponentId =
          fixture.homeId == playerId ? fixture.awayId : fixture.homeId;
      final club = world.clubs.where((item) => item.id == opponentId);
      final national =
          world.nationalTeams.where((item) => item.id == opponentId);
      final opponentName = club.isNotEmpty
          ? club.first.name
          : national.isNotEmpty
              ? national.first.countryName
              : opponentId;
      final quality = club.isNotEmpty
          ? club.first.quality
          : national.isNotEmpty
              ? national.first.quality
              : 65;
      return OpponentContext(
        clubId: opponentId,
        clubName: opponentName,
        quality: quality,
        tacticalFit: (55 + ((snapshot.seed ^ _stableHash(opponentId)) % 26))
            .clamp(1, 100),
        isHome: fixture.homeId == playerId,
        competitionId: competition.id,
        competitionKind: competition.kind,
      );
    }
    final leagueId = state.leagueIdForClub(snapshot.clubId);
    final schedule = _schedule(
      leagueId,
      state.leagueParticipants[leagueId]!,
    );
    final fixture = schedule.firstWhere(
      (item) =>
          item.matchweek == snapshot.week &&
          (item.homeId == snapshot.clubId || item.awayId == snapshot.clubId),
    );
    final opponentId =
        fixture.homeId == snapshot.clubId ? fixture.awayId : fixture.homeId;
    final opponent = world.clubs.firstWhere((club) => club.id == opponentId);
    final club = world.clubs.firstWhere((item) => item.id == snapshot.clubId);
    final archetypeFit =
        (snapshot.player.archetype.index * 7 + club.quality) % 17;
    return OpponentContext(
      clubId: opponent.id,
      clubName: opponent.name,
      quality: opponent.quality,
      tacticalFit: (58 + archetypeFit).clamp(1, 100),
      isHome: fixture.homeId == snapshot.clubId,
      competitionId: leagueId,
    );
  }

  CareerWorldState advanceMatchweek({
    required CareerSnapshot snapshot,
    required int playerHomeScore,
    required int playerAwayScore,
    WorldDefinition? definition,
  }) {
    final world = definition ?? buildLaunchWorld();
    final state = snapshot.world.leagueParticipants.isEmpty
        ? CareerWorldState.initial(world)
        : snapshot.world;
    final records = {
      for (final league in state.leagueRecords.entries)
        league.key: Map<String, ClubSeasonRecord>.from(league.value),
    };
    final quality = {for (final club in world.clubs) club.id: club.quality};
    final opponent = opponentFor(snapshot, definition: world);

    for (final entry in state.leagueParticipants.entries) {
      final fixtures = _schedule(
        entry.key,
        entry.value,
      ).where((fixture) => fixture.matchweek == snapshot.week);
      for (final fixture in fixtures) {
        int homeGoals;
        int awayGoals;
        if (opponent.competitionKind == CompetitionKind.league &&
            (fixture.homeId == snapshot.clubId ||
                fixture.awayId == snapshot.clubId)) {
          homeGoals = playerHomeScore;
          awayGoals = playerAwayScore;
        } else {
          final score = _score(
            snapshot.seed,
            snapshot.season,
            snapshot.week,
            fixture.id,
            quality[fixture.homeId]!,
            quality[fixture.awayId]!,
          );
          homeGoals = score.$1;
          awayGoals = score.$2;
        }
        final table = records[entry.key]!;
        table[fixture.homeId] =
            table[fixture.homeId]!.record(homeGoals, awayGoals);
        table[fixture.awayId] =
            table[fixture.awayId]!.record(awayGoals, homeGoals);
      }
    }
    final competitions = state.competitions.isEmpty
        ? _newCompetitions(state, world, snapshot.season)
        : state.competitions;
    final advancedCompetitions = <String, CompetitionProgress>{};
    for (final entry in competitions.entries) {
      advancedCompetitions[entry.key] = _advanceCompetition(
        entry.value,
        snapshot: snapshot,
        activeCompetitionId: opponent.competitionId,
        playerHomeScore: playerHomeScore,
        playerAwayScore: playerAwayScore,
        world: world,
      );
    }
    return state.copyWith(
      leagueRecords: records,
      competitions: Map.unmodifiable(advancedCompetitions),
    );
  }

  CareerWorldState beginNextSeason(
    CareerWorldState state,
    int seed, {
    WorldDefinition? definition,
  }) {
    final world = definition ?? buildLaunchWorld();
    final participants = {
      for (final entry in state.leagueParticipants.entries)
        entry.key: List<String>.from(entry.value),
    };

    for (final nation in FootballNation.values) {
      final nationLeagues =
          world.leagues.where((league) => league.nation == nation);
      final firstId = nationLeagues
          .firstWhere((league) => league.division == DivisionLevel.first)
          .id;
      final secondId = nationLeagues
          .firstWhere((league) => league.division == DivisionLevel.second)
          .id;
      final movement = promotionAndRelegation(
        firstDivision: state.table(firstId),
        secondDivision: state.table(secondId),
      );
      participants[firstId] = [
        ...participants[firstId]!
            .where((id) => !movement.relegated.contains(id)),
        ...movement.promoted,
      ];
      participants[secondId] = [
        ...participants[secondId]!
            .where((id) => !movement.promoted.contains(id)),
        ...movement.relegated,
      ];
    }

    final completed = state.competitions;
    final cupWinners = <String, String>{
      for (final cup in world.domesticCups)
        if (completed[cup.id]?.winnerId != null)
          cup.id: completed[cup.id]!.winnerId!,
    };
    final internationalWinner =
        completed[world.internationalClubCompetition.id]?.winnerId;
    final nationalWinner = completed['major-national-tournament']?.winnerId;
    final nextSeason = state.season + 1;
    return CareerWorldState(
      season: nextSeason,
      leagueParticipants: {
        for (final entry in participants.entries)
          entry.key: List<String>.unmodifiable(entry.value),
      },
      leagueRecords: {
        for (final entry in participants.entries)
          entry.key: {
            for (final clubId in entry.value) clubId: const ClubSeasonRecord(),
          },
      },
      domesticCupWinners: Map.unmodifiable(cupWinners),
      internationalClubWinner: internationalWinner,
      nationalTournamentWinner: nationalWinner,
      competitions: _newCompetitions(
        state,
        world,
        nextSeason,
        leagueParticipants: participants,
      ),
    );
  }

  Map<String, CompetitionProgress> _newCompetitions(
    CareerWorldState state,
    WorldDefinition world,
    int season, {
    Map<String, List<String>>? leagueParticipants,
  }) {
    final competitions = <String, CompetitionProgress>{};
    for (final cup in world.domesticCups) {
      competitions[cup.id] = CompetitionProgress(
        id: cup.id,
        kind: CompetitionKind.domesticCup,
        participantIds: cup.participantIds,
        fixtures: buildCupOpeningRound(cup.id, cup.participantIds),
      );
    }
    final internationalIds = <String>[];
    for (final nation in FootballNation.values) {
      final league = world.leagues.firstWhere(
        (item) => item.nation == nation && item.division == DivisionLevel.first,
      );
      if (state.leagueRecords[league.id]?.values.any(
            (record) => record.played > 0,
          ) ??
          false) {
        internationalIds.addAll(
          state.table(league.id).take(2).map((row) => row.clubId),
        );
      } else {
        final participants = leagueParticipants?[league.id] ?? league.clubIds;
        internationalIds.addAll(participants.take(2));
      }
    }
    competitions[world.internationalClubCompetition.id] = CompetitionProgress(
      id: world.internationalClubCompetition.id,
      kind: CompetitionKind.internationalClub,
      participantIds: List.unmodifiable(internationalIds),
      fixtures: buildInternationalGroupSchedule(internationalIds),
    );
    if (isMajorNationalTournamentSeason(season)) {
      final ids = world.nationalTeams.map((team) => team.id).toList();
      competitions['major-national-tournament'] = CompetitionProgress(
        id: 'major-national-tournament',
        kind: CompetitionKind.nationalTournament,
        participantIds: List.unmodifiable(ids),
        fixtures: buildNationalGroupSchedule(ids),
      );
    }
    return Map.unmodifiable(competitions);
  }

  CompetitionProgress _advanceCompetition(
    CompetitionProgress progress, {
    required CareerSnapshot snapshot,
    required String? activeCompetitionId,
    required int playerHomeScore,
    required int playerAwayScore,
    required WorldDefinition world,
  }) {
    if (progress.isComplete) return progress;
    final current = progress.fixtures.where(
      (fixture) => fixture.matchweek == snapshot.week && !fixture.isPlayed,
    );
    if (current.isEmpty) return progress;
    final qualities = <String, int>{
      for (final club in world.clubs) club.id: club.quality,
      for (final team in world.nationalTeams) team.id: team.quality,
    };
    final playerId = progress.kind == CompetitionKind.nationalTournament
        ? snapshot.player.nationalTeamId
        : snapshot.clubId;
    final scored = progress.fixtures.map((fixture) {
      if (fixture.matchweek != snapshot.week || fixture.isPlayed) {
        return fixture;
      }
      final isPlayerFixture = activeCompetitionId == progress.id &&
          (fixture.homeId == playerId || fixture.awayId == playerId);
      final result = isPlayerFixture
          ? (playerHomeScore, playerAwayScore)
          : _score(
              snapshot.seed,
              snapshot.season,
              snapshot.week,
              fixture.id,
              qualities[fixture.homeId] ?? 65,
              qualities[fixture.awayId] ?? 65,
            );
      var home = result.$1;
      var away = result.$2;
      var decision = FixtureDecision.regulation;
      final knockout =
          progress.kind == CompetitionKind.domesticCup || progress.stage > 0;
      if (knockout && home == away) {
        decision = ((snapshot.seed ^ _stableHash(fixture.id)) & 2) == 0
            ? FixtureDecision.extraTime
            : FixtureDecision.penalties;
        if (((snapshot.seed ^ _stableHash(fixture.id)) & 1) == 0) {
          home += 1;
        } else {
          away += 1;
        }
      }
      return fixture.withScore(home, away, decision: decision);
    }).toList(growable: true);

    if (!_stageFinished(progress, snapshot.week)) {
      return progress.copyWith(fixtures: List.unmodifiable(scored));
    }
    final next = _nextStage(
      progress,
      scored,
      snapshot.week,
    );
    return next;
  }

  bool _stageFinished(CompetitionProgress progress, int week) =>
      switch (progress.kind) {
        CompetitionKind.domesticCup => true,
        CompetitionKind.internationalClub =>
          progress.stage == 0 ? week == 11 : true,
        CompetitionKind.nationalTournament =>
          progress.stage == 0 ? week == 9 : true,
        CompetitionKind.league => false,
      };

  CompetitionProgress _nextStage(
    CompetitionProgress progress,
    List<Fixture> fixtures,
    int week,
  ) {
    List<String> entrants;
    if (progress.stage == 0 && progress.kind == CompetitionKind.domesticCup) {
      entrants = [
        ...progress.participantIds.take(12),
        ..._winners(fixtures.where((fixture) => fixture.matchweek == week)),
      ];
    } else if (progress.stage == 0 &&
        progress.kind != CompetitionKind.domesticCup) {
      final groupCount =
          progress.kind == CompetitionKind.internationalClub ? 3 : 6;
      entrants = _groupQualifiers(progress, fixtures, groupCount);
    } else {
      entrants = _winners(
        fixtures.where((fixture) => fixture.matchweek == week),
      );
    }
    if (entrants.length == 1) {
      return progress.copyWith(
        fixtures: List.unmodifiable(fixtures),
        stage: progress.stage + 1,
        winnerId: entrants.single,
      );
    }
    final nextWeek = switch (progress.kind) {
      CompetitionKind.domesticCup => const [6, 10, 14, 18][progress.stage],
      CompetitionKind.internationalClub => const [13, 15, 17][progress.stage],
      CompetitionKind.nationalTournament => const [
          12,
          14,
          16,
          18
        ][progress.stage],
      CompetitionKind.league => throw StateError('League is not a knockout.'),
    };
    final round = progress.stage + 1;
    final nextFixtures = <Fixture>[];
    for (var index = 0; index < entrants.length; index += 2) {
      nextFixtures.add(
        Fixture(
          id: '${progress.id}-r$round-m${index ~/ 2 + 1}',
          competitionId: progress.id,
          matchweek: nextWeek,
          homeId: entrants[index],
          awayId: entrants[index + 1],
        ),
      );
    }
    return progress.copyWith(
      fixtures: List.unmodifiable([...fixtures, ...nextFixtures]),
      stage: round,
    );
  }

  List<String> _groupQualifiers(
    CompetitionProgress progress,
    List<Fixture> fixtures,
    int groupCount,
  ) {
    final automatic = <String>[];
    final thirds = <StandingRow>[];
    for (var group = 0; group < groupCount; group++) {
      final ids = progress.participantIds.sublist(group * 4, group * 4 + 4);
      final table = tableFromFixtures(
        ids,
        fixtures.where(
          (fixture) =>
              ids.contains(fixture.homeId) && ids.contains(fixture.awayId),
        ),
      );
      automatic.addAll(table.take(2).map((row) => row.clubId));
      thirds.add(table[2]);
    }
    thirds.sort((left, right) {
      final points = right.points.compareTo(left.points);
      if (points != 0) return points;
      final difference = right.goalDifference.compareTo(left.goalDifference);
      if (difference != 0) return difference;
      return left.clubId.compareTo(right.clubId);
    });
    final extra = progress.kind == CompetitionKind.internationalClub ? 2 : 4;
    return [...automatic, ...thirds.take(extra).map((row) => row.clubId)];
  }

  List<String> _winners(Iterable<Fixture> fixtures) => fixtures
      .map(
        (fixture) => fixture.homeGoals! > fixture.awayGoals!
            ? fixture.homeId
            : fixture.awayId,
      )
      .toList(growable: false);

  (int, int) _score(
    int seed,
    int season,
    int week,
    String fixtureId,
    int homeQuality,
    int awayQuality,
  ) {
    var state = (seed ^ season * 1009 ^ week * 9176 ^ _stableHash(fixtureId)) &
        0x7fffffff;
    int next(int max) {
      state = (1103515245 * state + 12345) & 0x7fffffff;
      return ((state / 0x80000000) * max).floor();
    }

    final homeAdvantage = 4;
    final homeGoals =
        (next(3) + ((homeQuality + homeAdvantage - awayQuality) / 12).round())
            .clamp(0, 5);
    final awayGoals =
        (next(3) + ((awayQuality - homeQuality) / 12).round()).clamp(0, 5);
    return (homeGoals, awayGoals);
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
