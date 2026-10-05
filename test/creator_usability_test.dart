import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/create_career_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;

  setUp(() async {
    sqfliteFfiInit();
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    api = ElevenwardApi(accessToken: credentials.readAccountToken);
    content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
  });

  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'nationality search opens matches and clears at 200 percent in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_app(controller, locale: locale));
        await _identity(tester);
        await _tap(tester, find.byKey(const Key('career-create-next')), 0);
        await _tap(
          tester,
          find.byKey(const Key('popular-nationality-england')),
          1,
        );
        final search = find.byKey(const Key('nationality-search'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'Portugal');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await _tap(tester, find.byKey(const Key('nationality-portugal')), 1);
        expect(
          tester
              .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
              .groupValue,
          'portugal',
        );
        await tester.ensureVisible(search);
        await tester.enterText(search, 'no-country-can-match-this');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('nationality-search-empty')),
        );
        expect(
          find.byKey(const Key('nationality-search-empty')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('popular-nationality-england')),
          findsNothing,
        );
        await _tap(
          tester,
          find.byKey(const Key('nationality-search-clear')),
          1,
        );
        expect(find.byKey(const Key('nationality-search-empty')), findsNothing);
        expect(
          find.byKey(const Key('popular-nationality-england')),
          findsOneWidget,
        );
        // The country list is lazy and below the popular shortcuts after
        // clearing. Verify the user's persistent selection in its summary.
        await tester.dragUntilVisible(
          find.text('Portugal'),
          find.byKey(const Key('career-creator-step-1')),
          const Offset(0, 220),
        );
        await tester.ensureVisible(find.text('Portugal'));
        await tester.pumpAndSettle();
        expect(find.text('Portugal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('route back moves one step and cancels an edit from review', (
    tester,
  ) async {
    await tester.pumpWidget(_app(controller));
    await _review(tester);
    await _tap(tester, find.byTooltip('Edit Position'), 3);
    await _tap(tester, find.byKey(const Key('career-position-defender')), 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-creator-step-3')), findsOneWidget);
    expect(find.text('Midfielder'), findsOneWidget);
    expect(find.text('Playmaker'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-creator-step-2')), findsOneWidget);
    expect(find.byKey(const Key('career-create-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creation failure leaves choices reviewable and permits retry', (
    tester,
  ) async {
    await tester.pumpWidget(_app(controller));
    await _review(tester);
    await tester.runAsync(store.close);
    await tester.tap(find.byKey(const Key('career-create-save')));
    await _waitForSave(tester);
    expect(find.byKey(const Key('career-creator-step-3')), findsOneWidget);
    expect(find.text('Ari Vale'), findsOneWidget);
    expect(
      find.text('Something went wrong. Your local career is safe; try again.'),
      findsOneWidget,
    );
    expect(controller.activeCareer, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an occupied slot preserves the creator and existing career', (
    tester,
  ) async {
    final previous = CareerSnapshot.newCareer();
    await tester.runAsync(
      () => store.saveSlot(0, previous, eventType: 'test_existing_career'),
    );
    await tester.pumpWidget(_app(controller));
    await _review(tester);
    await tester.tap(find.byKey(const Key('career-create-save')));
    await _waitForSave(tester);
    expect(find.byKey(const Key('career-creator-step-3')), findsOneWidget);
    expect(controller.activeCareer, isNull);
    final saved = await tester.runAsync(() => store.loadSlot(0));
    expect(saved?.careerId, previous.careerId);
    expect(find.text('Ari Vale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(AppController controller, {Locale? locale}) => MaterialApp(
  theme: buildElevenwardTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) =>
                CreateCareerScreen(controller: controller, slotIndex: 0),
          ),
        ),
        child: const Text('Create'),
      ),
    ),
  ),
);

Future<void> _identity(WidgetTester tester) async {
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('career-first-name')), 'Ari');
  await tester.enterText(find.byKey(const Key('career-last-name')), 'Vale');
  tester.testTextInput.hide();
  await _tap(tester, find.byKey(const Key('career-position-midfielder')), 0);
  await _tap(tester, find.byKey(const Key('career-archetype-playmaker')), 0);
}

Future<void> _review(WidgetTester tester) async {
  await _identity(tester);
  await _tap(tester, find.byKey(const Key('career-create-next')), 0);
  await _tap(tester, find.byKey(const Key('popular-nationality-england')), 1);
  await _tap(tester, find.byKey(const Key('career-create-next')), 1);
  await tester.enterText(
    find.byKey(const Key('club-search')),
    'Northstar Athletic',
  );
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await _tap(
    tester,
    find.byKey(const Key('starting-club-england-northstar-athletic')),
    2,
  );
  await _tap(tester, find.byKey(const Key('career-create-next')), 2);
}

Future<void> _tap(WidgetTester tester, Finder control, int step) async {
  final next = find.byKey(const Key('career-create-next'));
  if (control.evaluate().isNotEmpty &&
      (control == next || control.evaluate().first.widget is FilledButton)) {
    await tester.tap(control);
    await tester.pumpAndSettle();
    return;
  }
  if (control.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      control,
      find.byKey(Key('career-creator-step-$step')),
      const Offset(0, -220),
    );
  }
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _waitForSave(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  do {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('career-create-save')),
    );
    if (save.onPressed != null) {
      await tester.pump();
      return;
    }
  } while (DateTime.now().isBefore(deadline));
  throw StateError('Creator save did not complete.');
}
