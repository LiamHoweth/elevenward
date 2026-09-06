import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  test('batch verifier is deterministic and covers every career dimension', () {
    const verifier = FullCareerVerifier();
    final first = verifier.run(careers: 2000);
    final second = verifier.run(careers: 2000);
    expect(first.passed, isTrue, reason: first.failures.join('\n'));
    expect(second.checksum, first.checksum);
    expect(first.positionCounts.keys, hasLength(4));
    expect(first.difficultyCounts.keys, hasLength(3));
    expect(first.leagueCounts.keys, hasLength(12));
    expect(first.retirementSeasonCounts.keys, hasLength(5));
    expect(first.weeks, greaterThan(500000));
  });
}
