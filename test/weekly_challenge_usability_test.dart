import 'dart:convert';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/weekly_challenge_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/api_models.dart';
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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late CareerStore store;
  late AppController controller;
  late ElevenwardApi api;
  late ContentService content;
  final requests = <http.Request>[];
  final enrolledAt = DateTime.utc(2026, 10, 1);
  const savedChoice = WeeklyChoice(
    focus: PlayerAttribute.pace,
    intensity: TrainingIntensity.light,
    spotlightApproach: SpotlightApproach.safe,
  );
  final actions = List.filled(3, savedChoice);
  setUp(() async {
    requests.clear();
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
    await store.setPreference('challenge.account.attempt', {
      'rulesVersion': WeeklyChallenge.rulesVersion,
      'contentVersion': WeeklyChallenge.contentVersion,
      'actions': actions.map((choice) => choice.toJson()).toList(),
    });
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => 'fixture-token',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'challenge': {
              'id': 'week',
              'startsAt': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'endsAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 7))
                  .toIso8601String(),
              'rulesVersion': WeeklyChallenge.rulesVersion,
              'contentVersion': WeeklyChallenge.contentVersion,
              'matchCount': WeeklyChallenge.matchCount,
              'configuration': {},
            },
            'attempt': {
              'attemptId': 'attempt',
              'seed': 14,
              'careerId': 'weekly',
              'status': 'enrolled',
              'enrolledAt': enrolledAt.toIso8601String(),
            },
            'entries': [],
          }),
          200,
        );
      }),
    );
    final credentials = SecureCredentials();
    content = ContentService(api: api, store: store);
    controller =
        AppController(
            store: store,
            auth: AuthService(api: api, credentials: credentials),
            entitlements: EntitlementService(
              credentials: credentials,
              store: store,
            ),
            sync: SyncService(api, store),
            analytics: AnalyticsService(api, store),
            content: content,
          )
          ..account = const ElevenwardAccount(
            id: 'account',
            alias: 'Me',
            provider: 'apple',
          );
  });
  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  testWidgets(
    'resume restores the saved plan and shows exact provisional match score',
    (tester) async {
      final regular = CareerSnapshot.newCareer(careerId: 'regular');
      await tester.runAsync(() => store.saveSlot(0, regular));
      final replay = const WeeklyChallenge().replay(
        seed: 14,
        careerId: 'weekly',
        updatedAt: enrolledAt,
        choices: actions,
      );
      await tester.pumpWidget(
        _app(WeeklyChallengeScreen(controller: controller)),
      );
      await _settleIo(tester);
      await _reveal(tester, find.byKey(const Key('challenge-local-score')));
      expect(find.text('Provisional score: ${replay.score}'), findsOneWidget);
      await _reveal(tester, find.byKey(const Key('challenge-focus-attempt')));
      expect(
        tester
            .state<FormFieldState<PlayerAttribute>>(
              find.byKey(const Key('challenge-focus-attempt')),
            )
            .value,
        PlayerAttribute.pace,
      );
      await _reveal(tester, find.byKey(const Key('challenge-load-attempt')));
      expect(
        tester
            .state<FormFieldState<TrainingIntensity>>(
              find.byKey(const Key('challenge-load-attempt')),
            )
            .value,
        TrainingIntensity.light,
      );
      await _reveal(
        tester,
        find.byKey(const Key('challenge-approach-attempt')),
      );
      expect(
        tester
            .state<FormFieldState<SpotlightApproach>>(
              find.byKey(const Key('challenge-approach-attempt')),
            )
            .value,
        SpotlightApproach.safe,
      );
      await _reveal(tester, find.byKey(const Key('challenge-next')));
      await tester.tap(find.byKey(const Key('challenge-next')));
      await _settleIo(tester);
      final stored = await tester.runAsync(
        () => store.getPreference('challenge.account.attempt'),
      ) as Map;
      expect(stored['actions'], [
        ...actions.map((choice) => choice.toJson()),
        savedChoice.toJson(),
      ]);
      expect(
        requests.where((request) => request.url.path.endsWith('/submit')),
        isEmpty,
      );
      expect(
        (await tester.runAsync(() => store.loadSlot(0)))!.encode(),
        regular.encode(),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in [
    const Locale('en'),
    const Locale('es'),
    const Locale('pt', 'BR'),
    const Locale('fr'),
  ]) {
    testWidgets(
      'active challenge controls fit 320px at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          _app(WeeklyChallengeScreen(controller: controller), locale: locale),
        );
        await _settleIo(tester);
        await _reveal(tester, find.byKey(const Key('challenge-local-score')));
        expect(tester.takeException(), isNull);
        await _reveal(tester, find.byKey(const Key('challenge-focus-attempt')));
        await tester.tap(find.byKey(const Key('challenge-focus-attempt')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        await _reveal(tester, find.byKey(const Key('challenge-load-attempt')));
        await tester.tap(find.byKey(const Key('challenge-load-attempt')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        await _reveal(
          tester,
          find.byKey(const Key('challenge-approach-attempt')),
        );
        await tester.tap(find.byKey(const Key('challenge-approach-attempt')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        await _reveal(tester, find.byKey(const Key('challenge-next')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> _settleIo(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
