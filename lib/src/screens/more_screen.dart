import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../feature_copy.dart';
import '../marketing_links.dart';
import 'leaderboard_screen.dart';
import 'more_detail_screens.dart';
import 'shop_screen.dart';
import 'career_journal_screen.dart';
import 'hall_of_fame_screen.dart';
import 'friends_screen.dart';
import 'weekly_challenge_screen.dart';
import 'support_screen.dart';

final class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.controller,
    this.marketingLinks = const StudioMarketingLinks.fromEnvironment(),
  });

  final AppController controller;
  final StudioMarketingLinks marketingLinks;

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
                _HubDestination(
                  key: const Key('more-journal'),
                  icon: Icons.menu_book_outlined,
                  title: featureCopy(locale, 'history'),
                  body: featureCopy(locale, 'historyBody'),
                  onTap: () => _push(
                    context,
                    CareerJournalScreen(controller: controller),
                  ),
                ),
                _HubDestination(
                  key: const Key('more-hall-of-fame'),
                  icon: Icons.emoji_events_outlined,
                  title: featureCopy(locale, 'hallOfFame'),
                  body: featureCopy(locale, 'hallBody'),
                  onTap: () =>
                      _push(context, HallOfFameScreen(controller: controller)),
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
                      : Icons.person_outline_rounded,
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
                _HubDestination(
                  key: const Key('more-friends'),
                  icon: Icons.people_outline,
                  title: featureCopy(locale, 'friends'),
                  body: featureCopy(locale, 'friendsBody'),
                  onTap: () =>
                      _push(context, FriendsScreen(controller: controller)),
                ),
                _HubDestination(
                  key: const Key('more-weekly-challenge'),
                  icon: Icons.sports_soccer_outlined,
                  title: featureCopy(locale, 'weeklyChallenge'),
                  body: featureCopy(locale, 'challengeBody'),
                  onTap: () => _push(
                    context,
                    WeeklyChallengeScreen(controller: controller),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionLabel(uiCopy(locale, 'appSection')),
                if (marketingLinks.studioDiscoveryUrl != null)
                  _HubDestination(
                    key: const Key('more-studio-games'),
                    icon: Icons.explore_outlined,
                    title: uiCopy(locale, 'studioGames'),
                    body: uiCopy(locale, 'studioGamesBody'),
                    onTap: () => _openStudio(context),
                  ),
                _HubDestination(
                  key: const Key('more-settings'),
                  icon: Icons.tune_rounded,
                  title: context.l10n.settings,
                  body: uiCopy(locale, 'settingsBody'),
                  onTap: () =>
                      _push(context, SettingsScreen(controller: controller)),
                ),
                _HubDestination(
                  key: const Key('more-support'),
                  icon: Icons.support_agent_outlined,
                  title: featureCopy(locale, 'support'),
                  body: featureCopy(locale, 'support'),
                  onTap: () =>
                      _push(context, SupportScreen(controller: controller)),
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

  Future<void> _openStudio(BuildContext context) async {
    final uri = marketingLinks.studioDiscoveryUrl;
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object {
      // Website discovery must not interfere with a player's local career.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(uiCopy(contentLocale(context), 'websiteOpenFailed')),
      ),
    );
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
      style: TextStyle(
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
    this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: ElevenwardColors.line),
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
                  Icon(icon, color: accent ?? ElevenwardColors.grass, size: 28),
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
