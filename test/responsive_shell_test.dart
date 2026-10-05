import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/create_career_screen.dart';
import 'package:elevenward/src/screens/home_shell.dart';
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
  late SecureCredentials credentials;
  late ElevenwardApi api;
  late ContentService content;

  setUpAll(() async {
    sqfliteFfiInit();
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    credentials = SecureCredentials();
    api = ElevenwardApi(accessToken: credentials.readAccountToken);
    content = ContentService(api: api, store: store);
  });

  tearDownAll(() async {
    content.close();
    api.close();
    await store.close();
  });

  for (final surface in const [
    Size(320, 568),
    Size(390, 844),
    Size(430, 932),
    Size(768, 1024),
  ]) {
    testWidgets(
      'primary shell fits ${surface.width.toInt()}x${surface.height.toInt()}',
      (tester) async {
        tester.view.physicalSize = surface;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _controller(store, credentials, api, content);
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(controller));
        await tester.pump();
        _expectNoLayoutError(tester, 'initial frame at $surface');

        for (final destination in const ['World', 'Life', 'More', 'Career']) {
          await tester.tap(find.text(destination).last);
          await tester.pump();
          _expectNoLayoutError(tester, '$destination at $surface');
        }
      },
    );
  }

  testWidgets('primary shell supports 200 percent text and reduced motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, reducedMotion: true));
    await tester.pump();
    _expectNoLayoutError(tester, 'reduced-motion initial frame');

    for (final destination in const ['World', 'Life', 'More', 'Career']) {
      await tester.tap(find.text(destination).last);
      await tester.pump();
      _expectNoLayoutError(tester, '$destination with large text');
    }
  });

  testWidgets('root tabs share compact chrome with no large app bars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pump();

    for (final destination in const ['Career', 'World', 'Life', 'More']) {
      await tester.tap(find.text(destination).last);
      await tester.pump();
      expect(
        find.byKey(const Key('compact-player-hud')),
        findsOneWidget,
        reason: '$destination should use the shared root HUD',
      );
      expect(
        find.byType(SliverAppBar),
        findsNothing,
        reason: '$destination should not restore large root chrome',
      );
    }
  });

  testWidgets('Life is a dense action list with focused destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);
    final startingCareer = controller.activeCareer!;
    final ownedListing = const LifestyleMarketEngine()
        .stockFor(startingCareer, buildLaunchContent())
        .forCategory(LifestyleCategory.home)
        .first;
    controller.activeCareer = startingCareer.copyWith(
      player: startingCareer.player.copyWith(money: 100000000),
      ownedItemIds: [ownedListing.id],
    );

    await tester.pumpWidget(_app(controller));
    await tester.tap(find.text('Life').last);
    await tester.pump();

    expect(find.byKey(const Key('life-pulse-strip')), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is SegmentedButton),
      findsNothing,
    );
    for (final key in const [
      'life-action-agent',
      'life-action-sponsors',
      'life-action-relationships',
    ]) {
      expect(
        find.byKey(Key(key)).hitTestable(),
        findsOneWidget,
        reason: '$key should be visible before the first scroll',
      );
    }

    await tester.tap(find.byKey(const Key('life-action-agent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('life-destination-agent')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('life-action-relationships')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('life-destination-relationships')),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('life-action-market')),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('life-action-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('life-action-market')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('life-destination-market')), findsOneWidget);

    final weekly = const LifestyleMarketEngine().stockFor(
      controller.activeCareer!,
      buildLaunchContent(),
    );
    for (final category in LifestyleCategory.values) {
      final expected = weekly.forCategory(category);
      expect(expected, hasLength(5));
      await tester.tap(find.byKey(Key('lifestyle-shop-${category.name}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('weekly-market-summary')), findsOneWidget);
      for (final item in expected) {
        final listing = find.byKey(Key('lifestyle-listing-${item.id}'));
        await tester.scrollUntilVisible(
          listing,
          140,
          scrollable: find.byType(Scrollable).last,
        );
        expect(listing, findsOneWidget);
        if (item.id == ownedListing.id) {
          expect(
            find.byKey(Key('lifestyle-buy-${ownedListing.id}')),
            findsNothing,
          );
          expect(find.text('OWNED'), findsOneWidget);
        }
      }

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('compact Life layout supports every locale at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    var openedLife = false;
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(_app(controller, locale: locale));
      if (!openedLife) {
        await tester.tap(find.byIcon(Icons.home_outlined));
        openedLife = true;
      }
      await tester.pump();
      expect(
        find.byKey(const Key('life-pulse-strip')),
        findsOneWidget,
        reason: 'Life should render for ${locale.languageCode}',
      );
      _expectNoLayoutError(tester, 'Life in ${locale.languageCode}');
    }
  });

  testWidgets('all World tabs support every locale at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    var openedWorld = false;
    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        _app(controller, locale: locale, reducedMotion: true),
      );
      if (!openedWorld) {
        await tester.tap(find.byIcon(Icons.public_outlined));
        openedWorld = true;
      }
      await tester.pump();
      final tabs = tester.widget<TabBar>(
        find.byKey(const Key('world-section-tabs')),
      );
      for (var index = 0; index < 5; index += 1) {
        tabs.controller!.animateTo(index);
        await tester.pump();
        _expectNoLayoutError(
          tester,
          'World tab $index in ${locale.toLanguageTag()}',
        );
      }
    }
  });

  testWidgets('every position exposes three styles and requires a choice', (
    tester,
  ) async {
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_creatorApp(controller));
    await tester.enterText(find.byKey(const Key('career-first-name')), 'Ari');
    await tester.enterText(find.byKey(const Key('career-last-name')), 'Vale');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pump();
    expect(find.byKey(const Key('career-creator-step-0')), findsOneWidget);
    expect(
      find.text('Choose a position and play style to continue.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    for (final position in PositionFamily.values) {
      await _tapCreatorControl(
        tester,
        find.byKey(Key('career-position-${position.name}')),
        step: 0,
      );
      final matching = Archetype.values
          .where((style) => style.positionFamily == position)
          .toList();
      expect(matching, hasLength(3));
      for (final style in Archetype.values) {
        expect(
          find.byKey(Key('career-archetype-${style.name}')),
          style.positionFamily == position ? findsOneWidget : findsNothing,
        );
      }
      await _tapCreatorControl(
        tester,
        find.byKey(Key('career-archetype-${matching.last.name}')),
        step: 0,
      );
    }

    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-position-striker')),
      step: 0,
    );
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pump();
    expect(find.byKey(const Key('career-creator-step-0')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-archetype-poacher')),
      step: 0,
    );

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-creator-step-1')), findsOneWidget);
    _expectNoLayoutError(tester, 'position-first role selection');
  });

  testWidgets('role cards fit every locale at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(_creatorApp(controller, locale: locale));
      await tester.pumpAndSettle();
      await _tapCreatorControl(
        tester,
        find.byKey(const Key('career-position-defender')),
        step: 0,
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('career-archetype-attackingFullback')),
        find.byKey(const Key('career-creator-step-0')),
        const Offset(0, -220),
      );
      _expectNoLayoutError(tester, 'role cards in ${locale.toLanguageTag()}');
    }
  });

  testWidgets('four-step career creation remains usable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildElevenwardTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CreateCareerScreen(controller: controller, slotIndex: 0),
      ),
    );
    _expectNoLayoutError(tester, 'career creation identity');

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pump();
    expect(find.byKey(const Key('career-creator-step-0')), findsOneWidget);
    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(find.text('Enter your last name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('career-first-name')), 'Mika');
    await tester.enterText(find.byKey(const Key('career-last-name')), 'Vale');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('career-creator-step-0')),
      const Offset(0, -600),
    );
    await tester.ensureVisible(find.byKey(const Key('career-choose-portrait')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('career-choose-portrait')));
    await tester.pumpAndSettle();
    final portraitGrid = tester.widget<GridView>(
      find.byKey(const Key('career-portrait-grid')),
    );
    expect(portraitGrid.childrenDelegate.estimatedChildCount, 30);
    await tester.tap(find.byKey(const Key('career-portrait-player_02')));
    await tester.pumpAndSettle();
    final selectedPortrait = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const Key('career-selected-portrait')),
        matching: find.byType(Image),
      ),
    );
    expect(
      (selectedPortrait.image as AssetImage).assetName,
      'assets/visual/player_portraits/player_02.webp',
    );
    _expectNoLayoutError(tester, 'career portrait selection');

    await tester.ensureVisible(
      find.byKey(const Key('career-position-striker')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('career-position-striker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('career-archetype-poacher')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('career-archetype-poacher')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    _expectNoLayoutError(tester, 'career creation nationality');

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pump();
    expect(find.byKey(const Key('career-creator-step-1')), findsOneWidget);
    expect(find.text('Choose a national team to continue.'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('popular-nationality-england')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('career-creator-step-1')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('popular-nationality-england')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    _expectNoLayoutError(tester, 'career creation club');

    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pump();
    expect(find.byKey(const Key('career-creator-step-2')), findsOneWidget);
    expect(find.text('Choose a starting club to continue.'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final clubScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('career-creator-step-2')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    clubScroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('club-search')),
      find.byKey(const Key('career-creator-step-2')),
      const Offset(0, -100),
    );
    await tester.enterText(
      find.byKey(const Key('club-search')),
      'Northstar Athletic',
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('starting-club-england-northstar-athletic')),
      find.byKey(const Key('career-creator-step-2')),
      const Offset(0, -300),
    );
    await tester.drag(
      find.byKey(const Key('career-creator-step-2')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('starting-club-england-northstar-athletic')),
    );
    await tester.ensureVisible(find.byKey(const Key('career-create-next')));
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-create-save')), findsOneWidget);
    expect(find.text('Mika Vale'), findsOneWidget);
    _expectNoLayoutError(tester, 'career creation review');
    await tester.dragUntilVisible(
      find.text('World class'),
      find.byKey(const Key('career-creator-step-3')),
      const Offset(0, -250),
    );
    _expectNoLayoutError(tester, 'career difficulty at large text');
  });

  testWidgets('club search, review edits, and saved career stay in sync', (
    tester,
  ) async {
    final controller = _controller(store, credentials, api, content);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_creatorApp(controller));
    await tester.enterText(find.byKey(const Key('career-first-name')), 'Ari');
    await tester.enterText(find.byKey(const Key('career-last-name')), 'Vale');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-position-midfielder')),
      step: 0,
    );
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-archetype-playmaker')),
      step: 0,
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('career-selected-portrait')),
      find.byKey(const Key('career-creator-step-0')),
      const Offset(0, 250),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ari Vale'), findsOneWidget);
    expect(find.text('Midfielder · Playmaker'), findsOneWidget);
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();

    await _tapCreatorControl(
      tester,
      find.byKey(const Key('popular-nationality-england')),
      step: 1,
    );
    await tester.dragUntilVisible(
      find.text('Country you will represent'),
      find.byKey(const Key('career-creator-step-1')),
      const Offset(0, 200),
    );
    expect(find.text('Country you will represent'), findsOneWidget);
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('club-search')),
      'Northstar Athletic',
    );
    await tester.pumpAndSettle();
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('starting-club-england-northstar-athletic')),
      step: 2,
    );
    expect(find.text('Northstar Athletic'), findsWidgets);
    await _tapCreatorControl(tester, find.text('Browse leagues'), step: 2);
    await _tapCreatorControl(
      tester,
      find.byKey(const ValueKey('region-europe')),
      step: 2,
    );
    await tester.tap(find.text('South America').last);
    await tester.pumpAndSettle();
    expect(find.text('Northstar Athletic'), findsNothing);
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('league-shortcut-spain')),
      step: 2,
      scrollDelta: 250,
    );
    expect(find.text('Northstar Athletic'), findsNothing);
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pump();
    expect(find.byKey(const Key('career-creator-step-2')), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(const Key('club-search')),
      find.byKey(const Key('career-creator-step-2')),
      const Offset(0, 200),
    );
    await tester.enterText(
      find.byKey(const Key('club-search')),
      'Ciudad Azahar',
    );
    await tester.pumpAndSettle();
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('starting-club-spain-ciudad-azahar')),
      step: 2,
    );
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-creator-step-3')), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Story'),
      find.byKey(const Key('career-creator-step-3')),
      const Offset(0, -200),
    );
    expect(find.text('Story'), findsOneWidget);
    expect(
      find.text(
        'More forgiving spotlight decisions. Starting attributes stay the same.',
      ),
      findsOneWidget,
    );

    await _tapCreatorControl(tester, find.byTooltip('Edit Position'), step: 3);
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-position-defender')),
      step: 0,
    );
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-archetype-attackingFullback')),
      step: 0,
    );
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    expect(find.text('Defender'), findsOneWidget);
    expect(find.text('Attacking fullback'), findsOneWidget);

    await _tapCreatorControl(
      tester,
      find.byTooltip('Edit National team'),
      step: 3,
    );
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('popular-nationality-brazil')),
      step: 1,
    );
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    expect(find.text('Brazil'), findsOneWidget);

    await _tapCreatorControl(
      tester,
      find.byTooltip('Edit Starting club'),
      step: 3,
    );
    await tester.enterText(
      find.byKey(const Key('club-search')),
      'Northstar Athletic',
    );
    await tester.pumpAndSettle();
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('starting-club-england-northstar-athletic')),
      step: 2,
    );
    await tester.tap(find.byKey(const Key('career-create-next')));
    await tester.pumpAndSettle();
    expect(find.text('Northstar Athletic'), findsOneWidget);

    await _tapCreatorControl(tester, find.byTooltip('Edit Position'), step: 3);
    await _tapCreatorControl(
      tester,
      find.byKey(const Key('career-position-striker')),
      step: 0,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Defender'), findsOneWidget);

    await _tapCreatorControl(tester, find.text('World class'), step: 3);
    await tester.tap(find.byKey(const Key('career-create-save')));
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (controller.activeSlotIndex != 0 || controller.activeCareer == null) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Career creation did not finish saving.');
      }
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump();
    final saved = await tester.runAsync(() => store.loadSlot(0));
    expect(saved?.player.name, 'Ari Vale');
    expect(saved?.player.position, PositionFamily.defender);
    expect(saved?.player.archetype, Archetype.attackingFullback);
    expect(saved?.player.nationalTeamId, 'brazil');
    expect(saved?.clubId, 'england-northstar-athletic');
    expect(saved?.difficulty, Difficulty.worldClass);
    expect(saved?.player.portraitId, 'player_01');
    _expectNoLayoutError(tester, 'saved creator choices');
  });
}

void _expectNoLayoutError(WidgetTester tester, String reason) {
  final error = tester.takeException();
  expect(error, isNull, reason: reason);
}

Widget _creatorApp(AppController controller, {Locale? locale}) => MaterialApp(
  theme: buildElevenwardTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: CreateCareerScreen(controller: controller, slotIndex: 0),
);

Future<void> _tapCreatorControl(
  WidgetTester tester,
  Finder control, {
  required int step,
  double scrollDelta = -250,
}) async {
  await tester.dragUntilVisible(
    control,
    find.byKey(Key('career-creator-step-$step')),
    Offset(0, scrollDelta),
  );
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Widget _app(
  AppController controller, {
  bool reducedMotion = false,
  Locale? locale,
}) => MaterialApp(
  theme: buildElevenwardTheme(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: HomeShell(controller: controller),
);

AppController _controller(
  CareerStore store,
  SecureCredentials credentials,
  ElevenwardApi api,
  ContentService content,
) {
  final entitlements = EntitlementService(
    credentials: credentials,
    store: store,
  );
  return AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: entitlements,
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    )
    ..activeCareer = CareerSnapshot.newCareer()
    ..stage = AppStage.playing;
}
