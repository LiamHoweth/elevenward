import 'dart:convert';

import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/privacy_error_reporter.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test('replays old consent and drains concurrent offline events in bounded idempotent batches', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    var online = false;
    final batches = <List<Object?>>[];
    var consentCalls = 0;
    final api = ElevenwardApi(
      accessToken: () async => online ? 'token' : null,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/analytics/consent')) {
          consentCalls++;
          return http.Response('{}', 200);
        }
        final body = jsonDecode(request.body) as Map;
        batches.add(body['events'] as List<Object?>);
        return http.Response('{"accepted":0}', 202);
      }),
    );
    final analytics = AnalyticsService(api, store);
    await store.setPreference('analytics.consent', true);
    await Future.wait(
      List.generate(75, (_) => analytics.record('app_started')),
    );
    expect(await store.getPreference('analytics.queue'), hasLength(75));
    online = true;
    await analytics.replayConsent();
    await analytics.replayConsent();
    expect(consentCalls, 2);
    await analytics.flush();
    expect(batches.map((batch) => batch.length), [50, 25]);
    expect(await store.getPreference('analytics.queue'), isEmpty);
    expect(
      batches
          .expand((batch) => batch)
          .map((event) => (event as Map)['eventId'])
          .toSet(),
      hasLength(75),
    );
  });

  test(
    'unknown events and private properties never enter the offline queue',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final analytics = AnalyticsService(
        ElevenwardApi(accessToken: () async => null),
        store,
      );
      await analytics.setConsent(true);
      await analytics.record(
        'email',
        properties: {'email': 'private@example.com'},
      );
      await analytics.record(
        'career_started',
        properties: {
          'position': 'striker',
          'difficulty': 'story',
          'email': 'private@example.com',
        },
      );
      final queue = await store.getPreference('analytics.queue') as List;
      expect(queue, hasLength(1));
      expect((queue.single as Map)['properties'], {
        'position': 'striker',
        'difficulty': 'story',
      });
      await analytics.setConsent(false);
      expect(await store.getPreference('analytics.queue'), isEmpty);
    },
  );

  test('error reports retain only a consented safe taxonomy', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final analytics = AnalyticsService(
      ElevenwardApi(accessToken: () async => null),
      store,
    );
    await analytics.setConsent(true);
    await PrivacyErrorReporter(analytics).report(
      'flutter',
      StateError('player@example.com bearer-secret /private/career.db'),
    );

    final queue = await store.getPreference('analytics.queue') as List;
    expect(queue, hasLength(1));
    final encoded = jsonEncode(queue.single);
    expect(encoded, contains('client_error'));
    expect(encoded, contains('StateError'));
    expect(encoded, isNot(contains('player@example.com')));
    expect(encoded, isNot(contains('bearer-secret')));
    expect(encoded, isNot(contains('/private/career.db')));
  });
}
