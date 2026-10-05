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
import 'src/screens/language_selection_screen.dart';
import 'src/screens/onboarding_screen.dart';
import 'src/services/analytics_service.dart';
import 'src/services/auth_service.dart';
import 'src/services/content_service.dart';
import 'src/services/elevenward_api.dart';
import 'src/services/entitlement_service.dart';
import 'src/services/privacy_error_reporter.dart';
import 'src/services/review_prompt_service.dart';
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
    reviewPrompts: ReviewPromptService(store: careerStore),
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
  final startupBrightness = switch (controller.displayMode) {
    ThemeMode.dark => Brightness.dark,
    ThemeMode.light => Brightness.light,
    ThemeMode.system => PlatformDispatcher.instance.platformBrightness,
  };
  SystemChrome.setSystemUIOverlayStyle(_systemUiStyle(startupBrightness));
  runApp(ElevenwardApp(controller: controller));
}

SystemUiOverlayStyle _systemUiStyle(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: brightness,
    systemNavigationBarColor: isDark
        ? ElevenwardPalette.dark.ink
        : ElevenwardPalette.light.ink,
    systemNavigationBarIconBrightness: isDark
        ? Brightness.light
        : Brightness.dark,
  );
}

class ElevenwardApp extends StatefulWidget {
  const ElevenwardApp({super.key, this.careerStore, this.controller});

  final CareerStore? careerStore;
  final AppController? controller;

  @override
  State<ElevenwardApp> createState() => _ElevenwardAppState();
}

class _ElevenwardAppState extends State<ElevenwardApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller?.resumed();
  }

  @override
  Widget build(BuildContext context) {
    final appController = widget.controller;
    return AnimatedBuilder(
      animation: appController ?? _NoopListenable.instance,
      builder: (context, _) => MaterialApp(
        title: 'Elevenward',
        debugShowCheckedModeBanner: false,
        theme: buildElevenwardTheme(
          appController?.themeId ?? 'graphite',
          Brightness.light,
        ),
        darkTheme: buildElevenwardTheme(
          appController?.themeId ?? 'graphite',
          Brightness.dark,
        ),
        themeMode: appController?.displayMode ?? ThemeMode.dark,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          ElevenwardColors.use(brightness);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: _systemUiStyle(brightness),
            child: child ?? const SizedBox.shrink(),
          );
        },
        locale: appController?.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: appController == null
            ? GameScreen(careerStore: widget.careerStore)
            : switch (appController.stage) {
                AppStage.booting => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                AppStage.languageSelection => LanguageSelectionScreen(
                  onSelected: appController.selectInitialLanguage,
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
