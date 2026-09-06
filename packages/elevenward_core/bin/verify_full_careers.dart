import 'dart:convert';
import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';

void main(List<String> arguments) {
  final careers = arguments.isEmpty ? 100000 : int.parse(arguments.first);
  final stopwatch = Stopwatch()..start();
  final report = const FullCareerVerifier().run(careers: careers);
  stopwatch.stop();
  final output = {
    ...report.toJson(),
    'elapsedMilliseconds': stopwatch.elapsedMilliseconds,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
  };
  final encoded = const JsonEncoder.withIndent('  ').convert(output);
  final outputPath = arguments.length > 1
      ? arguments[1]
      : '../../artifacts/verification/100k-full-careers.json';
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('$encoded\n');
  stdout.writeln(encoded);
  if (!report.passed || report.careers != careers) exitCode = 1;
}
