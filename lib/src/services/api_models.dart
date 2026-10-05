import 'package:elevenward_core/elevenward_core.dart';

final class ElevenwardAccount {
  const ElevenwardAccount({
    required this.id,
    required this.alias,
    required this.provider,
    this.email,
    this.publicUsername,
    this.usernameStatus = 'unset',
    this.usernameCanChangeAt,
    this.leaderboardSharingEnabled = true,
  });

  factory ElevenwardAccount.fromJson(Map<String, Object?> json) =>
      ElevenwardAccount(
        id: json['id'] as String,
        alias: json['alias'] as String,
        provider: json['provider'] as String,
        email: json['email'] as String?,
        publicUsername: json['publicUsername'] as String?,
        usernameStatus: json['usernameStatus'] as String? ?? 'unset',
        usernameCanChangeAt: json['usernameCanChangeAt'] == null
            ? null
            : DateTime.parse(json['usernameCanChangeAt'] as String).toUtc(),
        leaderboardSharingEnabled:
            json['leaderboardSharingEnabled'] as bool? ?? false,
      );

  final String id;
  final String alias;
  final String provider;
  final String? email;
  final String? publicUsername;
  final String usernameStatus;
  final DateTime? usernameCanChangeAt;
  final bool leaderboardSharingEnabled;

  Map<String, Object?> toJson() => {
    'id': id,
    'alias': alias,
    'provider': provider,
    'email': email,
    'publicUsername': publicUsername,
    'usernameStatus': usernameStatus,
    'usernameCanChangeAt': usernameCanChangeAt?.toIso8601String(),
    'leaderboardSharingEnabled': leaderboardSharingEnabled,
  };
}

final class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.alias,
    required this.legacyScore,
    required this.seasons,
    required this.trophies,
    this.profileId,
    this.isCurrentUser = false,
    this.reportable = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, Object?> json) {
    final metrics =
        (json['aggregateMetrics'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    return LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      alias: json['alias'] as String,
      legacyScore: (json['legacyScore'] as num).toInt(),
      seasons: (metrics['seasons'] as num?)?.toInt() ?? 0,
      trophies: (metrics['trophies'] as num?)?.toInt() ?? 0,
      profileId: json['profileId'] as String?,
      isCurrentUser: json['isCurrentUser'] == true,
      reportable: json['reportable'] == true,
    );
  }

  final int rank;
  final String alias;
  final int legacyScore;
  final int seasons;
  final int trophies;
  final String? profileId;
  final bool isCurrentUser;
  final bool reportable;
}

final class AuthSession {
  const AuthSession({
    required this.account,
    required this.accessToken,
    required this.expiresAt,
  });

  factory AuthSession.fromJson(Map<String, Object?> json) => AuthSession(
    account: ElevenwardAccount.fromJson(
      (json['account'] as Map).cast<String, Object?>(),
    ),
    accessToken: json['accessToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
  );

  final ElevenwardAccount account;
  final String accessToken;
  final DateTime expiresAt;
}

final class RemoteCareerSlot {
  const RemoteCareerSlot({
    required this.slotIndex,
    required this.snapshot,
    required this.revision,
    required this.checksum,
  });

  factory RemoteCareerSlot.fromJson(Map<String, Object?> json) =>
      RemoteCareerSlot(
        slotIndex: json['slotIndex'] as int,
        snapshot: CareerSnapshot.fromJson(
          (json['snapshot'] as Map).cast<String, Object?>(),
        ),
        revision: json['revision'] as int,
        checksum: json['checksum'] as String,
      );

  final int slotIndex;
  final CareerSnapshot snapshot;
  final int revision;
  final String checksum;
}

final class RemoteSyncConflict {
  const RemoteSyncConflict({
    required this.id,
    required this.slotIndex,
    required this.local,
    required this.remote,
    this.remoteRevision = 0,
  });

  factory RemoteSyncConflict.fromJson(Map<String, Object?> json) =>
      RemoteSyncConflict(
        id: json['conflictId'] as String,
        remoteRevision: (json['remoteRevision'] as num?)?.toInt() ?? 0,
        slotIndex: json['slotIndex'] as int,
        local: json['localSnapshot'] == null
            ? null
            : CareerSnapshot.fromJson(
                (json['localSnapshot'] as Map).cast<String, Object?>(),
              ),
        remote: json['remoteSnapshot'] == null
            ? null
            : CareerSnapshot.fromJson(
                (json['remoteSnapshot'] as Map).cast<String, Object?>(),
              ),
      );

  final String id;
  final int slotIndex;
  final CareerSnapshot? local;
  final CareerSnapshot? remote;
  final int remoteRevision;

  bool get localDeleted => local == null;
  bool get remoteDeleted => remote == null;
}

sealed class SyncOutcome {
  const SyncOutcome();
}

final class SyncAccepted extends SyncOutcome {
  const SyncAccepted(this.slot);
  final RemoteCareerSlot slot;
}

final class SyncConflict extends SyncOutcome {
  const SyncConflict(this.conflict);
  final RemoteSyncConflict conflict;
}

final class SyncDeleted extends SyncOutcome {
  const SyncDeleted();
}

final class ApiFailure implements Exception {
  const ApiFailure(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiFailure($statusCode, $message)';
}
