import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/support_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Elevenward',
      packageName: 'test',
      version: '1.1.0',
      buildNumber: '5',
      buildSignature: 'test',
    );
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => null,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final credentials = SecureCredentials();
    content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    await store.setPreference('ui.supportDraft', {
      'category': 'feature',
      'message': 'Please add a useful career feature.',
      'contactEmail': '',
    });
  });
  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  testWidgets('restored support category matches the visible selected field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SupportScreen(controller: controller),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final field = find.byType(DropdownButtonFormField<String>);
    expect(field, findsOneWidget);
    expect(tester.state<FormFieldState<String>>(field).value, 'feature');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('feedback-message')))
          .controller!
          .text,
      'Please add a useful career feature.',
    );
  });
}
