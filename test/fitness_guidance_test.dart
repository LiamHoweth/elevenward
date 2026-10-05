import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/fitness_guidance.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fitness display bands have stable, inclusive boundary values', () {
    for (final value in [1, 49]) {
      expect(fitnessBandFor(value), FitnessBand.low);
    }
    for (final value in [50, 79]) {
      expect(fitnessBandFor(value), FitnessBand.moderate);
    }
    for (final value in [80, 100]) {
      expect(fitnessBandFor(value), FitnessBand.high);
    }
  });

  testWidgets('uses capped core preview values and recovery guidance', (
    tester,
  ) async {
    const simulator = WeeklySimulator();
    final career = CareerSnapshot.newCareer();
    for (final entry in [
      (before: 98, intensity: TrainingIntensity.light, after: 100),
      (before: 2, intensity: TrainingIntensity.intensive, after: 1),
    ]) {
      final preview = simulator.previewTraining(
        snapshot: career.copyWith(
          player: career.player.copyWith(fitness: entry.before),
        ),
        focus: PlayerAttribute.finishing,
        intensity: entry.intensity,
      );
      expect(preview.fitnessAfter, entry.after);
      await tester.pumpWidget(_app(preview));
      expect(
        find.text('${entry.before} → ${entry.after} / 100'),
        findsOneWidget,
      );
      expect(
        find.text(
          entry.intensity == TrainingIntensity.light
              ? 'This load restores fitness.'
              : 'This load costs fitness. Light training helps recovery.',
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('paused training never promises recovery', (tester) async {
    final career = CareerSnapshot.newCareer().copyWith(
      phase: CareerPhase.internationalTournament,
    );
    final preview = const WeeklySimulator().previewTraining(
      snapshot: career,
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.light,
    );
    await tester.pumpWidget(_app(preview));
    expect(preview.fitnessChange, 0);
    expect(find.text('This load restores fitness.'), findsNothing);
    expect(
      find.text(
        'National-team matchday · club training is paused during the tournament.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('maximum and low clamp show honest, useful guidance', (
    tester,
  ) async {
    for (final entry in [
      (fitness: 100, advice: 'Fitness is at its maximum.'),
      (fitness: 1, advice: 'Try light training to restore fitness.'),
    ]) {
      await tester.pumpWidget(_app(_preview(entry.fitness, entry.fitness)));
      expect(find.text(entry.advice), findsOneWidget);
    }
  });

  testWidgets('all bands fit 320px and 200% text in every launch language', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      ElevenwardColors.use(brightness);
      for (final locale in AppLocalizations.supportedLocales) {
        for (final after in [1, 49, 50, 79, 80, 100]) {
          await tester.pumpWidget(
            _app(
              _preview(after == 100 ? 98 : after + 2, after),
              locale: locale,
              brightness: brightness,
              textScale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$locale, $brightness, fitness $after',
          );
          final band = tester.widget<Text>(
            find.byKey(const Key('fitness-guidance-band')),
          );
          expect(band.data, isNotEmpty);
          expect(find.byKey(const Key('fitness-guidance')), findsOneWidget);
        }
      }
    }
    ElevenwardColors.use(Brightness.dark);
  });

  testWidgets('screen readers hear current and projected fitness together', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_app(_preview(82, 80)));
      const label =
          'Fitness: 82 out of 100. After training: 80 out of 100, High. '
          'This load costs fitness. Light training helps recovery.';
      final guidance = find.bySemanticsLabel(label);
      expect(guidance, findsOneWidget);
      expect(tester.getSemantics(guidance).label, label);
    } finally {
      // Flutter verifies handles before test-framework teardown callbacks.
      semantics.dispose();
    }
  });
}

TrainingPreview _preview(int before, int after) => TrainingPreview(
  attributeBefore: 70,
  attributeAfter: 71,
  fitnessBefore: before,
  fitnessAfter: after,
  remainder: 0,
  multiplier: 1,
  paused: false,
);

Widget _app(
  TrainingPreview preview, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) => MaterialApp(
  theme: buildElevenwardTheme('graphite', brightness),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: FitnessGuidance(preview: preview),
    ),
  ),
);
