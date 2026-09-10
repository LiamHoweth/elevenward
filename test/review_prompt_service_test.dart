import 'package:elevenward/src/services/review_prompt_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('requests once for an eligible completed season', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final requester = _FakeReviewRequester();
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      loadAppVersion: () async => '1.0.0',
      now: () => DateTime.utc(2026, 9, 8),
      platformSupported: true,
    );
    final seasonBreak = CareerSnapshot.newCareer().copyWith(
      week: 18,
      phase: CareerPhase.offseason,
    );

    expect(await service.requestAfterSeason(seasonBreak), isTrue);
    expect(await service.requestAfterSeason(seasonBreak), isFalse);
    expect(requester.requestCount, 1);
  });

  test('requires a season break and an available system prompt', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final requester = _FakeReviewRequester(available: false);
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      loadAppVersion: () async => '1.0.0',
      now: () => DateTime.utc(2026, 9, 8),
      platformSupported: true,
    );

    expect(
      await service.requestAfterSeason(CareerSnapshot.newCareer()),
      isFalse,
    );
    requester.available = true;
    expect(
      await service.requestAfterSeason(
        CareerSnapshot.newCareer().copyWith(
          week: 18,
          phase: CareerPhase.offseason,
        ),
      ),
      isTrue,
    );
    expect(requester.requestCount, 1);
  });

  test('enforces both version and 120-day cooldown rules', () async {
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final requester = _FakeReviewRequester();
    var version = '1.0.0';
    var now = DateTime.utc(2026, 1, 1);
    final service = ReviewPromptService(
      store: store,
      requester: requester,
      loadAppVersion: () async => version,
      now: () => now,
      platformSupported: true,
    );
    final seasonBreak = CareerSnapshot.newCareer().copyWith(
      week: 18,
      phase: CareerPhase.offseason,
    );

    expect(await service.requestAfterSeason(seasonBreak), isTrue);
    version = '1.1.0';
    now = DateTime.utc(2026, 4, 30);
    expect(await service.requestAfterSeason(seasonBreak), isFalse);
    now = DateTime.utc(2026, 5, 1);
    expect(await service.requestAfterSeason(seasonBreak), isTrue);
    expect(requester.requestCount, 2);
  });
}

final class _FakeReviewRequester implements ReviewRequester {
  _FakeReviewRequester({this.available = true});

  bool available;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requestCount += 1;
  }
}
