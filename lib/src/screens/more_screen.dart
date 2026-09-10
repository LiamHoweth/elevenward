import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';
import 'leaderboard_screen.dart';
import 'more_detail_screens.dart';
import 'shop_screen.dart';

final class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final locale = contentLocale(context);
      return CustomScrollView(
        key: const Key('more-hub'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            sliver: SliverList.list(
              children: [
                _SectionLabel(uiCopy(locale, 'careerSection')),
                _HubDestination(
                  key: const Key('more-player'),
                  icon: Icons.person_outline_rounded,
                  title: uiCopy(locale, 'player'),
                  body: uiCopy(locale, 'playerBody'),
                  onTap: () =>
                      _push(context, PlayerScreen(controller: controller)),
                ),
                _HubDestination(
                  key: const Key('more-legacy'),
                  icon: Icons.workspace_premium_outlined,
                  title: uiCopy(locale, 'legacy'),
                  body: uiCopy(locale, 'legacyBody'),
                  accent: ElevenwardColors.amber,
                  onTap: () =>
                      _push(context, LegacyScreen(controller: controller)),
                ),
                const SizedBox(height: 12),
                _SectionLabel(uiCopy(locale, 'personalizationSection')),
                _HubDestination(
                  key: const Key('more-appearance'),
                  icon: Icons.palette_outlined,
                  title: uiCopy(locale, 'appearance'),
                  body: uiCopy(locale, 'appearanceBody'),
                  onTap: () =>
                      _push(context, AppearanceScreen(controller: controller)),
                ),
                const SizedBox(height: 12),
                _SectionLabel(uiCopy(locale, 'onlineSection')),
                _HubDestination(
                  key: const Key('more-account'),
                  icon: controller.account == null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  title: uiCopy(locale, 'account'),
                  body: uiCopy(locale, 'accountBody'),
                  onTap: () =>
                      _push(context, AccountScreen(controller: controller)),
                ),
                _HubDestination(
                  key: const Key('more-shop'),
                  icon: Icons.shopping_bag_outlined,
                  title: uiCopy(locale, 'shop'),
                  body: uiCopy(locale, 'shopIntro'),
                  accent: ElevenwardColors.amber,
                  onTap: () =>
                      _push(context, ShopScreen(controller: controller)),
                ),
                _HubDestination(
                  key: const Key('more-leaderboards'),
                  icon: Icons.leaderboard_outlined,
                  title: uiCopy(locale, 'leaderboards'),
                  body: uiCopy(locale, 'leaderboardNoPrizes'),
                  onTap: () =>
                      _push(context, LeaderboardScreen(controller: controller)),
                ),
                const SizedBox(height: 12),
                _SectionLabel(uiCopy(locale, 'appSection')),
                _HubDestination(
                  key: const Key('more-settings'),
                  icon: Icons.tune_rounded,
                  title: context.l10n.settings,
                  body: uiCopy(locale, 'settingsBody'),
                  onTap: () =>
                      _push(context, SettingsScreen(controller: controller)),
                ),
                _HubDestination(
                  key: const Key('more-switch-career'),
                  icon: Icons.swap_horiz_rounded,
                  title: uiCopy(locale, 'careerSwitching'),
                  body: context.l10n.careerSlotsIntro,
                  onTap: controller.showCareerSlots,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
  }
}

final class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 4, bottom: 9),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: ElevenwardColors.grass,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .9,
      ),
    ),
  );
}

final class _HubDestination extends StatelessWidget {
  const _HubDestination({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.accent = ElevenwardColors.grass,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ElevenwardColors.line),
        borderRadius: BorderRadius.circular(ElevenwardRadii.card),
      ),
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ElevenwardRadii.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(body),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
