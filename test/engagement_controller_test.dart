import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/career_hub_screen.dart';
import 'package:elevenward/src/theme.dart';
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
  setUpAll(sqfliteFfiInit);
  late CareerStore store;
  late AppController controller;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    final api = ElevenwardApi(accessToken: credentials.readAccountToken);
    final content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    addTearDown(() async {
      controller.dispose();
      content.close();
      api.close();
      await store.close();
    });
    await controller.initialize();
  });
  test(
    'new careers persist role focus and reopen with the exact saved choice',
    () async {
      final world = controller.availableContent!.catalog.world;
      for (final role in Archetype.values) {
        await controller.createCareer(
          slotIndex: 0,
          firstName: 'Test',
          lastName: 'Player',
          archetype: role,
          nationalTeamId: 'england',
          portraitId: 'player_01',
          club: world.clubs.first,
          difficulty: Difficulty.professional,
        );
        expect(controller.activeWeeklyFocus, recommendedTrainingFocus(role));
        expect(
          await store.loadWeeklyFocus(controller.activeCareer!.careerId),
          recommendedTrainingFocus(role),
        );
        expect(
          controller.resumeSlot?.snapshot?.careerId,
          controller.activeCareer!.careerId,
        );
        await controller.changeWeeklyFocus(PlayerAttribute.composure);
        controller.showCareerSlots();
        await controller.openSlot(0);
        expect(controller.activeWeeklyFocus, PlayerAttribute.composure);
        // Free the reviewed career before exercising the next archetype.
        // Creation deliberately refuses to overwrite an occupied slot.
        await controller.deleteSlot(0);
      }
    },
  );
  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    testWidgets(
      'resume card is reachable at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.runAsync(() async {
          await store.saveSlot(0, CareerSnapshot.newCareer());
          await controller.refreshSlots();
        });
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: buildElevenwardTheme('graphite'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CareerHubScreen(controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final resume = find.byKey(const Key('resume-career-button'));
        await tester.scrollUntilVisible(
          resume,
          150,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 80,
        );
        await tester.ensureVisible(resume);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(resume).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'resume uses stable career identity and never selects a deleted slot',
    () async {
      final older = CareerSnapshot.newCareer(
        careerId: 'old',
        updatedAt: DateTime.utc(2026, 1),
      );
      final newer = CareerSnapshot.newCareer(
        careerId: 'new',
        updatedAt: DateTime.utc(2026, 9),
      );
      await store.saveSlot(0, older);
      await store.saveSlot(1, newer);
      await controller.refreshSlots();
      expect(controller.resumeSlot?.snapshot?.careerId, 'new');
      await controller.openSlot(0);
      expect(controller.resumeSlot?.snapshot?.careerId, 'old');
      expect(await store.getPreference('ui.lastPlayedCareerId'), 'old');
      await controller.deleteSlot(0);
      expect(controller.resumeSlot?.snapshot?.careerId, 'new');
      await controller.deleteSlot(1);
      expect(controller.resumeSlot, isNull);
    },
  );
  test(
    'gameplay preferences are local, durable and do not rewrite careers',
    () async {
      final career = CareerSnapshot.newCareer();
      await store.saveSlot(0, career);
      await controller.changeGameplayPreference('quickTransitions', true);
      await controller.changeGameplayPreference('showCoachingTips', false);
      await controller.changeGameplayPreference('showCareerTarget', false);
      await controller.dismissCoachTip('focus');
      await controller.initialize();
      expect(controller.quickTransitions, isTrue);
      expect(controller.showCoachingTips, isFalse);
      expect(controller.showCareerTarget, isFalse);
      expect(controller.dismissedCoachTips, contains('focus'));
      expect((await store.loadSlot(0))!.encode(), career.encode());
    },
  );
}
