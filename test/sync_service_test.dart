import 'dart:convert';

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

    final report = await service.synchronize(onProgress: progress.add);

    expect(report.downloaded, 1);
    expect(report.uploaded, 0);
    expect((await store.loadSlot(1))?.careerId, cloudCareer.careerId);
    expect(progress.first.phase, SyncProgressPhase.loading);
    expect(progress.last.phase, SyncProgressPhase.complete);
    expect(progress.last.completed, progress.last.total);
  });
}
