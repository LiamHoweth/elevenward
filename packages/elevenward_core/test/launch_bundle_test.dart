import 'dart:convert';
import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  test('generated launch bundle decodes into the runtime content catalog', () {
    final source =
        File('../../assets/content/launch-2026.2.0.json').readAsStringSync();
    final bundle = (jsonDecode(source) as Map).cast<String, Object?>();
    final catalog = ContentCatalog.fromBundle(bundle);

    expect(catalog.version, '2026.2.0');
    expect(catalog.matchSituations, hasLength(160));
    expect(catalog.careerEvents, hasLength(200));
    expect(catalog.lifestyleItems, hasLength(120));
    expect(validateContentCatalog(catalog), isEmpty);
  });
}
