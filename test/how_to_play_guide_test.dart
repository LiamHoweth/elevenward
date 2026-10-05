import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/screens/how_to_play_screen.dart';
import 'package:elevenward/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _topics = [
  'training',
  'spotlight',
  'decisions',
  'contracts',
  'world',
  'numbers',
];

Widget _app(Locale locale, Brightness brightness) {
  ElevenwardColors.use(brightness);
  return MaterialApp(
    locale: locale,
    theme: buildElevenwardTheme('graphite', brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const HowToPlayScreen(),
  );
}

void main() {
  for (final (locale, rhythm, firstTopic) in [
    (const Locale('en'), 'Your weekly rhythm', 'Training and recovery'),
    (const Locale('es'), 'Tu rutina semanal', 'Entrenamiento y recuperación'),
    (const Locale('pt', 'BR'), 'Sua rotina semanal', 'Treino e recuperação'),
    (
      const Locale('fr'),
      'Votre rythme hebdomadaire',
      'Entraînement et récupération',
    ),
  ]) {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('all help topics remain readable ${locale.toLanguageTag()} '
            '${brightness.name} ${textScale}x', (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = textScale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(() => ElevenwardColors.use(Brightness.dark));
          await tester.pumpWidget(_app(locale, brightness));
          await tester.pumpAndSettle();
          expect(find.text(rhythm), findsOneWidget);
          expect(tester.takeException(), isNull);

          for (final step in ['prepare', 'play', 'review']) {
            final finder = find.byKey(Key('how-to-play-step-$step'));
            await _reveal(tester, finder);
            expect(tester.widget<Text>(finder).maxLines, isNull);
            expect(tester.takeException(), isNull);
          }

          for (final topic in _topics) {
            final tile = find.byKey(PageStorageKey('how-to-play-topic-$topic'));
            await _reveal(tester, tile);
            if (topic == 'training') {
              expect(find.text(firstTopic), findsOneWidget);
            }
            final title = tester.widget<ExpansionTile>(tile).title;
            expect(title, isA<Text>());
            expect((title as Text).maxLines, isNull);
            await tester.tap(tile);
            await tester.pumpAndSettle();
            final body = find.byKey(Key('how-to-play-body-$topic'));
            await _reveal(tester, body);
            expect(tester.widget<Text>(body).maxLines, isNull);
            expect(tester.takeException(), isNull);
          }

          // Returning to the first topic preserves the section the player
          // opened, so reading another topic does not lose their place.
          await tester.drag(find.byType(Scrollable), const Offset(0, 15000));
          await tester.pumpAndSettle();
          final firstTile = find.byKey(
            const PageStorageKey('how-to-play-topic-training'),
          );
          await _reveal(tester, firstTile);
          expect(
            find.byKey(const Key('how-to-play-body-training')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable),
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
