import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

enum SlotSyncState { localOnly, queued, synced, conflict }

final class SavedCareerSlot {
  const SavedCareerSlot({
    required this.slotIndex,
    required this.snapshot,
    required this.syncState,
    required this.serverRevision,
    required this.localRevision,
    this.tombstoneSnapshot,
    this.recoveryCode,
  });

  final int slotIndex;
  final CareerSnapshot? snapshot;
  final SlotSyncState syncState;
  final int serverRevision;
  final int localRevision;
  final CareerSnapshot? tombstoneSnapshot;
  final String? recoveryCode;

  bool get isOccupied => snapshot != null || recoveryCode != null;
  bool get isTombstone => snapshot == null && tombstoneSnapshot != null;
}

final class PreservedConflict {
  const PreservedConflict({
    required this.id,
    required this.careerId,
    required this.localSnapshot,
    required this.remoteSnapshot,
    required this.createdAt,
    required this.slotIndex,
    this.remoteConflictId,
    this.localDeleted = false,
    this.remoteRevision = 0,
  });

  final int id;
  final String careerId;
  final CareerSnapshot localSnapshot;
  final CareerSnapshot? remoteSnapshot;
  final DateTime createdAt;
  final int slotIndex;
  final String? remoteConflictId;
  final bool localDeleted;
  final int remoteRevision;

  bool get remoteDeleted => remoteSnapshot == null;
}

/// SQLite-backed career slots with versioned snapshots and a recovery journal.
final class CareerStore {
  CareerStore._(this._database, {required this._maxSlots});

  static const schemaVersion = 7;

  final Database _database;
  String? _recoveryNotice;
  int _maxSlots;
  int get maxSlots => _maxSlots;

  String? consumeRecoveryNotice() {
    final notice = _recoveryNotice;
    _recoveryNotice = null;
    return notice;
  }

  void updateMaxSlots(int value) {
    if (value != 2 && value != 5) {
      throw ArgumentError.value(
        value,
        'value',
        'Only two or five slots are supported.',
      );
    }
    _maxSlots = value;
  }

  static Future<CareerStore> open({
    String? path,
    DatabaseFactory? factory,
    int maxSlots = 2,
  }) async {
    if (maxSlots != 2 && maxSlots != 5) {
      throw ArgumentError.value(
        maxSlots,
        'maxSlots',
        'Only two or five slots are supported.',
      );
    }
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? p.join(await getDatabasesPath(), 'elevenward.sqlite');
    final database = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return CareerStore._(database, maxSlots: maxSlots);
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE career_slots (
        slot_index INTEGER PRIMARY KEY CHECK(slot_index BETWEEN 0 AND 4),
        career_id TEXT,
        snapshot_json TEXT,
        checksum TEXT,
        revision INTEGER NOT NULL DEFAULT 0,
        server_revision INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        sync_state TEXT NOT NULL DEFAULT 'localOnly'
        ,deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0, 1))
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
    await db.execute(
      'CREATE INDEX career_events_recovery_idx ON career_events(career_id, revision DESC, id DESC)',
    );
    await db.execute('''
      CREATE TABLE cloud_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        career_id TEXT NOT NULL,
        local_snapshot_json TEXT NOT NULL,
        remote_snapshot_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        resolved_at TEXT,
        slot_index INTEGER NOT NULL DEFAULT 0,
        remote_conflict_id TEXT,
        remote_revision INTEGER NOT NULL DEFAULT 0
        ,local_deleted INTEGER NOT NULL DEFAULT 0 CHECK(local_deleted IN (0, 1))
      )
    ''');
    await db.execute('''
      CREATE TABLE app_preferences (
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL
      )
    ''');
    await _createArchives(db);
  }

  static Future<void> _createArchives(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS career_archives (
      career_id TEXT PRIMARY KEY,
      snapshot_json TEXT NOT NULL,
      checksum TEXT NOT NULL,
      archived_at TEXT NOT NULL,
      cloud_account_id TEXT,
      cloud_synced INTEGER NOT NULL DEFAULT 0 CHECK(cloud_synced IN (0, 1))
    )
  ''');

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cloud_conflicts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          career_id TEXT NOT NULL,
          local_snapshot_json TEXT NOT NULL,
          remote_snapshot_json TEXT NOT NULL,
          created_at TEXT NOT NULL,
          resolved_at TEXT
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE career_slots ADD COLUMN server_revision INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE cloud_conflicts ADD COLUMN slot_index INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE cloud_conflicts ADD COLUMN remote_conflict_id TEXT',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE career_slots ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE cloud_conflicts ADD COLUMN local_deleted INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 6) await _createArchives(db);
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE cloud_conflicts ADD COLUMN remote_revision INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Retired careers are explicit archives, independent of playable slots.
  Future<void> saveArchive(
    CareerSnapshot snapshot, {
    String? accountId,
    bool cloudSynced = false,
  }) async {
    if (!snapshot.retired) {
      throw StateError('Only retired careers can be archived.');
    }
    final encoded = snapshot.encode();
    final checksum = sha256.convert(utf8.encode(encoded)).toString();
    await _database.transaction((txn) async {
      final existing = await txn.query(
        'career_archives',
        where: 'career_id = ?',
        whereArgs: [snapshot.careerId],
        limit: 1,
      );
      final owner = existing.firstOrNull?['cloud_account_id'];
      if (accountId != null && owner != null && owner != accountId) {
        throw StateError('This archive belongs to another account.');
      }
      if (existing.isEmpty) {
        final count =
            Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM career_archives'),
            ) ??
            0;
        if (count >= 40) throw StateError('The Hall of Fame holds 40 careers.');
      }
      await txn.insert('career_archives', {
        'career_id': snapshot.careerId,
        'snapshot_json': encoded,
        'checksum': checksum,
        'archived_at': existing.isEmpty
            ? DateTime.now().toUtc().toIso8601String()
            : existing.first['archived_at'],
        'cloud_account_id':
            accountId ?? existing.firstOrNull?['cloud_account_id'],
        'cloud_synced': cloudSynced ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<CareerSnapshot>> listArchives() async {
    final rows = await _database.query(
      'career_archives',
      orderBy: 'archived_at DESC',
    );
    return rows.map(_decodeVerified).toList(growable: false);
  }

  Future<List<CareerSnapshot>> pendingArchives(String accountId) async {
    final rows = await _database.query(
      'career_archives',
      where: '(cloud_account_id = ? OR cloud_account_id IS NULL) AND cloud_synced = 0',
      whereArgs: [accountId],
    );
    return rows.map(_decodeVerified).toList(growable: false);
  }

  Future<void> markArchiveSynced(
    String careerId,
    String accountId,
  ) => _database.update(
    'career_archives',
    {'cloud_synced': 1, 'cloud_account_id': accountId},
    where:
        'career_id = ? AND (cloud_account_id = ? OR cloud_account_id IS NULL)',
    whereArgs: [careerId, accountId],
  );

  Future<String?> archiveOwner(String careerId) async {
    final rows = await _database.query(
      'career_archives',
      columns: ['cloud_account_id'],
      where: 'career_id = ?',
      whereArgs: [careerId],
      limit: 1,
    );
    return rows.firstOrNull?['cloud_account_id'] as String?;
  }

  Future<void> deleteArchive(String careerId) => _database.delete(
    'career_archives',
    where: 'career_id = ?',
    whereArgs: [careerId],
  );

  Future<List<SavedCareerSlot>> listSlots() async {
    final rows = await _database.query('career_slots');
    final byIndex = {for (final row in rows) row['slot_index'] as int: row};
    return List.generate(maxSlots, (index) {
      final row = byIndex[index];
      if (row == null || row['snapshot_json'] == null) {
        return SavedCareerSlot(
          slotIndex: index,
          snapshot: null,
          syncState: SlotSyncState.localOnly,
          serverRevision: 0,
          localRevision: 0,
        );
      }
      final deleted = (row['deleted'] as int? ?? 0) == 1;
      final CareerSnapshot decoded;
      try {
        decoded = _decodeVerified(row);
      } on FormatException {
        return SavedCareerSlot(
          slotIndex: index,
          snapshot: null,
          syncState: SlotSyncState.localOnly,
          serverRevision: row['server_revision'] as int? ?? 0,
          localRevision: row['revision'] as int? ?? 0,
          recoveryCode: _supportCode(
            row['career_id'] as String? ?? 'slot-$index',
          ),
        );
      }
      return SavedCareerSlot(
        slotIndex: index,
        snapshot: deleted ? null : decoded,
        syncState: _syncState(row['sync_state'] as String),
        serverRevision: row['server_revision'] as int? ?? 0,
        localRevision: row['revision'] as int? ?? decoded.revision,
        tombstoneSnapshot: deleted ? decoded : null,
      );
    });
  }

  Future<CareerSnapshot?> loadSlot(int slotIndex) async {
    _checkSlot(slotIndex);
    final rows = await _database.query(
      'career_slots',
      where: 'slot_index = ?',
      whereArgs: [slotIndex],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['snapshot_json'] == null) return null;
    if ((rows.first['deleted'] as int? ?? 0) == 1) return null;
    try {
      return _decodeVerified(rows.first);
    } on FormatException {
      final careerId = rows.first['career_id'] as String?;
      if (careerId == null) rethrow;
      final recovered = await recoverCareer(careerId);
      if (recovered == null) rethrow;
      await saveSlot(slotIndex, recovered, eventType: 'snapshot_recovered');
      _recoveryNotice =
          'Recovered career ${_supportCode(careerId)} from its local journal.';
      return recovered;
    }
  }

  Future<void> saveSlot(
    int slotIndex,
    CareerSnapshot snapshot, {
    String eventType = 'snapshot_saved',
  }) async {
    _checkSlot(slotIndex);
    final encoded = snapshot.encode();
    final checksum = sha256.convert(utf8.encode(encoded)).toString();
    await _database.transaction((txn) async {
      await txn.insert('career_events', {
        'career_id': snapshot.careerId,
        'revision': snapshot.revision,
        'event_type': eventType,
        'payload_json': encoded,
        'created_at': snapshot.updatedAt.toUtc().toIso8601String(),
      });
      await txn.rawInsert(
        '''
        INSERT INTO career_slots (
          slot_index, career_id, snapshot_json, checksum, revision, updated_at, sync_state
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(slot_index) DO UPDATE SET
          career_id = excluded.career_id,
          snapshot_json = excluded.snapshot_json,
          checksum = excluded.checksum,
          revision = excluded.revision,
          updated_at = excluded.updated_at,
          sync_state = excluded.sync_state,
          deleted = 0
      ''',
        [
          slotIndex,
          snapshot.careerId,
          encoded,
          checksum,
          snapshot.revision,
          snapshot.updatedAt.toUtc().toIso8601String(),
          SlotSyncState.queued.name,
        ],
      );
    });
  }

  Future<void> deleteSlot(int slotIndex, DateTime deletedAt) async {
    _checkSlot(slotIndex);
    final snapshot = await loadSlot(slotIndex);
    if (snapshot == null) return;
    final rows = await _database.query(
      'career_slots',
      columns: ['server_revision'],
      where: 'slot_index = ?',
      whereArgs: [slotIndex],
      limit: 1,
    );
    final serverRevision = rows.first['server_revision'] as int? ?? 0;
    await _database.transaction((txn) async {
      await txn.insert('career_events', {
        'career_id': snapshot.careerId,
        'revision': snapshot.revision + 1,
        'event_type': 'slot_deleted',
        'payload_json': '{}',
        'created_at': deletedAt.toUtc().toIso8601String(),
      });
      if (serverRevision == 0) {
        await txn.delete(
          'career_slots',
          where: 'slot_index = ?',
          whereArgs: [slotIndex],
        );
      } else {
        await txn.update(
          'career_slots',
          {
            'deleted': 1,
            'revision': snapshot.revision + 1,
            'updated_at': deletedAt.toUtc().toIso8601String(),
            'sync_state': SlotSyncState.queued.name,
          },
          where: 'slot_index = ?',
          whereArgs: [slotIndex],
        );
      }
    });
  }

  Future<void> clearTombstone(int slotIndex) async {
    _checkSlot(slotIndex);
    await _database.delete(
      'career_slots',
      where: 'slot_index = ? AND deleted = 1',
      whereArgs: [slotIndex],
    );
  }

  /// Applies an explicitly chosen cloud deletion without removing a career
  /// replaced or advanced while conflict resolution was in flight.
  Future<bool> clearResolvedSlot(
    int slotIndex, {
    required String expectedCareerId,
    required int expectedRevision,
    bool Function()? isCurrentSession,
  }) async {
    _checkSlot(slotIndex);
    return _database.transaction((txn) async {
      if (isCurrentSession?.call() == false) {
        throw StateError('Account changed.');
      }
      final removed = await txn.delete(
        'career_slots',
        where: 'slot_index = ? AND career_id = ? AND revision = ?',
        whereArgs: [slotIndex, expectedCareerId, expectedRevision],
      );
      if (isCurrentSession?.call() == false) {
        throw StateError('Account changed.');
      }
      return removed > 0;
    });
  }

  Future<CareerSnapshot?> recoverCareer(String careerId) async {
    final rows = await _database.query(
      'career_events',
      columns: ['payload_json'],
      where: "career_id = ? AND event_type != 'slot_deleted'",
      whereArgs: [careerId],
      orderBy: 'revision DESC, id DESC',
    );
    for (final row in rows) {
      try {
        final recovered = CareerSnapshot.decode(row['payload_json'] as String);
        if (recovered.careerId == careerId) return recovered;
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return null;
  }

  Future<void> markSynced(
    int slotIndex,
    int expectedRevision,
    int serverRevision, {
    String? expectedCareerId,
    int? expectedServerRevision,
  }) async {
    _checkSlot(slotIndex);
    // An upload acknowledgment advances the cloud base even when the user
    // played another local week. Only the exact committed version is synced.
    await _database.rawUpdate(
      "UPDATE career_slots SET server_revision = MAX(server_revision, ?), "
      "sync_state = CASE WHEN revision = ? AND deleted = 0 THEN 'synced' ELSE 'queued' END "
      "WHERE slot_index = ?"
      "${expectedCareerId == null ? ' AND revision = ?' : ' AND career_id = ?'}"
      "${expectedServerRevision == null ? '' : ' AND server_revision = ?'}",
      [
        serverRevision,
        expectedRevision,
        slotIndex,
        expectedCareerId ?? expectedRevision,
        ?expectedServerRevision,
      ],
    );
  }

  Future<bool> markConflict(
    int slotIndex, {
    String? expectedCareerId,
    int? expectedServerRevision,
  }) async {
    _checkSlot(slotIndex);
    final changed = await _database.update(
      'career_slots',
      {'sync_state': SlotSyncState.conflict.name},
      where:
          'slot_index = ?'
          '${expectedCareerId == null ? '' : ' AND career_id = ?'}'
          '${expectedServerRevision == null ? '' : ' AND server_revision = ?'}',
      whereArgs: [slotIndex, ?expectedCareerId, ?expectedServerRevision],
    );
    return changed > 0;
  }

  Future<void> adoptCloudAccount(
    String accountId, {
    bool Function()? isCurrentSession,
  }) async {
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'app_preferences',
        where: 'key = ?',
        whereArgs: ['cloud.syncAccount'],
        limit: 1,
      );
      final previous = rows.isEmpty
          ? null
          : jsonDecode(rows.first['value_json'] as String);
      if (isCurrentSession?.call() == false) {
        throw StateError('Account changed.');
      }
      if (previous != null && previous != accountId) {
        await txn.delete('career_slots', where: 'deleted = 1');
        await txn.update('career_slots', {
          'server_revision': 0,
          'sync_state': SlotSyncState.queued.name,
        });
        // These private remote IDs belong to the previous account. Retain both
        // comparison snapshots as history while removing obsolete choices.
        await txn.update('cloud_conflicts', {
          'resolved_at': DateTime.now().toUtc().toIso8601String(),
        }, where: 'resolved_at IS NULL');
      }
      await txn.insert('app_preferences', {
        'key': 'cloud.syncAccount',
        'value_json': jsonEncode(accountId),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (isCurrentSession?.call() == false) {
        throw StateError('Account changed.');
      }
    });
  }

  Future<bool> applyRemoteSlot(
    int slotIndex,
    CareerSnapshot snapshot,
    int serverRevision, {
    bool onlyIfEmpty = false,
    String? expectedCareerId,
    int? expectedRevision,
    bool Function()? isCurrentSession,
  }) async {
    _checkSlot(slotIndex);
    final encoded = snapshot.encode();
    final checksum = sha256.convert(utf8.encode(encoded)).toString();
    return _database.transaction((txn) async {
      void checkSession() {
        if (isCurrentSession?.call() == false) {
          throw StateError('Account changed.');
        }
      }

      checkSession();
      if (onlyIfEmpty || expectedCareerId != null || expectedRevision != null) {
        final rows = await txn.query(
          'career_slots',
          where: 'slot_index = ?',
          whereArgs: [slotIndex],
          limit: 1,
        );
        // A downloaded slot must never replace a career created while its
        // network request was in flight, including a queued deletion.
        checkSession();
        if (onlyIfEmpty && rows.isNotEmpty) return false;
        if (expectedCareerId != null &&
            (rows.isEmpty || rows.first['career_id'] != expectedCareerId)) {
          return false;
        }
        if (expectedRevision != null &&
            (rows.isEmpty || rows.first['revision'] != expectedRevision)) {
          return false;
        }
      }
      checkSession();
      await txn.insert('career_slots', {
        'slot_index': slotIndex,
        'career_id': snapshot.careerId,
        'snapshot_json': encoded,
        'checksum': checksum,
        'revision': snapshot.revision,
        'server_revision': serverRevision,
        'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
        'sync_state': SlotSyncState.synced.name,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      checkSession();
      return true;
    });
  }

  Future<int> preserveConflict({
    required CareerSnapshot local,
    required CareerSnapshot? remote,
    required DateTime createdAt,
    int slotIndex = 0,
    String? remoteConflictId,
    bool localDeleted = false,
    int remoteRevision = 0,
  }) async {
    final values = <String, Object?>{
      'career_id': local.careerId,
      'local_snapshot_json': local.encode(),
      'remote_snapshot_json': remote?.encode() ?? 'null',
      'created_at': createdAt.toUtc().toIso8601String(),
      'slot_index': slotIndex,
      'remote_conflict_id': remoteConflictId,
      'local_deleted': localDeleted ? 1 : 0,
      'remote_revision': remoteRevision,
    };
    return _database.transaction((txn) async {
      if (remoteConflictId != null) {
        final existing = await txn.query(
          'cloud_conflicts',
          columns: ['id'],
          where: 'remote_conflict_id = ? AND resolved_at IS NULL',
          whereArgs: [remoteConflictId],
          orderBy: 'id ASC',
          limit: 1,
        );
        if (existing.isNotEmpty) {
          final id = existing.first['id'] as int;
          await txn.update(
            'cloud_conflicts',
            values,
            where: 'id = ?',
            whereArgs: [id],
          );
          return id;
        }
      }
      return txn.insert('cloud_conflicts', values);
    });
  }

  Future<List<PreservedConflict>> listConflicts() async {
    final rows = await _database.query(
      'cloud_conflicts',
      where: 'resolved_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => PreservedConflict(
            id: row['id'] as int,
            careerId: row['career_id'] as String,
            localSnapshot: CareerSnapshot.decode(
              row['local_snapshot_json'] as String,
            ),
            remoteSnapshot:
                (row['remote_snapshot_json'] as String).trim() == 'null'
                ? null
                : CareerSnapshot.decode(row['remote_snapshot_json'] as String),
            createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
            slotIndex: row['slot_index'] as int? ?? 0,
            remoteConflictId: row['remote_conflict_id'] as String?,
            localDeleted: (row['local_deleted'] as int? ?? 0) == 1,
            remoteRevision: row['remote_revision'] as int? ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<void> resolveConflict(int conflictId, DateTime resolvedAt) async {
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'cloud_conflicts',
        columns: ['remote_conflict_id'],
        where: 'id = ?',
        whereArgs: [conflictId],
        limit: 1,
      );
      final remoteId = rows.isEmpty
          ? null
          : rows.first['remote_conflict_id'] as String?;
      await txn.update(
        'cloud_conflicts',
        {'resolved_at': resolvedAt.toUtc().toIso8601String()},
        where: remoteId == null
            ? 'id = ? AND resolved_at IS NULL'
            : 'remote_conflict_id = ? AND resolved_at IS NULL',
        whereArgs: [remoteId ?? conflictId],
      );
    });
  }

  Future<void> setPreference(String key, Object? value) => _database.insert(
    'app_preferences',
    {'key': key, 'value_json': jsonEncode(value)},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<bool> removePreferenceIfUnchanged(
    String key,
    Object expectedValue,
  ) async {
    final removed = await _database.delete(
      'app_preferences',
      where: 'key = ? AND value_json = ?',
      whereArgs: [key, jsonEncode(expectedValue)],
    );
    return removed > 0;
  }

  Future<Object?> getPreference(String key) async {
    final rows = await _database.query(
      'app_preferences',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : jsonDecode(rows.first['value_json'] as String);
  }

  Future<void> removePreference(String key) =>
      _database.delete('app_preferences', where: 'key = ?', whereArgs: [key]);

  Future<PlayerAttribute> loadWeeklyFocus(String careerId) async {
    final value = await getPreference(weeklyFocusPreferenceKey(careerId));
    if (value is! String) return PlayerAttribute.finishing;
    return PlayerAttribute.values.firstWhere(
      (attribute) => attribute.name == value,
      orElse: () => PlayerAttribute.finishing,
    );
  }

  Future<void> saveWeeklyFocus(String careerId, PlayerAttribute focus) =>
      setPreference(weeklyFocusPreferenceKey(careerId), focus.name);

  Future<void> removeWeeklyFocus(String careerId) =>
      removePreference(weeklyFocusPreferenceKey(careerId));

  Future<void> close() => _database.close();

  CareerSnapshot _decodeVerified(Map<String, Object?> row) {
    final encoded = row['snapshot_json'] as String;
    final storedChecksum = row['checksum'] as String;
    final actualChecksum = sha256.convert(utf8.encode(encoded)).toString();
    if (storedChecksum != actualChecksum) {
      throw const FormatException('Career snapshot checksum mismatch.');
    }
    try {
      return CareerSnapshot.decode(encoded);
    } on TypeError {
      throw const FormatException('Career snapshot has invalid field types.');
    }
  }

  SlotSyncState _syncState(String value) => SlotSyncState.values.firstWhere(
    (state) => state.name == value,
    orElse: () => SlotSyncState.localOnly,
  );

  String _supportCode(String careerId) =>
      sha256.convert(utf8.encode(careerId)).toString().substring(0, 8);

  void _checkSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= maxSlots) {
      throw RangeError.range(slotIndex, 0, maxSlots - 1, 'slotIndex');
    }
  }
}

String weeklyFocusPreferenceKey(String careerId) =>
    'career.$careerId.weeklyFocus';
