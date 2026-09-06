import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class SecureCredentials {
  SecureCredentials({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'elevenward'),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  static const _accountTokenKey = 'elevenward.account.access_token';
  static const _installationTokenKey = 'elevenward.installation.token';
  static const _entitlementCacheKey = 'elevenward.entitlements.cache';

  final FlutterSecureStorage _storage;

  Future<String?> readAccountToken() => _storage.read(key: _accountTokenKey);
  Future<void> writeAccountToken(String token) =>
      _storage.write(key: _accountTokenKey, value: token);
  Future<void> clearAccountToken() => _storage.delete(key: _accountTokenKey);

  Future<String?> readInstallationToken() =>
      _storage.read(key: _installationTokenKey);
  Future<void> writeInstallationToken(String token) =>
      _storage.write(key: _installationTokenKey, value: token);

  Future<String?> readEntitlementCache() =>
      _storage.read(key: _entitlementCacheKey);
  Future<void> writeEntitlementCache(String value) =>
      _storage.write(key: _entitlementCacheKey, value: value);

  Future<void> clearAll() => _storage.deleteAll();
}
