import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:elevenward_core/elevenward_core.dart';
import 'package:http/http.dart' as http;

import '../util/uuid.dart';
import 'api_models.dart';

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

  Future<void> signOut() => _sendEmpty('POST', '/auth/sign-out');
  Future<void> deleteAccount() => _sendEmpty('DELETE', '/account');

  Future<Map<String, Object?>> createDeletionChallenge() =>
      _send('POST', '/account/deletion-challenge');

  Future<List<RemoteCareerSlot>> careerSlots() async {
    final body = await _send('GET', '/career-slots');
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
    String? idempotencyKey,
  }) async {
    final response = await _raw(
      'PUT',
      '/career-slots/$slotIndex/sync',
      body: {
        'baseRevision': baseRevision,
        'idempotencyKey': idempotencyKey ?? generateUuidV4(),
        'snapshot': snapshot.toJson(),
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
  }) async {
    final body = await _send(
      'POST',
      '/career-slots/$slotIndex/conflicts/$conflictId/resolve',
      body: {'choice': choice},
    );
    final slot = body['slot'];
    return slot == null
        ? null
        : RemoteCareerSlot.fromJson((slot as Map).cast<String, Object?>());
  }

  Future<SyncOutcome> deleteCareerSlot({
    required int slotIndex,
    required int baseRevision,
  }) async {
    final response = await _raw(
      'DELETE',
      '/career-slots/$slotIndex',
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
      },
    },
  );

  Future<List<Map<String, Object?>>> leaderboard({
    required PositionFamily position,
    required Difficulty difficulty,
    required String rulesVersion,
  }) async {
    final body = await _send(
      'GET',
      '/leaderboards',
      authenticated: false,
      query: {
        'position': position.name,
        'difficulty': _apiDifficulty(difficulty),
        'rulesVersion': rulesVersion,
      },
    );
    return (body['entries'] as List<Object?>)
        .map((item) => (item as Map).cast<String, Object?>())
        .toList(growable: false);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    bool authenticated = true,
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final response = await _raw(
      method,
      path,
      authenticated: authenticated,
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
    Map<String, Object?>? body,
  }) async {
    final response = await _raw(
      method,
      path,
      authenticated: authenticated,
      body: body,
    );
    final decoded = _decode(response);
    _throwUnlessSuccess(response, decoded);
  }

  Future<http.Response> _raw(
    String method,
    String path, {
    bool authenticated = true,
    Map<String, Object?>? body,
    Map<String, String>? query,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authenticated) {
      final token = await _accessToken();
      if (token == null) throw const ApiFailure(401, 'Sign in is required.');
      headers['authorization'] = 'Bearer $token';
    }
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    final request = switch (method) {
      'GET' => _client.get(uri, headers: headers),
      'POST' => _client.post(uri, headers: headers, body: encoded),
      'PUT' => _client.put(uri, headers: headers, body: encoded),
      'DELETE' => _client.delete(uri, headers: headers, body: encoded),
      _ => throw ArgumentError.value(method, 'method'),
    };
    return request.timeout(_requestTimeout);
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
