import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late CareerStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => store.close());

  test('atomically saves and loads a canonical career snapshot', () async {
    final snapshot = CareerSnapshot.newCareer(seed: 77);
    await store.saveSlot(0, snapshot);
    final loaded = await store.loadSlot(0);
    expect(loaded?.encode(), snapshot.encode());
    final slots = await store.listSlots();
    expect(slots, hasLength(2));
    expect(slots.first.isOccupied, isTrue);
    expect(slots.last.isOccupied, isFalse);
  });

  test(
    'weekly focus preferences are isolated, validated, and removable',
    () async {
      await store.saveWeeklyFocus('career-a', PlayerAttribute.pace);
      await store.saveWeeklyFocus('career-b', PlayerAttribute.composure);

      expect(await store.loadWeeklyFocus('career-a'), PlayerAttribute.pace);
      expect(
        await store.loadWeeklyFocus('career-b'),
        PlayerAttribute.composure,
      );

      await store.setPreference(
        weeklyFocusPreferenceKey('career-a'),
        'not-an-attribute',
      );
      expect(
        await store.loadWeeklyFocus('career-a'),
        PlayerAttribute.finishing,
      );

      await store.removeWeeklyFocus('career-b');
      expect(
        await store.getPreference(weeklyFocusPreferenceKey('career-b')),
        isNull,
      );
    },
  );

  test('enforces free and entitled career slot limits', () async {
    await expectLater(
      store.saveSlot(2, CareerSnapshot.newCareer()),
      throwsRangeError,
    );
    final entitled = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      maxSlots: 5,
    );
    addTearDown(entitled.close);
    await entitled.saveSlot(4, CareerSnapshot.newCareer());
    expect(await entitled.loadSlot(4), isNotNull);
  });

  test('entitlement loss hides but never deletes premium slots', () async {
    store.updateMaxSlots(5);
    final premium = CareerSnapshot.newCareer(careerId: 'premium-slot');
    await store.saveSlot(4, premium);

    store.updateMaxSlots(2);
    expect(await store.listSlots(), hasLength(2));
    await expectLater(store.loadSlot(4), throwsRangeError);

    store.updateMaxSlots(5);
    expect((await store.loadSlot(4))?.encode(), premium.encode());
  });

  test('preserves both sides of a cloud conflict', () async {
    final local = CareerSnapshot.newCareer(seed: 1);
    final remote = local.copyWith(revision: 2, seed: 22);
    final id = await store.preserveConflict(
      local: local,
      remote: remote,
      createdAt: DateTime.utc(2026, 9, 3),
    );
    final conflicts = await store.listConflicts();
    expect(conflicts.single.localSnapshot.seed, 1);
    expect(conflicts.single.remoteSnapshot!.seed, 22);
    await store.resolveConflict(id, DateTime.utc(2026, 9, 4));
    expect(await store.listConflicts(), isEmpty);
  });

  test(
    'a deleted cloud conflict persists as literal null without a schema change',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'elevenward-null-conflict-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/career.sqlite';
      final durable = await CareerStore.open(
        path: path,
        factory: databaseFactoryFfi,
      );
      final local = CareerSnapshot.newCareer(
        careerId: 'local-cloud-deleted',
        seed: 11,
      );
      await durable.preserveConflict(
        local: local,
        remote: null,
        createdAt: DateTime.utc(2026, 10, 1),
        remoteRevision: 0,
        remoteConflictId: 'deleted-cloud-conflict',
      );
      await durable.close();
      final raw = await databaseFactoryFfi.openDatabase(path);
      final rows = await raw.query('cloud_conflicts');
      expect(rows.single['remote_snapshot_json'], 'null');
      expect(await raw.getVersion(), 7);
      await raw.close();
      final reopened = await CareerStore.open(
        path: path,
        factory: databaseFactoryFfi,
      );
      addTearDown(reopened.close);
      final conflict = (await reopened.listConflicts()).single;
      expect(conflict.localSnapshot.encode(), local.encode());
      expect(conflict.remoteSnapshot, isNull);
      expect(conflict.remoteDeleted, isTrue);
      expect(conflict.remoteRevision, 0);
      expect(conflict.localDeleted, isFalse);
    },
  );

  test(
    'a resolved cloud deletion removes only the reviewed live or tombstone row',
    () async {
      final first = CareerSnapshot.newCareer(careerId: 'cloud-delete-first');
      final other = CareerSnapshot.newCareer(careerId: 'cloud-delete-other');
      await store.saveSlot(0, first);
      await store.saveSlot(1, other);
      expect(
        await store.clearResolvedSlot(
          0,
          expectedCareerId: first.careerId,
          expectedRevision: first.revision,
        ),
        isTrue,
      );
      expect(await store.loadSlot(0), isNull);
      expect((await store.loadSlot(1))?.encode(), other.encode());

      await store.saveSlot(0, first);
      await store.markSynced(0, first.revision, 3);
      await store.deleteSlot(0, DateTime.utc(2026, 10, 1));
      final tombstone = (await store.listSlots()).first;
      expect(tombstone.isTombstone, isTrue);
      expect(
        await store.clearResolvedSlot(
          0,
          expectedCareerId: first.careerId,
          expectedRevision: tombstone.localRevision,
        ),
        isTrue,
      );
      expect((await store.listSlots()).first.isTombstone, isFalse);
    },
  );

  test(
    'cloud deletion preserves replaced, advanced, or another-session rows',
    () async {
      final original = CareerSnapshot.newCareer(careerId: 'original-deletion');
      final replacement = CareerSnapshot.newCareer(
        careerId: 'replacement-deletion',
      );
      await store.saveSlot(0, replacement);
      expect(
        await store.clearResolvedSlot(
          0,
          expectedCareerId: original.careerId,
          expectedRevision: original.revision,
        ),
        isFalse,
      );
      expect((await store.loadSlot(0))?.encode(), replacement.encode());
      final advanced = replacement.copyWith(revision: replacement.revision + 1);
      await store.saveSlot(0, advanced);
      expect(
        await store.clearResolvedSlot(
          0,
          expectedCareerId: replacement.careerId,
          expectedRevision: replacement.revision,
        ),
        isFalse,
      );
      await expectLater(
        store.clearResolvedSlot(
          0,
          expectedCareerId: advanced.careerId,
          expectedRevision: advanced.revision,
          isCurrentSession: () => false,
        ),
        throwsStateError,
      );
      expect((await store.loadSlot(0))?.encode(), advanced.encode());
    },
  );

  test('repeated pending remote IDs update one conflict comparison', () async {
    final local = CareerSnapshot.newCareer(
      careerId: 'idempotent-conflict',
      seed: 8,
    );
    final newer = local.copyWith(revision: local.revision + 2, seed: 999);
    final first = await store.preserveConflict(
      local: local,
      remote: local,
      remoteRevision: 7,
      remoteConflictId: 'same-pending-id',
      createdAt: DateTime.utc(2026, 10, 1),
    );
    final repeated = await store.preserveConflict(
      local: newer,
      remote: null,
      remoteRevision: 0,
      remoteConflictId: 'same-pending-id',
      createdAt: DateTime.utc(2026, 10, 1, 1),
    );
    expect(repeated, first);
    final conflict = (await store.listConflicts()).single;
    expect(conflict.localSnapshot.encode(), newer.encode());
    expect(conflict.remoteDeleted, isTrue);
    expect(conflict.remoteRevision, 0);
  });

  test('resolving a remote ID closes legacy duplicates and preserves unrelated conflicts', () async {
    final directory = await Directory.systemTemp.createTemp(
      'elevenward-duplicate-conflicts-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/career.sqlite';
    final durable = await CareerStore.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    final local = CareerSnapshot.newCareer(careerId: 'duplicate-source');
    final id = await durable.preserveConflict(
      local: local,
      remote: null,
      remoteConflictId: 'duplicated-remote-id',
      createdAt: DateTime.utc(2026, 10, 1),
    );
    await durable.preserveConflict(
      local: local,
      remote: local,
      remoteConflictId: 'unrelated-remote-id',
      createdAt: DateTime.utc(2026, 10, 1),
    );
    await durable.close();
    final raw = await databaseFactoryFfi.openDatabase(path);
    final duplicate = Map<String, Object?>.of(
      (await raw.query(
        'cloud_conflicts',
        where: 'id = ?',
        whereArgs: [id],
      )).single,
    )..remove('id');
    await raw.insert('cloud_conflicts', duplicate);
    await raw.close();
    final reopened = await CareerStore.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    addTearDown(reopened.close);
    expect(await reopened.listConflicts(), hasLength(3));
    await reopened.resolveConflict(id, DateTime.utc(2026, 10, 1, 2));
    final unresolved = await reopened.listConflicts();
    expect(unresolved, hasLength(1));
    expect(unresolved.single.remoteConflictId, 'unrelated-remote-id');
  });

  test(
    'preference acknowledgments remove only the exact draft they saved',
    () async {
      final original = <String, Object?>{
        'message': 'first report',
        'category': 'save',
      };
      final replacement = <String, Object?>{
        'message': 'new failed report',
        'category': 'cloud',
      };
      await store.setPreference('support.draft', original);
      await store.setPreference('support.draft', replacement);
      expect(
        await store.removePreferenceIfUnchanged('support.draft', original),
        isFalse,
      );
      expect(await store.getPreference('support.draft'), replacement);
      expect(
        await store.removePreferenceIfUnchanged('support.draft', replacement),
        isTrue,
      );
      expect(await store.getPreference('support.draft'), isNull);
    },
  );

  test(
    'remote application requires the reviewed local identity and revision',
    () async {
      final reviewed = CareerSnapshot.newCareer(
        careerId: 'reviewed-remote-apply',
      );
      final replacement = CareerSnapshot.newCareer(
        careerId: 'remote-apply-replacement',
      );
      await store.saveSlot(0, replacement);
      expect(
        await store.applyRemoteSlot(
          0,
          reviewed,
          5,
          expectedCareerId: reviewed.careerId,
          expectedRevision: reviewed.revision,
        ),
        isFalse,
      );
      final advanced = replacement.copyWith(revision: replacement.revision + 1);
      await store.saveSlot(0, advanced);
      expect(
        await store.applyRemoteSlot(
          0,
          reviewed,
          5,
          expectedCareerId: replacement.careerId,
          expectedRevision: replacement.revision,
        ),
        isFalse,
      );
      expect((await store.loadSlot(0))?.encode(), advanced.encode());
    },
  );

  test('an account change cancels a queued SQLite remote write', () async {
    final directory = await Directory.systemTemp.createTemp(
      'elevenward-queued-remote-write-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/career.sqlite';
    final durable = await CareerStore.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    addTearDown(durable.close);
    final local = CareerSnapshot.newCareer(careerId: 'session-local-apply');
    await durable.saveSlot(0, local);
    final raw = await databaseFactoryFfi.openDatabase(path);
    final started = Completer<void>();
    final release = Completer<void>();
    final holding = raw.transaction((txn) async {
      await txn.query('career_slots');
      started.complete();
      await release.future;
    });
    await started.future;
    var current = true;
    final remote = local.copyWith(revision: local.revision + 1, seed: 999);
    final rejected = expectLater(
      durable.applyRemoteSlot(
        0,
        remote,
        5,
        expectedCareerId: local.careerId,
        expectedRevision: local.revision,
        isCurrentSession: () => current,
      ),
      throwsStateError,
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    release.complete();
    await holding;
    await rejected;
    expect((await durable.loadSlot(0))?.encode(), local.encode());
  });

  test(
    'only a known account change retires old private conflict IDs',
    () async {
      final local = CareerSnapshot.newCareer(careerId: 'account-switch-local');
      await store.saveSlot(0, local);
      await store.adoptCloudAccount('account-a');
      await store.markSynced(0, local.revision, 7);
      await store.preserveConflict(
        local: local,
        remote: null,
        createdAt: DateTime.utc(2026, 10, 1),
        remoteConflictId: 'private-account-a-conflict',
      );
      await store.adoptCloudAccount('account-a');
      expect(await store.listConflicts(), hasLength(1));
      await store.adoptCloudAccount('account-b');
      expect(await store.listConflicts(), isEmpty);
      expect((await store.loadSlot(0))?.encode(), local.encode());
      expect((await store.listSlots()).first.serverRevision, 0);
      expect((await store.listSlots()).first.syncState, SlotSyncState.queued);
    },
  );

  test('delete clears a slot without touching other careers', () async {
    await store.saveSlot(0, CareerSnapshot.newCareer(careerId: 'career-a'));
    await store.saveSlot(1, CareerSnapshot.newCareer(careerId: 'career-b'));
    await store.deleteSlot(0, DateTime.utc(2026, 9, 4));
    expect(await store.loadSlot(0), isNull);
    expect((await store.loadSlot(1))?.careerId, 'career-b');
  });

  test(
    'synced deletion remains as a tombstone until cloud confirmation',
    () async {
      final snapshot = CareerSnapshot.newCareer(careerId: 'career-synced');
      await store.saveSlot(0, snapshot);
      await store.markSynced(0, snapshot.revision, 7);
      await store.deleteSlot(0, DateTime.utc(2026, 9, 4));

      final slot = (await store.listSlots()).first;
      expect(slot.snapshot, isNull);
      expect(slot.isTombstone, isTrue);
      expect(slot.tombstoneSnapshot?.careerId, snapshot.careerId);
      expect(slot.serverRevision, 7);
      expect(slot.syncState, SlotSyncState.queued);

      await store.clearTombstone(0);
      expect((await store.listSlots()).first.isTombstone, isFalse);
    },
  );

  test('corrupted current snapshot recovers from the event journal', () async {
    final directory = await Directory.systemTemp.createTemp('elevenward-db-');
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = '${directory.path}/career.sqlite';
    final recoveryStore = await CareerStore.open(
      path: databasePath,
      factory: databaseFactoryFfi,
    );
    final snapshot = CareerSnapshot.newCareer(careerId: 'career-recovery');
    await recoveryStore.saveSlot(0, snapshot, eventType: 'week_completed');
    await recoveryStore.close();
    final raw = await databaseFactoryFfi.openDatabase(databasePath);
    await raw.update('career_slots', {
      'snapshot_json': '{broken',
      'checksum': 'not-a-checksum',
    }, where: 'slot_index = 0');
    await raw.insert('career_events', {
      'career_id': snapshot.careerId,
      'revision': snapshot.revision + 1,
      'event_type': 'week_completed',
      'payload_json': '{truncated',
      'created_at': snapshot.updatedAt.toIso8601String(),
    });
    await raw.close();

    final reopened = await CareerStore.open(
      path: databasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(reopened.close);
    final slotsBeforeRecovery = await reopened.listSlots();
    expect(slotsBeforeRecovery.first.isOccupied, isTrue);
    expect(
      slotsBeforeRecovery.first.recoveryCode,
      matches(RegExp(r'^[a-f0-9]{8}$')),
    );
    expect(slotsBeforeRecovery.last.isOccupied, isFalse);
    final recovered = await reopened.loadSlot(0);
    expect(recovered?.encode(), snapshot.encode());
    expect(reopened.consumeRecoveryNotice(), contains('Recovered career'));
    expect((await reopened.listSlots()).first.recoveryCode, isNull);
  });

  test(
    'valid-checksum snapshot with invalid field types recovers safely',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'elevenward-type-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/career.sqlite';
      final recoveryStore = await CareerStore.open(
        path: databasePath,
        factory: databaseFactoryFfi,
      );
      final snapshot = CareerSnapshot.newCareer(
        careerId: 'career-invalid-type',
      );
      await recoveryStore.saveSlot(0, snapshot, eventType: 'career_started');
      await recoveryStore.close();

      final malformed = (jsonDecode(snapshot.encode()) as Map)
          .cast<String, Object?>();
      malformed['seed'] = 'not-an-integer';
      final encoded = jsonEncode(malformed);
      final raw = await databaseFactoryFfi.openDatabase(databasePath);
      await raw.update('career_slots', {
        'snapshot_json': encoded,
        'checksum': sha256.convert(utf8.encode(encoded)).toString(),
      }, where: 'slot_index = 0');
      await raw.close();

      final reopened = await CareerStore.open(
        path: databasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(reopened.close);
      final recovered = await reopened.loadSlot(0);
      expect(recovered?.encode(), snapshot.encode());
      expect(reopened.consumeRecoveryNotice(), contains('Recovered career'));
    },
  );

  test(
    'unrecoverable slot does not prevent another slot from loading',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'elevenward-loss-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/career.sqlite';
      final recoveryStore = await CareerStore.open(
        path: databasePath,
        factory: databaseFactoryFfi,
      );
      final damaged = CareerSnapshot.newCareer(careerId: 'career-damaged');
      final safe = CareerSnapshot.newCareer(careerId: 'career-safe', seed: 91);
      await recoveryStore.saveSlot(0, damaged);
      await recoveryStore.saveSlot(1, safe);
      await recoveryStore.close();

      final raw = await databaseFactoryFfi.openDatabase(databasePath);
      await raw.update('career_slots', {
        'snapshot_json': '{broken',
        'checksum': 'bad',
      }, where: 'slot_index = 0');
      await raw.update(
        'career_events',
        {'payload_json': '{truncated'},
        where: 'career_id = ?',
        whereArgs: [damaged.careerId],
      );
      await raw.close();

      final reopened = await CareerStore.open(
        path: databasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(reopened.close);
      final slots = await reopened.listSlots();
      expect(slots.first.recoveryCode, isNotNull);
      await expectLater(reopened.loadSlot(0), throwsFormatException);
      expect((await reopened.loadSlot(1))?.encode(), safe.encode());
    },
  );

  test(
    'upgrades a version-four database without losing its snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp('elevenward-v4-');
      addTearDown(() => directory.delete(recursive: true));
      final databasePath = '${directory.path}/career.sqlite';
      final raw = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, _) async {
            await db.execute('''
            CREATE TABLE career_slots (
              slot_index INTEGER PRIMARY KEY,
              career_id TEXT,
              snapshot_json TEXT,
              checksum TEXT,
              revision INTEGER NOT NULL DEFAULT 0,
              server_revision INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT,
              sync_state TEXT NOT NULL DEFAULT 'localOnly'
            )
          ''');
            await db.execute('''
            CREATE TABLE cloud_conflicts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              career_id TEXT NOT NULL,
              local_snapshot_json TEXT NOT NULL,
              remote_snapshot_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              resolved_at TEXT,
              slot_index INTEGER NOT NULL DEFAULT 0,
              remote_conflict_id TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE career_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              career_id TEXT NOT NULL,
              revision INTEGER NOT NULL,
              event_type TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
            await db.execute('''
            CREATE TABLE app_preferences (
              key TEXT PRIMARY KEY,
              value_json TEXT NOT NULL
            )
          ''');
          },
        ),
      );
      await raw.close();

      final upgraded = await CareerStore.open(
        path: databasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(upgraded.close);
      final snapshot = CareerSnapshot.newCareer(careerId: 'career-migrated');
      await upgraded.saveSlot(0, snapshot);
      expect((await upgraded.loadSlot(0))?.careerId, 'career-migrated');
      expect((await upgraded.listSlots()).first.isTombstone, isFalse);
    },
  );
}
