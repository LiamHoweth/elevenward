import 'dart:convert';

import 'package:elevenward/src/services/api_models.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'leaderboard reads require an account and map reportable profiles',
    () async {
      final requests = <http.Request>[];
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'entries': [
                {
                  'rank': 1,
                  'alias': 'GoalAce',
                  'legacyScore': 412,
                  'aggregateMetrics': {'seasons': 3, 'trophies': 2},
                  'profileId': 'profile-1',
                  'isCurrentUser': false,
                  'reportable': true,
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);

      final entries = await api.leaderboard(
        position: PositionFamily.striker,
        difficulty: Difficulty.professional,
        rulesVersion: 'rules-1',
      );

      expect(requests.single.headers['authorization'], 'Bearer test-token');
      expect(requests.single.url.queryParameters['limit'], '25');
      expect(entries.single, isA<LeaderboardEntry>());
      expect(entries.single.profileId, 'profile-1');
      expect(entries.single.reportable, isTrue);
      expect(entries.single.seasons, 3);
    },
  );

  test(
    'username and report mutations send authenticated bounded payloads',
    () async {
      final requests = <http.Request>[];
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/account/username')) {
            return http.Response(
              jsonEncode({
                'account': {
                  'id': 'account-1',
                  'alias': 'GoalAce',
                  'provider': 'apple',
                  'publicUsername': 'GoalAce',
                  'usernameStatus': 'active',
                  'usernameCanChangeAt': '2026-10-28T12:00:00Z',
                },
              }),
              200,
            );
          }
          return http.Response('{"received":true}', 202);
        }),
      );
      addTearDown(api.close);

      final account = await api.updatePublicUsername(' GoalAce ');
      await api.reportLeaderboardUsername(
        profileId: 'profile-1',
        reason: 'impersonation',
      );

      expect(account.publicUsername, 'GoalAce');
      expect(account.usernameStatus, 'active');
      expect(jsonDecode(requests.first.body), {'username': 'GoalAce'});
      expect(jsonDecode(requests.last.body), {
        'profileId': 'profile-1',
        'reason': 'impersonation',
      });
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer test-token',
        ),
        isTrue,
      );
    },
  );

  test('sharing preference is saved on the account', () async {
    late http.Request sent;
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: () async => 'test-token',
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'account': {
              'id': 'account-1',
              'alias': 'Alias',
              'provider': 'apple',
              'leaderboardSharingEnabled': false,
            },
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final account = await api.updateLeaderboardSharing(false);

    expect(sent.url.path, '/v1/elevenward/account/leaderboard-sharing');
    expect(sent.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(sent.body), {'enabled': false});
    expect(account.leaderboardSharingEnabled, isFalse);
  });

  test('sync and conflict resolution carry the publication choice', () async {
    final career = CareerSnapshot.newCareer(careerId: 'career-1', seed: 31);
    final requests = <http.Request>[];
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: () async => 'test-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/sync')) {
          return http.Response(
            jsonEncode({
              'slot': {
                'slotIndex': 0,
                'snapshot': career.toJson(),
                'revision': 1,
                'checksum': 'checksum',
              },
            }),
            200,
          );
        }
        return http.Response('{"slot":null}', 200);
      }),
    );
    addTearDown(api.close);

    await api.syncCareer(
      slotIndex: 0,
      baseRevision: 0,
      snapshot: career,
      publishLeaderboard: false,
    );
    await api.resolveConflict(
      slotIndex: 0,
      conflictId: 'conflict-1',
      choice: 'local',
      publishLeaderboard: true,
    );

    expect(jsonDecode(requests.first.body)['publishLeaderboard'], isFalse);
    expect(jsonDecode(requests.last.body)['publishLeaderboard'], isTrue);
  });
}
