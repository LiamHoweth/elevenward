import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/training_preset.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.drag(find.byType(ListView).first, const Offset(0, 10000));
    await tester.pumpAndSettle();
  }
  for (var i = 0; i < 35; i++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await tester.pumpAndSettle();
      if (target.hitTestable().evaluate().isNotEmpty) return;
    }
    final list = find.byType(ListView).first;
    await tester.drag(list, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  fail('Could not reveal $target');
}

void main() {
  const loadLabels = {
    'en': ['Light', 'Balanced', 'Intensive'],
    'es': ['Ligero', 'Equilibrado', 'Intensivo'],
    'pt': ['Leve', 'Equilibrado', 'Intensivo'],
    'fr': ['Léger', 'Équilibré', 'Intensif'],
  };
  for (final locale in loadLabels.keys) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'localized loads update the real training preview: $locale ${scale}x',
        (tester) async {
          tester.view.physicalSize = Size(scale == 2 ? 320 : 390, 700);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final career = CareerSnapshot.newCareer();
          await tester.pumpWidget(
            _app(
              GameScreen(
                initialCareer: career,
                initialFocus: PlayerAttribute.passing,
              ),
              locale: Locale(locale),
            ),
          );
          await tester.pumpAndSettle();
          final positions = <Offset>[];
          final widths = <double>[];
          for (final intensity in TrainingIntensity.values) {
            final control = find.byKey(
              Key('training-intensity-${intensity.name}'),
            );
            await _reveal(tester, control);
            final label = find.descendant(
              of: control,
              matching: find.byType(Text),
            );
            expect(
              tester.widget<Text>(label).data,
              loadLabels[locale]![intensity.index],
            );
            expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
            await tester.tap(control);
            await tester.pumpAndSettle();
            expect(
              tester.widget<Semantics>(control).properties.selected,
              isTrue,
            );
            expect(tester.takeException(), isNull);
            final expected = const WeeklySimulator().previewTraining(
              snapshot: career,
              focus: PlayerAttribute.passing,
              intensity: intensity,
            );
            await _reveal(
              tester,
              find.byKey(const Key('fitness-guidance-values')),
            );
            expect(
              find.text(
                '${expected.fitnessBefore} → ${expected.fitnessAfter} / 100',
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          }
          // Inspect all three controls together after returning to the group.
          final first = find.byKey(const Key('training-intensity-light'));
          await _reveal(tester, first);
          for (final intensity in TrainingIntensity.values) {
            final control = find.byKey(
              Key('training-intensity-${intensity.name}'),
            );
            positions.add(tester.getCenter(control));
            widths.add(tester.getSize(control).width);
          }
          if (scale == 2) {
            expect(positions[1].dy, greaterThan(positions[0].dy));
            expect(positions[2].dy, greaterThan(positions[1].dy));
            expect(positions[0].dx, positions[1].dx);
            expect(positions[1].dx, positions[2].dx);
            expect(widths[0], widths[1]);
            expect(widths[1], widths[2]);
            expect(widths[0], greaterThan(200));
          } else {
            expect(positions[0].dy, positions[1].dy);
            expect(positions[1].dy, positions[2].dy);
            expect(positions[1].dx, greaterThan(positions[0].dx));
            expect(positions[2].dx, greaterThan(positions[1].dx));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'applying a favorite updates the real preview and committed week',
    (tester) async {
      final career = CareerSnapshot.newCareer();
      const favorite = TrainingPreset(
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.intensive,
      );
      final expected = const WeeklySimulator().previewTraining(
        snapshot: career,
        focus: favorite.focus,
        intensity: favorite.intensity,
      );
      CareerSnapshot? saved;
      await tester.pumpWidget(
        _app(
          GameScreen(
            initialCareer: career,
            initialFocus: PlayerAttribute.passing,
            quickTransitions: true,
            trainingPreset: favorite,
            onSaveTrainingPreset: (_) async {},
            onClearTrainingPreset: () async {},
            onCareerChanged: (snapshot, _) async => saved = snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final apply = find.byKey(const Key('apply-training-preset'));
      await _reveal(tester, apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('fitness-guidance-values')));
      expect(
        find.text('${expected.fitnessBefore} → ${expected.fitnessAfter} / 100'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('weekly-continue-button')));
      await tester.pumpAndSettle();
      final safe = find.byKey(const Key('spotlight-option-safe'));
      await _reveal(tester, safe);
      await tester.tap(safe);
      final commit = find.byKey(const Key('commit-button'));
      await _reveal(tester, commit);
      await tester.tap(commit);
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(
        saved!.player.attributes[PlayerAttribute.finishing],
        expected.attributeAfter,
      );
      expect(saved!.revision, career.revision + 1);
      expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('career stat help remains reachable at 320px and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(const GameScreen()));
    await tester.pumpAndSettle();
    final trust = find.byKey(const Key('career-stat-help-managerTrust'));
    await _reveal(tester, trust);
    await tester.tap(trust);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('stat-explanation-managerTrust')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('stat-explanation-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-continue-button')), findsOneWidget);
  });

  testWidgets('older career rules can open the matchup tactical fit help', (
    tester,
  ) async {
    final career = CareerSnapshot.fromJson({
      ...CareerSnapshot.newCareer().toJson(),
      'rulesVersion': '2026.4',
    });
    final before = career.encode();
    await tester.pumpWidget(
      _app(GameScreen(initialCareer: career, quickTransitions: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weekly-continue-button')));
    await tester.pumpAndSettle();
    final help = find.byKey(const Key('stat-help-tacticalFit'));
    await _reveal(tester, help);
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('stat-explanation-tacticalFit')),
      findsOneWidget,
    );
    expect(career.encode(), before);
    expect(tester.takeException(), isNull);
  });
}
