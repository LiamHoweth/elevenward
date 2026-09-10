import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../league_presentation.dart';
import '../storage/career_store.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/identity_badge.dart';
import '../widgets/share_career_card.dart';
import '../widgets/transfer_request_sheet.dart';
import 'shop_screen.dart';

final class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final career = controller.activeCareer!;
      final world =
          controller.activeContent?.catalog.world ?? buildLaunchWorld();
      final locale = contentLocale(context);
      final leagueId = career.world.leagueIdForClub(career.clubId);
      final league = world.leagues.firstWhere((item) => item.id == leagueId);
      final nationalTeam = world.nationalTeam(career.player.nationalTeamId);
      final country = world.country(nationalTeam.countryId);
      return _DetailPage(
        pageKey: const Key('more-player-screen'),
        title: uiCopy(locale, 'player'),
        children: [
          BroadcastPanel(
            accent: ElevenwardColors.grass,
            child: Row(
              children: [
                PlayerIdentityBadge(
                  playerName: career.player.name,
                  avatarId: controller.avatarId,
                  size: 70,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        career.player.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${localizedPosition(locale, career.player.position.name)} · ${localizedArchetype(locale, career.player.archetype)}',
                      ),
                    ],
                  ),
                ),
                _OverallBadge(value: career.player.overall),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'playerProfile')),
          _Card(
            children: [
              _ValueRow(
                label: uiCopy(locale, 'age'),
                value: '${career.player.age}',
              ),
              _ValueRow(
                label: uiCopy(locale, 'nationality'),
                value: country.nameFor(locale),
              ),
              _ValueRow(
                label: uiCopy(locale, 'currentClub'),
                value: career.clubName,
              ),
              _ValueRow(
                label: uiCopy(locale, 'currentLeague'),
                value: leagueDisplayName(league),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'attributes')),
          _AttributeGrid(career: career),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'playerStatistics')),
          _MetricGrid(
            metrics: [
              (uiCopy(locale, 'form'), '${career.player.form}'),
              (uiCopy(locale, 'fitness'), '${career.player.fitness}'),
              (uiCopy(locale, 'reputationLong'), '${career.player.reputation}'),
              (uiCopy(locale, 'managerTrust'), '${career.player.managerTrust}'),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'currentSeason')),
          _MetricGrid(
            metrics: [
              (
                uiCopy(locale, 'apps'),
                '${career.seasonPerformance.appearances}',
              ),
              (uiCopy(locale, 'goals'), '${career.seasonPerformance.goals}'),
              (
                uiCopy(locale, 'assists'),
                '${career.seasonPerformance.assists}',
              ),
              (
                uiCopy(locale, 'rating'),
                career.seasonPerformance.averageRating.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'careerRecord')),
          _MetricGrid(
            metrics: [
              (uiCopy(locale, 'apps'), '${career.player.appearances}'),
              (uiCopy(locale, 'goals'), '${career.player.goals}'),
              (uiCopy(locale, 'assists'), '${career.player.assists}'),
              (uiCopy(locale, 'caps'), '${career.nationalTeam.caps}'),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'contract')),
          _Card(
            children: [
              _ValueRow(
                label: uiCopy(locale, 'currentClub'),
                value: career.clubName,
              ),
              _ValueRow(
                label: uiCopy(locale, 'seasons'),
                value: '${career.contract.seasonsRemaining}',
              ),
              _ValueRow(
                label: uiCopy(locale, 'weeklyWage'),
                value: '£${career.contract.weeklyWage}',
              ),
              _ValueRow(
                label: uiCopy(locale, 'appearanceBonus'),
                value: '£${career.contract.appearanceBonus}',
              ),
              _ValueRow(
                label: uiCopy(locale, 'promisedRole'),
                value: localizedPromisedRole(
                  locale,
                  career.contract.promisedRole,
                ),
              ),
              _ValueRow(
                label: uiCopy(locale, 'roleSatisfaction'),
                value: '${career.contract.roleSatisfaction}/100',
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'careerMoves')),
          _TransferRequestCard(controller: controller, world: world),
        ],
      );
    },
  );
}

final class _TransferRequestCard extends StatelessWidget {
  const _TransferRequestCard({required this.controller, required this.world});

  final AppController controller;
  final WorldDefinition world;

  @override
  Widget build(BuildContext context) {
    final career = controller.activeCareer!;
    final locale = contentLocale(context);
    final request = career.transferRequest;
    LeagueDefinition? targetLeague;
    ClubDefinition? preferredClub;
    if (request != null) {
      targetLeague = world.leagues
          .where((league) => league.id == request.targetLeagueId)
          .firstOrNull;
      preferredClub = world.clubs
          .where((club) => club.id == request.preferredClubId)
          .firstOrNull;
    }
    return BroadcastPanel(
      accent: request == null ? null : ElevenwardColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                request == null
                    ? Icons.swap_horiz_rounded
                    : Icons.outbound_outlined,
                color: request == null
                    ? ElevenwardColors.grass
                    : ElevenwardColors.amber,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request == null
                          ? uiCopy(locale, 'requestTransfer')
                          : uiCopy(locale, 'transferRequestActive'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      request == null
                          ? uiCopy(locale, 'transferRequestBody')
                          : '${uiCopy(locale, 'targetLeague')}: ${targetLeague == null ? request.targetLeagueId : leagueDisplayName(targetLeague)}\n'
                                '${uiCopy(locale, 'preferredClub')}: ${preferredClub?.name ?? uiCopy(locale, 'anyEligibleClub')}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!career.retired) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('player-transfer-request'),
              onPressed: () => _edit(context, career),
              icon: const Icon(Icons.manage_search_rounded),
              label: Text(
                request == null
                    ? uiCopy(locale, 'requestTransfer').toUpperCase()
                    : uiCopy(locale, 'editTransferRequest').toUpperCase(),
              ),
            ),
            if (request != null)
              TextButton(
                key: const Key('player-transfer-cancel'),
                onPressed: () => _cancel(context),
                child: Text(uiCopy(locale, 'cancelTransferRequest')),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, CareerSnapshot career) async {
    final draft = await showTransferRequestFlow(
      context: context,
      career: career,
      world: world,
    );
    if (draft == null) return;
    await controller.fileTransferRequest(
      targetLeagueId: draft.targetLeagueId,
      preferredClubId: draft.preferredClubId,
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final locale = contentLocale(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiCopy(locale, 'cancelTransferTitle')),
        content: Text(uiCopy(locale, 'cancelTransferBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(uiCopy(locale, 'cancelTransferRequest')),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.cancelTransferRequest();
  }
}

final class LegacyScreen extends StatelessWidget {
  const LegacyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final career = controller.activeCareer!;
      final world =
          controller.activeContent?.catalog.world ?? buildLaunchWorld();
      final locale = contentLocale(context);
      final verdict = calculateLegacyVerdict(career);
      final trophies = career.seasonHistory.fold<int>(
        0,
        (sum, season) => sum + season.trophies.length,
      );
      return _DetailPage(
        pageKey: const Key('more-legacy-screen'),
        title: uiCopy(locale, 'legacy'),
        children: [
          BroadcastPanel(
            accent: ElevenwardColors.amber,
            child: Column(
              children: [
                Text(
                  uiCopy(
                    locale,
                    career.retired ? 'finalLegacy' : 'legacyProjection',
                  ).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ElevenwardColors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .9,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${verdict.score}',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  localizedLegacyTier(locale, verdict.tier),
                  style: const TextStyle(
                    color: ElevenwardColors.grass,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  localizedLegacyHeadline(locale, verdict.tier),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'careerRecord')),
          _MetricGrid(
            metrics: [
              (uiCopy(locale, 'apps'), '${career.player.appearances}'),
              (uiCopy(locale, 'goals'), '${career.player.goals}'),
              (uiCopy(locale, 'assists'), '${career.player.assists}'),
              (uiCopy(locale, 'trophies'), '$trophies'),
              (uiCopy(locale, 'seasons'), '${career.seasonHistory.length}'),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'nationalRecord')),
          _MetricGrid(
            metrics: [
              (uiCopy(locale, 'caps'), '${career.nationalTeam.caps}'),
              (uiCopy(locale, 'goals'), '${career.nationalTeam.goals}'),
              (uiCopy(locale, 'assists'), '${career.nationalTeam.assists}'),
            ],
          ),
          const SizedBox(height: 22),
          _Section(context.l10n.legacy),
          _CareerHonours(career: career),
          const SizedBox(height: 10),
          _SeasonArchive(
            career: career,
            layoutId: controller.archiveLayoutId,
            definition: world,
          ),
          const SizedBox(height: 22),
          _Section(context.l10n.shareCareer),
          ShareCareerCard(
            career: career,
            styleId: controller.shareCardStyleId,
            avatarId: controller.avatarId,
          ),
        ],
      );
    },
  );
}

final class _AttributeGrid extends StatelessWidget {
  const _AttributeGrid({required this.career});

  final CareerSnapshot career;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PlayerAttribute.values
              .map(
                (attribute) => SizedBox(
                  width: width,
                  child: _MetricTile(
                    label: localizedPlayerAttribute(locale, attribute),
                    value: '${career.player.attributes[attribute]}',
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

final class _OverallBadge extends StatelessWidget {
  const _OverallBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 54,
    height: 54,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: ElevenwardColors.grassDark,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$value',
      style: const TextStyle(
        color: ElevenwardColors.grass,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

final class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<(String, String)> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: metrics
            .map(
              (metric) => SizedBox(
                width: width,
                child: _MetricTile(label: metric.$1, value: metric.$2),
              ),
            )
            .toList(growable: false),
      );
    },
  );
}

final class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 78),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      border: Border.all(color: ElevenwardColors.line),
      borderRadius: BorderRadius.circular(ElevenwardRadii.control),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: ElevenwardColors.cream,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(label),
      ],
    ),
  );
}

final class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key, required this.controller});

  final AppController controller;

  static const _themeOptions = [
    (id: 'pitch', label: 'cosmeticPitch'),
    (id: 'ocean', label: 'cosmeticOcean'),
    (id: 'violet', label: 'cosmeticViolet'),
    (id: 'sunset', label: 'cosmeticSunset'),
  ];
  static const _avatarOptions = [
    (id: 'initials', label: 'cosmeticInitials'),
    (id: 'captain', label: 'cosmeticCaptain'),
    (id: 'creator', label: 'cosmeticCreator'),
    (id: 'finisher', label: 'cosmeticFinisher'),
  ];
  static const _archiveOptions = [
    (id: 'timeline', label: 'cosmeticTimeline'),
    (id: 'compact', label: 'cosmeticCompact'),
    (id: 'honors', label: 'cosmeticHonors'),
  ];
  static const _shareOptions = [
    (id: 'classic', label: 'cosmeticClassic'),
    (id: 'stadium', label: 'cosmeticStadium'),
    (id: 'editorial', label: 'cosmeticEditorial'),
    (id: 'midnight', label: 'cosmeticMidnight'),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final locale = contentLocale(context);
      final career = controller.activeCareer!;
      return _DetailPage(
        pageKey: const Key('more-appearance-screen'),
        title: uiCopy(locale, 'appearance'),
        children: [
          _Section(uiCopy(locale, 'appearancePreview')),
          BroadcastPanel(
            accent: elevenwardCosmeticColor(controller.themeId),
            child: Row(
              children: [
                PlayerIdentityBadge(
                  playerName: career.player.name,
                  avatarId: controller.avatarId,
                  size: 64,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        career.player.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_cosmeticLabel(locale, controller.themeId)} · ${_cosmeticLabel(locale, controller.avatarId)}',
                      ),
                      Text(
                        '${_cosmeticLabel(locale, controller.archiveLayoutId)} · ${_cosmeticLabel(locale, controller.shareCardStyleId)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _CosmeticSection(
            title: uiCopy(locale, 'theme'),
            kind: 'theme',
            selected: controller.themeId,
            options: _themeOptions,
            controller: controller,
          ),
          const SizedBox(height: 22),
          _CosmeticSection(
            title: uiCopy(locale, 'avatar'),
            kind: 'avatar',
            selected: controller.avatarId,
            options: _avatarOptions,
            controller: controller,
          ),
          const SizedBox(height: 22),
          _CosmeticSection(
            title: uiCopy(locale, 'archive'),
            kind: 'archiveLayout',
            selected: controller.archiveLayoutId,
            options: _archiveOptions,
            controller: controller,
          ),
          const SizedBox(height: 22),
          _CosmeticSection(
            title: uiCopy(locale, 'shareCard'),
            kind: 'shareCard',
            selected: controller.shareCardStyleId,
            options: _shareOptions,
            controller: controller,
          ),
          if (controller.lastMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              controller.lastMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ElevenwardColors.amber),
            ),
          ],
        ],
      );
    },
  );
}

final class _CosmeticSection extends StatelessWidget {
  const _CosmeticSection({
    required this.title,
    required this.kind,
    required this.selected,
    required this.options,
    required this.controller,
  });

  final String title;
  final String kind;
  final String selected;
  final List<({String id, String label})> options;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final unlocked = controller.entitlementState.premiumCosmetics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(title),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.indexed
                  .map((entry) {
                    final option = entry.$2;
                    final available = entry.$1 == 0 || unlocked;
                    final isSelected = selected == option.id;
                    return SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        selected: isSelected,
                        label:
                            '${uiCopy(locale, option.label)}, ${available ? uiCopy(locale, 'included') : 'VIP'}',
                        child: Material(
                          color: isSelected
                              ? ElevenwardColors.grassDark
                              : ElevenwardColors.panel,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? ElevenwardColors.grass
                                  : ElevenwardColors.line,
                            ),
                            borderRadius: BorderRadius.circular(
                              ElevenwardRadii.control,
                            ),
                          ),
                          child: InkWell(
                            key: Key('cosmetic-$kind-${option.id}'),
                            onTap: available
                                ? () => controller.setCosmeticPreference(
                                    kind,
                                    option.id,
                                  )
                                : () => _showLocked(context),
                            borderRadius: BorderRadius.circular(
                              ElevenwardRadii.control,
                            ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 88),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        _cosmeticIcon(kind, option.id),
                                        const Spacer(),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : available
                                              ? Icons.circle_outlined
                                              : Icons.lock_outline_rounded,
                                          color: isSelected
                                              ? ElevenwardColors.grass
                                              : ElevenwardColors.muted,
                                          size: 19,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      uiCopy(locale, option.label),
                                      style: const TextStyle(
                                        color: ElevenwardColors.cream,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      available
                                          ? uiCopy(locale, 'included')
                                          : 'VIP',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showLocked(BuildContext context) async {
    final locale = contentLocale(context);
    final openShop = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                uiCopy(locale, 'premiumCosmeticRequired'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(uiCopy(locale, 'lockedCosmeticBody')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(uiCopy(locale, 'viewShop').toUpperCase()),
              ),
            ],
          ),
        ),
      ),
    );
    if (openShop == true && context.mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ShopScreen(controller: controller)),
      );
    }
  }
}

Widget _cosmeticIcon(String kind, String value) {
  if (kind == 'avatar') {
    return Icon(
      elevenwardAvatarIcon(value),
      color: elevenwardCosmeticColor(value),
      size: 24,
    );
  }
  if (kind == 'archiveLayout') {
    return Icon(
      value == 'honors'
          ? Icons.emoji_events_outlined
          : value == 'compact'
          ? Icons.view_agenda_outlined
          : Icons.timeline_rounded,
      color: ElevenwardColors.grass,
      size: 24,
    );
  }
  if (kind == 'shareCard') {
    return Icon(
      value == 'editorial'
          ? Icons.article_outlined
          : value == 'stadium'
          ? Icons.stadium_outlined
          : value == 'midnight'
          ? Icons.nightlight_outlined
          : Icons.badge_outlined,
      color: elevenwardCosmeticColor(value),
      size: 24,
    );
  }
  return CircleAvatar(
    radius: 12,
    backgroundColor: elevenwardCosmeticColor(value),
  );
}

String _cosmeticLabel(String locale, String value) =>
    uiCopy(locale, switch (value) {
      'pitch' => 'cosmeticPitch',
      'ocean' => 'cosmeticOcean',
      'violet' => 'cosmeticViolet',
      'sunset' => 'cosmeticSunset',
      'initials' => 'cosmeticInitials',
      'captain' => 'cosmeticCaptain',
      'creator' => 'cosmeticCreator',
      'finisher' => 'cosmeticFinisher',
      'timeline' => 'cosmeticTimeline',
      'compact' => 'cosmeticCompact',
      'honors' => 'cosmeticHonors',
      'classic' => 'cosmeticClassic',
      'stadium' => 'cosmeticStadium',
      'editorial' => 'cosmeticEditorial',
      'midnight' => 'cosmeticMidnight',
      _ => value,
    });

final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final locale = contentLocale(context);
      final currentLanguage = switch (controller.locale?.languageCode) {
        'en' => 'English',
        'es' => 'Español',
        'pt' => 'Português (Brasil)',
        'fr' => 'Français',
        _ => uiCopy(locale, 'system'),
      };
      return _DetailPage(
        pageKey: const Key('more-settings-screen'),
        title: context.l10n.settings,
        children: [
          _Section(context.l10n.settings),
          _Card(
            children: [
              ListTile(
                key: const Key('settings-language'),
                leading: const Icon(Icons.language_rounded),
                title: Text(context.l10n.language),
                subtitle: Text(currentLanguage),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _chooseLanguage(context),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'privacy')),
          _Card(
            children: [
              SwitchListTile.adaptive(
                key: const Key('settings-analytics'),
                secondary: const Icon(Icons.query_stats_rounded),
                title: Text(context.l10n.analyticsConsent),
                subtitle: Text(context.l10n.analyticsBody),
                value: controller.analyticsGranted,
                onChanged: controller.changeAnalyticsConsent,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'localData')),
          BroadcastPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.offline_bolt_outlined,
                  color: ElevenwardColors.grass,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(uiCopy(locale, 'localDataBody'))),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _Section(uiCopy(locale, 'versionDetails')),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) => _Card(
              children: [
                _ValueRow(
                  label: uiCopy(locale, 'appVersion'),
                  value: snapshot.hasData
                      ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                      : '—',
                ),
                _ValueRow(
                  label: uiCopy(locale, 'contentVersionLabel'),
                  value:
                      controller.activeContent?.version ??
                      controller.activeCareer!.contentVersion,
                ),
                _ValueRow(
                  label: uiCopy(locale, 'rulesVersionLabel'),
                  value: controller.activeCareer!.rulesVersion,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Future<void> _chooseLanguage(BuildContext context) async {
    final locale = contentLocale(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final current = controller.locale?.languageCode ?? 'system';
        final options = <(String, String)>[
          ('system', uiCopy(locale, 'system')),
          ('en', 'English'),
          ('es', 'Español'),
          ('pt', 'Português (Brasil)'),
          ('fr', 'Français'),
        ];
        return SafeArea(
          child: RadioGroup<String>(
            groupValue: current,
            onChanged: (value) => Navigator.pop(context, value),
            child: ListView(
              shrinkWrap: true,
              children: options
                  .map(
                    (option) => RadioListTile<String>(
                      value: option.$1,
                      title: Text(option.$2),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    await controller.changeLocale(
      selected == 'system' ? null : Locale(selected),
    );
  }
}

final class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

final class _AccountScreenState extends State<AccountScreen> {
  late Future<List<PreservedConflict>> _conflicts;

  @override
  void initState() {
    super.initState();
    _conflicts = widget.controller.store.listConflicts();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final locale = contentLocale(context);
      return _DetailPage(
        pageKey: const Key('more-account-screen'),
        title: uiCopy(locale, 'account'),
        children: [
          BroadcastPanel(
            accent: controller.account == null
                ? ElevenwardColors.sky
                : ElevenwardColors.grass,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  controller.account == null
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  color: controller.account == null
                      ? ElevenwardColors.sky
                      : ElevenwardColors.grass,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.account == null
                            ? context.l10n.guestMode
                            : context.l10n.signedInAs(
                                controller.account!.alias,
                              ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(uiCopy(locale, 'localDataBody')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (controller.account == null) ...[
            const SizedBox(height: 22),
            _Section(uiCopy(locale, 'account')),
            _Card(
              children: [
                if (Platform.isIOS)
                  ListTile(
                    key: const Key('account-sign-in-apple'),
                    leading: const Icon(Icons.apple),
                    title: Text(context.l10n.signInApple),
                    enabled: !controller.busy,
                    onTap: controller.signInApple,
                  ),
                ListTile(
                  key: const Key('account-sign-in-google'),
                  leading: const Icon(Icons.g_mobiledata_rounded),
                  title: Text(context.l10n.signInGoogle),
                  enabled: !controller.busy,
                  onTap: controller.signInGoogle,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 22),
            _Section(uiCopy(locale, 'cloudSync')),
            _Card(
              children: [
                ListTile(
                  key: const Key('account-sync'),
                  leading: controller.syncStatus == SyncUiStatus.running
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          controller.syncStatus == SyncUiStatus.failed
                              ? Icons.sync_problem_rounded
                              : Icons.sync_rounded,
                        ),
                  title: Text(
                    controller.syncStatus == SyncUiStatus.failed
                        ? uiCopy(locale, 'retrySync')
                        : context.l10n.syncNow,
                  ),
                  subtitle: switch (_syncSubtitle(controller, locale)) {
                    final value? => Text(value),
                    null => null,
                  },
                  enabled: !controller.busy,
                  onTap: controller.synchronize,
                ),
              ],
            ),
            FutureBuilder<List<PreservedConflict>>(
              future: _conflicts,
              builder: (context, snapshot) {
                final conflicts = snapshot.data ?? const [];
                if (conflicts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Section(uiCopy(locale, 'cloudConflicts')),
                      ...conflicts.map(
                        (conflict) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ConflictCard(
                            conflict: conflict,
                            busy: controller.busy,
                            onResolve: (keepLocal) =>
                                _resolve(conflict, keepLocal),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            _Section(uiCopy(locale, 'dataControls')),
            _Card(
              children: [
                ListTile(
                  leading: const Icon(Icons.password_rounded),
                  title: Text(uiCopy(locale, 'webDeletionCode')),
                  subtitle: Text(uiCopy(locale, 'webDeletionBody')),
                  enabled: !controller.busy,
                  onTap: () => _showDeletionCode(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(context.l10n.signOut),
                  enabled: !controller.busy,
                  onTap: controller.signOut,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: ElevenwardColors.coral,
                  ),
                  title: Text(
                    context.l10n.deleteAccount,
                    style: const TextStyle(color: ElevenwardColors.coral),
                  ),
                  enabled: !controller.busy,
                  onTap: () => _confirmAccountDeletion(context),
                ),
              ],
            ),
          ],
          if (controller.lastMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              controller.lastMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ElevenwardColors.amber),
            ),
          ],
        ],
      );
    },
  );

  String? _syncSubtitle(AppController controller, String locale) {
    final progress = controller.syncProgress;
    if (controller.syncStatus == SyncUiStatus.running) {
      if (progress == null || progress.total == 0) {
        return uiCopy(locale, 'syncPreparing');
      }
      return '${uiCopy(locale, 'syncProgress')} ${progress.completed}/${progress.total}';
    }
    final report = controller.lastSyncReport;
    if (controller.syncStatus == SyncUiStatus.complete && report != null) {
      return '${report.uploaded} ↑ · ${report.downloaded} ↓ · ${report.conflicts} ${uiCopy(locale, 'conflicts')}';
    }
    if (controller.syncStatus == SyncUiStatus.failed) {
      return uiCopy(locale, 'syncFailedSafe');
    }
    return null;
  }

  Future<void> _resolve(PreservedConflict conflict, bool keepLocal) async {
    await widget.controller.resolveConflict(conflict, keepLocal: keepLocal);
    if (!mounted) return;
    setState(() {
      _conflicts = widget.controller.store.listConflicts();
    });
  }

  Future<void> _confirmAccountDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteAccount),
        content: Text(context.l10n.deleteAccountWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.deleteAccount.toUpperCase()),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.deleteAccount();
  }

  Future<void> _showDeletionCode(BuildContext context) async {
    final challenge = await widget.controller.requestDeletionChallenge();
    if (!context.mounted || challenge == null) return;
    final code = challenge['deletionCode'] as String;
    final accountId = challenge['accountId'] as String;
    final expiresAt = DateTime.parse(challenge['expiresAt'] as String)
        .toLocal();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiCopy(contentLocale(context), 'webDeletionCode')),
        content: SelectableText(
          '${uiCopy(contentLocale(context), 'accountId')}\n$accountId\n\n'
          '${uiCopy(contentLocale(context), 'code')}\n$code\n\n'
          '${uiCopy(contentLocale(context), 'expires')} $expiresAt',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }
}

final class _DetailPage extends StatelessWidget {
  const _DetailPage({
    required this.pageKey,
    required this.title,
    required this.children,
  });

  final Key pageKey;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      key: pageKey,
      slivers: [
        SliverAppBar(pinned: true, title: Text(title)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          sliver: SliverList.list(children: children),
        ),
      ],
    ),
  );
}

final class _Section extends StatelessWidget {
  const _Section(this.title);

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

final class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divided = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) divided.add(const Divider(height: 1));
      divided.add(children[index]);
    }
    return Material(
      color: ElevenwardColors.panel,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: ElevenwardColors.line),
        borderRadius: BorderRadius.circular(ElevenwardRadii.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: divided),
    );
  }
}

final class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: ElevenwardColors.cream,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

final class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.busy,
    required this.onResolve,
  });

  final PreservedConflict conflict;
  final bool busy;
  final ValueChanged<bool> onResolve;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return BroadcastPanel(
      accent: ElevenwardColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${uiCopy(locale, 'slot')} ${conflict.slotIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            conflict.localDeleted
                ? '${uiCopy(locale, 'local')}: ${uiCopy(locale, 'deleted')}'
                : '${uiCopy(locale, 'local')}: ${conflict.localSnapshot.clubName} · ${uiCopy(locale, 'season')} ${conflict.localSnapshot.season} · ${uiCopy(locale, 'week')} ${conflict.localSnapshot.week}',
          ),
          Text(
            '${uiCopy(locale, 'cloud')}: ${conflict.remoteSnapshot.clubName} · ${uiCopy(locale, 'season')} ${conflict.remoteSnapshot.season} · ${uiCopy(locale, 'week')} ${conflict.remoteSnapshot.week}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => onResolve(false),
                  child: Text(uiCopy(locale, 'keepCloud')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : () => onResolve(true),
                  child: Text(uiCopy(locale, 'keepLocal')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _CareerHonours extends StatelessWidget {
  const _CareerHonours({required this.career});

  final CareerSnapshot career;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final honours = [
      for (final season in career.seasonHistory)
        for (final trophy in season.trophies)
          (trophy: trophy, season: season.season),
    ];
    return _Card(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: ElevenwardColors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      uiCopy(locale, 'careerHonours'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${honours.length}',
                    style: const TextStyle(
                      color: ElevenwardColors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (honours.isEmpty)
                Text(
                  uiCopy(locale, 'noHonoursYet'),
                  style: const TextStyle(color: ElevenwardColors.muted),
                )
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: honours
                      .map(
                        (honour) => Chip(
                          avatar: const Icon(
                            Icons.workspace_premium_outlined,
                            size: 16,
                          ),
                          label: Text(
                            '${honour.trophy} · ${uiCopy(locale, 'seasonLabel')} ${honour.season}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _SeasonArchive extends StatelessWidget {
  const _SeasonArchive({
    required this.career,
    required this.layoutId,
    required this.definition,
  });

  final CareerSnapshot career;
  final String layoutId;
  final WorldDefinition definition;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    if (career.seasonHistory.isEmpty) {
      return _Card(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(uiCopy(locale, 'completedSeasons')),
          ),
        ],
      );
    }
    final seasons = layoutId == 'honors'
        ? career.seasonHistory.where((season) => season.trophies.isNotEmpty)
        : career.seasonHistory;
    if (seasons.isEmpty) {
      return _Card(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(uiCopy(locale, 'noHonoursYet')),
          ),
        ],
      );
    }
    final clubNames = {for (final club in definition.clubs) club.id: club.name};
    return _Card(
      children: seasons
          .map(
            (season) => ListTile(
              dense: layoutId == 'compact',
              leading: CircleAvatar(child: Text('${season.season}')),
              title: Text(
                '${uiCopy(locale, 'seasonLabel')} ${season.season} · ${clubNames[season.clubId] ?? season.clubId}',
              ),
              subtitle: Text(
                '${season.appearances} ${uiCopy(locale, 'apps')} · ${season.goals} ${uiCopy(locale, 'goals')} · '
                '${season.assists} ${uiCopy(locale, 'assists')} · ${season.averageRating.toStringAsFixed(1)} ${uiCopy(locale, 'rating')}'
                '${season.trophies.isEmpty ? '' : '\n${season.trophies.join(' · ')}'}',
              ),
              isThreeLine: season.trophies.isNotEmpty,
              trailing: season.trophies.isEmpty
                  ? null
                  : const Icon(
                      Icons.emoji_events_outlined,
                      color: ElevenwardColors.amber,
                    ),
            ),
          )
          .toList(growable: false),
    );
  }
}
