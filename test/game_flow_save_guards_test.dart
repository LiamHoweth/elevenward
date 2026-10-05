import 'dart:async';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> _commitSafe(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('weekly-continue-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('spotlight-option-safe')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('commit-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a rejected save adopts a newer same-generation authoritative career',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final base = CareerSnapshot.newCareer(careerId: 'same-career');
      final incoming = ValueNotifier(base);
      addTearDown(incoming.dispose);
      final pendingSave = Completer<void>();
      var attempts = 0;
      CareerSnapshot? saved;
      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<CareerSnapshot>(
            valueListenable: incoming,
            builder: (context, career, child) => GameScreen(
              initialCareer: career,
              quickTransitions: true,
              onCareerChanged: (snapshot, _) async {
                attempts++;
                if (attempts == 1) await pendingSave.future;
                saved = snapshot;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _commitSafe(tester);
      final authoritative = base.copyWith(
        revision: base.revision + 10,
        player: base.player.copyWith(money: base.player.money + 333),
      );
      incoming.value = authoritative;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('career-decision-saving')), findsOneWidget);
      pendingSave.completeError(StateError('The reviewed career changed'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('focus')), findsOneWidget);
      expect(find.byKey(const ValueKey('match-recap')), findsNothing);
      expect(find.byKey(const Key('career-decision-saving')), findsNothing);
      expect(find.text('Retry'), findsNothing);
      // Let the save-failure banner finish before tapping the next weekly CTA.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('weekly-continue-button')).hitTestable(),
        findsOneWidget,
      );
      await _commitSafe(tester);
      expect(saved?.revision, authoritative.revision + 1);
      expect(
        saved?.player.money,
        greaterThanOrEqualTo(authoritative.player.money),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('old save completion cannot unlock a newer career save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final generation = ValueNotifier(0);
    addTearDown(generation.dispose);
    final first = CareerSnapshot.newCareer(careerId: 'first');
    final second = CareerSnapshot.newCareer(careerId: 'second');
    final firstSave = Completer<void>();
    final secondSave = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      _app(
        ValueListenableBuilder<int>(
          valueListenable: generation,
          builder: (context, value, child) => GameScreen(
            initialCareer: value == 0 ? first : second,
            activeCareerGeneration: value,
            quickTransitions: true,
            onCareerChanged: (snapshot, _) {
              attempts++;
              return snapshot.careerId == first.careerId
                  ? firstSave.future
                  : secondSave.future;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _commitSafe(tester);
    generation.value = 1;
    await tester.pumpAndSettle();
    await _commitSafe(tester);
    expect(attempts, 2);
    firstSave.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('commit-button')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('career-decision-saving')), findsOneWidget);
    expect(find.byKey(const ValueKey('match-recap')), findsNothing);
    secondSave.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
    expect(find.byKey(const Key('career-decision-saving')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus changes publish only after durable success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final focusSave = Completer<void>();
    final base = CareerSnapshot.newCareer();
    await tester.pumpWidget(
      _app(
        GameScreen(
          initialCareer: base,
          initialFocus: PlayerAttribute.finishing,
          onFocusPreferenceChanged: (_) => focusSave.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-selector-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('focus-option-passing')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('weekly-continue-button')))
          .onPressed,
      isNull,
    );
    focusSave.completeError(StateError('Injected focus save failure'));
    await tester.pumpAndSettle();
    final expected = const WeeklySimulator().previewTraining(
      snapshot: base,
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.balanced,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('exact-training-preview'))).data,
      contains('${expected.attributeBefore} → ${expected.attributeAfter}'),
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('weekly-continue-button')))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final limit in ['season', 'age']) {
    testWidgets(
      'mandatory $limit retirement presents a truthful final-season action',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final base = CareerSnapshot.newCareer();
        final career = base.copyWith(
          phase: CareerPhase.offseason,
          season: limit == 'season' ? 20 : 3,
          player: base.player.copyWith(age: limit == 'age' ? 37 : 30),
        );
        CareerSnapshot? saved;
        await tester.pumpWidget(
          _app(
            GameScreen(
              initialCareer: career,
              onCareerChanged: (snapshot, _) async => saved = snapshot,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('mandatory-retirement-wrap-up')),
          findsOneWidget,
        );
        expect(find.text('CONTRACT OFFERS'), findsNothing);
        expect(
          find.byKey(const Key('offseason-edit-transfer-request')),
          findsNothing,
        );
        final finish = find.byKey(const Key('finish-required-retirement'));
        await tester.scrollUntilVisible(
          finish,
          150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 30,
        );
        await tester.pumpAndSettle();
        await tester.tap(finish);
        await tester.pumpAndSettle();
        expect(saved?.phase, CareerPhase.retired);
        expect(saved?.seasonHistory.last.season, career.season);
        expect(find.byKey(const ValueKey('retired')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
