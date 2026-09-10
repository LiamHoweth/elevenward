import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Elevenward',
      packageName: 'test',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  test(
    'cache signature is revalidated and tampered bytes fall back offline',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final algorithm = Ed25519();
      final key = await algorithm.newKeyPair();
      final publicKey = await key.extractPublicKey();
      final body = File(ContentService.bundledAsset).readAsStringSync();
      final bytes = utf8.encode(body);
      final releaseVersion =
          ((jsonDecode(body) as Map)['metadata'] as Map)['releaseVersion'];
      final signature = await algorithm.sign(bytes, keyPair: key);
      final manifest = <String, Object?>{
        'releaseVersion': releaseVersion,
        'signatureAlgorithm': 'Ed25519',
        'signature': base64Url.encode(signature.bytes),
        'checksum': 'sha256:${sha256.convert(bytes)}',
      };
      final service = ContentService(
        api: ElevenwardApi(accessToken: () async => null),
        store: store,
        publicKeyBase64: base64.encode(publicKey.bytes),
      );
      await store.setPreference('content.verified.bundle', {
        'body': body,
        'manifest': manifest,
      });
      expect((await service.load()).isBundled, isFalse);
      await store.setPreference('content.verified.bundle', {
        'body': '$body ',
        'manifest': manifest,
      });
      expect((await service.load()).isBundled, isTrue);
      // Even recomputing the checksum cannot forge the Ed25519 signature.
      manifest['checksum'] = 'sha256:${sha256.convert(utf8.encode('$body '))}';
      await store.setPreference('content.verified.bundle', {
        'body': '$body ',
        'manifest': manifest,
      });
      expect((await service.load()).isBundled, isTrue);
      await store.setPreference('content.verified.bundle', body);
      expect((await service.load()).isBundled, isTrue);
    },
  );

  test('verified releases remain available for pinned careers', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final algorithm = Ed25519();
    final key = await algorithm.newKeyPair();
    final publicKey = await key.extractPublicKey();
    final original = jsonDecode(
      File(ContentService.bundledAsset).readAsStringSync(),
    ) as Map<String, Object?>;
    final releases = <String, ({String body, Map<String, Object?> manifest})>{};
    for (final version in ['2026.2.1', '2026.2.2']) {
      final metadata = (original['metadata'] as Map).cast<String, Object?>();
      final body = jsonEncode({
        ...original,
        'metadata': {...metadata, 'releaseVersion': version},
      });
      final bytes = utf8.encode(body);
      final signature = await algorithm.sign(bytes, keyPair: key);
      releases[version] = (
        body: body,
        manifest: <String, Object?>{
          'releaseVersion': version,
          'signatureAlgorithm': 'Ed25519',
          'signature': base64Url.encode(signature.bytes),
          'checksum': 'sha256:${sha256.convert(bytes)}',
          'assets': [
            {'url': 'https://api.howethstudio.com/content/$version.json'},
          ],
        },
      );
    }

    var currentVersion = '2026.2.1';
    final apiClient = MockClient((request) async {
      expect(request.url.path, '/v1/elevenward/content/manifest');
      return http.Response.bytes(
        utf8.encode(jsonEncode(releases[currentVersion]!.manifest)),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final downloadClient = MockClient((request) async {
      final version = request.url.pathSegments.last.replaceAll('.json', '');
      return http.Response.bytes(
        utf8.encode(releases[version]!.body),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = ContentService(
      api: ElevenwardApi(accessToken: () async => null, client: apiClient),
      store: store,
      client: downloadClient,
      publicKeyBase64: base64.encode(publicKey.bytes),
    );
    addTearDown(service.close);

    expect((await service.checkForUpdate())?.version, '2026.2.1');
    currentVersion = '2026.2.2';
    expect((await service.checkForUpdate())?.version, '2026.2.2');

    expect((await service.load()).version, '2026.2.2');
    expect((await service.loadVersion('2026.2.1'))?.version, '2026.2.1');
    expect((await service.loadVersion('2026.2.2'))?.version, '2026.2.2');
    expect((await service.loadVersion('2026.9.9')), isNull);

    final registry = (await store.getPreference(
      'content.verified.versions',
    ) as Map).cast<String, Object?>();
    final first = (registry['2026.2.1'] as Map).cast<String, Object?>();
    registry['2026.2.1'] = {...first, 'body': '${first['body']} '};
    await store.setPreference('content.verified.versions', registry);
    expect(await service.loadVersion('2026.2.1'), isNull);
    expect((await service.loadVersion('2026.2.2'))?.version, '2026.2.2');
  });

  test(
    'bundled launch and compatible pre-release remain loadable offline',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final service = ContentService(
        api: ElevenwardApi(accessToken: () async => null),
        store: store,
      );
      addTearDown(service.close);

      expect((await service.loadVersion('2026.2.0'))?.version, '2026.2.0');
      expect((await service.loadVersion('2026.1.0'))?.version, '2026.1.0');
      expect(await service.loadVersion('2025.9.0'), isNull);
    },
  );

  test('content update rejects cross-origin asset before download', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final algorithm = Ed25519();
    final key = await algorithm.newKeyPair();
    final publicKey = await key.extractPublicKey();
    var downloaded = false;
    final apiClient = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'assets': [
            {'url': 'https://attacker.example/content.json'},
          ],
        }),
        200,
      ),
    );
    final service = ContentService(
      api: ElevenwardApi(accessToken: () async => null, client: apiClient),
      store: store,
      client: MockClient((_) async {
        downloaded = true;
        return http.Response('{}', 200);
      }),
      publicKeyBase64: base64.encode(publicKey.bytes),
    );
    addTearDown(service.close);

    await expectLater(service.checkForUpdate(), throwsFormatException);
    expect(downloaded, isFalse);
  });
}
