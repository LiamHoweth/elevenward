import 'dart:async';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/how_to_play_screen.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets(
    'a failed save preserves the choice and blocks recap until retry',
    (tester) async {
      final firstSave = Completer<void>();
      var attempts = 0;
      CareerSnapshot? saved;
      await tester.pumpWidget(
        _app(
          GameScreen(
            quickTransitions: true,
            onCareerChanged: (career, _) async {
              attempts++;
              if (attempts == 1) await firstSave.future;
              saved = career;
            },
          ),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('weekly-continue-button')));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('spotlight-option-safe')));
      await tester.tap(find.byKey(const Key('spotlight-option-safe')));
      final commit = find.byKey(const Key('commit-button'));
      await _reveal(tester, commit);
      await tester.tap(commit);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('match-recap')), findsNothing);
      expect(tester.widget<FilledButton>(commit).onPressed, isNull);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      firstSave.completeError(StateError('Injected storage failure'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Could not save this choice'), findsOneWidget);
      expect(tester.widget<FilledButton>(commit).onPressed, isNotNull);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(saved?.revision, 1);
      expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in [
    const Locale('en'),
    const Locale('es'),
    const Locale('pt', 'BR'),
    const Locale('fr'),
  ]) {
    testWidgets(
      'full quick-match and help flow at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        CareerSnapshot? saved;
        await tester.pumpWidget(
          _app(
            GameScreen(
              quickTransitions: true,
              onCareerChanged: (career, _) async {
                saved = career;
              },
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('weekly-continue-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('matchup-loading-overlay')), findsNothing);
        final commit = find.byKey(const Key('commit-button'));
        await _reveal(tester, commit);
        expect(tester.widget<FilledButton>(commit).onPressed, isNull);
        final safe = find.byKey(const Key('spotlight-option-safe'));
        await _reveal(tester, safe);
        await tester.pumpAndSettle();
        await tester.tap(safe);
        await tester.pumpAndSettle();
        await _reveal(tester, commit);
        await tester.pumpAndSettle();
        await tester.tap(commit);
        await tester.pumpAndSettle();
        expect(saved?.revision, 1);
        expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
        expect(tester.takeException(), isNull);
        final next = find.byKey(const Key('recap-continue-button'));
        await _reveal(tester, next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(_app(const HowToPlayScreen(), locale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'localized tournament and season summary fit ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final base = CareerSnapshot.newCareer();
        await tester.pumpWidget(
          _app(
            GameScreen(
              initialCareer: base.copyWith(
                phase: CareerPhase.internationalCallup,
              ),
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _reveal(
          tester,
          find.byKey(const Key('accept-world-nations-callup')),
        );
        expect(
          find.text('ACCEPT CALL-UP'),
          locale.languageCode == 'en' ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(
          _app(
            GameScreen(
              key: const ValueKey('season'),
              initialCareer: base.copyWith(
                phase: CareerPhase.offseason,
                seasonHistory: [
                  SeasonSummary(
                    season: 0,
                    age: 16,
                    clubId: base.clubId,
                    appearances: 4,
                    goals: 2,
                    assists: 1,
                    averageRating: 6.2,
                    trophies: const [],
                  ),
                ],
              ),
            ),
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 15000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}
