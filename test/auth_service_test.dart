import 'dart:async';
import 'dart:convert';

import 'package:elevenward/src/services/api_models.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cached account remains available when Railway is offline', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final credentials = SecureCredentials();
    await credentials.writeAccountToken('token');
    await credentials.writeAccountProfile(
      '{"id":"account-1","alias":"Striker Player ABC123",'
      '"provider":"apple","publicUsername":"GoalAce",'
      '"usernameStatus":"active"}',
    );
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: credentials.readAccountToken,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    addTearDown(api.close);

    final account = await AuthService(
      api: api,
      credentials: credentials,
    ).restoreSession();

    expect(account?.publicUsername, 'GoalAce');
    expect(account?.leaderboardSharingEnabled, isFalse);
    expect(await credentials.readAccountToken(), 'token');
  });

  test('unauthorized session removes token and cached account', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final credentials = SecureCredentials();
    await credentials.writeAccountToken('expired-token');
    await credentials.writeAccountProfile(
      '{"id":"account-1","alias":"Alias","provider":"apple"}',
    );
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: credentials.readAccountToken,
      client: MockClient(
        (_) async => http.Response('{"error":"expired"}', 401),
      ),
    );
    addTearDown(api.close);

    final account = await AuthService(
      api: api,
      credentials: credentials,
    ).restoreSession();

    expect(account, isNull);
    expect(await credentials.readAccountToken(), isNull);
    expect(await credentials.readAccountProfile(), isNull);
  });

  test(
    'a delayed restored profile cannot resurrect a signed-out account',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final credentials = SecureCredentials();
      await credentials.writeAccountToken('old-token');
      await credentials.writeAccountProfile(
        jsonEncode({
          'id': 'account-a',
          'alias': 'Alias A',
          'provider': 'apple',
        }),
      );
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: credentials.readAccountToken,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/account')) {
            started.complete();
            return response.future;
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      final auth = AuthService(api: api, credentials: credentials);
      final restoring = auth.restoreSession();
      await started.future;
      final originalGeneration = auth.sessionGeneration;
      await auth.signOut();
      expect(auth.sessionGeneration, greaterThan(originalGeneration));
      response.complete(
        http.Response(
          jsonEncode({
            'account': {
              'id': 'account-a',
              'alias': 'Alias A',
              'provider': 'apple',
            },
          }),
          200,
        ),
      );
      expect(await restoring, isNull);
      expect(auth.currentAccount, isNull);
      expect(await credentials.readAccountToken(), isNull);
      expect(await credentials.readAccountProfile(), isNull);
    },
  );

  test('a stale 401 cannot clear a newly accepted account token', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final credentials = SecureCredentials();
    await credentials.writeAccountToken('old-token');
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: credentials.readAccountToken,
      client: MockClient((_) async {
        started.complete();
        return response.future;
      }),
    );
    addTearDown(api.close);
    final auth = AuthService(api: api, credentials: credentials);
    final restoring = auth.restoreSession();
    await started.future;
    await credentials.writeAccountToken('new-token');
    final newProfile = jsonEncode({
      'id': 'account-b',
      'alias': 'Alias B',
      'provider': 'apple',
    });
    await credentials.writeAccountProfile(newProfile);
    response.complete(http.Response('{"error":"expired"}', 401));
    await restoring;
    expect(await credentials.readAccountToken(), 'new-token');
    expect(await credentials.readAccountProfile(), newProfile);
  });

  test(
    'an older restore response cannot replace a newer authenticated profile',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final credentials = SecureCredentials();
      await credentials.writeAccountToken('old-token');
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: credentials.readAccountToken,
        client: MockClient((request) async {
          if (request.headers['authorization'] == 'Bearer old-token') {
            started.complete();
            return response.future;
          }
          return http.Response(
            jsonEncode({
              'account': {
                'id': 'account-b',
                'alias': 'Alias B',
                'provider': 'apple',
              },
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final auth = AuthService(api: api, credentials: credentials);
      final oldRestore = auth.restoreSession();
      await started.future;
      await credentials.writeAccountToken('new-token');
      expect((await auth.restoreSession())?.id, 'account-b');
      response.complete(
        http.Response(
          jsonEncode({
            'account': {
              'id': 'account-a',
              'alias': 'Alias A',
              'provider': 'apple',
            },
          }),
          200,
        ),
      );
      expect((await oldRestore)?.id, 'account-b');
      expect(auth.currentAccount?.id, 'account-b');
      expect(
        jsonDecode((await credentials.readAccountProfile())!)['id'],
        'account-b',
      );
    },
  );

  test(
    'a cached offline fallback and a profile update cannot undo sign-out',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final credentials = SecureCredentials();
      await credentials.writeAccountToken('old-token');
      await credentials.writeAccountProfile(
        jsonEncode({
          'id': 'account-a',
          'alias': 'Alias A',
          'provider': 'apple',
        }),
      );
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: credentials.readAccountToken,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/account')) {
            started.complete();
            return response.future;
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      final auth = AuthService(api: api, credentials: credentials);
      final restoring = auth.restoreSession();
      await started.future;
      await auth.signOut();
      response.completeError(http.ClientException('offline'));
      expect(await restoring, isNull);
      expect(auth.currentAccount, isNull);
      expect(await credentials.readAccountProfile(), isNull);
      await expectLater(
        auth.updateCurrentAccount(
          ElevenwardAccount.fromJson({
            'id': 'account-a',
            'alias': 'Alias A',
            'provider': 'apple',
          }),
        ),
        throwsStateError,
      );
      expect(await credentials.readAccountProfile(), isNull);
    },
  );
}
