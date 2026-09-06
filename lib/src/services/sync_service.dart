import '../storage/career_store.dart';

import 'package:elevenward_core/elevenward_core.dart';

import 'api_models.dart';
import 'elevenward_api.dart';

final class SyncReport {
  const SyncReport({
    required this.uploaded,
    required this.downloaded,
    required this.conflicts,
  });

  final int uploaded;
  final int downloaded;
  final int conflicts;
}

enum SyncProgressPhase { loading, uploading, downloading, complete }

final class SyncProgressUpdate {
  const SyncProgressUpdate({
    required this.phase,
    required this.completed,
    required this.total,
  });

  final SyncProgressPhase phase;
  final int completed;
  final int total;
}

final class SyncService {
  const SyncService(this._api, this._store);

  final ElevenwardApi _api;
  final CareerStore _store;

  Future<void> submitLeaderboard(CareerSnapshot snapshot) =>
      _api.submitLeaderboard(snapshot);

  Future<List<Map<String, Object?>>> leaderboard({
    required PositionFamily position,
    required Difficulty difficulty,
    required String rulesVersion,
  }) => _api.leaderboard(
    position: position,
    difficulty: difficulty,
    rulesVersion: rulesVersion,
  );

  Future<SyncReport> synchronize({
    void Function(SyncProgressUpdate progress)? onProgress,
  }) async {
    onProgress?.call(
      const SyncProgressUpdate(
        phase: SyncProgressPhase.loading,
        completed: 0,
        total: 0,
      ),
    );
    final local = await _store.listSlots();
    var uploaded = 0;
    var downloaded = 0;
    var conflicts = 0;
    final remote = await _api.careerSlots();
    final remoteBySlot = {for (final slot in remote) slot.slotIndex: slot};
    final localIndexes = local.map((slot) => slot.slotIndex).toSet();
    final total =
        local.length +
        remote.where((slot) => !localIndexes.contains(slot.slotIndex)).length;
    var completed = 0;

    for (final slot in local) {
      onProgress?.call(
        SyncProgressUpdate(
          phase: slot.snapshot == null
              ? SyncProgressPhase.downloading
              : SyncProgressPhase.uploading,
          completed: completed,
          total: total,
        ),
      );
      final snapshot = slot.snapshot;
      final cloud = remoteBySlot.remove(slot.slotIndex);
      if (slot.isTombstone) {
        if (cloud == null) {
          await _store.clearTombstone(slot.slotIndex);
          completed += 1;
          continue;
        }
        final outcome = await _api.deleteCareerSlot(
          slotIndex: slot.slotIndex,
          baseRevision: slot.serverRevision,
        );
        switch (outcome) {
          case SyncDeleted():
            await _store.clearTombstone(slot.slotIndex);
            uploaded += 1;
          case SyncConflict(:final conflict):
            await _store.preserveConflict(
              local: slot.tombstoneSnapshot!,
              remote: conflict.remote,
              createdAt: DateTime.now().toUtc(),
              slotIndex: conflict.slotIndex,
              remoteConflictId: conflict.id,
              localDeleted: true,
            );
            await _store.markConflict(conflict.slotIndex);
            conflicts += 1;
          case SyncAccepted():
            throw StateError('A delete returned an invalid save response.');
        }
        completed += 1;
        continue;
      }
      if (snapshot == null && cloud != null) {
        await _store.applyRemoteSlot(
          slot.slotIndex,
          cloud.snapshot,
          cloud.revision,
        );
        downloaded += 1;
        completed += 1;
        continue;
      }
      if (snapshot == null) {
        completed += 1;
        continue;
      }
      if (slot.syncState == SlotSyncState.synced &&
          cloud != null &&
          cloud.revision == slot.serverRevision) {
        completed += 1;
        continue;
      }
      final outcome = await _api.syncCareer(
        slotIndex: slot.slotIndex,
        baseRevision: slot.serverRevision,
        snapshot: snapshot,
      );
      switch (outcome) {
        case SyncAccepted(:final slot):
          await _store.markSynced(
            slot.slotIndex,
            snapshot.revision,
            slot.revision,
          );
          uploaded += 1;
        case SyncConflict(:final conflict):
          await _store.preserveConflict(
            local: conflict.local ?? snapshot,
            remote: conflict.remote,
            createdAt: DateTime.now().toUtc(),
            slotIndex: conflict.slotIndex,
            remoteConflictId: conflict.id,
          );
          await _store.markConflict(conflict.slotIndex);
          conflicts += 1;
        case SyncDeleted():
          throw StateError('A save returned an invalid deletion response.');
      }
      completed += 1;
    }
    for (final cloud in remoteBySlot.values) {
      onProgress?.call(
        SyncProgressUpdate(
          phase: SyncProgressPhase.downloading,
          completed: completed,
          total: total,
        ),
      );
      await _store.applyRemoteSlot(
        cloud.slotIndex,
        cloud.snapshot,
        cloud.revision,
      );
      downloaded += 1;
      completed += 1;
    }
    final report = SyncReport(
      uploaded: uploaded,
      downloaded: downloaded,
      conflicts: conflicts,
    );
    onProgress?.call(
      SyncProgressUpdate(
        phase: SyncProgressPhase.complete,
        completed: completed,
        total: total,
      ),
    );
    return report;
  }

  Future<void> resolve({
    required int localConflictId,
    required int slotIndex,
    required String remoteConflictId,
    required bool keepLocal,
  }) async {
    final slot = await _api.resolveConflict(
      slotIndex: slotIndex,
      conflictId: remoteConflictId,
      choice: keepLocal ? 'local' : 'remote',
    );
    if (slot == null) {
      await _store.clearTombstone(slotIndex);
    } else {
      await _store.applyRemoteSlot(slotIndex, slot.snapshot, slot.revision);
    }
    await _store.resolveConflict(localConflictId, DateTime.now().toUtc());
  }
}
