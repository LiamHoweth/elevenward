import 'analytics_service.dart';

/// Reports only a small error taxonomy. Messages, stack traces, file paths,
/// player state, identifiers, and user-authored text are intentionally omitted.
final class PrivacyErrorReporter {
  const PrivacyErrorReporter(this._analytics);

  final AnalyticsService _analytics;

  Future<void> report(String area, Object error) => _analytics.record(
    'client_error',
    properties: {
      'area': _safe(area),
      'category': _safe(error.runtimeType.toString()),
      'code': 'unhandled',
    },
  );

  String _safe(String value) {
    final safe = value.replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
    if (safe.isEmpty) return 'unknown';
    return safe.substring(0, safe.length.clamp(1, 48));
  }
}
