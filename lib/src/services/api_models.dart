import 'package:elevenward_core/elevenward_core.dart';

final class ElevenwardAccount {
  const ElevenwardAccount({
    required this.id,
    required this.alias,
    required this.provider,
    this.email,
  });

  factory ElevenwardAccount.fromJson(Map<String, Object?> json) =>
      ElevenwardAccount(
        id: json['id'] as String,
        alias: json['alias'] as String,
        provider: json['provider'] as String,
        email: json['email'] as String?,
      );

  final String id;
  final String alias;
  final String provider;
  final String? email;
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
  });

  factory RemoteSyncConflict.fromJson(Map<String, Object?> json) =>
      RemoteSyncConflict(
        id: json['conflictId'] as String,
        slotIndex: json['slotIndex'] as int,
        local: json['localSnapshot'] == null
            ? null
            : CareerSnapshot.fromJson(
                (json['localSnapshot'] as Map).cast<String, Object?>(),
              ),
        remote: CareerSnapshot.fromJson(
          (json['remoteSnapshot'] as Map).cast<String, Object?>(),
        ),
      );

  final String id;
  final int slotIndex;
  final CareerSnapshot? local;
  final CareerSnapshot remote;

  bool get localDeleted => local == null;
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
