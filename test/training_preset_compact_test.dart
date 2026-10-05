import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/training_preset.dart';
import 'package:elevenward/src/widgets/training_preset_panel.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const favorite = TrainingPreset(
    focus: PlayerAttribute.defending,
    intensity: TrainingIntensity.intensive,
  );
  tearDown(() => ElevenwardColors.use(Brightness.dark));
  for (final locale in AppLocalizations.supportedLocales) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'matched favorite stays compact and removable: $locale $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var removals = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              theme: buildElevenwardTheme('graphite', brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                ElevenwardColors.use(brightness);
                return MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                );
              },
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: TrainingPresetPanel(
                    focus: favorite.focus,
                    intensity: favorite.intensity,
                    preset: favorite,
                    onSave: (_) async =>
                        fail('Matched favorite cannot be replaced'),
                    onClear: () async => removals++,
                    onApply: (_) =>
                        fail('Matched favorite needs no reapplication'),
                  ),
                ),
              ),
            ),
          );
          expect(
            find.byKey(const Key('training-preset-active')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('save-training-preset')), findsNothing);
          expect(find.byKey(const Key('apply-training-preset')), findsNothing);
          final remove = find.byKey(const Key('clear-training-preset'));
          await tester.ensureVisible(remove);
          expect(tester.getSize(remove).height, greaterThanOrEqualTo(48));
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(removals, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
