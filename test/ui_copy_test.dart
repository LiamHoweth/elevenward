import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const locales = {'en', 'es', 'pt-BR', 'fr'};

  test('every interface copy key covers all launch languages', () {
    for (final entry in uiCopyTranslations.entries) {
      expect(
        entry.value.keys.toSet(),
        containsAll(locales),
        reason: '${entry.key} is missing a launch-language value.',
      );
      for (final locale in locales) {
        expect(
          entry.value[locale]?.trim(),
          isNotEmpty,
          reason: '${entry.key} has an empty $locale value.',
        );
      }
    }
  });

  test('every football nation has a display name in every launch language', () {
    for (final locale in locales) {
      for (final nation in FootballNation.values) {
        expect(localizedFootballNation(locale, nation).trim(), isNotEmpty);
      }
    }
  });
}
