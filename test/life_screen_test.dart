import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/life_screen.dart';
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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late SecureCredentials credentials;
  late ElevenwardApi api;
  late ContentService content;
  final catalog = buildLaunchContent();

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

  AppController controller({int money = 100000000}) {
    final result = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    )..activeSlotIndex = 0;
    final career = CareerSnapshot.newCareer();
    result.activeCareer = career.copyWith(
      player: career.player.copyWith(money: money, reputation: 99),
      wellness: 99,
    );
    addTearDown(result.dispose);
    return result;
  }

  LifestyleItemDefinition firstItem(AppController app) =>
      const LifestyleMarketEngine()
          .stockFor(app.activeCareer!, catalog)
          .forCategory(LifestyleCategory.wellness)
          .first;

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('market review fits ${locale.toLanguageTag()} at 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = controller();
      final before = app.activeCareer!.encode();
      await _openMarket(tester, app, catalog, locale: locale);
      expect(
        find.byKey(const Key('lifestyle-available-money')),
        findsOneWidget,
      );
      final item = firstItem(app);
      final description = tester.widget<Text>(
        find.descendant(
          of: find.byKey(Key('lifestyle-listing-${item.id}')),
          matching: find.text(
            item.description.forLocale(
              locale.languageCode == 'pt' ? 'pt-BR' : locale.languageCode,
            ),
          ),
        ),
      );
      expect(description.maxLines, isNull);
      expect(description.overflow, isNull);
      final buy = find.byKey(Key('lifestyle-buy-${item.id}'));
      await tester.ensureVisible(buy);
      await tester.pumpAndSettle();
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('lifestyle-purchase-review')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lifestyle-purchase-balance')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('lifestyle-purchase-price')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('lifestyle-purchase-cancel')));
      await tester.pumpAndSettle();
      expect(app.activeCareer!.encode(), before);
    });
  }

  testWidgets('reviewed purchase saves exactly once with the engine effects', (
    tester,
  ) async {
    final app = controller();
    final before = app.activeCareer!;
    final item = firstItem(app);
    await _openMarket(tester, app, catalog);
    final buy = find.byKey(Key('lifestyle-buy-${item.id}'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.pumpAndSettle();
    final expected = const CareerEngine().purchaseLifestyleItem(
      snapshot: before,
      item: item,
      updatedAt: before.updatedAt,
    );
    if (item.wellnessEffect != 0) {
      expect(find.text('Wellness: 99 → ${expected.wellness}'), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('lifestyle-purchase-confirm')));
    await tester.pump();
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (app.activeCareer!.ownedItemIds.contains(item.id)) break;
    }
    expect(app.activeCareer!.player.money, before.player.money - item.price);
    expect(
      app.activeCareer!.ownedItemIds.where((id) => id == item.id),
      hasLength(1),
    );
    expect(app.activeCareer!.equippedItemIds[item.category.name], item.id);
    expect(app.activeCareer!.wellness, expected.wellness);
    expect(app.activeCareer!.player.reputation, expected.player.reputation);
    expect(app.activeCareer!.revision, before.revision + 1);
    expect(find.byKey(Key('lifestyle-buy-${item.id}')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'French home review renders the full name and visible price at 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = controller();
      final item = const LifestyleMarketEngine()
          .stockFor(app.activeCareer!, catalog)
          .forCategory(LifestyleCategory.home)
          .first;
      await _openMarket(
        tester,
        app,
        catalog,
        locale: const Locale('fr'),
        category: LifestyleCategory.home,
      );
      final buy = find.byKey(Key('lifestyle-buy-${item.id}'));
      await tester.ensureVisible(buy);
      await tester.pumpAndSettle();
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('lifestyle-purchase-price')).hitTestable(),
        findsOneWidget,
      );
      final title = find.byKey(const Key('lifestyle-purchase-item-name'));
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: title, matching: find.byType(RichText)),
      );
      final name = item.name.forLocale('fr');
      final label = tester.widget<Text>(title);
      expect(label.data, name);
      expect(label.maxLines, isNull);
      expect(label.overflow, isNull);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.size.width, inInclusiveRange(250, 288));
      expect(
        find.byKey(const Key('lifestyle-purchase-confirm')).hitTestable(),
        findsOneWidget,
      );
      final cancel = find.byKey(const Key('lifestyle-purchase-cancel'));
      expect(cancel.hitTestable(), findsOneWidget);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(app.activeCareer!.ownedItemIds.contains(item.id), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('purchase review refuses a career changed while open', (
    tester,
  ) async {
    final app = controller();
    final item = firstItem(app);
    await _openMarket(tester, app, catalog);
    final buy = find.byKey(Key('lifestyle-buy-${item.id}'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.pumpAndSettle();
    final changed = app.activeCareer!.copyWith(
      revision: app.activeCareer!.revision + 1,
    );
    app.activeCareer = changed;
    await tester.tap(find.byKey(const Key('lifestyle-purchase-confirm')));
    await tester.pumpAndSettle();
    expect(app.activeCareer!.encode(), changed.encode());
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unaffordable listings explain the disabled purchase', (
    tester,
  ) async {
    final app = controller(money: 0);
    await _openMarket(tester, app, catalog);
    final item = firstItem(app);
    final buy = find.byKey(Key('lifestyle-buy-${item.id}'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(buy).onPressed, isNull);
    expect(find.text('Not enough money'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openMarket(
  WidgetTester tester,
  AppController controller,
  ContentCatalog catalog, {
  Locale locale = const Locale('en'),
  LifestyleCategory category = LifestyleCategory.wellness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildElevenwardTheme(),
      home: Scaffold(
        body: LifeScreen(controller: controller, contentCatalog: catalog),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final contentLocale = locale.languageCode == 'pt'
      ? 'pt-BR'
      : locale.languageCode;
  final salary = find.text(uiCopy(contentLocale, 'monthlyIncome'));
  final sponsors = find.text(uiCopy(contentLocale, 'weeklySponsors'));
  for (final metric in [salary, sponsors]) {
    final label = tester.widget<Text>(metric);
    expect(label.maxLines, isNull);
    expect(label.overflow, isNull);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: metric, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  }
  expect(tester.getCenter(salary).dx, lessThan(tester.getCenter(sponsors).dx));
  final agentTile = find.byKey(const Key('life-action-agent'));
  if (MediaQuery.textScalerOf(tester.element(agentTile)).scale(14) >= 21) {
    final agentTitle = find.descendant(
      of: agentTile,
      matching: find.text(AppLocalizations.of(tester.element(agentTile)).agent),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: agentTitle, matching: find.byType(RichText)),
    );
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(tester.getSize(agentTile).width - 28),
    );
    for (final text in tester.widgetList<Text>(
      find.descendant(of: agentTile, matching: find.byType(Text)),
    )) {
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }
  }
  final market = find.byKey(const Key('life-action-market'));
  await tester.scrollUntilVisible(
    market,
    180,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('life-action-list')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(market);
  await tester.pumpAndSettle();
  expect(market.hitTestable(), findsOneWidget);
  await tester.tap(market);
  await tester.pumpAndSettle();
  final destination = find.byKey(const Key('life-destination-market'));
  expect(destination, findsOneWidget);
  final wellness = find.byKey(Key('lifestyle-shop-${category.name}'));
  await tester.scrollUntilVisible(
    wellness,
    180,
    scrollable: find
        .descendant(of: destination, matching: find.byType(Scrollable))
        .first,
  );
  await tester.ensureVisible(wellness);
  await tester.pumpAndSettle();
  expect(wellness.hitTestable(), findsOneWidget);
  await tester.tap(wellness);
  await tester.pumpAndSettle();
}
