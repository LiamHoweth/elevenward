import 'dart:convert';
import 'dart:io';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/create_career_screen.dart';
import 'package:elevenward/src/screens/life_screen.dart';
import 'package:elevenward/src/screens/hall_of_fame_screen.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
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
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Native evidence only: disposable databases and an allowlisted in-memory HTTP
// challenge fixture. No auth, billing, credentials, or production initialization.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native gameplay loop, improved screens and large text', (
    tester,
  ) async {
    final catalog = buildLatestContent();
    final base = _playedCareer(catalog);
    for (final locale in const [
      Locale('en'),
      Locale('es'),
      Locale('pt', 'BR'),
      Locale('fr'),
    ]) {
      final tag = locale.toLanguageTag();
      final brightness = tag == 'en' || tag == 'es'
          ? Brightness.dark
          : Brightness.light;
      final databasePath = p.join(
        Directory.systemTemp.path,
        'elevenward-gameplay-loop-qa-$tag.sqlite',
      );
      await deleteDatabase(databasePath);
      final session = await _FixtureSession.open(databasePath, base);
      Future<void> mount(
        Widget child,
        String scene, {
        bool compact = true,
      }) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _app(locale, brightness, child, scene, compact: compact),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tag/$scene');
      }

      Future<void> commit(CareerSnapshot snapshot, String eventType) async {
        await session.store.saveSlot(0, snapshot, eventType: eventType);
        expect((await session.store.loadSlot(0))!.encode(), snapshot.encode());
        session.controller.activeCareer = snapshot;
      }

      Widget game() => GameScreen(
        initialCareer: session.controller.activeCareer,
        initialFocus: PlayerAttribute.passing,
        contentCatalog: catalog,
        quickTransitions: true,
        showCoachingTips: false,
        showCareerTarget: false,
        onCareerChanged: commit,
      );

      await mount(game(), 'career-normal', compact: false);
      await _capture(tester, tag, 'career-normal');
      await _reveal(tester, find.byKey(const Key('exact-training-preview')));
      await _capture(tester, tag, 'training-normal');
      await _tap(tester, 'weekly-continue-button');
      await _capture(tester, tag, 'selection-normal');
      await _tap(tester, 'spotlight-option-safe');
      await _tap(tester, 'commit-button');
      expect(
        (await session.store.loadSlot(0))!.revision,
        greaterThan(base.revision),
      );
      await _capture(tester, tag, 'recap-normal');

      await mount(game(), 'training-comparison');
      await _tap(tester, 'training-load-comparison-toggle');
      await _reveal(tester, find.byKey(const Key('training-compare-balanced')));
      await _capture(tester, tag, 'training-comparison');
      await _tap(tester, 'training-compare-light');

      await mount(
        PlayerScreen(controller: session.controller),
        'player-normal',
        compact: false,
      );
      await _capture(tester, tag, 'player-normal');
      await mount(
        PlayerScreen(controller: session.controller),
        'player-overall',
      );
      await _capture(tester, tag, 'player-overall');
      await _reveal(tester, find.byKey(const Key('player-attributes')));
      await _capture(tester, tag, 'player-attributes');

      Widget life() => Scaffold(
        body: SafeArea(
          child: LifeScreen(
            controller: session.controller,
            contentCatalog: catalog,
          ),
        ),
      );
      await mount(life(), 'life-normal', compact: false);
      await _capture(tester, tag, 'life-normal');
      final funded = session.controller.activeCareer!.copyWith(
        player: session.controller.activeCareer!.player.copyWith(
          money: 100000000,
        ),
      );
      session.controller.activeCareer = funded;
      final stock = const LifestyleMarketEngine()
          .stockFor(funded, catalog)
          .forCategory(LifestyleCategory.home)
          .first;
      await mount(life(), 'life-purchase-review');
      await _tap(tester, 'life-action-market');
      await _tap(tester, 'lifestyle-shop-home');
      await _tap(tester, 'lifestyle-buy-${stock.id}');
      await _capture(tester, tag, 'life-purchase-review');
      await _tap(tester, 'lifestyle-purchase-cancel');
      expect(session.controller.activeCareer!.player.money, 100000000);

      await mount(
        CreateCareerScreen(controller: session.controller, slotIndex: 1),
        'creator-normal',
        compact: false,
      );
      await _capture(tester, tag, 'creator-normal');
      await mount(
        CreateCareerScreen(controller: session.controller, slotIndex: 1),
        'creator-role',
      );
      await _reveal(tester, find.byKey(const Key('career-first-name')));
      await tester.enterText(
        find.byKey(const Key('career-first-name')),
        'Mika',
      );
      await _reveal(tester, find.byKey(const Key('career-last-name')));
      await tester.enterText(find.byKey(const Key('career-last-name')), 'Vale');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await _tap(tester, 'career-position-midfielder');
      await _capture(tester, tag, 'creator-role');

      final retired = base.copyWith(retired: true, phase: CareerPhase.retired);
      await session.store.saveArchive(retired);
      await mount(HallOfFameScreen(controller: session.controller), 'hall');
      await _reveal(
        tester,
        find.byKey(Key('archived-career-${base.careerId}')),
      );
      await _capture(tester, tag, 'hall');

      // A fixture account unlocks only the in-memory challenge endpoint. It is
      // never restored or logged in, and never sent to an external server.
      session.controller.account = const ElevenwardAccount(
        id: 'gameplay-qa-account',
        alias: 'Mika Vale',
        provider: 'fixture',
      );
      await session.store.setPreference(
        'challenge.gameplay-qa-account.fixture-attempt',
        {
          'rulesVersion': WeeklyChallenge.rulesVersion,
          'contentVersion': WeeklyChallenge.contentVersion,
          'actions': [
            const WeeklyChoice(
              focus: PlayerAttribute.passing,
              intensity: TrainingIntensity.light,
              spotlightApproach: SpotlightApproach.safe,
            ).toJson(),
          ],
        },
      );
      await mount(
        WeeklyChallengeScreen(controller: session.controller),
        'challenge-score',
      );
      await _reveal(tester, find.byKey(const Key('challenge-local-score')));
      await _capture(tester, tag, 'challenge-score');
      await _tap(tester, 'challenge-next');
      await _reveal(tester, find.byKey(const Key('challenge-local-score')));
      await _capture(tester, tag, 'challenge-saved-plan');
      session.controller.account = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await session.close();
      await deleteDatabase(databasePath);
    }
  });
}

CareerSnapshot _playedCareer(ContentCatalog catalog) {
  var career = CareerSnapshot.newCareer(
    careerId: 'gameplay-loop-qa',
    seed: 811,
    player: PlayerState.newCareer(
      id: 'gameplay-loop-player',
      name: 'Mika Vale',
      archetype: Archetype.playmaker,
      portraitId: 'player_01',
    ).copyWith(managerTrust: 95, fitness: 95, form: 80),
  );
  for (var i = 0; i < 6; i++) {
    final event = const CareerEngine().pendingEvent(career, catalog);
    if (event != null) {
      career = const CareerEngine().applyEventChoice(
        snapshot: career,
        event: event,
        choice: event.choices.first,
        updatedAt: DateTime.utc(2026, 10, 1, 12, i),
      );
    }
    career = const WeeklySimulator()
        .advance(
          snapshot: career,
          choice: const WeeklyChoice(
            focus: PlayerAttribute.passing,
            intensity: TrainingIntensity.light,
            spotlightApproach: SpotlightApproach.balanced,
          ),
          opponent: const WorldSimulator().opponentFor(
            career,
            definition: catalog.world,
          ),
          catalog: catalog,
          definition: catalog.world,
          updatedAt: DateTime.utc(2026, 10, 1, 13, i),
        )
        .snapshot;
  }
  final pending = const CareerEngine().pendingEvent(career, catalog);
  if (pending != null) {
    career = const CareerEngine().applyEventChoice(
      snapshot: career,
      event: pending,
      choice: pending.choices.first,
      updatedAt: DateTime.utc(2026, 10, 1, 14),
    );
  }
  return career;
}

Widget _app(
  Locale locale,
  Brightness brightness,
  Widget child,
  String scene, {
  bool compact = true,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  key: ValueKey('${locale.toLanguageTag()}-$scene'),
  locale: locale,
  theme: buildElevenwardTheme('graphite', brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) {
    ElevenwardColors.use(brightness);
    if (!compact) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1),
          disableAnimations: true,
        ),
        child: child!,
      );
    }
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: 320,
          height: 568,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: const Size(320, 568),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
        ),
      ),
    );
  },
  home: child,
);

final class _FixtureSession {
  _FixtureSession(this.store, this.api, this.content, this.controller);
  final CareerStore store;
  final ElevenwardApi api;
  final ContentService content;
  final AppController controller;

  static Future<_FixtureSession> open(
    String path,
    CareerSnapshot career,
  ) async {
    final store = await CareerStore.open(path: path);
    if (await store.loadSlot(0) == null) await store.saveSlot(0, career);
    final credentials = SecureCredentials();
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => 'fixture-token',
      client: MockClient((request) async {
        if (request.method != 'GET' ||
            request.url.path != '/v1/elevenward/challenges/current') {
          throw StateError(
            'Native gameplay QA attempted non-fixture HTTP: ${request.url.path}',
          );
        }
        return http.Response(
          jsonEncode({
            'challenge': {
              'id': 'fixture-week',
              'startsAt': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'endsAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 6))
                  .toIso8601String(),
              'rulesVersion': WeeklyChallenge.rulesVersion,
              'contentVersion': WeeklyChallenge.contentVersion,
              'matchCount': WeeklyChallenge.matchCount,
              'configuration': {},
            },
            'attempt': {
              'attemptId': 'fixture-attempt',
              'seed': 811,
              'careerId': 'fixture-challenge',
              'status': 'active',
              'enrolledAt': DateTime.utc(2026, 10, 1).toIso8601String(),
            },
            'entries': [],
          }),
          200,
        );
      }),
    );
    final content = ContentService(
      api: api,
      store: store,
      client: MockClient((request) async {
        throw StateError('Native polish QA attempted a content download.');
      }),
    );
    final controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    // Do not initialize auth/purchases or restore any account credential.
    controller.activeCareer = await store.loadSlot(0);
    controller.activeSlotIndex = 0;
    controller.activeContent = await content.load();
    controller.availableContent = controller.activeContent;
    await controller.refreshSlots();
    return _FixtureSession(store, api, content, controller);
  }

  Future<void> close() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'After tapping $key');
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  Finder? scrollRoot,
}) async {
  if (target.evaluate().isEmpty) {
    final verticals = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final explorer = find.byKey(const Key('world-explorer-options'));
    final worldMap = find.byKey(const Key('world-map-view'));
    final root =
        scrollRoot ??
        (explorer.evaluate().isNotEmpty
            ? explorer
            : worldMap.evaluate().isNotEmpty
            ? worldMap
            : null);
    final scrollable = root == null
        ? verticals.last
        : find.descendant(of: root, matching: verticals);
    expect(
      scrollable,
      findsOneWidget,
      reason: 'A vertical pane reveals $target',
    );
    final state = tester.state<ScrollableState>(scrollable);
    expect(
      state.position.viewportDimension,
      greaterThan(0),
      reason: 'The native viewport must leave space for the result pane.',
    );
    state.position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && target.evaluate().isEmpty; i++) {
      if (state.position.pixels >= state.position.maxScrollExtent) break;
      await tester.drag(scrollable, const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    expect(
      target,
      findsOneWidget,
      reason:
          'The expected result was absent after revealing its vertical '
          'pane (offset ${state.position.pixels}, '
          'extent ${state.position.maxScrollExtent}, '
          'viewport ${state.position.viewportDimension}).',
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String locale, String name) async {
  expect(tester.takeException(), isNull, reason: '$locale/$name');
  final context = tester.element(find.byType(Navigator).first);
  final media = MediaQuery.of(context);
  debugPrint(
    'GAMEPLAY_CAPTURE_LAYOUT|$locale|$name|${media.size.width}|'
    '${media.size.height}|${media.textScaler.scale(1)}|'
    '${Theme.of(context).brightness.name}',
  );
  final ack = File(
    p.join(Directory.systemTemp.path, 'elevenward-gameplay-$locale-$name.ack'),
  );
  if (await ack.exists()) await ack.delete();
  debugPrint('GAMEPLAY_CAPTURE_READY|$locale|$name|${ack.path}');
  // Only the host's completed simctl screenshot permits the next scene.
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
