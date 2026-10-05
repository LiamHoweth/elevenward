import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final interruption in ['none', 'tab', 'route', 'background']) {
    testWidgets('season review respects $interruption interruption', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      var requests = 0;
      CareerSnapshot? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildElevenwardTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, isVisible, child) => GameScreen(
              initialCareer: _internationalInvitation(),
              quickTransitions: true,
              reviewPromptVisible: isVisible,
              onCareerChanged: (career, _) async => saved = career,
              onReviewOpportunity: (_, isEligible) async {
                if (isEligible()) requests++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('decline-world-nations-callup')));
      await tester.pumpAndSettle();
      expect(saved?.phase, CareerPhase.offseason);
      expect(requests, 0);
      if (interruption == 'tab') {
        visible.value = false;
      } else if (interruption == 'route') {
        Navigator.of(tester.element(find.byType(GameScreen))).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Other activity')),
          ),
        );
      } else if (interruption == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(requests, interruption == 'none' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }
}

CareerSnapshot _internationalInvitation() {
  final catalog = buildLatestContent();
  final world = catalog.world;
  var state = CareerWorldState.initial(world);
  const simulator = WorldSimulator();
  while (state.season < 4) {
    state = simulator.beginNextSeason(state, 4404, definition: world);
  }
  final player =
      PlayerState.newCareer(
        id: 'review-flow-player',
        name: 'Review Player',
        archetype: Archetype.poacher,
        nationalTeamId: state.nationalQualification!.qualifiedTeamIds.first,
      ).copyWith(
        attributes: PlayerAttributes({
          for (final attribute in PlayerAttribute.values) attribute: 90,
        }),
        reputation: 90,
      );
  return CareerSnapshot.newCareer(
    careerId: 'review-flow-career',
    seed: 4404,
    contentVersion: catalog.version,
    worldDefinition: world,
    player: player,
  ).copyWith(
    season: 4,
    week: 18,
    phase: CareerPhase.internationalCallup,
    world: state,
  );
}
