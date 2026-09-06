import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../services/entitlement_service.dart';
import '../storage/career_store.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../widgets/share_career_card.dart';
import 'leaderboard_screen.dart';

final class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final career = controller.activeCareer!;
    final locale = contentLocale(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(pinned: true, title: Text(context.l10n.more)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverList.list(
            children: [
              _Section(title: context.l10n.shareCareer),
              ShareCareerCard(
                career: career,
                styleId: controller.shareCardStyleId,
                avatarId: controller.avatarId,
              ),
              const SizedBox(height: 22),
              _Section(title: context.l10n.legacy),
              _CareerHonours(career: career),
              const SizedBox(height: 10),
              _SeasonArchive(
                career: career,
                layoutId: controller.archiveLayoutId,
              ),
              const SizedBox(height: 22),
              _Section(title: context.l10n.relationships),
              _RelationshipGrid(career: career),
              const SizedBox(height: 22),
              _Section(title: uiCopy(locale, 'leaderboards')),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.leaderboard_outlined),
                    title: Text(uiCopy(locale, 'browseLeaderboards')),
                    subtitle: Text(uiCopy(locale, 'leaderboardNoPrizes')),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            LeaderboardScreen(controller: controller),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.visibility_outlined),
                    title: Text(uiCopy(locale, 'shareRetiredCareer')),
                    subtitle: Text(uiCopy(locale, 'leaderboardPrivacy')),
                    value: controller.leaderboardOptIn,
                    onChanged: controller.changeLeaderboardOptIn,
                  ),
                  if (career.retired && controller.leaderboardOptIn)
                    ListTile(
                      leading: const Icon(Icons.publish_rounded),
                      title: Text(uiCopy(locale, 'submitCompletedCareer')),
                      enabled: controller.account != null && !controller.busy,
                      onTap: controller.submitActiveCareerLeaderboard,
                    ),
                ],
              ),
              const SizedBox(height: 22),
              _Section(title: context.l10n.permanentUpgrades),
              _UpgradeCard(
                icon: Icons.library_add_outlined,
                title: context.l10n.extraCareerSlots,
                body: context.l10n.extraCareerSlotsBody,
                price:
                    controller.entitlements.localizedPrice(extraSlotsProduct) ??
                    uiCopy(locale, 'storePrice'),
                active: controller.entitlementState.extraCareerSlots,
                onTap: controller.busy
                    ? null
                    : () => controller.purchase(extraSlotsEntitlement),
              ),
              const SizedBox(height: 10),
              _UpgradeCard(
                icon: Icons.palette_outlined,
                title: context.l10n.supporterPack,
                body: context.l10n.supporterPackBody,
                price:
                    controller.entitlements.localizedPrice(
                      supporterPackProduct,
                    ) ??
                    uiCopy(locale, 'storePrice'),
                active: controller.entitlementState.supporterPack,
                onTap: controller.busy
                    ? null
                    : () => controller.purchase(supporterPackEntitlement),
              ),
              TextButton(
                onPressed: controller.busy ? null : controller.restorePurchases,
                child: Text(context.l10n.restorePurchases),
              ),
              const SizedBox(height: 18),
              _Section(title: uiCopy(locale, 'supporterCosmetics')),
              _CosmeticsCard(controller: controller),
              const SizedBox(height: 22),
              _Section(title: context.l10n.settings),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language_rounded),
                    title: Text(context.l10n.language),
                    trailing: DropdownButton<Locale?>(
                      value: _normalizedLocale(controller.locale),
                      underline: const SizedBox.shrink(),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(uiCopy(locale, 'system')),
                        ),
                        DropdownMenuItem(
                          value: Locale('en'),
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: Locale('es'),
                          child: Text('Español'),
                        ),
                        DropdownMenuItem(
                          value: Locale('pt'),
                          child: Text('Português (Brasil)'),
                        ),
                        DropdownMenuItem(
                          value: Locale('fr'),
                          child: Text('Français'),
                        ),
                      ],
                      onChanged: controller.changeLocale,
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    secondary: const Icon(Icons.query_stats_rounded),
                    title: Text(context.l10n.analyticsConsent),
                    subtitle: Text(context.l10n.analyticsBody),
                    value: controller.analyticsGranted,
                    onChanged: controller.changeAnalyticsConsent,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.save_outlined),
                    title: Text(context.l10n.careerSlots),
                    onTap: controller.showCareerSlots,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _Section(title: context.l10n.accountAndCloud),
              _SettingsCard(
                children: [
                  ListTile(
                    leading: Icon(
                      controller.account == null
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined,
                    ),
                    title: Text(
                      controller.account == null
                          ? context.l10n.guestMode
                          : context.l10n.signedInAs(controller.account!.alias),
                    ),
                    subtitle: Text(context.l10n.offlineReady),
                  ),
                  if (controller.account == null) ...[
                    if (Platform.isIOS)
                      ListTile(
                        leading: const Icon(Icons.apple),
                        title: Text(context.l10n.signInApple),
                        enabled: !controller.busy,
                        onTap: controller.signInApple,
                      ),
                    ListTile(
                      leading: const Icon(Icons.g_mobiledata_rounded),
                      title: Text(context.l10n.signInGoogle),
                      enabled: !controller.busy,
                      onTap: controller.signInGoogle,
                    ),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.password_rounded),
                      title: Text(uiCopy(locale, 'webDeletionCode')),
                      subtitle: Text(uiCopy(locale, 'webDeletionBody')),
                      enabled: !controller.busy,
                      onTap: () => _showDeletionCode(context),
                    ),
                    ListTile(
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
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: Text(context.l10n.signOut),
                      enabled: !controller.busy,
                      onTap: controller.signOut,
                    ),
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
                ],
              ),
              FutureBuilder<List<PreservedConflict>>(
                future: controller.store.listConflicts(),
                builder: (context, snapshot) {
                  final conflicts = snapshot.data ?? const [];
                  if (conflicts.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Section(title: uiCopy(locale, 'cloudConflicts')),
                        ...conflicts.map(
                          (conflict) => _ConflictCard(
                            conflict: conflict,
                            controller: controller,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (controller.lastMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  controller.lastMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ElevenwardColors.amber),
                ),
              ],
              const SizedBox(height: 20),
              Center(
                child: Text(
                  context.l10n.contentVersion(
                    controller.activeContent?.version ?? career.contentVersion,
                  ),
                  style: const TextStyle(
                    color: ElevenwardColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

  Locale? _normalizedLocale(Locale? locale) =>
      locale == null ? null : Locale(locale.languageCode);

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
    if (confirmed == true) await controller.deleteAccount();
  }

  Future<void> _showDeletionCode(BuildContext context) async {
    final challenge = await controller.requestDeletionChallenge();
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

final class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 9),
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

final class _RelationshipGrid extends StatelessWidget {
  const _RelationshipGrid({required this.career});
  final CareerSnapshot career;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final values = <(String, int, String)>[
      (
        uiCopy(locale, 'manager'),
        career.relationships.manager,
        uiCopy(locale, 'managerConsequence'),
      ),
      (
        uiCopy(locale, 'teammates'),
        career.relationships.teammates,
        uiCopy(locale, 'teammateConsequence'),
      ),
      (
        context.l10n.agent,
        career.relationships.agent,
        uiCopy(locale, 'agentConsequence'),
      ),
      (
        uiCopy(locale, 'family'),
        career.relationships.family,
        uiCopy(locale, 'familyConsequence'),
      ),
      (
        uiCopy(locale, 'community'),
        career.relationships.community,
        uiCopy(locale, 'communityConsequence'),
      ),
      (
        uiCopy(locale, 'wellness'),
        career.wellness,
        uiCopy(locale, 'wellnessConsequence'),
      ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: values
          .map(
            (value) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ElevenwardColors.panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ElevenwardColors.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${value.$2}',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ElevenwardColors.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

final class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: ElevenwardColors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: children),
  );
}

final class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.price,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final String price;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: ElevenwardColors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: active ? ElevenwardColors.grass : ElevenwardColors.line,
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: active ? ElevenwardColors.grass : ElevenwardColors.amber,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: active ? null : onTap,
          child: Text(active ? context.l10n.owned : price),
        ),
      ],
    ),
  );
}

final class _ConflictCard extends StatelessWidget {
  const _ConflictCard({required this.conflict, required this.controller});
  final PreservedConflict conflict;
  final AppController controller;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Slot ${conflict.slotIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            conflict.localDeleted
                ? 'Local: deleted at ${_time(conflict.createdAt)}'
                : 'Local: ${conflict.localSnapshot.clubName} · season ${conflict.localSnapshot.season}, week ${conflict.localSnapshot.week} · revision ${conflict.localSnapshot.revision} · ${_time(conflict.localSnapshot.updatedAt)}',
          ),
          Text(
            'Cloud: ${conflict.remoteSnapshot.clubName} · season ${conflict.remoteSnapshot.season}, week ${conflict.remoteSnapshot.week} · revision ${conflict.remoteSnapshot.revision} · ${_time(conflict.remoteSnapshot.updatedAt)}',
          ),
          const SizedBox(height: 6),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.busy
                      ? null
                      : () => controller.resolveConflict(
                          conflict,
                          keepLocal: false,
                        ),
                  child: Text(uiCopy(contentLocale(context), 'keepCloud')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: controller.busy
                      ? null
                      : () => controller.resolveConflict(
                          conflict,
                          keepLocal: true,
                        ),
                  child: Text(uiCopy(contentLocale(context), 'keepLocal')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  String _time(DateTime value) =>
      value.toLocal().toIso8601String().replaceFirst('T', ' ').substring(0, 16);
}

final class _CosmeticsCard extends StatelessWidget {
  const _CosmeticsCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final unlocked = controller.entitlementState.supporterPack;
    return _SettingsCard(
      children: [
        _CosmeticPicker(
          kind: 'theme',
          title: uiCopy(contentLocale(context), 'theme'),
          selected: controller.themeId,
          values: const {
            'pitch': 'Pitch',
            'ocean': 'Ocean',
            'violet': 'Violet',
            'sunset': 'Sunset',
          },
          unlocked: unlocked,
          onSelected: (value) =>
              controller.setCosmeticPreference('theme', value),
        ),
        const Divider(height: 1),
        _CosmeticPicker(
          kind: 'avatar',
          title: uiCopy(contentLocale(context), 'avatar'),
          selected: controller.avatarId,
          values: const {
            'initials': 'Initials',
            'captain': 'Captain',
            'creator': 'Creator',
            'finisher': 'Finisher',
          },
          unlocked: unlocked,
          onSelected: (value) =>
              controller.setCosmeticPreference('avatar', value),
        ),
        const Divider(height: 1),
        _CosmeticPicker(
          kind: 'archive',
          title: uiCopy(contentLocale(context), 'archive'),
          selected: controller.archiveLayoutId,
          values: const {
            'timeline': 'Timeline',
            'compact': 'Compact',
            'honors': 'Honors',
          },
          unlocked: unlocked,
          onSelected: (value) =>
              controller.setCosmeticPreference('archiveLayout', value),
        ),
        const Divider(height: 1),
        _CosmeticPicker(
          kind: 'shareCard',
          title: uiCopy(contentLocale(context), 'shareCard'),
          selected: controller.shareCardStyleId,
          values: const {
            'classic': 'Classic',
            'stadium': 'Stadium',
            'editorial': 'Editorial',
            'midnight': 'Midnight',
          },
          unlocked: unlocked,
          onSelected: (value) =>
              controller.setCosmeticPreference('shareCard', value),
        ),
      ],
    );
  }
}

final class _CosmeticPicker extends StatelessWidget {
  const _CosmeticPicker({
    required this.kind,
    required this.title,
    required this.selected,
    required this.values,
    required this.unlocked,
    required this.onSelected,
  });

  final String kind;
  final String title;
  final String selected;
  final Map<String, String> values;
  final bool unlocked;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: values.entries
              .map((entry) {
                final isFree = entry.key == values.keys.first;
                return ChoiceChip(
                  selected: selected == entry.key,
                  onSelected: isFree || unlocked
                      ? (_) => onSelected(entry.key)
                      : null,
                  avatar: isFree || unlocked
                      ? _cosmeticPreview(kind, entry.key)
                      : const Icon(Icons.lock_outline_rounded, size: 14),
                  label: Text(entry.value),
                );
              })
              .toList(growable: false),
        ),
      ],
    ),
  );

  Widget _cosmeticPreview(String kind, String value) {
    if (kind == 'avatar') {
      return Icon(
        elevenwardAvatarIcon(value),
        size: 16,
        color: elevenwardCosmeticColor(value),
      );
    }
    if (kind == 'archive') {
      return Icon(
        value == 'honors'
            ? Icons.emoji_events_outlined
            : value == 'compact'
            ? Icons.view_agenda_outlined
            : Icons.timeline_rounded,
        size: 16,
      );
    }
    return CircleAvatar(
      radius: 7,
      backgroundColor: elevenwardCosmeticColor(value),
    );
  }
}

final class _SeasonArchive extends StatelessWidget {
  const _SeasonArchive({required this.career, required this.layoutId});

  final CareerSnapshot career;
  final String layoutId;

  @override
  Widget build(BuildContext context) {
    if (career.seasonHistory.isEmpty) {
      return _SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(uiCopy(contentLocale(context), 'completedSeasons')),
          ),
        ],
      );
    }
    final seasons = layoutId == 'honors'
        ? career.seasonHistory.where((season) => season.trophies.isNotEmpty)
        : career.seasonHistory;
    final clubNames = {
      for (final club in buildLaunchWorld().clubs) club.id: club.name,
    };
    final locale = contentLocale(context);
    if (seasons.isEmpty) {
      return _SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(uiCopy(locale, 'noHonoursYet')),
          ),
        ],
      );
    }
    return _SettingsCard(
      children: seasons
          .map((season) {
            final compact = layoutId == 'compact';
            return ListTile(
              dense: compact,
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
            );
          })
          .toList(growable: false),
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
    return _SettingsCard(
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
