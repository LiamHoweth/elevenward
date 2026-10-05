import 'dart:async';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/league_presentation.dart';
import 'package:elevenward/src/screens/world_screen.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late AppController controller;
  late CareerStore store;
  final world = buildLaunchWorld();
  final career = CareerSnapshot.newCareer(
    worldDefinition: world,
    clubId: 'spain-ciudad-azahar',
    clubName: 'Ciudad Azahar',
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    final api = ElevenwardApi(
      accessToken: credentials.readAccountToken,
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    final content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    addTearDown(() async {
      controller.dispose();
      content.close();
      api.close();
      await store.close();
    });
  });

  testWidgets('country search focuses the map and clearing restores explorer', (
    tester,
  ) async {
    final original = career.encode();
    await _openSearch(tester, career, world, controller);
    await tester.enterText(
      find.byKey(const Key('world-search-field')),
      'Japan',
    );
    await tester.pumpAndSettle();
    await _tapExplorer(tester, const Key('world-search-country-japan'));
    final map = tester.widget<AccurateFootballWorldMap>(
      find.byType(AccurateFootballWorldMap).last,
    );
    expect(map.selectedCountryId, 'japan');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('world-search-field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.byKey(const Key('country-league-japan-first')), findsOneWidget);
    expect(career.encode(), original);

    await tester.enterText(
      find.byKey(const Key('world-search-field')),
      'zzzzz',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-search-empty')), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-search-clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-search-empty')), findsNothing);
    expect(find.byKey(const Key('country-league-japan-first')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard search reveals mobile results and focuses selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final original = career.encode();
    await _openSearch(tester, career, world, controller);
    final search = find.byKey(const Key('world-search-field'));
    await tester.enterText(search, 'Japao');
    final searchFocus = tester.widget<TextField>(search).focusNode!;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(searchFocus.hasFocus, isTrue);
    expect(
      tester
          .widget<Offstage>(find.byKey(const Key('world-explorer-map-area')))
          .offstage,
      isTrue,
    );
    final result = find.byKey(const Key('world-search-country-japan'));
    await tester.scrollUntilVisible(
      result,
      100,
      scrollable: _verticalWorldScroll(
        find.byKey(const Key('world-explorer-options')),
      ),
    );
    await tester.ensureVisible(result);
    await tester.pumpAndSettle();
    expect(result.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(searchFocus.hasFocus, isFalse);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Offstage>(find.byKey(const Key('world-explorer-map-area')))
          .offstage,
      isFalse,
    );
    await _tapExplorer(tester, const Key('world-search-country-japan'));
    expect(
      tester
          .widget<AccurateFootballWorldMap>(
            find.byType(AccurateFootballWorldMap).last,
          )
          .selectedCountryId,
      'japan',
    );
    expect(career.encode(), original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'large-text league names keep complete words and bookmark targets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openSearch(tester, career, world, controller);
      await tester.enterText(
        find.byKey(const Key('world-search-field')),
        'Spain',
      );
      await tester.pumpAndSettle();
      await _tapExplorer(tester, const Key('world-search-country-spain'));
      final league = find.byKey(const Key('country-league-spain-first'));
      await tester.scrollUntilVisible(
        league,
        120,
        scrollable: _verticalWorldScroll(
          find.byKey(const Key('world-explorer-options')),
        ),
      );
      await tester.ensureVisible(league);
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: league,
        matching: find.text(
          leagueDisplayName(
            world.leagues.firstWhere((item) => item.id == 'spain-first'),
          ),
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 7),
        ),
        hasLength(1),
        reason:
            'Spanish must remain on one line instead of splitting mid-word.',
      );
      final bookmark = find.descendant(
        of: find.byKey(const Key('favorite-league-spain-first')),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(bookmark).width, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(title).top,
        greaterThanOrEqualTo(tester.getRect(bookmark).bottom),
      );
      await _tapFavorite(
        tester,
        controller,
        const Key('favorite-league-spain-first'),
      );
      expect(controller.favoriteLeagueIds, contains('spain-first'));
      await _tapExplorer(tester, const Key('country-league-spain-first'));
      expect(
        tester
            .widget<WorldScreen>(find.byType(WorldScreen).last)
            .initialLeagueId,
        'spain-first',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'club search opens the correct highlighted league and bookmarks',
    (tester) async {
      await _openSearch(tester, career, world, controller);
      await tester.enterText(
        find.byKey(const Key('world-search-field')),
        'Ciudad Azahar',
      );
      await tester.pumpAndSettle();
      await _tapExplorer(
        tester,
        const Key('world-search-club-spain-ciudad-azahar'),
      );
      expect(
        tester
            .widget<AccurateFootballWorldMap>(
              find.byType(AccurateFootballWorldMap).last,
            )
            .selectedCountryId,
        'spain',
      );
      await _tapFavorite(
        tester,
        controller,
        const Key('favorite-club-spain-ciudad-azahar'),
      );
      expect(controller.favoriteClubIds, contains('spain-ciudad-azahar'));
      expect(
        await tester.runAsync(() => store.getPreference('ui.favoriteClubIds')),
        ['spain-ciudad-azahar'],
      );
      await _tapExplorer(
        tester,
        const Key('world-search-open-league-spain-ciudad-azahar'),
      );
      final leagueRoute = tester.widget<WorldScreen>(
        find.byType(WorldScreen).last,
      );
      expect(leagueRoute.initialLeagueId, 'spain-first');
      expect(leagueRoute.highlightClubId, 'spain-ciudad-azahar');
      expect(leagueRoute.controller, same(controller));
      await _tapFavorite(
        tester,
        controller,
        const Key('favorite-league-spain-first'),
      );
      expect(controller.favoriteLeagueIds, contains('spain-first'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('favorites are live quick links and hide unknown pinned IDs', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await controller.toggleFavoriteClub('spain-ciudad-azahar');
      await controller.toggleFavoriteLeague('spain-first');
      await controller.toggleFavoriteClub('unknown-club');
      await controller.toggleFavoriteLeague('unknown-league');
    });
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      _app(
        WorldScreen(career: career, definition: world, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    final favorite = find.byKey(
      const Key('world-favorite-club-spain-ciudad-azahar'),
    );
    await tester.scrollUntilVisible(
      favorite,
      180,
      scrollable: _verticalWorldScroll(find.byKey(const Key('world-map-view'))),
    );
    await tester.ensureVisible(favorite);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('world-favorite-club-unknown-club')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('world-favorite-league-unknown-league')),
      findsNothing,
    );
    expect(controller.favoriteClubIds, contains('unknown-club'));
    await tester.tap(
      find.descendant(of: favorite, matching: find.byType(ListTile)),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<WorldScreen>(find.byType(WorldScreen).last).highlightClubId,
      'spain-ciudad-azahar',
    );
    Navigator.of(tester.element(find.byType(WorldScreen).last)).pop();
    await tester.pumpAndSettle();
    await _tapFavorite(
      tester,
      controller,
      const Key('favorite-club-spain-ciudad-azahar'),
    );
    expect(controller.favoriteClubIds, isNot(contains('spain-ciudad-azahar')));
    expect(favorite, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact favorite clubs keep names intact and independent actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final club = world.club('spain-solmera-cf');
      await tester.runAsync(() => controller.toggleFavoriteClub(club.id));
      await tester.runAsync(WorldMapData.load);
      await tester.pumpWidget(
        _app(
          WorldScreen(
            career: career,
            definition: world,
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final favorite = find.byKey(Key('world-favorite-club-${club.id}'));
      await tester.scrollUntilVisible(
        favorite,
        180,
        scrollable: _verticalWorldScroll(
          find.byKey(const Key('world-map-view')),
        ),
      );
      await tester.ensureVisible(favorite);
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: favorite,
        matching: find.text(club.name),
      );
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(
        paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 7),
        ),
        hasLength(1),
        reason: 'Solmera must remain intact instead of splitting before its last letter.',
      );
      final bookmark = find.descendant(
        of: find.byKey(Key('favorite-club-${club.id}')),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(bookmark).width, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(title).top,
        greaterThanOrEqualTo(tester.getRect(bookmark).bottom),
      );
      await tester.tap(favorite);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WorldScreen>(find.byType(WorldScreen).last)
            .highlightClubId,
        club.id,
      );
      await _tapFavorite(tester, controller, Key('favorite-club-${club.id}'));
      expect(controller.favoriteClubIds, isNot(contains(club.id)));
      expect(
        await tester.runAsync(() => store.getPreference('ui.favoriteClubIds')),
        isEmpty,
      );
      Navigator.of(tester.element(find.byType(WorldScreen).last)).pop();
      await tester.pumpAndSettle();
      expect(favorite, findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    testWidgets(
      'search and favorites remain reachable at 320px/200% in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _openSearch(tester, career, world, controller, locale: locale);
        await tester.enterText(
          find.byKey(const Key('world-search-field')),
          'Ciudad Azahar',
        );
        await tester.pumpAndSettle();
        await _tapExplorer(
          tester,
          const Key('world-search-club-spain-ciudad-azahar'),
        );
        await _tapExplorer(
          tester,
          const Key('world-search-open-league-spain-ciudad-azahar'),
        );
        await _tapFavorite(
          tester,
          controller,
          const Key('favorite-league-spain-first'),
        );
        expect(controller.favoriteLeagueIds, contains('spain-first'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

Widget _app(Widget screen, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: screen),
);

Future<void> _openSearch(
  WidgetTester tester,
  CareerSnapshot career,
  WorldDefinition world,
  AppController controller, {
  Locale locale = const Locale('en'),
}) async {
  await tester.runAsync(WorldMapData.load);
  await tester.pumpWidget(
    _app(
      WorldScreen(career: career, definition: world, controller: controller),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('world-search-open')));
  await tester.pumpAndSettle();
}

// World includes horizontal map legends and single-line text-field scrolling.
// Drive only the vertical content pane selected by the test.
Finder _verticalWorldScroll(Finder pane) => find.descendant(
  of: pane,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  ),
);

Future<void> _tapExplorer(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: _verticalWorldScroll(
      find.byKey(const Key('world-explorer-options')),
    ),
    maxScrolls: 60,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapFavorite(
  WidgetTester tester,
  AppController controller,
  Key key,
) async {
  final changed = Completer<void>();
  void listener() {
    if (!changed.isCompleted) changed.complete();
  }

  controller.addListener(listener);
  try {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(
      find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
    );
    for (var attempt = 0; attempt < 200 && !changed.isCompleted; attempt++) {
      // The serialized preference queue needs fake-clock frames, while SQLite
      // completes in the real event loop. Give both clocks bounded progress.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(
      changed.isCompleted,
      isTrue,
      reason: 'Favorite did not commit: $key',
    );
    await tester.pumpAndSettle();
  } finally {
    controller.removeListener(listener);
  }
}
