import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:elevenward_core/elevenward_core.dart';
import 'package:http/http.dart' as http;

import '../util/uuid.dart';
import 'api_models.dart';
import 'online_models.dart';

typedef AccessTokenReader = Future<String?> Function();

final class ElevenwardApi {
  ElevenwardApi({
    Uri? baseUri,
    http.Client? client,
    required AccessTokenReader accessToken,
  }) : baseUri =
           baseUri ??
           Uri.parse(
             const String.fromEnvironment(
               'ELEVENWARD_API_BASE_URL',
               defaultValue: 'https://api.howethstudio.com',
             ),
           ),
       _client = client ?? http.Client(),
       _accessToken = accessToken; // ignore: prefer_initializing_formals

  final Uri baseUri;
  final http.Client _client;
  final AccessTokenReader _accessToken;
  int _sessionEpoch = 0;

  /// Invalidates every pending request when the authenticated identity changes.
  /// Capturing this epoch also protects foreground friends/challenge actions.
  void invalidateSession() => _sessionEpoch += 1;

  static const _requestTimeout = Duration(seconds: 15);

  Uri _uri(String path, [Map<String, String>? query]) =>
      baseUri.replace(path: '/v1/elevenward$path', queryParameters: query);

  Future<AuthSession> authenticateApple({
    required String identityToken,
    required String authorizationCode,
    required String nonce,
  }) async {
    final body = await _send(
      'POST',
      '/auth/apple',
      authenticated: false,
      body: {
        'identityToken': identityToken,
        'authorizationCode': authorizationCode,
        'nonce': nonce,
      },
    );
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> authenticateGoogle({required String idToken}) async {
    final body = await _send(
      'POST',
      '/auth/google',
      authenticated: false,
      body: {'idToken': idToken},
    );
    return AuthSession.fromJson(body);
  }

  Future<ElevenwardAccount> account() async {
    final body = await _send('GET', '/account');
    return ElevenwardAccount.fromJson(
      (body['account'] as Map).cast<String, Object?>(),
    );
  }

  Future<ElevenwardAccount> updatePublicUsername(String username) async {
    final body = await _send(
      'PUT',
      '/account/username',
      body: {'username': username.trim()},
    );
    return ElevenwardAccount.fromJson(
      (body['account'] as Map).cast<String, Object?>(),
    );
  }

  Future<ElevenwardAccount> updateLeaderboardSharing(
    bool enabled, {
    bool Function()? isCurrentSession,
  }) async {
    final body = await _send(
      'PUT',
      '/account/leaderboard-sharing',
      isCurrentSession: isCurrentSession,
      body: {'enabled': enabled},
    );
    return ElevenwardAccount.fromJson(
      (body['account'] as Map).cast<String, Object?>(),
    );
  }

  Future<void> reportLeaderboardUsername({
    required String profileId,
    required String reason,
  }) => _sendEmpty(
    'POST',
    '/leaderboard-reports',
    body: {'profileId': profileId, 'reason': reason},
  );

  Future<void> signOut() => _sendEmpty('POST', '/auth/sign-out');
  Future<void> deleteAccount() => _sendEmpty('DELETE', '/account');

  Future<Map<String, Object?>> createDeletionChallenge() =>
      _send('POST', '/account/deletion-challenge');

  Future<List<RemoteCareerSlot>> careerSlots({
    bool Function()? isCurrentSession,
  }) async {
    final body = await _send(
      'GET',
      '/career-slots',
      isCurrentSession: isCurrentSession,
    );
    return (body['slots'] as List<Object?>)
        .map(
          (item) =>
              RemoteCareerSlot.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(growable: false);
  }

  Future<SyncOutcome> syncCareer({
    required int slotIndex,
    required int baseRevision,
    required CareerSnapshot snapshot,
    required bool publishLeaderboard,
    String? idempotencyKey,
    bool Function()? isCurrentSession,
  }) async {
    final response = await _raw(
      'PUT',
      '/career-slots/$slotIndex/sync',
      isCurrentSession: isCurrentSession,
      body: {
        'baseRevision': baseRevision,
        'idempotencyKey': idempotencyKey ?? generateUuidV4(),
        'snapshot': snapshot.toJson(),
        'publishLeaderboard': publishLeaderboard,
      },
    );
    final body = _decode(response);
    if (response.statusCode == 409) {
      return SyncConflict(
        RemoteSyncConflict.fromJson(
          (body['conflict'] as Map).cast<String, Object?>(),
        ),
      );
    }
    _throwUnlessSuccess(response, body);
    return SyncAccepted(
      RemoteCareerSlot.fromJson((body['slot'] as Map).cast<String, Object?>()),
    );
  }

  Future<RemoteCareerSlot?> resolveConflict({
    required int slotIndex,
    required String conflictId,
    required String choice,
    required bool publishLeaderboard,
    CareerSnapshot? localSnapshot,
    int? expectedRemoteRevision,
    bool Function()? isCurrentSession,
  }) async {
    final body = await _send(
      'POST',
      '/career-slots/$slotIndex/conflicts/$conflictId/resolve',
      isCurrentSession: isCurrentSession,
      body: {
        'choice': choice,
        'publishLeaderboard': publishLeaderboard,
        if (localSnapshot != null) 'localSnapshot': localSnapshot.toJson(),
        'expectedRemoteRevision': ?expectedRemoteRevision,
      },
    );
    final slot = body['slot'];
    return slot == null
        ? null
        : RemoteCareerSlot.fromJson((slot as Map).cast<String, Object?>());
  }

  Future<SyncOutcome> deleteCareerSlot({
    required int slotIndex,
    required int baseRevision,
    bool Function()? isCurrentSession,
  }) async {
    final response = await _raw(
      'DELETE',
      '/career-slots/$slotIndex',
      isCurrentSession: isCurrentSession,
      query: {'baseRevision': '$baseRevision'},
    );
    final body = _decode(response);
    if (response.statusCode == 409) {
      return SyncConflict(
        RemoteSyncConflict.fromJson(
          (body['conflict'] as Map).cast<String, Object?>(),
        ),
      );
    }
    _throwUnlessSuccess(response, body);
    return const SyncDeleted();
  }

  Future<Map<String, Object?>> manifest() =>
      _send('GET', '/content/manifest', authenticated: false);

  Future<List<Map<String, Object?>>> entitlements() async {
    final body = await _send('GET', '/entitlements');
    return (body['entitlements'] as List<Object?>)
        .map((item) => (item as Map).cast<String, Object?>())
        .toList(growable: false);
  }

  Future<void> setAnalyticsConsent({
    required bool granted,
    required String policyVersion,
  }) => _sendEmpty(
    'PUT',
    '/analytics/consent',
    body: {
      'state': granted ? 'granted' : 'denied',
      'policyVersion': policyVersion,
    },
  );

  Future<int> sendAnalytics(List<Map<String, Object?>> events) async {
    final body = await _send(
      'POST',
      '/analytics/events',
      body: {'events': events},
    );
    return body['accepted'] as int;
  }

  Future<void> submitLeaderboard(CareerSnapshot snapshot) => _sendEmpty(
    'POST',
    '/leaderboards/submissions',
    body: {
      'careerId': snapshot.careerId,
      'position': snapshot.player.position.name,
      'difficulty': _apiDifficulty(snapshot.difficulty),
      'rulesVersion': snapshot.rulesVersion,
      'aggregateMetrics': {
        'seasons': snapshot.seasonHistory.length.clamp(1, 20),
        'matches': snapshot.player.appearances,
        'legacyScore': snapshot.legacyScore,
        'goals': snapshot.player.goals,
        'assists': snapshot.player.assists,
        'trophies': snapshot.seasonHistory.fold<int>(
          0,
          (sum, season) => sum + season.trophies.length,
        ),
      },
      'validationEvidence': {
        'seed': snapshot.seed,
        'finalRevision': snapshot.revision,
        'snapshotChecksum': sha256Snapshot(snapshot),
        'boostIdsUsed': snapshot.boostIdsUsed,
        'developmentProgress': {
          for (final entry in snapshot.developmentProgress.entries)
            entry.key.name: entry.value,
        },
      },
    },
  );

  Future<List<LeaderboardEntry>> leaderboard({
    required PositionFamily position,
    required Difficulty difficulty,
    required String rulesVersion,
  }) async {
    final body = await _send(
      'GET',
      '/leaderboards',
      query: {
        'position': position.name,
        'difficulty': _apiDifficulty(difficulty),
        'rulesVersion': rulesVersion,
        'limit': '25',
      },
    );
    return (body['entries'] as List<Object?>)
        .map(
          (item) =>
              LeaderboardEntry.fromJson((item as Map).cast<String, Object?>()),
        )
        .toList(growable: false);
  }

  Future<LeaderboardPage> leaderboardPage({
    required PositionFamily position,
    required Difficulty difficulty,
    required String rulesVersion,
    String? careerId,
  }) async {
    final body = await _send(
      'GET',
      '/leaderboards',
      query: {
        'position': position.name,
        'difficulty': _apiDifficulty(difficulty),
        'rulesVersion': rulesVersion,
        'limit': '25',
        'careerId': ?careerId,
      },
    );
    return LeaderboardPage.fromJson(body);
  }

  Future<void> sendFeedback(Map<String, Object?> submission) =>
      _sendEmpty('POST', '/feedback', authenticated: false, body: submission);

  Future<List<CareerSnapshot>> archives({
    bool Function()? isCurrentSession,
  }) async {
    final body = await _send(
      'GET',
      '/career-archives',
      isCurrentSession: isCurrentSession,
    );
    return (body['archives'] as List)
        .map(
          (e) => CareerSnapshot.fromJson(
            onlineObject(onlineObject(e)['snapshot']),
          ),
        )
        .toList();
  }

  Future<void> archive(
    CareerSnapshot snapshot, {
    bool Function()? isCurrentSession,
  }) => _sendEmpty(
    'POST',
    '/career-archives',
    isCurrentSession: isCurrentSession,
    body: {'snapshot': snapshot.toJson()},
  );
  Future<void> deleteArchive(
    String careerId, {
    bool Function()? isCurrentSession,
  }) => _sendEmpty(
    'DELETE',
    '/career-archives/$careerId',
    isCurrentSession: isCurrentSession,
  );
  Future<FriendsState> friends() async =>
      FriendsState.fromJson(await _send('GET', '/friends'));
  Future<void> setFriendSharing(bool enabled) => _sendEmpty(
    'PUT',
    '/account/friend-comparison-sharing',
    body: {'enabled': enabled},
  );
  Future<Map<String, Object?>> createFriendCode() =>
      _send('POST', '/friends/invite-code', body: {});
  Future<void> requestFriend(String inviteCode) =>
      _sendEmpty('POST', '/friends/requests', body: {'inviteCode': inviteCode});
  Future<void> respondFriend(String requestId, bool accept) => _sendEmpty(
    'POST',
    '/friends/requests/$requestId/respond',
    body: {'accept': accept},
  );
  Future<void> removeFriend(String profileId) =>
      _sendEmpty('DELETE', '/friends/$profileId');
  Future<void> blockFriend(String profileId) =>
      _sendEmpty('POST', '/friends/$profileId/block', body: {});
  Future<void> unblockFriend(String profileId) =>
      _sendEmpty('DELETE', '/friends/$profileId/block');
  Future<ChallengeState> currentChallenge() async =>
      ChallengeState.fromJson(await _send('GET', '/challenges/current'));
  Future<ChallengeAttempt> enrollChallenge(String challengeId) async {
    final body = await _send(
      'POST',
      '/challenges/$challengeId/enroll',
      body: {},
    );
    return ChallengeAttempt.fromJson(onlineObject(body['attempt']));
  }

  Future<Map<String, Object?>> submitChallenge(
    String challengeId,
    String attemptId,
    List<Map<String, Object?>> actions,
  ) => _send(
    'POST',
    '/challenges/$challengeId/submit',
    body: {'attemptId': attemptId, 'actions': actions},
  );

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    bool authenticated = true,
    bool Function()? isCurrentSession,
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final response = await _raw(
      method,
      path,
      authenticated: authenticated,
      isCurrentSession: isCurrentSession,
      body: body,
      query: query,
    );
    final decoded = _decode(response);
    _throwUnlessSuccess(response, decoded);
    return decoded;
  }

  Future<void> _sendEmpty(
    String method,
    String path, {
    bool authenticated = true,
    bool Function()? isCurrentSession,
    Map<String, Object?>? body,
  }) async {
    final response = await _raw(
      method,
      path,
      authenticated: authenticated,
      isCurrentSession: isCurrentSession,
      body: body,
    );
    final decoded = _decode(response);
    _throwUnlessSuccess(response, decoded);
  }

  Future<http.Response> _raw(
    String method,
    String path, {
    bool authenticated = true,
    bool Function()? isCurrentSession,
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final requestSession = _sessionEpoch;
    void checkSession() {
      if (requestSession != _sessionEpoch ||
          isCurrentSession?.call() == false) {
        throw StateError('Account changed during the request.');
      }
    }

    checkSession();
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authenticated) {
      final token = await _accessToken();
      checkSession();
      if (token == null) throw const ApiFailure(401, 'Sign in is required.');
      headers['authorization'] = 'Bearer $token';
    }
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    checkSession();
    final request = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encoded),
      'PUT' => _client.put(uri, headers: headers, body: encoded),
      'DELETE' => _client.delete(uri, headers: headers, body: encoded),
      _ => throw ArgumentError.value(method, 'method'),
    };
    final response = await request.timeout(_requestTimeout);
    checkSession();
    return response;
  }

  Map<String, Object?> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map ? decoded.cast<String, Object?>() : const {};
  }

  void _throwUnlessSuccess(http.Response response, Map<String, Object?> body) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiFailure(
      response.statusCode,
      body['error'] as String? ?? 'The server could not complete the request.',
    );
  }

  String _apiDifficulty(Difficulty difficulty) => switch (difficulty) {
    Difficulty.story => 'story',
    Difficulty.professional => 'balanced',
    Difficulty.worldClass => 'elite',
  };

  String sha256Snapshot(CareerSnapshot snapshot) {
    // This checksum is evidence, not a secret. The backend performs additional
    // plausibility checks and never awards valuable leaderboard prizes.
    return crypto.sha256.convert(utf8.encode(snapshot.encode())).toString();
  }

  void close() => _client.close();
}
