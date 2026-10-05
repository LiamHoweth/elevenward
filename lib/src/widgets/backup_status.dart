import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../feature_copy.dart';
import '../l10n_context.dart';
import '../storage/career_store.dart';
import '../theme.dart';
import '../ui_copy.dart';

String conflictSideLabel(
  BuildContext context,
  CareerSnapshot? snapshot, {
  required String side,
  bool deleted = false,
}) {
  final locale = contentLocale(context);
  final prefix = uiCopy(locale, side);
  if (deleted || snapshot == null) {
    return '$prefix: ${uiCopy(locale, 'deleted')}';
  }
  return '$prefix: ${snapshot.clubName} · ${context.l10n.seasonWeek(snapshot.season, snapshot.week)}';
}

String backupStateLabel(String locale, BackupState state) =>
    featureCopy(locale, switch (state) {
      BackupState.deviceOnly => 'deviceOnly',
      BackupState.pending => 'backupPending',
      BackupState.backedUp => 'backedUp',
      BackupState.conflict => 'backupConflict',
      BackupState.failed => 'backupFailed',
    });

String lastBackupLabel(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final copy = MaterialLocalizations.of(context);
  return formatFeatureCopy(contentLocale(context), 'lastBackup', {
    'time':
        '${copy.formatCompactDate(local)} ${copy.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
  });
}

final class SlotBackupStatus extends StatelessWidget {
  const SlotBackupStatus({
    super.key,
    required this.controller,
    required this.slot,
  });
  final AppController controller;
  final SavedCareerSlot slot;

  @override
  Widget build(BuildContext context) {
    final state = controller.backupStateFor(slot);
    final backedUpAt = controller.lastBackupAtFor(slot);
    final color = switch (state) {
      BackupState.backedUp => ElevenwardColors.grass,
      BackupState.failed || BackupState.conflict => ElevenwardColors.amber,
      _ => ElevenwardColors.muted,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          backupStateLabel(contentLocale(context), state),
          style: TextStyle(color: color, fontSize: 12),
        ),
        if (backedUpAt != null)
          Text(
            lastBackupLabel(context, backedUpAt),
            style: TextStyle(color: ElevenwardColors.muted, fontSize: 11),
          ),
      ],
    );
  }
}
