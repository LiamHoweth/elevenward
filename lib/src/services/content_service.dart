import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/career_store.dart';
import 'elevenward_api.dart';

final class ActiveContent {
  ActiveContent({
    required this.version,
    required this.bundle,
    required this.isBundled,
  }) : catalog = ContentCatalog.fromBundle(bundle) {
    final errors = validateContentCatalog(catalog);
    if (errors.isNotEmpty) {
      throw FormatException('Invalid content catalog: ${errors.first}');
    }
  }

  final String version;
  final Map<String, Object?> bundle;
  final bool isBundled;
  final ContentCatalog catalog;
}

/// Loads the immutable launch bundle immediately, then optionally replaces only
/// content data after checksum, client-range, rules-version, and Ed25519 checks.
final class ContentService {
  ContentService({
    required ElevenwardApi api,
    required CareerStore store,
    http.Client? client,
    String publicKeyBase64 = const String.fromEnvironment(
      'ELEVENWARD_CONTENT_PUBLIC_KEY_BASE64',
    ),
  }) : _api = api, // ignore: prefer_initializing_formals
       _store = store, // ignore: prefer_initializing_formals
       _client = client ?? http.Client(),
       // ignore: prefer_initializing_formals
       _publicKeyBase64 = publicKeyBase64;

  static const bundledAsset = 'assets/content/launch-2026.2.0.json';
  static const executableRulesVersion = CareerSnapshot.currentRulesVersion;
  static const _cacheKey = 'content.verified.bundle';
  static const _versionCacheKey = 'content.verified.versions';
  static const _bundledCompatibilityAliases = {'2026.1.0'};

  final ElevenwardApi _api;
  final CareerStore _store;
  final http.Client _client;
  final String _publicKeyBase64;
  static const _maximumBytes = 5000000;

  Future<ActiveContent> load() async {
    final cached = await _store.getPreference(_cacheKey);
    if (cached is Map && _publicKeyBase64.isNotEmpty) {
      try {
        return await _verify(
          utf8.encode(cached['body'] as String),
          (cached['manifest'] as Map).cast<String, Object?>(),
        );
      } on Object {
        // Fall back to the signed-in-app bundle on any cache corruption.
      }
    }
    return _loadBundled();
  }

  /// Loads the exact authored-data release recorded by a career snapshot.
  ///
  /// Verified downloads are retained by release rather than overwritten so a
  /// content update can never change an in-progress career's situations,
  /// events, or lifestyle catalog. The compatibility alias covers the
  /// pre-release 2026.1 catalog, whose authored data is compatible with the
  /// bundled launch catalog.
  Future<ActiveContent?> loadVersion(String version) async {
    final bundled = await _loadBundled(versionAlias: version);
    if (bundled.version == version) return bundled;
    if (_publicKeyBase64.isEmpty) return null;

    final versions = await _store.getPreference(_versionCacheKey);
    if (versions is Map) {
      final cached = versions[version];
      final verified = await _verifyCached(cached, requiredVersion: version);
      if (verified != null) return verified;
    }

    // Read the original single-release cache for users upgrading from builds
    // made before the version registry was introduced.
    final legacy = await _store.getPreference(_cacheKey);
    return _verifyCached(legacy, requiredVersion: version);
  }

  Future<ActiveContent> _loadBundled({String? versionAlias}) async {
    final source = await rootBundle.loadString(bundledAsset);
    final bundle = (jsonDecode(source) as Map).cast<String, Object?>();
    final bundledVersion = _releaseVersion(bundle);
    if (versionAlias != null &&
        versionAlias != bundledVersion &&
        _bundledCompatibilityAliases.contains(versionAlias)) {
      final metadata = (bundle['metadata'] as Map).cast<String, Object?>();
      final compatibleBundle = <String, Object?>{
        ...bundle,
        'metadata': {...metadata, 'releaseVersion': versionAlias},
      };
      return ActiveContent(
        version: versionAlias,
        bundle: compatibleBundle,
        isBundled: true,
      );
    }
    return ActiveContent(
      version: bundledVersion,
      bundle: bundle,
      isBundled: true,
    );
  }

  Future<ActiveContent?> checkForUpdate() async {
    if (_publicKeyBase64.isEmpty) return null;
    final manifest = await _api.manifest();
    final assets = manifest['assets'] as List<Object?>;
    final asset = (assets.single as Map).cast<String, Object?>();
    final uri = Uri.parse(asset['url'] as String);
    if (uri.scheme != 'https' ||
        uri.origin != _api.baseUri.origin ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Content must use the configured HTTPS API origin.',
      );
    }
    final bytes = await _download(uri).timeout(const Duration(seconds: 20));
    final content = await _verify(bytes, manifest);
    final cachedRelease = <String, Object?>{
      'body': utf8.decode(bytes),
      'manifest': manifest,
    };
    final storedVersions = await _store.getPreference(_versionCacheKey);
    final versions = storedVersions is Map
        ? Map<String, Object?>.from(storedVersions)
        : <String, Object?>{};
    versions[content.version] = cachedRelease;
    await _store.setPreference(_versionCacheKey, versions);
    await _store.setPreference(_cacheKey, cachedRelease);
    return content;
  }

  Future<ActiveContent?> _verifyCached(
    Object? cached, {
    required String requiredVersion,
  }) async {
    if (cached is! Map) return null;
    try {
      final verified = await _verify(
        utf8.encode(cached['body'] as String),
        (cached['manifest'] as Map).cast<String, Object?>(),
      );
      return verified.version == requiredVersion ? verified : null;
    } on Object {
      return null;
    }
  }

  Future<List<int>> _download(Uri uri) async {
    final response = await _client.send(
      http.Request('GET', uri)..followRedirects = false,
    );
    if (response.statusCode != 200) {
      throw StateError('Content download failed with ${response.statusCode}.');
    }
    if ((response.contentLength ?? 0) > _maximumBytes) {
      throw const FormatException('Content download exceeds its size limit.');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > _maximumBytes) {
        throw const FormatException('Content download exceeds its size limit.');
      }
      bytes.addAll(chunk);
    }
    return bytes;
  }

  Future<ActiveContent> _verify(
    List<int> bytes,
    Map<String, Object?> manifest,
  ) async {
    if (bytes.length > _maximumBytes ||
        manifest['signatureAlgorithm'] != 'Ed25519') {
      throw const FormatException('Invalid content envelope.');
    }
    final expectedChecksum = (manifest['checksum'] as String).replaceFirst(
      'sha256:',
      '',
    );
    final actualChecksum = sha256.convert(bytes).toString();
    if (actualChecksum != expectedChecksum) {
      throw const FormatException('Content checksum verification failed.');
    }
    final algorithm = Ed25519();
    final signature = Signature(
      base64Url.decode(base64Url.normalize(manifest['signature'] as String)),
      publicKey: SimplePublicKey(
        base64.decode(_publicKeyBase64),
        type: KeyPairType.ed25519,
      ),
    );
    if (!await algorithm.verify(bytes, signature: signature)) {
      throw const FormatException('Content signature verification failed.');
    }
    final bundle = (jsonDecode(utf8.decode(bytes)) as Map)
        .cast<String, Object?>();
    if (_releaseVersion(bundle) != manifest['releaseVersion']) {
      throw const FormatException(
        'Content version does not match its manifest.',
      );
    }
    final metadata = (bundle['metadata'] as Map).cast<String, Object?>();
    if (metadata['rulesVersion'] != executableRulesVersion) {
      throw const FormatException(
        'Remote content cannot replace executable rules.',
      );
    }
    final info = await PackageInfo.fromPlatform();
    // Compatibility is read from the signed payload, not the unsigned manifest.
    if (!_inRange(
      info.version,
      metadata['minClientVersion'] as String,
      metadata['maxClientVersion'] as String?,
    )) {
      throw const FormatException(
        'Content is incompatible with this app version.',
      );
    }
    return ActiveContent(
      version: _releaseVersion(bundle),
      bundle: bundle,
      isBundled: false,
    );
  }

  String _releaseVersion(Map<String, Object?> bundle) =>
      ((bundle['metadata'] as Map)['releaseVersion']) as String;

  bool _inRange(String version, String minimum, String? maximum) {
    final current = _versionParts(version);
    return _compare(current, _versionParts(minimum)) >= 0 &&
        (maximum == null || _compare(current, _versionParts(maximum)) <= 0);
  }

  List<int> _versionParts(String value) {
    final core = value.split('+').first.split('-').first;
    final parts = core
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    return List.generate(3, (index) => index < parts.length ? parts[index] : 0);
  }

  int _compare(List<int> left, List<int> right) {
    for (var index = 0; index < 3; index++) {
      final result = left[index].compareTo(right[index]);
      if (result != 0) return result;
    }
    return 0;
  }

  void close() => _client.close();
}
