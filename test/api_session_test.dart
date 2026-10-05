import 'dart:async';

import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef GuardedOperation = Future<void> Function(
  ElevenwardApi api,
  bool Function() current,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  final career = CareerSnapshot.newCareer(careerId: 'session-career', seed: 71);
  final operations = <String, GuardedOperation>{
    'cloud slots': (api, current) async {
      await api.careerSlots(isCurrentSession: current);
    },
    'career upload': (api, current) async {
      await api.syncCareer(
        slotIndex: 0,
        baseRevision: 1,
        snapshot: career,
        publishLeaderboard: false,
        isCurrentSession: current,
      );
    },
    'career deletion': (api, current) async {
      await api.deleteCareerSlot(
        slotIndex: 0,
        baseRevision: 1,
        isCurrentSession: current,
      );
    },
    'conflict resolution': (api, current) async {
      await api.resolveConflict(
        slotIndex: 0,
        conflictId: 'pending-conflict',
        choice: 'local',
        publishLeaderboard: false,
        localSnapshot: career,
        expectedRemoteRevision: 1,
        isCurrentSession: current,
      );
    },
    'archive download': (api, current) async {
      await api.archives(isCurrentSession: current);
    },
    'archive upload': (api, current) async {
      await api.archive(career, isCurrentSession: current);
    },
    'archive deletion': (api, current) async {
      await api.deleteArchive(career.careerId, isCurrentSession: current);
    },
    'sharing preference': (api, current) async {
      await api.updateLeaderboardSharing(false, isCurrentSession: current);
    },
  };

  for (final operation in operations.entries) {
    test(
      '${operation.key} cannot send with a replacement account token',
      () async {
        var current = true;
        var sent = 0;
        final tokenStarted = Completer<void>();
        final token = Completer<String?>();
        final api = ElevenwardApi(
          baseUri: Uri.parse('https://api.example.test'),
          accessToken: () {
            tokenStarted.complete();
            return token.future;
          },
          client: MockClient((_) async {
            sent += 1;
            return http.Response('{}', 200);
          }),
        );
        addTearDown(api.close);
        final result = operation.value(api, () => current);
        final rejected = expectLater(result, throwsStateError);
        await tokenStarted.future;
        current = false;
        token.complete('different-account-token');
        await rejected;
        expect(sent, 0);
      },
    );

    test('${operation.key} rejects a response after account replacement', () async {
      var current = true;
      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'original-account-token',
        client: MockClient((request) {
          expect(
            request.headers['authorization'],
            'Bearer original-account-token',
          );
          requestStarted.complete();
          return response.future;
        }),
      );
      addTearDown(api.close);
      final result = operation.value(api, () => current);
      final rejected = expectLater(result, throwsStateError);
      await requestStarted.future;
      current = false;
      // The guard must reject before parsing an obsolete payload as new state.
      response.complete(http.Response('an obsolete payload', 200));
      await rejected;
    });
  }

  test(
    'synchronization forwards its guard through asynchronous token reads',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      await store.saveSlot(0, career, eventType: 'career_created');
      var current = true;
      var sent = 0;
      final tokenStarted = Completer<void>();
      final token = Completer<String?>();
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () {
          tokenStarted.complete();
          return token.future;
        },
        client: MockClient((_) async {
          sent += 1;
          return http.Response('{"slots":[]}', 200);
        }),
      );
      addTearDown(api.close);
      final sync = SyncService(api, store);
      final rejected = expectLater(
        sync.synchronize(
          publishLeaderboard: false,
          isCurrentSession: () => current,
        ),
        throwsStateError,
      );
      await tokenStarted.future;
      current = false;
      token.complete('replacement-token');
      await rejected;
      expect(sent, 0);
      expect((await store.loadSlot(0))?.encode(), career.encode());
    },
  );

  test(
    'auth sign-out invalidates a pending friend mutation before token use',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final credentials = SecureCredentials();
      await credentials.writeAccountToken('original-token');
      var tokenReads = 0;
      final firstToken = Completer<String?>();
      final started = Completer<void>();
      final sent = <String>[];
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () {
          tokenReads += 1;
          if (tokenReads == 1) {
            started.complete();
            return firstToken.future;
          }
          return Future.value('original-token');
        },
        client: MockClient((request) async {
          sent.add(request.url.path);
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      final auth = AuthService(api: api, credentials: credentials);
      final rejected = expectLater(
        api.requestFriend('invite-code'),
        throwsStateError,
      );
      await started.future;
      await auth.signOut();
      firstToken.complete('replacement-account-token');
      await rejected;
      expect(sent, ['/v1/elevenward/auth/sign-out']);
      expect(await credentials.readAccountToken(), isNull);
    },
  );

  test(
    'session invalidation blocks challenge enrollment during credential read',
    () async {
      final token = Completer<String?>();
      final started = Completer<void>();
      var sent = 0;
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () {
          started.complete();
          return token.future;
        },
        client: MockClient((_) async {
          sent += 1;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      final rejected = expectLater(
        api.enrollChallenge('weekly-id'),
        throwsStateError,
      );
      await started.future;
      api.invalidateSession();
      token.complete('replacement-account-token');
      await rejected;
      expect(sent, 0);
    },
  );

  test('foreground callers retain the existing optional-guard API', () async {
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: () async => 'token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer token');
        return http.Response('{"slots":[]}', 200);
      }),
    );
    addTearDown(api.close);
    expect(await api.careerSlots(), isEmpty);
  });
}
