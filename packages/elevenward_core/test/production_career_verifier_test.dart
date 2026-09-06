import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  test('production verifier drives real careers deterministically', () {
    const verifier = ProductionCareerVerifier();
    final first = verifier.run(careers: 36);
    final second = verifier.run(careers: 36);
    expect(first.passed, isTrue, reason: first.failures.join('\n'));
    expect(first.checksum, second.checksum);
    expect(first.weeks, greaterThan(10000));
    expect(first.archetypeCounts.keys,
        containsAll(Archetype.values.map((e) => e.name)));
    expect(first.difficultyCounts.keys,
        containsAll(Difficulty.values.map((e) => e.name)));
    expect(first.competitionCompletions['domesticCup'], greaterThan(0));
    expect(first.competitionCompletions['internationalClub'], greaterThan(0));
    expect(first.competitionCompletions['nationalTournament'], greaterThan(0));
    expect(
        first.nationalTeamDecisionCounts.values, everyElement(greaterThan(0)));
    expect(first.leagueMovementCounts['unchanged'], greaterThan(0));
  });
}
