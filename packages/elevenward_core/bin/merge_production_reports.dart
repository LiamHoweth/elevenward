import 'dart:convert';
import 'dart:io';

/// Release gate for the 20 real-engine shards. Refuses missing, duplicate,
/// overlapping, failed, or incomplete reports rather than merely uploading them.
void main(List<String> paths) {
  String? output;
  final reportPaths = <String>[];
  for (var index = 0; index < paths.length; index++) {
    if (paths[index] == '--output') {
      output = paths[++index];
    } else {
      reportPaths.add(paths[index]);
    }
  }
  if (reportPaths.isEmpty) {
    throw ArgumentError('Pass the production shard JSON paths.');
  }
  final reports = reportPaths
      .map((path) => (jsonDecode(File(path).readAsStringSync()) as Map)
          .cast<String, Object?>())
      .toList()
    ..sort(
        (a, b) => (a['startIndex'] as int).compareTo(b['startIndex'] as int));
  var next = 0;
  var weeks = 0;
  final coverage = <String, Map<String, int>>{};
  for (final report in reports) {
    if (report['engine'] !=
            'CareerSnapshot+WeeklySimulator+WorldSimulator+CareerEngine' ||
        report['passed'] != true ||
        (report['failures'] as List).isNotEmpty ||
        report['startIndex'] != next) {
      throw StateError(
          'Failed, synthetic, non-contiguous, or overlapping shard at $next.');
    }
    final completed = (report['retirementSeasonCounts'] as Map)
        .values
        .cast<int>()
        .fold(0, (a, b) => a + b);
    if (completed != report['careers'])
      throw StateError('Shard did not complete all requested careers.');
    next += completed;
    weeks += report['weeks'] as int;
    for (final name in [
      'positionCounts',
      'archetypeCounts',
      'difficultyCounts',
      'startingLeagueCounts',
      'retirementSeasonCounts',
      'competitionCompletions',
      'transferCounts',
      'nationalTeamDecisionCounts',
      'leagueMovementCounts',
      'rewardProfileCounts',
    ]) {
      final totals = coverage.putIfAbsent(name, () => {});
      for (final entry in (report[name] as Map).entries) {
        totals.update(
            entry.key as String, (value) => value + (entry.value as int),
            ifAbsent: () => entry.value as int);
      }
    }
  }
  if (next < 100000) {
    throw StateError('Only $next real careers; 100,000 required.');
  }
  for (final requirement in {
    'positionCounts': 4,
    'archetypeCounts': 12,
    'difficultyCounts': 3,
    'startingLeagueCounts': 12,
    'retirementSeasonCounts': 5,
    'competitionCompletions': 3,
    'transferCounts': 3,
    'nationalTeamDecisionCounts': 2,
    'leagueMovementCounts': 3,
    'rewardProfileCounts': 4,
  }.entries) {
    final counts = coverage[requirement.key]!;
    if (counts.length != requirement.value ||
        counts.values.any((count) => count <= 0)) {
      throw StateError('Incomplete ${requirement.key} coverage.');
    }
  }
  final json = '${const JsonEncoder.withIndent('  ').convert({
        'passed': true,
        'careers': next,
        'weeks': weeks,
        'coverage': coverage,
        'shards': reports
            .map((report) => {
                  'startIndex': report['startIndex'],
                  'careers': report['careers'],
                  'checksum': report['checksum']
                })
            .toList(),
      })}\n';
  if (output == null) {
    stdout.write(json);
  } else {
    final file = File(output);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(json);
    stdout.writeln('Wrote $output');
  }
}
