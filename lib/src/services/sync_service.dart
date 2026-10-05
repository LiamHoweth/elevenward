import '../storage/career_store.dart';

import 'package:elevenward_core/elevenward_core.dart';

import 'api_models.dart';
import 'elevenward_api.dart';
import 'online_models.dart';

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

  Future<ElevenwardAccount> updatePublicUsername(String username) =>
      _api.updatePublicUsername(username);

  Future<ElevenwardAccount> updateLeaderboardSharing(
    bool enabled, {
    bool Function()? isCurrentSession,
  }) => _api.updateLeaderboardSharing(
    enabled,
    isCurrentSession: isCurrentSession,
  );

  Future<void> reportLeaderboardUsername({
    required String profileId,
    required String reason,
  }) => _api.reportLeaderboardUsername(profileId: profileId, reason: reason);

  Future<List<LeaderboardEntry>> leaderboard({
    required PositionFamily position,
    required Difficulty difficulty,
    required String rulesVersion,
  }) => _api.leaderboard(
    position: position,
    difficulty: difficulty,
    rulesVersion: rulesVersion,
  );

  Future<LeaderboardPage> leaderboardPage({
    required PositionFamily position,
    required Difficulty difficulty,
    required String rulesVersion,
    String? careerId,
  }) => _api.leaderboardPage(
    position: position,
    difficulty: difficulty,
    rulesVersion: rulesVersion,
    careerId: careerId,
  );
  Future<void> sendFeedback(Map<String, Object?> body) =>
      _api.sendFeedback(body);
  Future<List<CareerSnapshot>> archives({bool Function()? isCurrentSession}) =>
      _api.archives(isCurrentSession: isCurrentSession);
  Future<void> archive(
    CareerSnapshot snapshot, {
    bool Function()? isCurrentSession,
  }) => _api.archive(snapshot, isCurrentSession: isCurrentSession);
  Future<void> deleteArchive(
    String careerId, {
    bool Function()? isCurrentSession,
  }) => _api.deleteArchive(careerId, isCurrentSession: isCurrentSession);
  Future<FriendsState> friends() => _api.friends();
  Future<void> setFriendSharing(bool enabled) => _api.setFriendSharing(enabled);
  Future<Map<String, Object?>> createFriendCode() => _api.createFriendCode();
  Future<void> requestFriend(String inviteCode) =>
      _api.requestFriend(inviteCode);
  Future<void> respondFriend(String requestId, bool accept) =>
      _api.respondFriend(requestId, accept);
  Future<void> removeFriend(String profileId) => _api.removeFriend(profileId);
  Future<void> blockFriend(String profileId) => _api.blockFriend(profileId);
  Future<void> unblockFriend(String profileId) => _api.unblockFriend(profileId);
  Future<ChallengeState> currentChallenge() => _api.currentChallenge();
  Future<ChallengeAttempt> enrollChallenge(String id) =>
      _api.enrollChallenge(id);
  Future<Map<String, Object?>> submitChallenge(
    String id,
    String attemptId,
    List<Map<String, Object?>> actions,
  ) => _api.submitChallenge(id, attemptId, actions);

  Future<SyncReport> synchronize({
    required bool publishLeaderboard,
    bool forcePublicationRefresh = false,
    void Function(SyncProgressUpdate progress)? onProgress,
    bool Function()? isCurrentSession,
  }) async {
    void checkSession() {
      if (isCurrentSession?.call() == false) {
        throw StateError('Account changed during synchronization.');
      }
    }

    checkSession();
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
    checkSession();
    final remote = await _api.careerSlots(isCurrentSession: isCurrentSession);
    checkSession();
    final remoteBySlot = {for (final slot in remote) slot.slotIndex: slot};
    final localIndexes = local.map((slot) => slot.slotIndex).toSet();
    final total =
        local.length +
        remote.where((slot) => !localIndexes.contains(slot.slotIndex)).length;
    var completed = 0;

    for (final slot in local) {
      checkSession();
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
          isCurrentSession: isCurrentSession,
        );
        checkSession();
        switch (outcome) {
          case SyncDeleted():
            await _store.clearTombstone(slot.slotIndex);
            uploaded += 1;
          case SyncConflict(:final conflict):
            await _store.preserveConflict(
              local: conflict.local ?? slot.tombstoneSnapshot!,
              remote: conflict.remote,
              createdAt: DateTime.now().toUtc(),
              slotIndex: conflict.slotIndex,
              remoteConflictId: conflict.id,
              localDeleted: conflict.localDeleted,
              remoteRevision: conflict.remoteRevision,
            );
            await _store.markConflict(
              conflict.slotIndex,
              expectedCareerId: slot.tombstoneSnapshot!.careerId,
              expectedServerRevision: slot.serverRevision,
            );
            conflicts += 1;
          case SyncAccepted():
            throw StateError('A delete returned an invalid save response.');
        }
        completed += 1;
        continue;
      }
      if (snapshot == null && cloud != null) {
        final applied = await _store.applyRemoteSlot(
          slot.slotIndex,
          cloud.snapshot,
          cloud.revision,
          onlyIfEmpty: true,
          isCurrentSession: isCurrentSession,
        );
        if (applied) downloaded += 1;
        completed += 1;
        continue;
      }
      if (snapshot == null) {
        completed += 1;
        continue;
      }
      if (slot.syncState == SlotSyncState.synced &&
          cloud != null &&
          cloud.revision == slot.serverRevision &&
          !forcePublicationRefresh) {
        completed += 1;
        continue;
      }
      final outcome = await _api.syncCareer(
        slotIndex: slot.slotIndex,
        baseRevision: slot.serverRevision,
        snapshot: snapshot,
        publishLeaderboard: publishLeaderboard,
        isCurrentSession: isCurrentSession,
      );
      checkSession();
      switch (outcome) {
        case SyncAccepted(slot: final accepted):
          await _store.markSynced(
            accepted.slotIndex,
            snapshot.revision,
            accepted.revision,
            expectedCareerId: snapshot.careerId,
            expectedServerRevision: slot.serverRevision,
          );
          uploaded += 1;
        case SyncConflict(:final conflict):
          final latest = await _store.loadSlot(slot.slotIndex);
          checkSession();
          final baseline = conflict.local ?? snapshot;
          final comparison = latest?.careerId == baseline.careerId
              ? latest!
              : baseline;
          await _store.preserveConflict(
            local: comparison,
            remote: conflict.remote,
            createdAt: DateTime.now().toUtc(),
            slotIndex: conflict.slotIndex,
            remoteConflictId: conflict.id,
            remoteRevision: conflict.remoteRevision,
          );
          await _store.markConflict(
            conflict.slotIndex,
            expectedCareerId: snapshot.careerId,
            expectedServerRevision: slot.serverRevision,
          );
          conflicts += 1;
        case SyncDeleted():
          throw StateError('A save returned an invalid deletion response.');
      }
      completed += 1;
    }
    for (final cloud in remoteBySlot.values) {
      checkSession();
      onProgress?.call(
        SyncProgressUpdate(
          phase: SyncProgressPhase.downloading,
          completed: completed,
          total: total,
        ),
      );
      final applied = await _store.applyRemoteSlot(
        cloud.slotIndex,
        cloud.snapshot,
        cloud.revision,
        onlyIfEmpty: true,
        isCurrentSession: isCurrentSession,
      );
      if (applied) downloaded += 1;
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
    required bool publishLeaderboard,
    CareerSnapshot? localSnapshot,
    int? expectedRemoteRevision,
    String? expectedCareerId,
    int? expectedLocalRevision,
    bool Function()? isCurrentSession,
  }) async {
    if (isCurrentSession?.call() == false) throw StateError('Account changed.');
    // Callers can pin the exact reviewed row. Capture it here for legacy callers
    // so a network response still cannot delete a replacement slot.
    final before = (await _store.listSlots()).firstWhere(
      (saved) => saved.slotIndex == slotIndex,
    );
    final expectedId =
        expectedCareerId ??
        before.snapshot?.careerId ??
        before.tombstoneSnapshot?.careerId;
    final expectedRevision = expectedLocalRevision ?? before.localRevision;
    if (isCurrentSession?.call() == false) throw StateError('Account changed.');
    final slot = await _api.resolveConflict(
      slotIndex: slotIndex,
      conflictId: remoteConflictId,
      choice: keepLocal ? 'local' : 'remote',
      publishLeaderboard: publishLeaderboard,
      localSnapshot: localSnapshot,
      expectedRemoteRevision: expectedRemoteRevision,
      isCurrentSession: isCurrentSession,
    );
    if (isCurrentSession?.call() == false) throw StateError('Account changed.');
    if (slot == null) {
      if (expectedId != null) {
        final cleared = await _store.clearResolvedSlot(
          slotIndex,
          expectedCareerId: expectedId,
          expectedRevision: expectedRevision,
          isCurrentSession: isCurrentSession,
        );
        if (!cleared) {
          throw StateError(
            'The local career changed during conflict resolution.',
          );
        }
      }
    } else {
      final applied = await _store.applyRemoteSlot(
        slotIndex,
        slot.snapshot,
        slot.revision,
        onlyIfEmpty: expectedId == null,
        expectedCareerId: expectedId,
        expectedRevision: expectedId == null ? null : expectedRevision,
        isCurrentSession: isCurrentSession,
      );
      if (!applied) {
        throw StateError(
          'The local career changed during conflict resolution.',
        );
      }
    }
    await _store.resolveConflict(localConflictId, DateTime.now().toUtc());
  }
}
