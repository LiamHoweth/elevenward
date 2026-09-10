import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/career_store.dart';

abstract interface class ReviewRequester {
  Future<bool> isAvailable();

  Future<void> requestReview();
}

final class SystemReviewRequester implements ReviewRequester {
  SystemReviewRequester({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  @override
  Future<bool> isAvailable() => _inAppReview.isAvailable();

  @override
  Future<void> requestReview() => _inAppReview.requestReview();
}

/// Applies Elevenward's engagement and frequency rules before asking StoreKit
/// to consider showing its system-owned rating prompt.
final class ReviewPromptService {
  ReviewPromptService({
    required this.store,
    ReviewRequester? requester,
    Future<String> Function()? loadAppVersion,
    DateTime Function()? now,
    bool? platformSupported,
  }) : _requester = requester ?? SystemReviewRequester(),
       _loadAppVersion = loadAppVersion ?? _currentAppVersion,
       _now = now ?? DateTime.now,
       _platformSupported =
           platformSupported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  static const minimumCooldown = Duration(days: 120);
  static const _lastRequestedAtKey = 'review.lastRequestedAt';
  static const _lastRequestedVersionKey = 'review.lastRequestedVersion';

  final CareerStore store;
  final ReviewRequester _requester;
  final Future<String> Function() _loadAppVersion;
  final DateTime Function() _now;
  final bool _platformSupported;

  bool _requestInFlight = false;

  /// Requests a review only at a completed-season break, after the player has
  /// experienced a full season. StoreKit retains final control over whether the
  /// prompt is actually displayed.
  Future<bool> requestAfterSeason(CareerSnapshot snapshot) async {
    if (_requestInFlight ||
        !_platformSupported ||
        snapshot.phase != CareerPhase.offseason ||
        snapshot.week != 18 ||
        snapshot.season < 1) {
      return false;
    }

    _requestInFlight = true;
    try {
      final version = (await _loadAppVersion()).trim();
      if (version.isEmpty) return false;

      final lastVersion = await store.getPreference(_lastRequestedVersionKey);
      if (lastVersion == version) return false;

      final lastRequestedValue = await store.getPreference(_lastRequestedAtKey);
      final lastRequestedAt = lastRequestedValue is String
          ? DateTime.tryParse(lastRequestedValue)?.toUtc()
          : null;
      final requestedAt = _now().toUtc();
      if (lastRequestedAt != null &&
          requestedAt.difference(lastRequestedAt) < minimumCooldown) {
        return false;
      }

      if (!await _requester.isAvailable()) return false;
      await _requester.requestReview();
      await store.setPreference(_lastRequestedVersionKey, version);
      await store.setPreference(
        _lastRequestedAtKey,
        requestedAt.toIso8601String(),
      );
      return true;
    } on Object {
      // A rating request must never interfere with saving or playing a career.
      return false;
    } finally {
      _requestInFlight = false;
    }
  }

  static Future<String> _currentAppVersion() async =>
      (await PackageInfo.fromPlatform()).version;
}
