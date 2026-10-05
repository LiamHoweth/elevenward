import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/create_career_screen.dart';
import 'package:elevenward/src/screens/life_screen.dart';
import 'package:elevenward/src/screens/hall_of_fame_screen.dart';
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
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Evidence renderer only, deliberately excluded from routine regression runs.
// This is widget raster output, not a native Simulator or physical device.
void main() {
  if (!const bool.fromEnvironment('GAMEPLAY_WIDGET_CAPTURE')) {
    test(
      'widget raster evidence is opt-in',
      () {},
      skip: 'Run with --dart-define=GAMEPLAY_WIDGET_CAPTURE=true',
    );
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    final bytes = await File('/System/Library/Fonts/SFNS.ttf').readAsBytes();
    final loader = FontLoader('QA System Sans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    for (final family in [
      'Ahem',
      'Roboto',
      '.AppleSystemUIFont',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      final alias = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await alias.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('raster capture final actual gameplay widgets', (tester) async {
    final output = Directory(
      'artifacts/verification/gameplay-loop-2026-10-01/widget-ui',
    );
    await tester.runAsync(() => output.create(recursive: true));
    final catalog = buildLatestContent();
    final career = _playedCareer(catalog);
    late CareerStore store;
    late ElevenwardApi api;
    late ContentService content;
    late AppController controller;
    await tester.runAsync(() async {
      FlutterSecureStorage.setMockInitialValues({});
      store = await CareerStore.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      final credentials = SecureCredentials();
      api = ElevenwardApi(
        baseUri: Uri.parse('https://example.test'),
        accessToken: () async => null,
        client: MockClient((request) async {
          throw StateError(
            'Widget visual QA attempted HTTP: ${request.url.path}',
          );
        }),
      );
      content = ContentService(
        api: api,
        store: store,
        client: MockClient((request) async {
          throw StateError('Widget visual QA attempted a content download.');
        }),
      );
      controller = AppController(
        store: store,
        auth: AuthService(api: api, credentials: credentials),
        entitlements: EntitlementService(
          credentials: credentials,
          store: store,
        ),
        sync: SyncService(api, store),
        analytics: AnalyticsService(api, store),
        content: content,
      );
      controller.activeCareer = career;
      controller.activeSlotIndex = 0;
      controller.activeContent = await content.load();
      controller.availableContent = controller.activeContent;
      await store.saveSlot(0, career);
      await store.saveArchive(
        career.copyWith(retired: true, phase: CareerPhase.retired),
      );
    });
    final boundaryKey = GlobalKey();
    final records = <Map<String, Object?>>[];
    for (final compact in [false, true]) {
      final locale = compact ? const Locale('fr') : const Locale('en');
      final tag = locale.toLanguageTag();
      final brightness = compact ? Brightness.light : Brightness.dark;
      final size = compact ? const Size(320, 568) : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final scale = compact ? 2.0 : 1.0;
      final prefix = compact ? 'compact' : 'normal';
      Future<void> mount(Widget child, String scene) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        final theme = buildElevenwardTheme('graphite', brightness);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              key: ValueKey('$tag-$scene'),
              debugShowCheckedModeBanner: false,
              locale: locale,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'QA System Sans'),
                primaryTextTheme: theme.primaryTextTheme.apply(
                  fontFamily: 'QA System Sans',
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: theme.filledButtonTheme.style!.copyWith(
                    textStyle: WidgetStatePropertyAll(
                      theme.filledButtonTheme.style!.textStyle!
                          .resolve({})!
                          .copyWith(fontFamily: 'QA System Sans'),
                    ),
                  ),
                ),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) {
                ElevenwardColors.use(brightness);
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                );
              },
              home: child,
            ),
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/visual/player_portraits/player_01.webp'),
            tester.element(find.byType(MaterialApp)),
          );
        });
        // Allow real SQLite/isolate and image decoding callbacks before settling.
        for (var attempt = 0; attempt < 30; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump(const Duration(milliseconds: 16));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$prefix/$scene');
      }

      Future<void> capture(String scene) async {
        await tester.pump();
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final path = '${output.path}/$tag-$prefix-$scene.png';
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(path).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        records.add({
          'scene': scene,
          'path': path,
          'locale': tag,
          'brightness': brightness.name,
          'logicalWidth': size.width,
          'logicalHeight': size.height,
          'textScale': scale,
          'pixelRatio': 2,
        });
        debugPrint('WIDGET_CAPTURE|$path');
      }

      controller.activeCareer = career;
      await mount(
        GameScreen(
          initialCareer: career,
          contentCatalog: catalog,
          initialFocus: PlayerAttribute.passing,
          quickTransitions: true,
          showCoachingTips: false,
          showCareerTarget: false,
        ),
        'career',
      );
      await capture('career');
      await _tap(tester, 'training-load-comparison-toggle');
      await _reveal(tester, find.byKey(const Key('training-compare-balanced')));
      await capture('training-comparison');
      await mount(PlayerScreen(controller: controller), 'player');
      final overallText = find.descendant(
        of: find.byKey(const Key('player-overall-badge')),
        matching: find.text('${career.player.overall}'),
      );
      final overallParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: overallText, matching: find.byType(RichText)),
      );
      expect(
        overallParagraph.getBoxesForSelection(
          TextSelection(
            baseOffset: 0,
            extentOffset: '${career.player.overall}'.length,
          ),
        ),
        hasLength(1),
        reason:
            'All OVR digits must fit on one line with the actual captured font',
      );
      await capture('player');
      final nationalityLabel = compact ? 'Nationalité' : 'Nationality';
      final nationality = find.text(nationalityLabel);
      await _reveal(tester, nationality);
      final nationalityParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: nationality, matching: find.byType(RichText)),
      );
      expect(
        nationalityParagraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: nationalityLabel.length),
        ),
        hasLength(1),
        reason: 'The complete nationality label must fit as a word with the actual captured font',
      );
      await _reveal(tester, find.byKey(const Key('player-attributes')));
      await capture('player-attributes');
      await mount(
        Scaffold(
          body: SafeArea(
            child: LifeScreen(controller: controller, contentCatalog: catalog),
          ),
        ),
        'life',
      );
      for (final key in ['monthlyIncome', 'weeklySponsors']) {
        final label = find.descendant(
          of: find.byKey(const Key('life-pulse-strip')),
          matching: find.text(uiCopy(tag, key)),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: label, matching: find.byType(RichText)),
        );
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: 'Pulse labels must be completely rendered without ellipsis',
        );
      }
      await _reveal(tester, find.byKey(const Key('life-action-agent')));
      final agentTile = find.byKey(const Key('life-action-agent'));
      final agentTitle = find.descendant(
        of: agentTile,
        matching: find.text('Agent'),
      );
      final agentParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: agentTitle, matching: find.byType(RichText)),
      );
      expect(
        agentParagraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5),
        ),
        hasLength(1),
        reason: 'Agent title must remain a complete word at large text',
      );
      final agentName = localizedAgentName(tag, career.activeAgentId);
      final agentSubtitle = find.descendant(
        of: agentTile,
        matching: find.text(agentName),
      );
      final agentSubtitleParagraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: agentSubtitle, matching: find.byType(RichText)),
      );
      expect(
        agentSubtitleParagraph.didExceedMaxLines,
        isFalse,
        reason: 'The active agent subtitle must be fully readable',
      );
      await capture('life');
      final funded = career.copyWith(
        player: career.player.copyWith(money: 100000000),
      );
      controller.activeCareer = funded;
      final stock = const LifestyleMarketEngine()
          .stockFor(funded, catalog)
          .forCategory(LifestyleCategory.home)
          .first;
      await _tap(tester, 'life-action-market');
      await _tap(tester, 'lifestyle-shop-home');
      await _tap(tester, 'lifestyle-buy-${stock.id}');
      final priceRect = tester.getRect(
        find.byKey(const Key('lifestyle-purchase-price')),
      );
      expect(priceRect.top, greaterThanOrEqualTo(0));
      expect(
        priceRect.bottom,
        lessThanOrEqualTo(size.height),
        reason: 'The reviewed price must be visible before confirming',
      );
      await capture('purchase-review');
      await _tap(tester, 'lifestyle-purchase-cancel');
      controller.activeCareer = career;
      await mount(
        CreateCareerScreen(controller: controller, slotIndex: 1),
        'creator',
      );
      await _tap(tester, 'career-position-midfielder');
      await capture('creator');
      await mount(HallOfFameScreen(controller: controller), 'hall');
      await tester.runAsync(() async {
        await controller.localHallOfFame();
      });
      await tester.pumpAndSettle();
      await _reveal(
        tester,
        find.byKey(Key('archived-career-${career.careerId}')),
      );
      await capture('hall');
      expect(tester.takeException(), isNull);
    }
    await tester.runAsync(
      () => File('${output.path}/widget-capture-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'source': 'Flutter widget raster RepaintBoundary; not native Simulator or physical device',
          'font': 'host SFNS.ttf registered as QA System Sans; bundled MaterialIcons loaded',
          'isolatedDatabase': true,
          'productionNetwork': false,
          'captures': records,
        }),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    controller.dispose();
    content.close();
    api.close();
    await tester.runAsync(store.close);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    ElevenwardColors.use(Brightness.dark);
  }, timeout: const Timeout(Duration(minutes: 5)));
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
