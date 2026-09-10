import 'package:elevenward/main.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late SecureCredentials credentials;
  late ElevenwardApi api;
  late ContentService content;

  setUpAll(() async {
    sqfliteFfiInit();
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    credentials = SecureCredentials();
    api = ElevenwardApi(accessToken: credentials.readAccountToken);
    content = ContentService(api: api, store: store);
  });

  tearDownAll(() async {
    content.close();
    api.close();
    await store.close();
  });

  testWidgets('More opens five focused destinations', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    await tester.pumpWidget(ElevenwardApp(controller: controller));
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-hub')), findsOneWidget);

    for (final destination in const [
      ('more-player', 'more-player-screen'),
      ('more-legacy', 'more-legacy-screen'),
      ('more-appearance', 'more-appearance-screen'),
      ('more-settings', 'more-settings-screen'),
      ('more-account', 'more-account-screen'),
    ]) {
      final tile = find.byKey(Key(destination.$1));
      await _revealInMore(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byKey(Key(destination.$2)), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('more-hub')),
        const Offset(0, 1800),
      );
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Player files, edits, and cancels a transfer request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);
    final originalTrust = controller.activeCareer!.player.managerTrust;

    await tester.pumpWidget(ElevenwardApp(controller: controller));
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more-player')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('player-transfer-request')),
      260,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('more-player-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('player-transfer-request')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('player-transfer-request')));
    await tester.pumpAndSettle();

    final league = find.byKey(const Key('transfer-league-spain-first'));
    await tester.scrollUntilVisible(
      league,
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('transfer-request-league-step')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(league);
    await tester.pump();
    await tester.tap(find.byKey(const Key('transfer-request-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-club-any')));
    await tester.tap(find.byKey(const Key('transfer-request-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-request-confirm')));
    await tester.runAsync(() async {
      while (controller.activeCareer!.transferRequest == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(
      controller.activeCareer!.transferRequest?.targetLeagueId,
      'spain-first',
    );
    expect(
      controller.activeCareer!.player.managerTrust,
      originalTrust - CareerEngine.transferRequestManagerTrustPenalty,
    );
    expect(find.text('Active for the next offseason'), findsOneWidget);

    await tester.tap(find.byKey(const Key('player-transfer-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel request').last);
    await tester.runAsync(() async {
      while (controller.activeCareer!.transferRequest != null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(controller.activeCareer!.transferRequest, isNull);
    expect(
      controller.activeCareer!.player.managerTrust,
      originalTrust - CareerEngine.transferRequestManagerTrustPenalty,
    );
  });

  testWidgets(
    'locked appearance choices explain access without changing state',
    (tester) async {
      final controller = _controller(store, credentials, api, content);
      addTearDown(controller.dispose);
      await tester.pumpWidget(ElevenwardApp(controller: controller));
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await _revealInMore(tester, find.byKey(const Key('more-appearance')));
      await tester.tap(find.byKey(const Key('more-appearance')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cosmetic-theme-ocean')));
      await tester.pumpAndSettle();
      expect(
        find.text('VIP or All-Access unlocks this cosmetic.'),
        findsOneWidget,
      );
      expect(controller.themeId, 'pitch');
    },
  );

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    testWidgets(
      'focused More pages support ${locale.toLanguageTag()} at 200 percent text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final controller = _controller(store, credentials, api, content)
          ..locale = locale;
        addTearDown(controller.dispose);

        await tester.pumpWidget(ElevenwardApp(controller: controller));
        await tester.tap(find.byIcon(Icons.more_horiz_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final destination in const [
          ('more-player', 'more-player-screen'),
          ('more-legacy', 'more-legacy-screen'),
          ('more-appearance', 'more-appearance-screen'),
          ('more-settings', 'more-settings-screen'),
          ('more-account', 'more-account-screen'),
        ]) {
          final tile = find.byKey(Key(destination.$1));
          await _revealInMore(tester, tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(find.byKey(Key(destination.$2)), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '${destination.$2} in ${locale.toLanguageTag()}',
          );
          Navigator.of(tester.element(find.byKey(Key(destination.$2)))).pop();
          await tester.pumpAndSettle();
        }
      },
    );
  }
}

Future<void> _revealInMore(WidgetTester tester, Finder target) async {
  // Pushed routes preserve the hub's scroll offset. Always return to its start
  // before locating a lazily-built sliver child so destinations work in any
  // traversal order and at large text scales.
  await tester.drag(find.byKey(const Key('more-hub')), const Offset(0, 10000));
  await tester.pumpAndSettle();
  for (
    var attempt = 0;
    attempt < 40 && target.evaluate().isEmpty;
    attempt += 1
  ) {
    await tester.drag(find.byKey(const Key('more-hub')), const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

AppController _controller(
  CareerStore store,
  SecureCredentials credentials,
  ElevenwardApi api,
  ContentService content,
) {
  final entitlements = EntitlementService(
    credentials: credentials,
    store: store,
  );
  return AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: entitlements,
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    )
    ..activeSlotIndex = 0
    ..activeCareer = CareerSnapshot.newCareer()
    ..stage = AppStage.playing;
}
