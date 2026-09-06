import '../storage/career_store.dart';
import '../util/uuid.dart';
import 'elevenward_api.dart';

final class AnalyticsService {
  AnalyticsService(this._api, this._store);

  static const policyVersion = '2026-09';
  static const _preferenceKey = 'analytics.consent';
  static const _pendingConsentKey = 'analytics.pendingConsent';
  static const _queueKey = 'analytics.queue';
  static const _queueLimit = 100;

  final ElevenwardApi _api;
  final CareerStore _store;
  Future<void> _pending = Future.value();
  bool _withdrawn = false;
  static const _allowed = <String, List<String>>{
    'app_started': [],
    'career_started': ['position', 'difficulty'],
    'week_completed': ['position', 'difficulty', 'season', 'week', 'result'],
    'season_completed': ['position', 'difficulty', 'season', 'placement'],
    'career_retired': ['position', 'difficulty', 'seasons', 'legacyScore'],
    'purchase_screen_opened': ['product'],
    'entitlement_restored': ['product'],
    'client_error': ['area', 'category', 'code'],
  };
  static const _values = <String, Set<String>>{
    'position': {'striker', 'winger', 'midfielder', 'defender'},
    'difficulty': {'story', 'professional', 'worldClass', 'balanced', 'elite'},
    'result': {'win', 'draw', 'loss'},
    'product': {'extra_career_slots', 'supporter_pack'},
  };
  static const _safeTextFields = {'area', 'category', 'code'};

  // Serialize persistence and network acknowledgements so a flush cannot erase
  // a concurrently recorded event or a consent withdrawal.
  Future<void> _serialize(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<bool> isGranted() async =>
      !_withdrawn && await _store.getPreference(_preferenceKey) == true;

  Future<void> setConsent(bool granted) {
    // Stop subsequent batches immediately, even while an earlier request is in
    // flight. Already transmitted requests cannot be recalled.
    _withdrawn = !granted;
    return _serialize(() async {
      await _store.setPreference(_preferenceKey, granted);
      await _store.setPreference(_pendingConsentKey, true);
      if (!granted) await _store.setPreference(_queueKey, <Object?>[]);
      await _replayConsent();
    });
  }

  Future<void> replayConsent() => _serialize(_replayConsent);

  Future<void> _replayConsent() async {
    // Re-send explicit device consent for every restored/new account, including
    // consent saved before the retry flag was introduced.
    if (await _store.getPreference(_preferenceKey) is! bool) return;
    final granted = await isGranted();
    try {
      await _api.setAnalyticsConsent(
        granted: granted,
        policyVersion: policyVersion,
      );
      await _store.setPreference(_pendingConsentKey, false);
    } on Object {
      // Consent remains marked pending and is replayed after sign-in/startup.
    }
  }

  Future<void> record(
    String name, {
    Map<String, Object?> properties = const {},
  }) => _serialize(() async {
    if (!await isGranted()) return;
    final safe = _scrub(name, properties);
    if (safe == null) return;
    final event = <String, Object?>{
      'eventId': generateUuidV4(),
      'eventName': name,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
      'properties': safe,
    };
    final queued = await _queue();
    queued.add(event);
    if (queued.length > _queueLimit) {
      queued.removeRange(0, queued.length - _queueLimit);
    }
    await _store.setPreference(_queueKey, queued);
    await _flush();
  });

  Map<String, Object?>? _scrub(String name, Map properties) {
    final allowed = _allowed[name];
    if (allowed == null) return null;
    final safe = <String, Object?>{};
    for (final key in allowed) {
      final value = properties[key];
      if (_values.containsKey(key)) {
        if (value is! String || !_values[key]!.contains(value)) return null;
      } else if (_safeTextFields.contains(key)) {
        if (value is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(value)) {
          return null;
        }
      } else if (value is! int || value < 0 || value > 10000000) {
        return null;
      }
      safe[key] = value;
    }
    return safe;
  }

  Future<void> flush() => _serialize(_flush);

  Future<void> _flush() async {
    if (!await isGranted()) return;
    final queued = await _queue();
    await _store.setPreference(_queueKey, queued);
    if (queued.isEmpty) return;
    try {
      while (queued.isNotEmpty && !_withdrawn) {
        final batch = queued.take(50).toList();
        // A 202 acknowledges the whole idempotent batch, including duplicates.
        // The accepted count counts newly inserted rows only.
        await _api.sendAnalytics(batch);
        queued.removeRange(0, batch.length);
        await _store.setPreference(_queueKey, queued);
      }
    } on Object {
      // The bounded, allowlisted queue is retried without blocking offline play.
    }
  }

  Future<List<Map<String, Object?>>> _queue() async {
    final stored = await _store.getPreference(_queueKey);
    if (stored is! List) return <Map<String, Object?>>[];
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    return stored
        .whereType<Map>()
        .map((value) => value.cast<String, Object?>())
        .where((value) {
          final occurredAt = value['occurredAt'];
          final occurred = occurredAt is String
              ? DateTime.tryParse(occurredAt)
              : null;
          final id = value['eventId'];
          return occurred != null &&
              occurred.isAfter(cutoff) &&
              id is String &&
              RegExp(r'^[a-f0-9-]{36}$').hasMatch(id) &&
              _allowed.containsKey(value['eventName']);
        })
        .map((value) {
          final name = value['eventName'] as String;
          final source = value['properties'];
          final safe = _scrub(name, source is Map ? source : const {});
          if (safe == null) return null;
          return <String, Object?>{
            'eventId': value['eventId'],
            'eventName': name,
            'occurredAt': value['occurredAt'],
            'properties': safe,
          };
        })
        .whereType<Map<String, Object?>>()
        .take(_queueLimit)
        .toList();
  }
}
