import 'dart:convert';
import 'dart:io';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';
import '../bin/merge_production_reports.dart' as merger;

void main() {
  // Report metadata fixtures only; these are not simulation evidence.
  Map<String, Object?> report(Map<String, int> leagues) => {
        'engine': 'CareerSnapshot+WeeklySimulator+WorldSimulator+CareerEngine',
        'passed': true,
        'failures': <String>[],
        'startIndex': 0,
        'careers': 100000,
        'weeks': 32000000,
        'checksum': 'fixture',
        'positionCounts': {
          for (final p in PositionFamily.values) p.name: 25000
        },
        'archetypeCounts': {for (final p in Archetype.values) p.name: 1},
        'difficultyCounts': {for (final p in Difficulty.values) p.name: 1},
        'startingLeagueCounts': leagues,
        'retirementSeasonCounts': {for (var s = 16; s <= 20; s++) '$s': 20000},
        'competitionCompletions': {
          'domesticCup': 1,
          'internationalClub': 1,
          'nationalTournament': 1
        },
        'transferCounts': {'stayed': 1, 'sameNation': 1, 'international': 1},
        'nationalTeamDecisionCounts': {'accepted': 1, 'declined': 1},
        'leagueMovementCounts': {'promoted': 1, 'relegated': 1, 'unchanged': 1},
        'rewardProfileCounts': {
          'standard': 1,
          'vip': 1,
          'double': 1,
          'allAccess': 1
        },
      };
  late Directory directory;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('elevenward-merge-test-');
  });
  tearDown(() {
    directory.deleteSync(recursive: true);
  });
  test('expanded shipped leagues pass the release coverage gate', () {
    final input = File('${directory.path}/input.json');
    final output = File('${directory.path}/output.json');
    input.writeAsStringSync(jsonEncode(
        report({for (final l in buildLaunchWorld().leagues) l.id: 1})));
    merger.main(['--output', output.path, input.path]);
    expect((jsonDecode(output.readAsStringSync()) as Map)['passed'], isTrue);
  });
  test('an unknown league cannot replace a missing shipped league', () {
    final leagues = {for (final l in buildLaunchWorld().leagues) l.id: 1};
    leagues.remove(leagues.keys.first);
    leagues['unshipped-league'] = 1;
    final input = File('${directory.path}/input.json');
    input.writeAsStringSync(jsonEncode(report(leagues)));
    expect(() => merger.main([input.path]), throwsStateError);
  });
  test('old twelve-league coverage still fails after world expansion', () {
    final input = File('${directory.path}/input.json');
    input.writeAsStringSync(jsonEncode(report(
        {for (final l in buildLaunchWorld().leagues.take(12)) l.id: 1})));
    expect(() => merger.main([input.path]), throwsStateError);
  });
}
