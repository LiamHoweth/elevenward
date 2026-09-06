import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../game_screen.dart';
import '../l10n_context.dart';
import '../theme.dart';
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
    final screens = [
      GameScreen(
        key: ValueKey(career.careerId),
        initialCareer: career,
        avatarId: widget.controller.avatarId,
        contentCatalog: widget.controller.activeContent?.catalog,
        onCareerChanged: (snapshot, eventType) =>
            widget.controller.saveCareer(snapshot, eventType: eventType),
      ),
      WorldScreen(career: career),
      LifeScreen(
        controller: widget.controller,
        contentCatalog: widget.controller.activeContent?.catalog,
      ),
      MoreScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
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
