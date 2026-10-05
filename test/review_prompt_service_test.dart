import 'dart:async';

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

  test(
    'includes completed seasons after an international tournament',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final requester = _FakeReviewRequester();
      final service = ReviewPromptService(
        store: store,
        requester: requester,
        loadAppVersion: () async => '1.1.0',
        platformSupported: true,
      );
      expect(
        await service.requestAfterSeason(
          CareerSnapshot.newCareer().copyWith(
            week: 24,
            phase: CareerPhase.internationalTournament,
          ),
        ),
        isFalse,
      );
      expect(
        await service.requestAfterSeason(
          CareerSnapshot.newCareer().copyWith(
            week: 25,
            phase: CareerPhase.offseason,
          ),
        ),
        isTrue,
      );
      expect(requester.requestCount, 1);
    },
  );

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

  test(
    'cancels when visibility changes during platform availability check',
    () async {
      final store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      addTearDown(store.close);
      final availability = Completer<bool>();
      final availabilityStarted = Completer<void>();
      final requester = _FakeReviewRequester(
        availability: () {
          availabilityStarted.complete();
          return availability.future;
        },
      );
      final service = ReviewPromptService(
        store: store,
        requester: requester,
        loadAppVersion: () async => '1.1.0',
        platformSupported: true,
      );
      var visible = true;
      final request = service.requestAfterSeason(
        CareerSnapshot.newCareer().copyWith(
          week: 18,
          phase: CareerPhase.offseason,
        ),
        isEligible: () => visible,
      );
      await availabilityStarted.future;
      visible = false;
      availability.complete(true);
      expect(await request, isFalse);
      expect(requester.requestCount, 0);
      expect(await store.getPreference('review.lastRequestedAt'), isNull);
    },
  );
}

final class _FakeReviewRequester implements ReviewRequester {
  _FakeReviewRequester({this.available = true, this.availability});

  bool available;
  int requestCount = 0;
  final Future<bool> Function()? availability;

  @override
  Future<bool> isAvailable() async => availability?.call() ?? available;

  @override
  Future<void> requestReview() async {
    requestCount += 1;
  }
}
