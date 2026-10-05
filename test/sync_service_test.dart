import 'dart:async';
import 'dart:convert';

import 'package:elevenward/src/services/api_models.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('downloads cloud-only careers and reports visible progress', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final cloudCareer = CareerSnapshot.newCareer(
      careerId: 'cloud-only-career',
      seed: 707,
    );
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/elevenward/career-slots');
      expect(request.headers['authorization'], 'Bearer test-token');
      return http.Response(
        jsonEncode({
          'slots': [
            {
              'slotIndex': 1,
              'snapshot': cloudCareer.toJson(),
              'revision': 9,
              'checksum': List.filled(64, 'a').join(),
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = SyncService(
      ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        client: client,
        accessToken: () async => 'test-token',
      ),
      store,
    );
    final progress = <SyncProgressUpdate>[];

    final report = await service.synchronize(
      publishLeaderboard: true,
      onProgress: progress.add,
    );

    expect(report.downloaded, 1);
    expect(report.uploaded, 0);
    expect((await store.loadSlot(1))?.careerId, cloudCareer.careerId);
    expect(progress.first.phase, SyncProgressPhase.loading);
    expect(progress.last.phase, SyncProgressPhase.complete);
    expect(progress.last.completed, progress.last.total);
  });

  test(
    'the backend null-cloud conflict contract parses without inventing a save',
    () {
      final local = CareerSnapshot.newCareer(careerId: 'contract-local');
      final conflict = RemoteSyncConflict.fromJson({
        'conflictId': 'real-contract-conflict',
        'slotIndex': 0,
        'localSnapshot': local.toJson(),
        'remoteSnapshot': null,
        'remoteRevision': 0,
      });
      expect(conflict.remote, isNull);
      expect(conflict.remoteDeleted, isTrue);
      expect(conflict.remoteRevision, 0);
      expect(conflict.local?.encode(), local.encode());
      expect(conflict.localDeleted, isFalse);
    },
  );

  test(
    'synchronization preserves a deleted cloud side from the real response',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final local = CareerSnapshot.newCareer(
        careerId: 'cloud-was-deleted',
        seed: 71,
      );
      await store.saveSlot(0, local);
      await store.markSynced(0, local.revision, 5);
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'token',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"slots":[]}', 200);
          }
          expect(jsonDecode(request.body)['baseRevision'], 5);
          return http.Response(
            jsonEncode({
              'conflict': {
                'conflictId': 'deleted-cloud-conflict',
                'slotIndex': 0,
                'localSnapshot': local.toJson(),
                'remoteSnapshot': null,
                'remoteRevision': 0,
              },
            }),
            409,
          );
        }),
      );
      addTearDown(api.close);
      final report = await SyncService(
        api,
        store,
      ).synchronize(publishLeaderboard: false);
      expect(report.conflicts, 1);
      final conflict = (await store.listConflicts()).single;
      expect(conflict.remoteDeleted, isTrue);
      expect(conflict.remoteSnapshot, isNull);
      expect(conflict.remoteRevision, 0);
      expect(conflict.localSnapshot.encode(), local.encode());
      expect((await store.listSlots()).first.syncState, SlotSyncState.conflict);
    },
  );

  test(
    'keep local after cloud deletion uploads current progress with CAS0',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final original = CareerSnapshot.newCareer(
        careerId: 'keep-current-local',
        seed: 74,
      );
      final current = const WeeklySimulator()
          .advance(
            snapshot: original,
            opponent: const WorldSimulator().opponentFor(original),
            updatedAt: DateTime.utc(2026, 10, 1),
            choice: const WeeklyChoice(
              focus: PlayerAttribute.finishing,
              intensity: TrainingIntensity.balanced,
              spotlightApproach: SpotlightApproach.balanced,
            ),
          )
          .snapshot;
      await store.saveSlot(0, current);
      final conflictId = await store.preserveConflict(
        local: original,
        remote: null,
        createdAt: DateTime.utc(2026, 10, 1),
        remoteRevision: 0,
        remoteConflictId: 'keep-local-deleted-cloud',
      );
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['choice'], 'local');
          expect(body['expectedRemoteRevision'], 0);
          expect(body['localSnapshot'], current.toJson());
          return http.Response(
            jsonEncode({
              'slot': {
                'slotIndex': 0,
                'snapshot': current.toJson(),
                'revision': 1,
                'checksum': List.filled(64, 'a').join(),
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      await SyncService(api, store).resolve(
        localConflictId: conflictId,
        slotIndex: 0,
        remoteConflictId: 'keep-local-deleted-cloud',
        keepLocal: true,
        publishLeaderboard: false,
        localSnapshot: current,
        expectedRemoteRevision: 0,
        expectedCareerId: current.careerId,
        expectedLocalRevision: current.revision,
      );
      expect((await store.loadSlot(0))?.encode(), current.encode());
      expect((await store.listSlots()).first.serverRevision, 1);
      expect(await store.listConflicts(), isEmpty);
    },
  );

  test(
    'choosing the deleted cloud side removes the reviewed live career',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final local = CareerSnapshot.newCareer(careerId: 'accept-cloud-deletion');
      await store.saveSlot(0, local);
      final conflictId = await store.preserveConflict(
        local: local,
        remote: null,
        createdAt: DateTime.utc(2026, 10, 1),
        remoteConflictId: 'cloud-delete-resolution',
      );
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'token',
        client: MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['choice'], 'remote');
          expect(body['expectedRemoteRevision'], 0);
          return http.Response('{"slot":null,"resolution":"remote"}', 200);
        }),
      );
      addTearDown(api.close);
      await SyncService(api, store).resolve(
        localConflictId: conflictId,
        slotIndex: 0,
        remoteConflictId: 'cloud-delete-resolution',
        keepLocal: false,
        publishLeaderboard: false,
        expectedRemoteRevision: 0,
        expectedCareerId: local.careerId,
        expectedLocalRevision: local.revision,
      );
      expect(await store.loadSlot(0), isNull);
      expect((await store.listSlots()).first.isOccupied, isFalse);
      expect(await store.listConflicts(), isEmpty);
    },
  );

  for (final replacement in [false, true]) {
    test(
      'cloud deletion cannot remove a ${replacement ? 'replacement' : 'newer'} career after request',
      () async {
        final store = await CareerStore.open(
          path: inMemoryDatabasePath,
          factory: databaseFactoryFfi,
        );
        addTearDown(store.close);
        final original = CareerSnapshot.newCareer(
          careerId: 'racing-cloud-deletion',
        );
        await store.saveSlot(0, original);
        final conflictId = await store.preserveConflict(
          local: original,
          remote: null,
          createdAt: DateTime.utc(2026, 10, 1),
          remoteConflictId: 'racing-cloud-conflict',
        );
        final started = Completer<void>();
        final response = Completer<http.Response>();
        final api = ElevenwardApi(
          baseUri: Uri.parse('https://api.example.test'),
          accessToken: () async => 'token',
          client: MockClient((_) {
            started.complete();
            return response.future;
          }),
        );
        addTearDown(api.close);
        final rejected = expectLater(
          SyncService(api, store).resolve(
            localConflictId: conflictId,
            slotIndex: 0,
            remoteConflictId: 'racing-cloud-conflict',
            keepLocal: false,
            publishLeaderboard: false,
            expectedRemoteRevision: 0,
            expectedCareerId: original.careerId,
            expectedLocalRevision: original.revision,
          ),
          throwsStateError,
        );
        await started.future;
        final current = replacement
            ? CareerSnapshot.newCareer(careerId: 'new-replacement-career')
            : original.copyWith(revision: original.revision + 1);
        await store.saveSlot(0, current);
        response.complete(http.Response('{"slot":null}', 200));
        await rejected;
        expect((await store.loadSlot(0))?.encode(), current.encode());
        expect(
          (await store.listConflicts()).single.localSnapshot.encode(),
          original.encode(),
        );
      },
    );
  }

  test(
    'repeated pending conflicts compare latest committed local progress',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final original = CareerSnapshot.newCareer(
        careerId: 'pending-retry-career',
        seed: 75,
      );
      await store.saveSlot(0, original);
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var uploads = 0;
      final conflictResponse = http.Response(
        jsonEncode({
          'conflict': {
            'conflictId': 'same-pending-conflict',
            'slotIndex': 0,
            'localSnapshot': original.toJson(),
            'remoteSnapshot': null,
            'remoteRevision': 0,
          },
        }),
        409,
      );
      final api = ElevenwardApi(
        baseUri: Uri.parse('https://api.example.test'),
        accessToken: () async => 'token',
        client: MockClient((request) {
          if (request.method == 'GET') {
            return Future.value(http.Response('{"slots":[]}', 200));
          }
          uploads += 1;
          if (uploads == 1) {
            started.complete();
            return response.future;
          }
          return Future.value(conflictResponse);
        }),
      );
      addTearDown(api.close);
      final service = SyncService(api, store);
      final synchronizing = service.synchronize(publishLeaderboard: false);
      await started.future;
      final advanced = original.copyWith(
        revision: original.revision + 1,
        seed: 999,
      );
      await store.saveSlot(0, advanced);
      response.complete(conflictResponse);
      await synchronizing;
      expect(
        (await store.listConflicts()).single.localSnapshot.encode(),
        advanced.encode(),
      );
      final latest = advanced.copyWith(
        revision: advanced.revision + 1,
        seed: 1000,
      );
      await store.saveSlot(0, latest);
      await service.synchronize(publishLeaderboard: false);
      final conflicts = await store.listConflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.localSnapshot.encode(), latest.encode());
      expect(conflicts.single.remoteDeleted, isTrue);
    },
  );

  test('an old pending conflict never adopts a replacement career as its local side', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final original = CareerSnapshot.newCareer(
      careerId: 'original-pending-career',
    );
    final replacement = CareerSnapshot.newCareer(
      careerId: 'replacement-pending-career',
    );
    await store.saveSlot(0, replacement);
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://api.example.test'),
      accessToken: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"slots":[]}', 200);
        }
        return http.Response(
          jsonEncode({
            'conflict': {
              'conflictId': 'original-pending-id',
              'slotIndex': 0,
              'localSnapshot': original.toJson(),
              'remoteSnapshot': null,
              'remoteRevision': 0,
            },
          }),
          409,
        );
      }),
    );
    addTearDown(api.close);
    await SyncService(api, store).synchronize(publishLeaderboard: false);
    expect(
      (await store.listConflicts()).single.localSnapshot.encode(),
      original.encode(),
    );
    expect((await store.loadSlot(0))?.encode(), replacement.encode());
  });

  for (final replacement in [false, true]) {
    test(
      'a nonnull cloud resolution preserves a ${replacement ? 'replacement' : 'newer'} career',
      () async {
        final store = await CareerStore.open(
          path: inMemoryDatabasePath,
          factory: databaseFactoryFfi,
        );
        addTearDown(store.close);
        final reviewed = CareerSnapshot.newCareer(
          careerId: 'nonnull-reviewed-local',
        );
        final cloud = reviewed.copyWith(
          revision: reviewed.revision + 2,
          seed: 992,
        );
        await store.saveSlot(0, reviewed);
        final conflictId = await store.preserveConflict(
          local: reviewed,
          remote: cloud,
          createdAt: DateTime.utc(2026, 10, 1),
          remoteConflictId: 'nonnull-pending-conflict',
          remoteRevision: 5,
        );
        final started = Completer<void>();
        final response = Completer<http.Response>();
        final api = ElevenwardApi(
          baseUri: Uri.parse('https://api.example.test'),
          accessToken: () async => 'token',
          client: MockClient((_) {
            started.complete();
            return response.future;
          }),
        );
        addTearDown(api.close);
        final rejected = expectLater(
          SyncService(api, store).resolve(
            localConflictId: conflictId,
            slotIndex: 0,
            remoteConflictId: 'nonnull-pending-conflict',
            keepLocal: false,
            publishLeaderboard: false,
            expectedRemoteRevision: 5,
            expectedCareerId: reviewed.careerId,
            expectedLocalRevision: reviewed.revision,
          ),
          throwsStateError,
        );
        await started.future;
        final current = replacement
            ? CareerSnapshot.newCareer(careerId: 'nonnull-replacement-local')
            : reviewed.copyWith(revision: reviewed.revision + 1);
        await store.saveSlot(0, current);
        response.complete(
          http.Response(
            jsonEncode({
              'slot': {
                'slotIndex': 0,
                'snapshot': cloud.toJson(),
                'revision': 6,
                'checksum': List.filled(64, 'a').join(),
              },
            }),
            200,
          ),
        );
        await rejected;
        expect((await store.loadSlot(0))?.encode(), current.encode());
        expect(await store.listConflicts(), hasLength(1));
      },
    );
  }
}
