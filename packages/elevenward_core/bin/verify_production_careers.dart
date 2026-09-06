import 'dart:convert';
import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';

void main(List<String> arguments) {
  var careers = 100000;
  var startIndex = 0;
  String? output;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--careers':
        careers = int.parse(arguments[++index]);
      case '--start':
        startIndex = int.parse(arguments[++index]);
      case '--output':
        output = arguments[++index];
      default:
        throw ArgumentError('Unknown argument ${arguments[index]}');
    }
  }
  final report = const ProductionCareerVerifier().run(
    careers: careers,
    startIndex: startIndex,
  );
  const encoder = JsonEncoder.withIndent('  ');
  final json = '${encoder.convert(report.toJson())}\n';
  if (output == null) {
    stdout.write(json);
  } else {
    final file = File(output);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(json);
    stdout.writeln('Wrote $output');
  }
  if (!report.passed) exitCode = 1;
}
