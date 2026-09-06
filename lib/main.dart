import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'src/app_controller.dart';
import 'src/game_screen.dart';
import 'src/screens/career_hub_screen.dart';
import 'src/screens/home_shell.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/services/analytics_service.dart';
import 'src/services/auth_service.dart';
import 'src/services/content_service.dart';
import 'src/services/elevenward_api.dart';
import 'src/services/entitlement_service.dart';
import 'src/services/privacy_error_reporter.dart';
import 'src/services/sync_service.dart';
import 'src/storage/career_store.dart';
import 'src/storage/secure_credentials.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ElevenwardColors.ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final careerStore = await CareerStore.open();
  final credentials = SecureCredentials();
  final api = ElevenwardApi(accessToken: credentials.readAccountToken);
  final controller = AppController(
    store: careerStore,
    auth: AuthService(api: api, credentials: credentials),
    entitlements: EntitlementService(
      credentials: credentials,
      store: careerStore,
    ),
    sync: SyncService(api, careerStore),
    analytics: AnalyticsService(api, careerStore),
    content: ContentService(api: api, store: careerStore),
  );
  final errorReporter = PrivacyErrorReporter(controller.analytics);
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(errorReporter.report('flutter', details.exception));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(errorReporter.report('platform', error));
    return false;
  };
  await controller.initialize();
  runApp(ElevenwardApp(controller: controller));
}

class ElevenwardApp extends StatelessWidget {
  const ElevenwardApp({super.key, this.careerStore, this.controller});

  final CareerStore? careerStore;
  final AppController? controller;

  @override
  Widget build(BuildContext context) {
    final appController = controller;
    return AnimatedBuilder(
      animation: appController ?? _NoopListenable.instance,
      builder: (context, _) => MaterialApp(
        title: 'Elevenward',
        debugShowCheckedModeBanner: false,
        theme: buildElevenwardTheme(appController?.themeId ?? 'pitch'),
        locale: appController?.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: appController == null
            ? GameScreen(careerStore: careerStore)
            : switch (appController.stage) {
                AppStage.booting => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                AppStage.onboarding => OnboardingScreen(
                  onComplete: appController.completeOnboarding,
                ),
                AppStage.careerSlots => CareerHubScreen(
                  controller: appController,
                ),
                AppStage.playing => HomeShell(controller: appController),
              },
      ),
    );
  }
}

final class _NoopListenable extends ChangeNotifier {
  _NoopListenable._();
  static final instance = _NoopListenable._();
}
