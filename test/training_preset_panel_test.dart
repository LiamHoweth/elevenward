import 'dart:async';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/training_preset.dart';
import 'package:elevenward/src/widgets/training_preset_panel.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _saved = TrainingPreset(
  focus: PlayerAttribute.finishing,
  intensity: TrainingIntensity.light,
);
const _current = TrainingPreset(
  focus: PlayerAttribute.passing,
  intensity: TrainingIntensity.intensive,
);

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildElevenwardTheme('graphite', brightness),
  builder: (context, child) {
    ElevenwardColors.use(brightness);
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
  },
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  tearDown(() => ElevenwardColors.use(Brightness.dark));

  testWidgets(
    'saves, replaces, applies both choices and removes the favorite',
    (tester) async {
      TrainingPreset? preset;
      var current = _current;
      late StateSetter update;
      final saves = <TrainingPreset>[];
      final applied = <TrainingPreset>[];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TrainingPresetPanel(
                focus: current.focus,
                intensity: current.intensity,
                preset: preset,
                onSave: (value) async {
                  saves.add(value);
                  setState(() => preset = value);
                },
                onClear: () async => setState(() => preset = null),
                onApply: (value) {
                  applied.add(value);
                  setState(() => current = value);
                },
              );
            },
          ),
        ),
      );

      expect(find.text('Save current settings'), findsOneWidget);
      expect(find.byKey(const Key('apply-training-preset')), findsNothing);
      await tester.tap(find.byKey(const Key('save-training-preset')));
      await tester.pumpAndSettle();
      expect(saves.single, _current);
      expect(find.text('Using favorite'), findsOneWidget);
      expect(find.byKey(const Key('training-preset-active')), findsOneWidget);
      expect(find.byKey(const Key('save-training-preset')), findsNothing);
      expect(find.byKey(const Key('apply-training-preset')), findsNothing);

      update(() => current = _saved);
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-training-preset')));
      await tester.pumpAndSettle();
      expect(saves, [_current, _saved]);
      update(() => current = _current);
      await tester.pump();
      await tester.tap(find.byKey(const Key('apply-training-preset')));
      await tester.pump();
      expect(applied.single, _saved);
      expect(current, _saved);
      expect(find.text('Using favorite'), findsOneWidget);
      expect(find.byKey(const Key('save-training-preset')), findsNothing);
      expect(find.byKey(const Key('apply-training-preset')), findsNothing);

      await tester.tap(find.byKey(const Key('clear-training-preset')));
      await tester.pumpAndSettle();
      expect(preset, isNull);
      expect(current, _saved, reason: 'Removing a shortcut preserves choices.');
      expect(find.text('Save current settings'), findsOneWidget);
    },
  );

  testWidgets('pending writes disable all preset controls until completion', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        TrainingPresetPanel(
          focus: _current.focus,
          intensity: _current.intensity,
          preset: _saved,
          onSave: (_) {
            calls++;
            return pending.future;
          },
          onClear: () async => fail('Clear must be disabled during save'),
          onApply: (_) => fail('Apply must be disabled during save'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('save-training-preset')));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    for (final key in [
      'save-training-preset',
      'apply-training-preset',
      'clear-training-preset',
    ]) {
      expect(
        tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed,
        isNull,
      );
    }
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('apply-training-preset')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'failed save retains the favorite and retries its exact choices',
    (tester) async {
      final attempts = <TrainingPreset>[];
      var current = _current;
      var failSave = true;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TrainingPresetPanel(
                focus: current.focus,
                intensity: current.intensity,
                preset: _saved,
                onSave: (value) async {
                  attempts.add(value);
                  if (failSave) throw StateError('Storage unavailable');
                },
                onClear: () async {},
                onApply: (_) {},
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('save-training-preset')));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t save your favorite. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Finishing · Light'), findsOneWidget);
      expect(tester.takeException(), isNull);
      failSave = false;
      update(() => current = _saved);
      await tester.pump();
      await tester.tap(find.byKey(const Key('retry-training-preset')));
      await tester.pumpAndSettle();
      expect(attempts, [_current, _current]);
      expect(find.byKey(const Key('training-preset-error')), findsNothing);
    },
  );

  testWidgets(
    'failed removal is retryable and external disabling is respected',
    (tester) async {
      var removals = 0;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return TrainingPresetPanel(
                focus: _current.focus,
                intensity: _current.intensity,
                preset: _saved,
                enabled: enabled,
                onSave: (_) async {},
                onClear: () async {
                  removals++;
                  if (removals == 1) throw StateError('Storage unavailable');
                },
                onApply: (_) {},
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('clear-training-preset')));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t remove your favorite. Try again.'),
        findsOneWidget,
      );
      update(() => enabled = false);
      await tester.pump();
      for (final key in [
        'save-training-preset',
        'apply-training-preset',
        'clear-training-preset',
        'retry-training-preset',
      ]) {
        expect(
          tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed,
          isNull,
        );
      }
      update(() => enabled = true);
      await tester.pump();
      await tester.tap(find.byKey(const Key('retry-training-preset')));
      await tester.pumpAndSettle();
      expect(removals, 2);
      expect(find.byKey(const Key('training-preset-error')), findsNothing);
    },
  );

  for (final locale in ['en', 'es', 'pt', 'fr']) {
    for (final brightness in Brightness.values) {
      testWidgets('320px 200% text remains readable: $locale $brightness', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _app(
            TrainingPresetPanel(
              focus: _current.focus,
              intensity: _current.intensity,
              preset: _saved,
              onSave: (_) async => throw StateError('Storage unavailable'),
              onClear: () async {},
              onApply: (_) {},
            ),
            locale: Locale(locale),
            brightness: brightness,
            scale: 2,
          ),
        );
        final save = find.byKey(const Key('save-training-preset'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('retry-training-preset')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('training-preset-error')), findsOneWidget);
        expect(tester.getSize(save).width, lessThanOrEqualTo(288));
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
