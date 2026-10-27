import 'dart:io';

import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/career_hub_screen.dart';
import 'package:elevenward/src/screens/life_screen.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
import 'package:elevenward/src/screens/shop_screen.dart';
import 'package:elevenward/src/screens/world_screen.dart';
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

import '../tool/app_store/career_fixture.dart';

const _deviceClass = String.fromEnvironment(
  'APP_STORE_DEVICE_CLASS',
  defaultValue: 'iphone-65',
);
const _onlyScene = String.fromEnvironment('APP_STORE_CAPTURE_ONLY_SCENE');

const _locales = <(String, Locale)>[
  ('en', Locale('en')),
  ('es', Locale('es')),
  ('pt-BR', Locale('pt', 'BR')),
  ('fr', Locale('fr')),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture the localized App Store product-page story', (
    tester,
  ) async {
    debugPrint('[capture] configuring simulator surface');
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: ElevenwardColors.ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    debugPrint('[capture] building deterministic career fixture');
    final fixture = const AppStoreCareerFixtureBuilder().build();
    debugPrint('[capture] using production-engine seed ${fixture.seed}');
    final databasePath = p.join(
      Directory.systemTemp.path,
      'elevenward-app-store-capture.sqlite',
    );
    await deleteDatabase(databasePath);
    final store = await CareerStore.open(path: databasePath);
    debugPrint('[capture] seeding simulator-local SQLite');
    await store.saveSlot(0, fixture.midCareer, eventType: 'capture_fixture');
    await store.saveWeeklyFocus(
      fixture.midCareer.careerId,
      PlayerAttribute.composure,
    );
    final controller = _buildController(store);
    controller.activeSlotIndex = 0;
    controller.activeCareer = fixture.midCareer;
    controller.activeWeeklyFocus = PlayerAttribute.composure;
    controller.slots = await store.listSlots();
    controller.stage = AppStage.playing;

    // The first native capture must include decoded atmospheric art and the
    // small brand mark, so warm the image cache before the localized story.
    await _mount(
      tester,
      const Locale('en'),
      CareerHubScreen(controller: controller),
    );

    for (final (localeKey, locale) in _locales) {
      debugPrint('[capture] locale $localeKey');
      controller.locale = locale;
      controller.activeCareer = fixture.midCareer;
      controller.slots = await store.listSlots();

      await _mount(tester, locale, PlayerScreen(controller: controller));
      await _capture(tester, localeKey, '01-player-profile');
      debugPrint('[capture] preparing spotlight');

      await _mount(
        tester,
        locale,
        GameScreen(
          initialCareer: fixture.midCareer,
          initialFocus: PlayerAttribute.composure,
          avatarId: controller.avatarId,
        ),
      );
      debugPrint('[capture] tapping weekly continue');
      await tester.tap(find.byKey(const Key('weekly-continue-button')));
      debugPrint('[capture] weekly continue tapped');
      await tester.pump();
      debugPrint('[capture] matchup overlay opened');
      await tester.pump(const Duration(milliseconds: 2300));
      debugPrint('[capture] matchup overlay timer advanced');
      await tester.pump(const Duration(milliseconds: 400));
      debugPrint('[capture] spotlight rendered');
      final boldChoice = find.byKey(const Key('spotlight-option-bold'));
      if (boldChoice.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          boldChoice,
          300,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 20,
        );
      }
      await Scrollable.ensureVisible(
        tester.element(boldChoice),
        alignment: .84,
        duration: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, localeKey, '02-spotlight-decision');

      await _mount(
        tester,
        locale,
        Scaffold(
          body: SafeArea(
            child: WorldScreen(
              career: fixture.midCareer,
              definition: buildLatestContent().world,
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('world-tab-club')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      if (_deviceClass == 'iphone-65') {
        await tester.drag(
          find.byKey(const Key('world-club-stats-tab')),
          const Offset(0, -155),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _capture(tester, localeKey, '03-world-club');

      await _mount(
        tester,
        locale,
        GameScreen(
          initialCareer: fixture.midCareer,
          initialFocus: PlayerAttribute.composure,
          avatarId: controller.avatarId,
        ),
      );
      await _capture(tester, localeKey, '04-weekly-focus');

      await _mount(tester, locale, PlayerScreen(controller: controller));
      final transferButton = find.byKey(const Key('player-transfer-request'));
      await tester.scrollUntilVisible(
        transferButton,
        520,
        scrollable: find.descendant(
          of: find.byKey(const Key('more-player-screen')),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 20,
      );
      await Scrollable.ensureVisible(
        tester.element(transferButton),
        alignment: .48,
        duration: Duration.zero,
      );
      await tester.drag(
        find.descendant(
          of: find.byKey(const Key('more-player-screen')),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, -260),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, localeKey, '05-transfer-request');

      await _mount(
        tester,
        locale,
        Scaffold(
          body: SafeArea(
            child: LifeScreen(
              controller: controller,
              contentCatalog: buildLatestContent(),
            ),
          ),
        ),
      );
      await _capture(tester, localeKey, '06-life-overview');

      controller.activeCareer = fixture.lateCareer;
      await _mount(tester, locale, LegacyScreen(controller: controller));
      final honours = find.text(uiCopy(localeKey, 'careerHonours'));
      await tester.scrollUntilVisible(
        honours,
        440,
        scrollable: find.descendant(
          of: find.byKey(const Key('more-legacy-screen')),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 12,
      );
      await Scrollable.ensureVisible(
        tester.element(honours),
        alignment: .38,
        duration: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, localeKey, '07-legacy');

      controller.activeCareer = fixture.midCareer;
      controller.stage = AppStage.careerSlots;
      await _mount(tester, locale, CareerHubScreen(controller: controller));
      await _capture(tester, localeKey, '08-career-hub');
      controller.stage = AppStage.playing;
    }

    // Review evidence uses the real shop with uninitialized billing. Never
    // purchase, restore, inject ownership, or manufacture a localized price.
    controller.locale = const Locale('en');
    expect(controller.entitlementState.ownedPasses, isEmpty);
    await _mount(
      tester,
      const Locale('en'),
      ShopScreen(controller: controller),
    );
    const reviewScenes = <GamePassId, String>{
      GamePassId.allAccess: 'iap-all-access',
      GamePassId.vip: 'iap-vip',
      GamePassId.doubleDevelopment: 'iap-double-development',
      GamePassId.doubleMoney: 'iap-double-money',
    };
    for (final definition in gamePassDefinitions) {
      final card = find.byKey(Key('gamepass-${definition.id.name}'));
      await tester.scrollUntilVisible(card, 420, maxScrolls: 20);
      await Scrollable.ensureVisible(
        tester.element(card),
        alignment: .28,
        duration: Duration.zero,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await _capture(tester, 'en', reviewScenes[definition.id]!);
    }

    await store.close();
  });
}

AppController _buildController(CareerStore store) {
  final credentials = SecureCredentials();
  final api = ElevenwardApi(accessToken: () async => null);
  return AppController(
    store: store,
    auth: AuthService(api: api, credentials: credentials),
    entitlements: EntitlementService(credentials: credentials, store: store),
    sync: SyncService(api, store),
    analytics: AnalyticsService(api, store),
    content: ContentService(api: api, store: store),
  );
}

Future<void> _mount(WidgetTester tester, Locale locale, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      title: 'Elevenward',
      debugShowCheckedModeBanner: false,
      theme: buildElevenwardTheme('graphite'),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.noScaling,
          boldText: false,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: screen,
    ),
  );
  if (screen is CareerHubScreen) {
    await tester.runAsync(() async {
      final context = tester.element(find.byType(CareerHubScreen));
      await Future.wait([
        precacheImage(
          const AssetImage('assets/branding/graphite/elevenward-11-ui.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/visual/stadium-graphite.png'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/visual/player_portraits/player_01.webp'),
          context,
        ),
        precacheImage(
          const AssetImage('assets/visual/shop-all-access.png'),
          context,
        ),
      ]);
    });
  }
  await tester.pump(const Duration(milliseconds: 700));
  if (screen is CareerHubScreen) {
    final mark = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/branding/graphite/elevenward-11-ui.png',
    );
    expect(mark, findsOneWidget);
    expect(tester.renderObject<RenderImage>(mark).image, isNotNull);
  }
}

Future<void> _capture(WidgetTester tester, String locale, String source) async {
  if (_onlyScene.isNotEmpty && source != _onlyScene) return;
  final acknowledgment = File(
    p.join(Directory.systemTemp.path, 'elevenward-store-$locale-$source.ack'),
  );
  if (acknowledgment.existsSync()) acknowledgment.deleteSync();
  await tester.runAsync(() async {
    debugPrint(
      'APP_STORE_CAPTURE_READY|$locale|$_deviceClass|$source|'
      '${acknowledgment.path}',
    );
    final timeout = DateTime.now().add(const Duration(seconds: 45));
    while (!acknowledgment.existsSync()) {
      if (DateTime.now().isAfter(timeout)) {
        throw StateError('Host did not acknowledge $locale/$source capture.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 75));
    }
    acknowledgment.deleteSync();
  });
}
