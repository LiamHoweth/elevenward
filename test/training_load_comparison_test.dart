import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/fitness_guidance.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => ElevenwardColors.use(Brightness.dark));

  testWidgets('compares supplied core projections and selects the real load', (
    tester,
  ) async {
    final base = CareerSnapshot.newCareer();
    final career = base.copyWith(
      player: base.player.copyWith(fitness: 98),
      developmentProgress: {PlayerAttribute.passing: .45},
    );
    final original = career.encode();
    const simulator = WeeklySimulator();
    final previews = {
      for (final load in TrainingIntensity.values)
        load: simulator.previewTraining(
          snapshot: career,
          focus: PlayerAttribute.passing,
          intensity: load,
          modifiers: const RewardModifiers(developmentMultiplier: 2),
        ),
    };
    var selected = TrainingIntensity.balanced;
    final selections = <TrainingIntensity>[];
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => FitnessGuidance(
            preview: previews[selected]!,
            focus: PlayerAttribute.passing,
            intensity: selected,
            loadPreviews: previews,
            onIntensityChanged: (load) {
              selections.add(load);
              setState(() => selected = load);
            },
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('training-compare-light')), findsNothing);
    await tester.tap(find.byKey(const Key('training-load-comparison-toggle')));
    await tester.pump();

    for (final load in TrainingIntensity.values) {
      final row = find.byKey(Key('training-compare-${load.name}'));
      final preview = previews[load]!;
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            'Passing ${preview.attributeBefore} → ${preview.attributeAfter}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(
            'Fitness ${preview.fitnessBefore} → ${preview.fitnessAfter} / 100',
          ),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      expect(selected, load);
      expect(tester.widget<Semantics>(row).properties.selected, isTrue);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('fitness-guidance-values')))
            .data,
        '${preview.fitnessBefore} → ${preview.fitnessAfter} / 100',
      );
    }
    expect(selections, TrainingIntensity.values);
    expect(career.encode(), original, reason: 'Comparisons are read-only.');
    await tester.ensureVisible(
      find.byKey(const Key('training-load-comparison-toggle')),
    );
    await tester.tap(find.byKey(const Key('training-load-comparison-toggle')));
    await tester.pump();
    expect(find.byKey(const Key('training-compare-light')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fractional progress never claims a point before it is earned', (
    tester,
  ) async {
    final previews = {
      TrainingIntensity.light: _preview(attributeAfter: 70, remainder: .9999),
      TrainingIntensity.balanced: _preview(attributeAfter: 71, remainder: .004),
      TrainingIntensity.intensive: _preview(attributeAfter: 99, remainder: .9),
    };
    await tester.pumpWidget(
      _app(
        FitnessGuidance(
          preview: previews[TrainingIntensity.light]!,
          loadPreviews: previews,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('training-load-comparison-toggle')));
    await tester.pump();
    expect(
      find.text('Progress after training: 99% toward the next point.'),
      findsOneWidget,
    );
    expect(
      find.text('Progress after training: <1% toward the next point.'),
      findsOneWidget,
    );
    expect(
      find.text('Progress after training: 100% toward the next point.'),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('training-compare-intensive')),
        matching: find.textContaining('Progress after training'),
      ),
      findsNothing,
      reason: 'Capped attributes do not promise another point.',
    );
  });

  testWidgets('paused training hides load comparison', (tester) async {
    final preview = _preview(paused: true);
    await tester.pumpWidget(
      _app(
        FitnessGuidance(
          preview: preview,
          loadPreviews: {TrainingIntensity.light: preview},
        ),
      ),
    );
    expect(
      find.byKey(const Key('training-load-comparison-toggle')),
      findsNothing,
    );
  });

  testWidgets('each accessible row states its projection and selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          FitnessGuidance(
            preview: _preview(),
            focus: PlayerAttribute.passing,
            intensity: TrainingIntensity.light,
            loadPreviews: {TrainingIntensity.light: _preview()},
            onIntensityChanged: (_) {},
          ),
        ),
      );
      await tester.tap(
        find.byKey(const Key('training-load-comparison-toggle')),
      );
      await tester.pump();
      final row = find.byKey(const Key('training-compare-light'));
      final node = tester.getSemantics(row);
      expect(node.label, 'Light. Passing 70 → 71. Fitness 80 → 86 / 100.');
      expect(tester.widget<Semantics>(row).properties.selected, isTrue);
      expect(tester.widget<Semantics>(row).properties.onTap, isNotNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    for (final brightness in Brightness.values) {
      testWidgets('comparison wraps at 320px and 200%: $locale $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final previews = {
          for (final load in TrainingIntensity.values)
            load: _preview(remainder: .35),
        };
        await tester.pumpWidget(
          _app(
            FitnessGuidance(
              preview: previews[TrainingIntensity.balanced]!,
              focus: PlayerAttribute.defending,
              intensity: TrainingIntensity.balanced,
              loadPreviews: previews,
              onIntensityChanged: (_) {},
            ),
            locale: locale,
            brightness: brightness,
            scale: 2,
          ),
        );
        final toggle = find.byKey(const Key('training-load-comparison-toggle'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pump();
        for (final load in TrainingIntensity.values) {
          final row = find.byKey(Key('training-compare-${load.name}'));
          await tester.ensureVisible(row);
          await tester.pump();
          expect(tester.getSize(row).width, lessThanOrEqualTo(288));
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}

TrainingPreview _preview({
  int attributeAfter = 71,
  double remainder = 0,
  bool paused = false,
}) => TrainingPreview(
  attributeBefore: 70,
  attributeAfter: attributeAfter,
  fitnessBefore: 80,
  fitnessAfter: 86,
  remainder: remainder,
  multiplier: 1,
  paused: paused,
);

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite', brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
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
