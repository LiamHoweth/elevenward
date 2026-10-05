import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/career_hub_screen.dart';
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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late CareerStore store;
  late AppController controller;
  late ContentService content;
  late ElevenwardApi api;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: credentials.readAccountToken,
      client: MockClient((_) async => http.Response('{}', 404)),
    );
    content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    await controller.initialize();
  });
  tearDown(() async {
    ElevenwardColors.use(Brightness.dark);
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  Widget app(Locale locale) => MaterialApp(
    locale: locale,
    theme: buildElevenwardTheme('graphite'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CareerHubScreen(controller: controller),
  );

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    testWidgets(
      'hub identifies slots, next fixture and reviewed deletion at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final pinned = controller.availableContent!;
        final career = CareerSnapshot.newCareer(
          contentVersion: pinned.version,
          worldDefinition: pinned.catalog.world,
        );
        final opponent = const WorldSimulator().opponentFor(
          career,
          definition: pinned.catalog.world,
        );
        await tester.runAsync(() async {
          await store.saveSlot(0, career);
          await controller.refreshSlots();
        });
        await tester.pumpWidget(app(locale));
        await tester.pumpAndSettle();
        final detail = find.byKey(const Key('resume-career-context'));
        await _reveal(tester, detail);
        final l10n = AppLocalizations.of(tester.element(detail));
        expect(
          tester.widget<Text>(detail).data,
          '${l10n.nextMatch}: ${opponent.clubName} · ${opponent.isHome ? l10n.home : l10n.away}',
        );
        final slotLabel = find.byKey(const Key('career-slot-label-0'));
        await _reveal(tester, slotLabel);
        expect(
          tester.widget<Text>(slotLabel).data,
          '${uiCopy(locale.toLanguageTag(), 'slotLabel')} 1',
        );
        final deletion = find.byTooltip(
          uiCopy(locale.toLanguageTag(), 'deleteTooltip'),
        );
        await _reveal(tester, deletion);
        await tester.tap(deletion);
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('delete-career-name'))).data,
          career.player.name,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.seasonWeek(career.season, career.week)),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(
            TextButton,
            MaterialLocalizations.of(tester.element(find.byType(AlertDialog)))
                .cancelButtonLabel,
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          expect((await store.loadSlot(0))!.encode(), career.encode());
        });
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'conflict choices use full width at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final career = CareerSnapshot.newCareer();
        late int conflictId;
        await tester.runAsync(() async {
          await store.saveSlot(0, career);
          conflictId = await store.preserveConflict(
            local: career,
            remote: null,
            createdAt: DateTime.utc(2026, 10, 1),
          );
          await controller.refreshSlots();
        });
        await tester.pumpWidget(app(locale));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        final cloud = find.byKey(Key('hub-conflict-cloud-$conflictId'));
        final local = find.byKey(Key('hub-conflict-local-$conflictId'));
        await _reveal(tester, cloud);
        await _reveal(tester, local);
        final cloudRect = tester.getRect(cloud);
        final localRect = tester.getRect(local);
        expect(localRect.top, greaterThan(cloudRect.bottom));
        expect(cloudRect.width, localRect.width);
        expect(cloudRect.width, greaterThan(200));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saved offseason and retired state replace the next fixture', (
    tester,
  ) async {
    final base = CareerSnapshot.newCareer();
    for (final phase in [CareerPhase.offseason, CareerPhase.retired]) {
      final career = base.copyWith(
        phase: phase,
        retired: phase == CareerPhase.retired,
      );
      await tester.runAsync(() async {
        await store.saveSlot(0, career);
        await controller.refreshSlots();
      });
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pumpAndSettle();
      final detail = find.byKey(const Key('resume-career-context'));
      final l10n = AppLocalizations.of(tester.element(detail));
      expect(
        tester.widget<Text>(detail).data,
        phase == CareerPhase.retired
            ? l10n.careerComplete
            : l10n.seasonComplete,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
