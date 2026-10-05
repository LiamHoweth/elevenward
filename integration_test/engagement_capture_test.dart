import 'dart:io';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/career_hub_screen.dart';
import 'package:elevenward/src/screens/how_to_play_screen.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture engagement screens and complete the native match loop', (
    tester,
  ) async {
    final databasePath = p.join(
      Directory.systemTemp.path,
      'elevenward-engagement-qa.sqlite',
    );
    await deleteDatabase(databasePath);
    final store = await CareerStore.open(path: databasePath);
    final credentials = SecureCredentials();
    final api = ElevenwardApi(accessToken: credentials.readAccountToken);
    final content = ContentService(api: api, store: store);
    final controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    // A disposable QA database; never signs in or touches the player's database.
    final career = CareerSnapshot.newCareer(
      player: PlayerState.newCareer(
        id: 'engagement-qa',
        name: 'Mika Vale',
        archetype: Archetype.playmaker,
        portraitId: 'player_01',
      ),
    );
    await store.saveSlot(0, career);
    controller.activeSlotIndex = 0;
    controller.activeCareer = career;
    controller.slots = await store.listSlots();
    controller.activeContent = await content.load();
    controller.availableContent = controller.activeContent;
    for (final locale in [
      const Locale('en'),
      const Locale('es'),
      const Locale('pt', 'BR'),
      const Locale('fr'),
    ]) {
      Widget app(Widget child) => MaterialApp(
        locale: locale,
        theme: buildElevenwardTheme('graphite'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );
      final tag = locale.toLanguageTag();
      await tester.pumpWidget(app(CareerHubScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'resume');
      await tester.pumpWidget(
        app(
          GameScreen(
            key: ValueKey(tag),
            initialCareer: career,
            initialFocus: recommendedTrainingFocus(career.player.archetype),
            quickTransitions: true,
            onCareerChanged: (snapshot, eventType) async {
              expect(snapshot.revision, 1);
              await store.saveSlot(0, snapshot, eventType: eventType);
              expect((await store.loadSlot(0))?.encode(), snapshot.encode());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'career');
      await _reveal(tester, find.byKey(const Key('exact-training-preview')));
      await _capture(tester, tag, 'training');
      await tester.tap(find.byKey(const Key('weekly-continue-button')));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'selection');
      await _reveal(tester, find.byKey(const Key('spotlight-option-safe')));
      await tester.tap(find.byKey(const Key('spotlight-option-safe')));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('commit-button')));
      await tester.tap(find.byKey(const Key('commit-button')));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'recap');
      await _reveal(tester, find.byKey(const Key('recap-continue-button')));
      await tester.tap(find.byKey(const Key('recap-continue-button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(const HowToPlayScreen()));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'help');
      await tester.pumpWidget(app(SettingsScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'settings');
      await tester.pumpWidget(
        app(
          GameScreen(
            key: ValueKey('season-$tag'),
            initialCareer: career.copyWith(
              phase: CareerPhase.offseason,
              seasonHistory: [
                SeasonSummary(
                  season: 0,
                  age: 16,
                  clubId: career.clubId,
                  appearances: 10,
                  goals: 1,
                  assists: 2,
                  averageRating: 6.4,
                  trophies: const [],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'season');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });
}

Future<void> _capture(WidgetTester tester, String locale, String name) async {
  expect(tester.takeException(), isNull);
  final ack = File(
    p.join(Directory.systemTemp.path, 'elevenward-capture-$locale-$name.ack'),
  );
  if (await ack.exists()) await ack.delete();
  debugPrint('ENGAGEMENT_CAPTURE_READY|$locale|$name|${ack.path}');
  // The host acknowledges only after simctl has finished reading native pixels.
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!await ack.exists()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Capture was not acknowledged: $locale/$name');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await ack.delete();
  });
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 15000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
