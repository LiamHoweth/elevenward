import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game_screen.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../widgets/compact_player_hud.dart';
import 'life_screen.dart';
import 'more_screen.dart';
import 'world_screen.dart';

final class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final career = widget.controller.activeCareer!;
    final generation = widget.controller.activeCareerGeneration;
    final screens = [
      GameScreen(
        key: ValueKey(career.careerId),
        initialCareer: career,
        activeCareerGeneration: generation,
        initialFocus: widget.controller.activeWeeklyFocus,
        avatarId: widget.controller.avatarId,
        shareCardStyleId: widget.controller.shareCardStyleId,
        rewardModifiers: widget.controller.entitlementState.rewardModifiers,
        quickTransitions: widget.controller.quickTransitions,
        showCoachingTips: widget.controller.showCoachingTips,
        showCareerTarget: widget.controller.showCareerTarget,
        dismissedCoachTips: widget.controller.dismissedCoachTips,
        onDismissCoachTip: widget.controller.dismissCoachTip,
        trainingPreset: widget.controller.trainingPreset,
        onSaveTrainingPreset: widget.controller.saveTrainingPreset,
        onClearTrainingPreset: widget.controller.clearTrainingPreset,
        contentCatalog: widget.controller.activeContent?.catalog,
        onFocusPreferenceChanged: widget.controller.changeWeeklyFocus,
        onCareerChanged: (snapshot, eventType) => widget.controller.saveCareer(
          snapshot,
          eventType: eventType,
          expectedGeneration: generation,
          expectedCareerId: career.careerId,
          expectedRevision: career.revision,
        ),
        onReviewOpportunity: (snapshot, isEligible) => widget.controller
            .requestReviewAfterSeason(snapshot, isEligible: isEligible),
        reviewPromptVisible: _index == 0,
      ),
      WorldScreen(
        career: career,
        controller: widget.controller,
        definition: widget.controller.activeContent?.catalog.world,
      ),
      LifeScreen(
        controller: widget.controller,
        contentCatalog: widget.controller.activeContent?.catalog,
      ),
      MoreScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CompactPlayerHud(
              career: career,
              avatarId: widget.controller.avatarId,
            ),
            Expanded(
              child: IndexedStack(index: _index, children: screens),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: ElevenwardColors.deep,
        indicatorColor: ElevenwardColors.grassDark,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.sports_soccer_outlined),
            selectedIcon: const Icon(Icons.sports_soccer),
            label: context.l10n.career,
          ),
          NavigationDestination(
            icon: const Icon(Icons.public_outlined),
            selectedIcon: const Icon(Icons.public),
            label: context.l10n.world,
          ),
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: context.l10n.life,
          ),
          NavigationDestination(
            icon: const Icon(Icons.more_horiz_rounded),
            label: context.l10n.more,
          ),
        ],
      ),
    );
  }
}
