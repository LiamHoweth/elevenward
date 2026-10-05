import 'package:flutter/material.dart';
import 'package:elevenward_core/elevenward_core.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../player_portraits.dart';
import '../storage/career_store.dart';
import '../theme.dart';
import '../ui_copy.dart';
import '../feature_copy.dart';
import '../widgets/backup_status.dart';
import 'create_career_screen.dart';
import 'more_detail_screens.dart';
import 'hall_of_fame_screen.dart';
import 'support_screen.dart';
import 'shop_screen.dart';

final class CareerHubScreen extends StatelessWidget {
  const CareerHubScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final resume = controller.resumeSlot;
    final resumeContext = resume?.snapshot == null
        ? null
        : _resumeContext(context, resume!.snapshot!);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/visual/stadium-graphite.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ElevenwardColors.ink.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .65
                        : .9,
                  ),
                  ElevenwardColors.ink,
                ],
                stops: [0, 0.62],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: ElevenwardColors.panel,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Image.asset(
                        'assets/branding/graphite/elevenward-11-ui.png',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ELEVENWARD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: uiCopy(contentLocale(context), 'shop'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ShopScreen(controller: controller),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 44),
                Text(
                  context.l10n.careerSlots,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.careerSlotsIntro),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.offline_bolt_outlined,
                      size: 17,
                      color: ElevenwardColors.grass,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        context.l10n.offlineReady,
                        style: TextStyle(
                          color: ElevenwardColors.grass,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('hub-account'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => AccountScreen(controller: controller),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_outlined),
                      label: Text(
                        featureCopy(contentLocale(context), 'accountRestore'),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('hub-settings'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(controller: controller),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      label: Text(context.l10n.settings),
                    ),
                    OutlinedButton.icon(
                      key: const Key('hub-hall-of-fame'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              HallOfFameScreen(controller: controller),
                        ),
                      ),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: Text(
                        featureCopy(contentLocale(context), 'hallOfFame'),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('hub-support'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => SupportScreen(controller: controller),
                        ),
                      ),
                      icon: const Icon(Icons.support_agent_outlined),
                      label: Text(
                        featureCopy(contentLocale(context), 'support'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (resume?.snapshot != null) ...[
                  BroadcastPanel(
                    accent: ElevenwardColors.grass,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${uiCopy(contentLocale(context), 'slotLabel')} ${resume!.slotIndex + 1}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          resume.snapshot!.player.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${resume.snapshot!.clubName} · ${context.l10n.seasonWeek(resume.snapshot!.season, resume.snapshot!.week)}',
                        ),
                        if (resumeContext != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              resumeContext,
                              key: const Key('resume-career-context'),
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const Key('resume-career-button'),
                          onPressed: () =>
                              controller.openSlot(resume.slotIndex),
                          icon: Icon(
                            resume.snapshot!.retired
                                ? Icons.emoji_events_outlined
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            uiCopy(
                              contentLocale(context),
                              resume.snapshot!.retired
                                  ? 'viewLegacy'
                                  : 'continueCareer',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                ...controller.slots.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SlotCard(
                      controller: controller,
                      slot: slot,
                      onOpen: slot.isOccupied
                          ? () => controller.openSlot(slot.slotIndex)
                          : slot.isTombstone
                          ? controller.synchronize
                          : () => _create(context, slot.slotIndex),
                      onDelete: slot.snapshot != null
                          ? () => _confirmDelete(context, slot)
                          : null,
                    ),
                  ),
                ),
                FutureBuilder<List<PreservedConflict>>(
                  future: controller.store.listConflicts(),
                  builder: (context, snapshot) {
                    final conflicts = snapshot.data ?? const [];
                    if (conflicts.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: conflicts
                          .map(
                            (conflict) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _HubConflictCard(
                                conflict: conflict,
                                controller: controller,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ShopScreen(controller: controller),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(uiCopy(contentLocale(context), 'shop')),
                ),
                if (controller.lastMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    controller.lastMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ElevenwardColors.amber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, int slotIndex) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            CreateCareerScreen(controller: controller, slotIndex: slotIndex),
      ),
    );
  }

  String? _resumeContext(BuildContext context, CareerSnapshot career) {
    final locale = contentLocale(context);
    if (career.retired || career.phase == CareerPhase.retired) {
      return context.l10n.careerComplete;
    }
    final pinned = controller.availableContent?.version == career.contentVersion
        ? controller.availableContent
        : controller.activeContent?.version == career.contentVersion
        ? controller.activeContent
        : null;
    if (career.pendingEventId != null) {
      final event = pinned == null
          ? null
          : const CareerEngine().pendingEvent(career, pinned.catalog);
      return event?.title.forLocale(locale) ?? uiCopy(locale, 'awayPitch');
    }
    switch (career.phase) {
      case CareerPhase.offseason:
        return context.l10n.seasonComplete;
      case CareerPhase.contractDecision:
        return context.l10n.contractOffers;
      case CareerPhase.retirementDecision:
        return context.l10n.retirement;
      case CareerPhase.internationalCallup:
        return uiCopy(locale, 'worldNationsTitle');
      case CareerPhase.retired:
        return context.l10n.careerComplete;
      case CareerPhase.inSeason:
      case CareerPhase.internationalTournament:
        break;
    }
    try {
      if (pinned == null) return null;
      final opponent = const WorldSimulator().opponentFor(
        career,
        definition: pinned.catalog.world,
      );
      return '${context.l10n.nextMatch}: ${opponent.clubName} · ${opponent.isHome ? context.l10n.home : context.l10n.away}';
    } on Object {
      return null;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SavedCareerSlot openingSlot,
  ) async {
    final openingCareerId = openingSlot.snapshot!.careerId;
    final openingRevision = openingSlot.localRevision;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiCopy(contentLocale(context), 'deleteLocalTitle')),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              openingSlot.snapshot!.player.name,
              key: const Key('delete-career-name'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${uiCopy(contentLocale(context), 'slotLabel')} ${openingSlot.slotIndex + 1} · ${openingSlot.snapshot!.clubName}',
            ),
            Text(
              context.l10n.seasonWeek(
                openingSlot.snapshot!.season,
                openingSlot.snapshot!.week,
              ),
            ),
            const SizedBox(height: 16),
            Text(uiCopy(contentLocale(context), 'deleteLocalBody')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(uiCopy(contentLocale(context), 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final current = controller.slots
        .where((slot) => slot.slotIndex == openingSlot.slotIndex)
        .firstOrNull;
    if (current?.snapshot?.careerId != openingCareerId ||
        current?.localRevision != openingRevision) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            featureCopy(contentLocale(context), 'careerChangedBeforeDeletion'),
          ),
        ),
      );
      return;
    }
    await controller.deleteSlot(
      openingSlot.slotIndex,
      expectedCareerId: openingCareerId,
      expectedRevision: openingRevision,
    );
  }
}

final class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.controller,
    required this.slot,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedCareerSlot slot;
  final AppController controller;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final career = slot.snapshot;
    final tombstone = slot.isTombstone;
    final recoveryCode = slot.recoveryCode;
    final locale = contentLocale(context);
    final portraitAsset = career == null || tombstone
        ? null
        : playerPortraitAsset(career.player.portraitId);
    return Semantics(
      button: true,
      label: recoveryCode != null
          ? '${uiCopy(locale, 'slotLabel')} ${slot.slotIndex + 1}, ${uiCopy(locale, 'recoverySlotSemantics')}'
          : tombstone
          ? '${uiCopy(locale, 'slotLabel')} ${slot.slotIndex + 1}, ${uiCopy(locale, 'deletionPendingSemantics')}'
          : career == null
          ? '${context.l10n.emptySlot} ${slot.slotIndex + 1}'
          : '${uiCopy(locale, 'slotLabel')} ${slot.slotIndex + 1}, ${career.player.name}, ${career.clubName}, ${context.l10n.seasonWeek(career.season, career.week)}',
      child: Material(
        color: ElevenwardColors.panel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: portraitAsset == null
                      ? null
                      : AssetImage(portraitAsset),
                  backgroundColor: career == null
                      ? ElevenwardColors.panelLight
                      : ElevenwardColors.grass,
                  foregroundColor: career == null
                      ? ElevenwardColors.muted
                      : ElevenwardColors.ink,
                  child: portraitAsset != null
                      ? null
                      : Icon(
                          tombstone
                              ? Icons.cloud_sync_outlined
                              : career == null
                              ? Icons.add_rounded
                              : Icons.person_rounded,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${uiCopy(locale, 'slotLabel')} ${slot.slotIndex + 1}',
                        key: Key('career-slot-label-${slot.slotIndex}'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 5),
                      recoveryCode != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(uiCopy(locale, 'saveNeedsRecovery')),
                                Text(uiCopy(locale, 'restoreJournal')),
                                Text(
                                  '${uiCopy(locale, 'supportCode')}: $recoveryCode',
                                ),
                              ],
                            )
                          : tombstone
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  uiCopy(
                                    contentLocale(context),
                                    'deletedLocally',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  uiCopy(contentLocale(context), 'finishCloud'),
                                ),
                              ],
                            )
                          : career == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.emptySlot,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(context.l10n.newCareer),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  career.player.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${career.clubName} · ${career.player.overall} OVR',
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  context.l10n.seasonWeek(
                                    career.season,
                                    career.week,
                                  ),
                                  style: TextStyle(
                                    color: ElevenwardColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SlotBackupStatus(
                                  controller: controller,
                                  slot: slot,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: uiCopy(contentLocale(context), 'deleteTooltip'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                else
                  const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _HubConflictCard extends StatelessWidget {
  const _HubConflictCard({required this.conflict, required this.controller});

  final PreservedConflict conflict;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final remote = conflict.remoteSnapshot;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ElevenwardColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ElevenwardColors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${uiCopy(locale, 'cloudConflicts')} · ${uiCopy(locale, 'slot')} ${conflict.slotIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            conflict.localDeleted
                ? uiCopy(contentLocale(context), 'deletionConflict')
                : uiCopy(contentLocale(context), 'saveConflict'),
          ),
          const SizedBox(height: 6),
          Text(
            conflictSideLabel(
              context,
              conflict.localSnapshot,
              side: 'local',
              deleted: conflict.localDeleted,
            ),
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            conflictSideLabel(context, remote, side: 'cloud'),
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            MaterialLocalizations.of(context)
                .formatMediumDate(conflict.createdAt.toLocal()),
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cloudButton = OutlinedButton(
                key: Key('hub-conflict-cloud-${conflict.id}'),
                onPressed: controller.busy
                    ? null
                    : () => controller.resolveConflict(
                        conflict,
                        keepLocal: false,
                      ),
                child: Text(
                  remote == null
                      ? featureCopy(locale, 'useCloudDeletion')
                      : uiCopy(locale, 'keepCloud'),
                ),
              );
              final localButton = FilledButton(
                key: Key('hub-conflict-local-${conflict.id}'),
                onPressed: controller.busy
                    ? null
                    : () =>
                          controller.resolveConflict(conflict, keepLocal: true),
                child: Text(
                  uiCopy(
                    contentLocale(context),
                    conflict.localDeleted ? 'keepDeleted' : 'keepLocal',
                  ),
                ),
              );
              if (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cloudButton,
                    const SizedBox(height: 8),
                    localButton,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: cloudButton),
                  const SizedBox(width: 8),
                  Expanded(child: localButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
