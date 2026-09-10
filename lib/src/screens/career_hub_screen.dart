import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../storage/career_store.dart';
import '../theme.dart';
import '../ui_copy.dart';
import 'create_career_screen.dart';
import 'shop_screen.dart';

final class CareerHubScreen extends StatelessWidget {
  const CareerHubScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/visual/stadium-hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xA607110C), ElevenwardColors.ink],
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
                        color: ElevenwardColors.grass,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        color: ElevenwardColors.ink,
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
                    if (controller.account != null)
                      Tooltip(
                        message: context.l10n.signedInAs(
                          controller.account!.alias,
                        ),
                        child: const Icon(
                          Icons.cloud_done_outlined,
                          color: ElevenwardColors.sky,
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
                    const Icon(
                      Icons.offline_bolt_outlined,
                      size: 17,
                      color: ElevenwardColors.grass,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      context.l10n.offlineReady,
                      style: const TextStyle(
                        color: ElevenwardColors.grass,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ...controller.slots.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SlotCard(
                      slot: slot,
                      onOpen: slot.isOccupied
                          ? () => controller.openSlot(slot.slotIndex)
                          : slot.isTombstone
                          ? controller.synchronize
                          : () => _create(context, slot.slotIndex),
                      onDelete: slot.snapshot != null
                          ? () => _confirmDelete(context, slot.slotIndex)
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
                    style: const TextStyle(color: ElevenwardColors.amber),
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

  Future<void> _confirmDelete(BuildContext context, int slotIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(uiCopy(contentLocale(context), 'deleteLocalTitle')),
        content: Text(uiCopy(contentLocale(context), 'deleteLocalBody')),
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
    if (confirmed == true) await controller.deleteSlot(slotIndex);
  }
}

final class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedCareerSlot slot;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final career = slot.snapshot;
    final tombstone = slot.isTombstone;
    final recoveryCode = slot.recoveryCode;
    final locale = contentLocale(context);
    return Semantics(
      button: true,
      label: recoveryCode != null
          ? '${uiCopy(locale, 'slotLabel')} ${slot.slotIndex + 1}, ${uiCopy(locale, 'recoverySlotSemantics')}'
          : tombstone
          ? '${uiCopy(locale, 'slotLabel')} ${slot.slotIndex + 1}, ${uiCopy(locale, 'deletionPendingSemantics')}'
          : career == null
          ? '${context.l10n.emptySlot} ${slot.slotIndex + 1}'
          : '${career.player.name}, ${career.clubName}, ${context.l10n.seasonWeek(career.season, career.week)}',
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
                  backgroundColor: career == null
                      ? ElevenwardColors.panelLight
                      : ElevenwardColors.grass,
                  foregroundColor: career == null
                      ? ElevenwardColors.muted
                      : ElevenwardColors.ink,
                  child: Icon(
                    tombstone
                        ? Icons.cloud_sync_outlined
                        : career == null
                        ? Icons.add_rounded
                        : Icons.person_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: recoveryCode != null
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
                              uiCopy(contentLocale(context), 'deletedLocally'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(uiCopy(contentLocale(context), 'finishCloud')),
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
                              style: const TextStyle(
                                color: ElevenwardColors.muted,
                                fontSize: 12,
                              ),
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
  Widget build(BuildContext context) => Container(
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
          'Cloud conflict · Slot ${conflict.slotIndex + 1}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        Text(
          conflict.localDeleted
              ? uiCopy(contentLocale(context), 'deletionConflict')
              : uiCopy(contentLocale(context), 'saveConflict'),
        ),
        const SizedBox(height: 6),
        if (!conflict.localDeleted)
          Text(
            'Local · ${conflict.localSnapshot.clubName} · S${conflict.localSnapshot.season} W${conflict.localSnapshot.week} · r${conflict.localSnapshot.revision}',
            style: const TextStyle(fontSize: 12),
          ),
        Text(
          'Cloud · ${conflict.remoteSnapshot.clubName} · S${conflict.remoteSnapshot.season} W${conflict.remoteSnapshot.week} · r${conflict.remoteSnapshot.revision}',
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          conflict.createdAt
              .toLocal()
              .toIso8601String()
              .replaceFirst('T', ' ')
              .substring(0, 16),
          style: const TextStyle(color: ElevenwardColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 10),
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
                    : () =>
                          controller.resolveConflict(conflict, keepLocal: true),
                child: Text(
                  uiCopy(
                    contentLocale(context),
                    conflict.localDeleted ? 'keepDeleted' : 'keepLocal',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
