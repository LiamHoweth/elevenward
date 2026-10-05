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
  static const _accountProfileKey = 'elevenward.account.profile';
  static const _installationTokenKey = 'elevenward.installation.token';
  static const _entitlementCacheKey = 'elevenward.entitlements.cache';

  final FlutterSecureStorage _storage;

  Future<String?> readAccountToken() => _storage.read(key: _accountTokenKey);
  Future<void> writeAccountToken(String token) =>
      _storage.write(key: _accountTokenKey, value: token);
  Future<String?> readAccountProfile() =>
      _storage.read(key: _accountProfileKey);
  Future<void> writeAccountProfile(String profile) =>
      _storage.write(key: _accountProfileKey, value: profile);
  Future<void> clearAccountToken() async {
    await _storage.delete(key: _accountTokenKey);
    await _storage.delete(key: _accountProfileKey);
  }

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
