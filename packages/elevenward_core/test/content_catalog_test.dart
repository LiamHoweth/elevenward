import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  final catalog = buildLaunchContent();

  test('launch catalog meets every initial content count', () {
    expect(catalog.matchSituations, hasLength(160));
    expect(catalog.careerEvents, hasLength(200));
    expect(catalog.lifestyleItems, hasLength(120));
    for (final position in PositionFamily.values) {
      expect(
        catalog.matchSituations.where((item) => item.position == position),
        hasLength(40),
      );
    }
  });

  test('catalog has unique ids and complete launch localization', () {
    expect(validateContentCatalog(catalog), isEmpty);
  });

  test('every situation preserves attributes and risk on all three choices',
      () {
    for (final situation in catalog.matchSituations) {
      expect(
        situation.options.map((option) => option.approach).toSet(),
        SpotlightApproach.values.toSet(),
      );
      for (final option in situation.options) {
        expect(option.primaryAttributes, hasLength(2));
      }
    }
  });
}
