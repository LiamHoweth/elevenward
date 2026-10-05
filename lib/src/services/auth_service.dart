import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../storage/secure_credentials.dart';
import 'api_models.dart';
import 'elevenward_api.dart';

final class AuthService {
  AuthService({
    required ElevenwardApi api,
    required SecureCredentials credentials,
    GoogleSignIn? googleSignIn,
  }) : _api = api, // ignore: prefer_initializing_formals
       _credentials = credentials, // ignore: prefer_initializing_formals
       _google = googleSignIn ?? GoogleSignIn.instance;

  final ElevenwardApi _api;
  final SecureCredentials _credentials;
  final GoogleSignIn _google;
  bool _googleInitialized = false;
  ElevenwardAccount? _account;
  int _sessionGeneration = 0;
  Future<void> _credentialMutation = Future<void>.value();

  /// Changes when authentication is replaced or revoked. In-flight callers can
  /// bind work to this generation instead of adopting a later account token.
  int get sessionGeneration => _sessionGeneration;

  int _beginSessionChange() {
    _api.invalidateSession();
    return ++_sessionGeneration;
  }

  Future<T> _serializeCredentials<T>(Future<T> Function() action) {
    final next = _credentialMutation.then((_) => action());
    _credentialMutation = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<bool> _restoreStillCurrent(int generation, String token) async {
    if (generation != _sessionGeneration) return false;
    final current = await _credentials.readAccountToken();
    return generation == _sessionGeneration && token == current;
  }

  ElevenwardAccount? get currentAccount => _account;

  Future<ElevenwardAccount?> restoreSession() async {
    final generation = _sessionGeneration;
    final token = await _credentials.readAccountToken();
    if (generation != _sessionGeneration) return _account;
    if (token == null) return null;
    try {
      final restored = await _api.account();
      return await _serializeCredentials(() async {
        if (!await _restoreStillCurrent(generation, token)) return _account;
        await _credentials.writeAccountProfile(jsonEncode(restored.toJson()));
        if (generation != _sessionGeneration) return _account;
        if (_account?.id != restored.id) _api.invalidateSession();
        _account = restored;
        return restored;
      });
    } on ApiFailure catch (error) {
      if (error.statusCode == 401) {
        return _serializeCredentials(() async {
          if (!await _restoreStillCurrent(generation, token)) return _account;
          _api.invalidateSession();
          await _credentials.clearAccountToken();
          if (generation == _sessionGeneration) _account = null;
          return _account;
        });
      }
      return _restoreCachedAccount(generation, token);
    } on Object {
      return _restoreCachedAccount(generation, token);
    }
  }

  Future<ElevenwardAccount?> _restoreCachedAccount(
    int generation,
    String token,
  ) => _serializeCredentials(() async {
    try {
      if (!await _restoreStillCurrent(generation, token)) return _account;
      final stored = await _credentials.readAccountProfile();
      if (generation != _sessionGeneration) return _account;
      if (stored == null) return null;
      final json = (jsonDecode(stored) as Map).cast<String, Object?>();
      final account = ElevenwardAccount.fromJson(json);
      if (account.id.isEmpty ||
          !{'apple', 'google'}.contains(account.provider)) {
        return null;
      }
      if (_account?.id != account.id) _api.invalidateSession();
      _account = account;
      return account;
    } on Object {
      return generation == _sessionGeneration ? null : _account;
    }
  });

  Future<ElevenwardAccount> signInWithApple() async {
    final generation = _beginSessionChange();
    final rawNonce = _nonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email],
      nonce: hashedNonce,
    );
    final identityToken = credential.identityToken;
    final authorizationCode = credential.authorizationCode;
    if (identityToken == null || authorizationCode.isEmpty) {
      throw const ApiFailure(
        401,
        'Apple did not return a complete credential.',
      );
    }
    final session = await _api.authenticateApple(
      identityToken: identityToken,
      authorizationCode: authorizationCode,
      nonce: hashedNonce,
    );
    return _accept(session, generation);
  }

  Future<ElevenwardAccount> signInWithGoogle() async {
    final generation = _beginSessionChange();
    if (!_googleInitialized) {
      const serverClientId = String.fromEnvironment(
        'ELEVENWARD_GOOGLE_SERVER_CLIENT_ID',
      );
      await _google.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );
      _googleInitialized = true;
    }
    final user = await _google.authenticate();
    final idToken = user.authentication.idToken;
    if (idToken == null) {
      throw const ApiFailure(401, 'Google did not return an identity token.');
    }
    return _accept(await _api.authenticateGoogle(idToken: idToken), generation);
  }

  Future<void> signOut() async {
    final generation = _beginSessionChange();
    try {
      await _api.signOut();
    } finally {
      await _serializeCredentials(() async {
        if (generation != _sessionGeneration) return;
        _account = null;
        await _credentials.clearAccountToken();
      });
      if (_googleInitialized && generation == _sessionGeneration) {
        await _google.signOut();
      }
    }
  }

  Future<bool> deleteAccount() async {
    final generation = _beginSessionChange();
    await _api.deleteAccount();
    if (generation != _sessionGeneration) return true;
    _account = null;
    try {
      await _serializeCredentials(() async {
        if (generation == _sessionGeneration) {
          await _credentials.clearAccountToken();
        }
      });
      if (_googleInitialized && generation == _sessionGeneration) {
        await _google.signOut();
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<Map<String, Object?>> createDeletionChallenge() =>
      _api.createDeletionChallenge();

  Future<void> updateCurrentAccount(ElevenwardAccount account) async {
    final generation = _sessionGeneration;
    if (_account?.id != account.id) {
      throw StateError('The authenticated account changed.');
    }
    await _serializeCredentials(() async {
      if (generation != _sessionGeneration || _account?.id != account.id) {
        throw StateError('The authenticated account changed.');
      }
      await _credentials.writeAccountProfile(jsonEncode(account.toJson()));
      if (generation == _sessionGeneration) _account = account;
    });
  }

  Future<ElevenwardAccount> _accept(AuthSession session, int generation) =>
      _serializeCredentials(() async {
        if (generation != _sessionGeneration) {
          throw StateError('The sign-in request was replaced.');
        }
        await _credentials.writeAccountToken(session.accessToken);
        await _credentials.writeAccountProfile(
          jsonEncode(session.account.toJson()),
        );
        if (generation != _sessionGeneration) {
          throw StateError('The sign-in request was replaced.');
        }
        _account = session.account;
        return session.account;
      });

  String _nonce() {
    const alphabet =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }
}
