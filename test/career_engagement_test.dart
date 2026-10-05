import 'package:elevenward/src/career_engagement.dart';
import 'package:elevenward/src/match_feedback.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tied points outside the top two do not claim a promotion place', () {
    final world = buildLaunchWorld();
    final league = world.leagues.firstWhere(
      (league) => league.division == DivisionLevel.second,
    );
    final ids = [...league.clubIds]..sort();
    final club = world.clubs.firstWhere((club) => club.id == ids.last);
    final base = CareerSnapshot.newCareer(clubId: club.id, clubName: club.name);
    final career = base.copyWith(
      world: base.world.copyWith(
        leagueRecords: {
          ...base.world.leagueRecords,
          league.id: {
            for (final id in ids)
              id: const ClubSeasonRecord(played: 1, drawn: 1),
          },
        },
      ),
    );
    expect(career.world.table(league.id).last.clubId, club.id);
    final opponent = OpponentContext(
      clubId: ids.first,
      clubName: 'Rival',
      quality: 60,
      tacticalFit: 60,
      isHome: true,
      competitionId: league.id,
    );
    final text = nextMatchStakes(career, opponent, world, 'en');
    expect(text, contains('${uiCopy('en', 'promotionGap')} 0'));
    expect(text, isNot(contains(uiCopy('en', 'promotionPlaces'))));
  });
  test('the first continental knockout stage is numbered one', () {
    final world = buildLaunchWorld();
    final base = CareerSnapshot.newCareer();
    final id = world.internationalClubCompetition.id;
    final career = base.copyWith(
      world: base.world.copyWith(
        competitions: {
          ...base.world.competitions,
          id: base.world.competitions[id]!.copyWith(stage: 1),
        },
      ),
    );
    final opponent = OpponentContext(
      clubId: 'rival',
      clubName: 'Rival',
      quality: 60,
      tacticalFit: 60,
      isHome: true,
      competitionId: id,
      competitionKind: CompetitionKind.internationalClub,
    );
    expect(
      nextMatchStakes(career, opponent, world, 'en'),
      endsWith('${uiCopy('en', 'knockoutRound')} 1'),
    );
  });
  test('season trophy previews match the archived engine result', () {
    const simulator = WeeklySimulator();
    const engine = CareerEngine();
    for (final seed in [1, 7, 17]) {
      var career = CareerSnapshot.newCareer(seed: seed);
      while (career.phase == CareerPhase.inSeason) {
        career = simulator
            .advance(
              snapshot: career,
              choice: const WeeklyChoice(
                focus: PlayerAttribute.finishing,
                intensity: TrainingIntensity.balanced,
                spotlightApproach: SpotlightApproach.safe,
              ),
              opponent: const WorldSimulator().opponentFor(career),
              updatedAt: DateTime.utc(2026, 9, 30),
            )
            .snapshot;
      }
      if (career.phase == CareerPhase.internationalCallup) {
        career = engine.decideNationalTeamCallUp(
          snapshot: career,
          accept: false,
          updatedAt: DateTime.utc(2026, 9, 30),
        );
      }
      final archived = engine.completeOffseason(
        career,
        updatedAt: DateTime.utc(2026, 9, 30),
      );
      expect(
        currentSeasonTrophies(career).toSet(),
        archived.seasonHistory.last.trophies.toSet(),
      );
    }
  });
  test('national trophies require a recorded player appearance', () {
    final base = CareerSnapshot.newCareer();
    final competition = CompetitionProgress(
      id: 'world-nations-championship',
      kind: CompetitionKind.nationalTournament,
      participantIds: [base.player.nationalTeamId],
      fixtures: const [],
      winnerId: base.player.nationalTeamId,
    );
    CareerSnapshot withAppearances(int appearances) => base.copyWith(
      world: base.world.copyWith(
        competitions: {competition.id: competition},
        nationalTournamentHistory: [
          NationalTournamentHistoryEntry(
            season: base.season,
            winnerId: base.player.nationalTeamId,
            playerTeamId: base.player.nationalTeamId,
            playerFinish: 'champion',
            playerAppearances: appearances,
          ),
        ],
      ),
    );
    expect(currentSeasonTrophies(withAppearances(0)), isEmpty);
    expect(currentSeasonTrophies(withAppearances(1)), [
      'world-nations-championship',
    ]);
  });
  test('milestones fire only on crossing a recorded threshold', () {
    final before = CareerSnapshot.newCareer();
    final after = before.copyWith(
      player: before.player.copyWith(appearances: 1, goals: 1),
    );
    expect(
      careerMilestones(before, after),
      contains((kind: CareerMilestoneKind.appearances, value: 1)),
    );
    expect(
      careerMilestones(before, after),
      contains((kind: CareerMilestoneKind.goals, value: 1)),
    );
    expect(careerMilestones(after, after), isEmpty);
    expect(
      careerMilestones(before, CareerSnapshot.newCareer(careerId: 'other')),
      isEmpty,
    );
  });
  test(
    'targets follow position, always advance and never alter saved state',
    () {
      for (final role in Archetype.values) {
        final career = CareerSnapshot.newCareer(
          player: PlayerState.newCareer(
            id: role.name,
            name: 'Test Player',
            archetype: role,
          ).copyWith(appearances: 25, goals: 10, assists: 10),
        );
        final original = career.encode();
        final target = careerTarget(career)!;
        expect(target.goal, greaterThan(target.current));
        if (role.positionFamily == PositionFamily.defender) {
          expect(target.kind, CareerMilestoneKind.appearances);
        }
        expect(career.encode(), original);
        expect(careerTarget(career.copyWith(retired: true)), isNull);
      }
    },
  );
  test('localized feedback uses committed evidence and omitted players get no invented impact', () {
    final before = CareerSnapshot.newCareer();
    final snapshot = before.copyWith(
      player: before.player.copyWith(managerTrust: 1, form: 1, fitness: 1),
    );
    final result = const WeeklySimulator().advance(
      snapshot: snapshot,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.intensive,
        spotlightApproach: SpotlightApproach.safe,
      ),
      opponent: const WorldSimulator().opponentFor(snapshot),
      updatedAt: DateTime.utc(2026, 9, 30),
    );
    expect(result.selection.status, SelectionStatus.omitted);
    for (final locale in ['en', 'es', 'pt-BR', 'fr']) {
      expect(matchReport(result, locale, snapshot.clubName), isNotEmpty);
      for (final story in result.newsStories) {
        expect(
          matchNews(story, result, locale, snapshot.clubName).body,
          isNotEmpty,
        );
      }
      expect(playerMatchLine(result, locale), contains(snapshot.player.name));
    }
    expect(
      matchReport(result, 'es', snapshot.clubName),
      contains('no participó'),
    );
    expect(
      matchReport(result, 'fr', snapshot.clubName),
      contains('n’a pas joué'),
    );
  });
}
