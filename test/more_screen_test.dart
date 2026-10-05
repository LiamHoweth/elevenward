import 'package:elevenward/main.dart';
import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/marketing_links.dart';
import 'package:elevenward/src/screens/more_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  testWidgets(
    'studio discovery opens only on tap and handles browser failure',
    (tester) async {
      final controller = _controller(store, credentials, api, content);
      addTearDown(controller.dispose);
      final before = controller.activeCareer!.encode();
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      var succeed = true;
      final launches = <Map>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        launches.add(call.arguments as Map);
        return succeed;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildElevenwardTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MoreScreen(
              controller: controller,
              marketingLinks: const StudioMarketingLinks(
                websiteBaseUrl: 'https://studio.example',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(launches, isEmpty);
      final destination = find.byKey(const Key('more-studio-games'));
      await _revealInMore(tester, destination);
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(launches, hasLength(1));
      expect(
        Uri.parse(launches.single['url'] as String).host,
        'studio.example',
      );
      expect(launches.single['useSafariVC'], isFalse);
      succeed = false;
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not open the website. Please try again.'),
        findsOneWidget,
      );
      expect(controller.activeCareer!.encode(), before);
      expect(tester.takeException(), isNull);
    },
  );

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

  testWidgets('large-text Player stat labels remain readable and explainable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);
    final before = controller.activeCareer!.encode();

    for (final locale in const ['en', 'es', 'pt-BR', 'fr']) {
      controller.locale = locale == 'pt-BR'
          ? const Locale('pt', 'BR')
          : Locale(locale);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(ElevenwardApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(NavigationDestination).at(3));
      await tester.pumpAndSettle();
      await _revealInMore(tester, find.byKey(const Key('more-player')));
      await tester.tap(find.byKey(const Key('more-player')));
      await tester.pumpAndSettle();
      final trust = find.byKey(const Key('player-stat-help-managerTrust'));
      final scrollable = find
          .descendant(
            of: find.byKey(const Key('more-player-screen')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(trust, 160, scrollable: scrollable);
      await tester.ensureVisible(trust);
      await tester.pumpAndSettle();
      final label = uiCopy(locale, 'managerTrust');
      final title = find.descendant(
        of: trust,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is RichText && widget.text.toPlainText().startsWith(label),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(title);
      final firstWord = label.split(' ').first;
      expect(
        paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: firstWord.length),
        ),
        hasLength(1),
        reason: '$locale trust label must preserve whole words at 200% text',
      );
      expect(trust.hitTestable(), findsOneWidget);
      await tester.tap(trust);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('stat-explanation-managerTrust')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('stat-explanation-close')));
      await tester.pumpAndSettle();
      expect(controller.activeCareer!.encode(), before);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
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
    await _waitForCommit(
      tester,
      () => controller.activeCareer!.transferRequest != null,
    );
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
    await _waitForCommit(
      tester,
      () => controller.activeCareer!.transferRequest == null,
    );
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
      expect(controller.themeId, 'graphite');
    },
  );

  testWidgets('display mode selection persists', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => store.setPreference('ui.displayMode', null));
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    await tester.pumpWidget(ElevenwardApp(controller: controller));
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await _revealInMore(tester, find.byKey(const Key('more-settings')));
    await tester.tap(find.byKey(const Key('more-settings')));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byKey(const Key('more-settings-screen'))))
          .brightness,
      Brightness.dark,
    );
    expect(ElevenwardColors.ink, ElevenwardPalette.dark.ink);
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(const Key('settings-display-mode')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      ElevenwardPalette.dark.panel,
    );
    await tester.tap(find.byKey(const Key('settings-display-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    expect(controller.displayMode, ThemeMode.light);
    expect(
      await tester.runAsync(() => store.getPreference('ui.displayMode')),
      'light',
    );
    expect(
      Theme.of(tester.element(find.byKey(const Key('more-settings-screen'))))
          .brightness,
      Brightness.light,
    );
    expect(ElevenwardColors.ink, ElevenwardPalette.light.ink);
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byKey(const Key('settings-display-mode')),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      ElevenwardPalette.light.panel,
    );
  });

  testWidgets('Follow System responds to appearance changes', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(() => store.setPreference('ui.displayMode', null));
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);
    controller.stage = AppStage.booting;
    await tester.runAsync(() => controller.changeDisplayMode(ThemeMode.system));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpWidget(ElevenwardApp(controller: controller));
    expect(
      Theme.of(tester.element(find.byType(CircularProgressIndicator)))
          .brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      Theme.of(tester.element(find.byType(CircularProgressIndicator)))
          .brightness,
      Brightness.light,
    );
    expect(ElevenwardColors.ink, ElevenwardPalette.light.ink);
    expect(
      await tester.runAsync(() => store.getPreference('ui.displayMode')),
      'system',
    );
  });

  test('legacy pitch and paid appearance preferences survive load', () async {
    addTearDown(() => store.setPreference('cosmetic.theme', null));
    addTearDown(() => store.setPreference('ui.displayMode', null));
    await store.setPreference('cosmetic.theme', 'pitch');
    await store.setPreference('ui.displayMode', null);
    final legacy = _controller(store, credentials, api, content);
    addTearDown(legacy.dispose);
    await legacy.initialize();
    expect(legacy.themeId, 'graphite');
    expect(legacy.displayMode, ThemeMode.dark);
    expect(await store.getPreference('cosmetic.theme'), 'pitch');

    await store.setPreference('cosmetic.theme', 'ocean');
    await store.setPreference('ui.displayMode', 'light');
    final premium = _controller(store, credentials, api, content);
    addTearDown(premium.dispose);
    await premium.initialize();
    expect(premium.themeId, 'ocean');
    expect(premium.displayMode, ThemeMode.light);
    expect(
      buildElevenwardTheme('ocean', Brightness.light).colorScheme.primary,
      ElevenwardPalette.light.action,
    );
  });

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

Future<void> _waitForCommit(
  WidgetTester tester,
  bool Function() committed,
) async {
  for (var attempt = 0; attempt < 200; attempt++) {
    // Native SQLite completes outside the fake clock; queued controller work
    // also needs a frame before the durable state can be published.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (committed()) return;
  }
  fail('The reviewed transfer did not commit.');
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
