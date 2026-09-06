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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('career opens only with its exact content release', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(store.close);
    final credentials = SecureCredentials();
    final api = ElevenwardApi(accessToken: credentials.readAccountToken);
    addTearDown(api.close);
    final content = ContentService(api: api, store: store);
    addTearDown(content.close);
    final controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    await store.setPreference('onboarding.completed', true);
    await store.saveSlot(
      0,
      CareerSnapshot.newCareer(
        careerId: 'unknown-content',
        contentVersion: '2099.1.0',
      ),
    );
    await controller.initialize();

    await controller.openSlot(0);
    expect(controller.stage, AppStage.careerSlots);
    expect(controller.activeCareer, isNull);
    expect(controller.lastMessage, contains('2099.1.0'));

    await store.saveSlot(
      0,
      CareerSnapshot.newCareer(
        careerId: 'compatible-content',
        contentVersion: '2026.1.0',
      ),
    );
    await controller.openSlot(0);
    expect(controller.stage, AppStage.playing);
    expect(controller.activeCareer?.careerId, 'compatible-content');
    expect(controller.activeContent?.version, '2026.1.0');

    controller.showCareerSlots();
    expect(controller.activeContent?.version, '2026.2.0');
  });
}
