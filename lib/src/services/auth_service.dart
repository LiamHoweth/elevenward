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

  ElevenwardAccount? get currentAccount => _account;

  Future<ElevenwardAccount?> restoreSession() async {
    if (await _credentials.readAccountToken() == null) return null;
    try {
      _account = await _api.account();
      return _account;
    } on ApiFailure catch (error) {
      if (error.statusCode == 401) await _credentials.clearAccountToken();
      return null;
    }
  }

  Future<ElevenwardAccount> signInWithApple() async {
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
    return _accept(session);
  }

  Future<ElevenwardAccount> signInWithGoogle() async {
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
    return _accept(await _api.authenticateGoogle(idToken: idToken));
  }

  Future<void> signOut() async {
    try {
      await _api.signOut();
    } finally {
      _account = null;
      await _credentials.clearAccountToken();
      if (_googleInitialized) await _google.signOut();
    }
  }

  Future<bool> deleteAccount() async {
    await _api.deleteAccount();
    _account = null;
    try {
      await _credentials.clearAccountToken();
      if (_googleInitialized) await _google.signOut();
      return true;
    } on Object {
      // The server deletion succeeded and revoked this token. Report local
      // cleanup separately; never present the deleted account as signed in.
      return false;
    }
  }

  Future<Map<String, Object?>> createDeletionChallenge() =>
      _api.createDeletionChallenge();

  Future<ElevenwardAccount> _accept(AuthSession session) async {
    await _credentials.writeAccountToken(session.accessToken);
    _account = session.account;
    return session.account;
  }

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
