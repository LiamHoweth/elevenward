import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/shop_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
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

  testWidgets(
    'shop is available without an active career and uses store prices',
    (tester) async {
      _useTallSurface(tester);
      final controller = _shopController(
        store: store,
        credentials: credentials,
        api: api,
        content: content,
        prices: {
          for (final product in gamePassDefinitions)
            product.productId: switch (product.id) {
              GamePassId.allAccess => r'$10.49',
              GamePassId.vip => r'$5.49',
              _ => r'$4.49',
            },
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(controller));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('All-Access Pass'), findsOneWidget);
      expect(find.text('VIP Starter Pack'), findsOneWidget);
      expect(find.text('2× Development'), findsOneWidget);
      expect(find.text('2× Money'), findsOneWidget);
      expect(find.text('Stack them. Multiply the reward.'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('1.5×'), findsOneWidget);
      expect(find.text('3×'), findsOneWidget);
      expect(find.text(r'$10.49'), findsWidgets);
      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final heroTop = tester.getTopLeft(find.byKey(const Key('shop-hero'))).dy;
      expect(heroTop - appBarBottom, greaterThanOrEqualTo(19));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('partial ownership disables the non-prorated All-Access bundle', (
    tester,
  ) async {
    _useTallSurface(tester);
    final controller = _shopController(
      store: store,
      credentials: credentials,
      api: api,
      content: content,
      state: const EntitlementState(
        ownedPasses: {GamePassId.doubleDevelopment},
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('cannot be prorated'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('purchase-allAccess')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Owned'), findsWidgets);
  });

  testWidgets('All-Access marks each focused pass as included', (tester) async {
    _useTallSurface(tester);
    final controller = _shopController(
      store: store,
      credentials: credentials,
      api: api,
      content: content,
      state: const EntitlementState(ownedPasses: {GamePassId.allAccess}),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Included with All-Access'), findsNWidgets(3));
    expect(find.text('Owned'), findsWidgets);
  });

  testWidgets('cancelled and restored purchases have distinct feedback', (
    tester,
  ) async {
    final controller = _shopController(
      store: store,
      credentials: credentials,
      api: api,
      content: content,
    );
    addTearDown(controller.dispose);
    controller.lastPurchaseOutcome = PurchaseUiOutcome.cancelled;
    await tester.pumpWidget(_app(controller));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Purchase cancelled. Nothing was charged.'),
      findsOneWidget,
    );

    controller.lastPurchaseOutcome = PurchaseUiOutcome.restored;
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Permanent purchases restored.'), findsOneWidget);
  });

  testWidgets('shop remains scrollable at 200 percent text with long prices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _shopController(
      store: store,
      credentials: credentials,
      api: api,
      content: content,
      prices: {
        for (final product in gamePassDefinitions)
          product.productId: 'R\$ 123.456,78',
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('gamepass-doubleMoney')),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, processing, and failed catalog states are explicit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final loading = _shopController(
      store: store,
      credentials: credentials,
      api: api,
      content: content,
      catalogStatus: StoreCatalogStatus.loading,
    );
    addTearDown(loading.dispose);
    await tester.pumpWidget(_app(loading));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(LinearProgressIndicator),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    loading.processingPass = GamePassId.allAccess;
    loading.busy = true;
    loading.notifyListeners();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('purchase-allAccess')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('purchase-allAccess')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    final failed = _shopController(
      store: store,
      credentials: credentials,
      api: api,
      content: content,
      catalogStatus: StoreCatalogStatus.failed,
    );
    addTearDown(failed.dispose);
    await tester.pumpWidget(_app(failed));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Retry store'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Retry store'), findsOneWidget);
    expect(find.text(r'$9.99'), findsNothing);
  });
}

Widget _app(AppController controller) => MaterialApp(
  key: ValueKey(controller),
  theme: buildElevenwardTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: AnimatedBuilder(
    animation: controller,
    builder: (_, _) =>
        ShopScreen(controller: controller, showAtmosphere: false),
  ),
);

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AppController _shopController({
  required CareerStore store,
  required SecureCredentials credentials,
  required ElevenwardApi api,
  required ContentService content,
  EntitlementState state = const EntitlementState(),
  Map<String, String> prices = const {},
  StoreCatalogStatus catalogStatus = StoreCatalogStatus.available,
}) {
  final available = gamePassDefinitions.map((item) => item.productId).toSet();
  final entitlements = EntitlementService(
    credentials: credentials,
    store: store,
    initialState: state,
    initialCatalogStatus: catalogStatus,
    initialLocalizedPrices:
        prices.isEmpty && catalogStatus == StoreCatalogStatus.available
        ? {for (final id in available) id: r'$9.99'}
        : prices,
    initialAvailableProductIds: catalogStatus == StoreCatalogStatus.available
        ? available
        : const {},
  );
  return AppController(
    store: store,
    auth: AuthService(api: api, credentials: credentials),
    entitlements: entitlements,
    sync: SyncService(api, store),
    analytics: AnalyticsService(api, store),
    content: content,
  )..entitlementState = state;
}
