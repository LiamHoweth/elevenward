import 'package:elevenward/main.dart';
import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/language_selection_screen.dart';
import 'package:elevenward/src/screens/onboarding_screen.dart';
import 'package:elevenward/src/screens/world_screen.dart';
import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('language is chosen before onboarding can begin', (tester) async {
    Locale? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: LanguageSelectionScreen(
          onSelected: (locale) async => selected = locale,
        ),
      ),
    );

    expect(find.text('Choose your language'), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.pump();

    expect(selected, const Locale('es'));
  });

  testWidgets('onboarding remains scrollable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onComplete: () async {}),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('world hub labels nationality and current club independently', (
    tester,
  ) async {
    final world = buildLaunchWorld();
    final career = CareerSnapshot.newCareer(
      clubId: 'spain-ciudad-azahar',
      clubName: 'Ciudad Azahar',
      worldDefinition: world,
      player: PlayerState.newCareer(
        id: 'japan-player',
        name: 'Mika Vale',
        archetype: Archetype.poacher,
        nationalTeamId: 'japan',
      ),
    );
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      _localizedApp(WorldScreen(career: career, definition: world)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nationality · Japan'), findsOneWidget);
    expect(find.text('Current club · Spain'), findsOneWidget);
    final map = tester.widget<AccurateFootballWorldMap>(
      find.byType(AccurateFootballWorldMap),
    );
    expect(map.homeCountryId, 'japan');
    expect(map.currentClubCountryId, 'spain');
    expect(map.playableCountryIds, hasLength(26));

    final tabs = tester.widget<TabBar>(
      find.byKey(const Key('world-section-tabs')),
    );
    tabs.controller!.animateTo(1);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-player-stats-tab')), findsOneWidget);
    tabs.controller!.animateTo(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-club-stats-tab')), findsOneWidget);
    tabs.controller!.animateTo(3);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-global-stats-tab')), findsOneWidget);
    tabs.controller!.animateTo(4);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-rankings-tab')), findsOneWidget);
    expect(find.text('Club world rankings'), findsOneWidget);

    final transferred = career.copyWith(
      revision: 1,
      clubId: 'japan-sakura-bay-athletic',
      clubName: 'Sakura Bay Athletic',
    );
    await tester.pumpWidget(
      _localizedApp(WorldScreen(career: transferred, definition: world)),
    );
    tabs.controller!.animateTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Current club · Japan'), findsOneWidget);
    final updatedMap = tester.widget<AccurateFootballWorldMap>(
      find.byType(AccurateFootballWorldMap),
    );
    expect(updatedMap.homeCountryId, 'japan');
    expect(updatedMap.currentClubCountryId, 'japan');
  });

  testWidgets('world renders when the national tournament is not scheduled', (
    tester,
  ) async {
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WorldScreen(career: CareerSnapshot.newCareer())),
      ),
    );
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('world-map-view')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('world-region-europe')),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('world-map-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('world-region-europe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-explorer')), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-country-england')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English Premier Division'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('England Unity Cup'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('England Unity Cup'));
    await tester.pumpAndSettle();
    expect(find.text('KNOCKOUT BRACKET'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('ALL FIXTURES'), findsOneWidget);
  });

  testWidgets('world shows the player completed league score', (tester) async {
    final snapshot = CareerSnapshot.newCareer(seed: 811);
    final opponent = const WorldSimulator().opponentFor(snapshot);
    final result = const WeeklySimulator().advance(
      snapshot: snapshot,
      choice: const WeeklyChoice(
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.balanced,
        spotlightApproach: SpotlightApproach.safe,
      ),
      opponent: opponent,
      updatedAt: DateTime.utc(2026, 9, 6),
    );
    final fixture = result.snapshot.world.playerLeagueFixtures.single;
    await tester.pumpWidget(
      _localizedApp(WorldScreen(career: result.snapshot)),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('world-region-europe')),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('world-map-view')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('world-region-europe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('world-country-england')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English Premier Division'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('RECENT RESULTS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(CustomScrollView).last,
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(Key('league-result-${fixture.id}')), findsOneWidget);
    expect(
      find.text('${result.homeScore}–${result.awayScore}'),
      findsOneWidget,
    );
  });

  testWidgets('national-only home country opens its qualification panel', (
    tester,
  ) async {
    final career = CareerSnapshot.newCareer(
      player: PlayerState.newCareer(
        id: 'canada-player',
        name: 'Canada Player',
        archetype: Archetype.playmaker,
        nationalTeamId: 'canada',
      ),
    );
    await tester.pumpWidget(_localizedApp(WorldScreen(career: career)));

    expect(find.text('Nationality · Canada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-nationality-chip')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Canada · CONCACAF'), findsOneWidget);
    expect(find.textContaining('Next qualifying cycle'), findsOneWidget);
    expect(find.byKey(const Key('country-league-canada-first')), findsNothing);
  });

  testWidgets('world overview scroll is separate from explorer gestures', (
    tester,
  ) async {
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      _localizedApp(WorldScreen(career: CareerSnapshot.newCareer())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    final rootScroll = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('world-map-view')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(rootScroll.position.pixels, 0);
    await tester.drag(
      find.byType(AccurateFootballWorldMap),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(rootScroll.position.pixels, greaterThan(0));
  });

  testWidgets('explorer uses transformed hit testing and semantic back steps', (
    tester,
  ) async {
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      _localizedApp(WorldScreen(career: CareerSnapshot.newCareer())),
    );
    await tester.pumpAndSettle();
    await _revealWorldMapControl(
      tester,
      find.byKey(const Key('world-explore-leagues')),
    );
    await tester.tap(find.byKey(const Key('world-explore-leagues')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('world-region-europe')));
    await tester.pumpAndSettle();

    final data = await tester.runAsync(WorldMapData.load);
    final england = data!.features.singleWhere(
      (feature) => feature.nation == FootballNation.england,
    );
    final normalizedPoint = _insideFeature(england);
    final mapFinder = find.byKey(const Key('accurate-world-map'));
    final mapBox = tester.renderObject<RenderBox>(mapFinder);
    final scenePoint = Offset(
      normalizedPoint.dx * mapBox.size.width,
      normalizedPoint.dy * mapBox.size.height,
    );
    final viewer = tester.widget<InteractiveViewer>(
      find.descendant(of: mapFinder, matching: find.byType(InteractiveViewer)),
    );
    final transformedPoint = MatrixUtils.transformPoint(
      viewer.transformationController!.value,
      scenePoint,
    );
    await tester.tapAt(mapBox.localToGlobal(transformedPoint));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('country-league-england-first')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('world-map-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('country-league-england-first')), findsNothing);
    expect(find.byKey(const Key('world-country-england')), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-map-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-country-england')), findsNothing);
    expect(find.byKey(const Key('world-region-europe')), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-map-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-explorer')), findsNothing);
  });

  testWidgets('unsupported geography gives feedback and reset is available', (
    tester,
  ) async {
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      _localizedApp(WorldScreen(career: CareerSnapshot.newCareer())),
    );
    await tester.pumpAndSettle();
    await _revealWorldMapControl(
      tester,
      find.byKey(const Key('world-explore-leagues')),
    );
    await tester.tap(find.byKey(const Key('world-explore-leagues')));
    await tester.pumpAndSettle();

    final data = await tester.runAsync(WorldMapData.load);
    final unsupported = data!.features.singleWhere(
      (feature) => feature.name == 'Zimbabwe',
    );
    final point = _insideTopmostFeature(data, unsupported);
    final mapFinder = find.byKey(const Key('accurate-world-map'));
    final mapBox = tester.renderObject<RenderBox>(mapFinder);
    await tester.tapAt(
      mapBox.localToGlobal(
        Offset(point.dx * mapBox.size.width, point.dy * mapBox.size.height),
      ),
    );
    await tester.pump();
    expect(find.textContaining('No playable leagues here yet'), findsOneWidget);
    expect(find.byKey(const Key('world-map-reset')), findsOneWidget);
    await tester.tap(find.byKey(const Key('world-map-reset')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-region-europe')), findsOneWidget);
  });

  testWidgets('opens on a real career focus week', (tester) async {
    await tester.pumpWidget(const ElevenwardApp());

    expect(find.text('ELEVENWARD'), findsNothing);
    expect(find.text('CHOOSE YOUR EDGE'), findsOneWidget);
    expect(find.text('Mika Vale'), findsOneWidget);
    expect(find.text('Finishing'), findsOneWidget);
    expect(find.byKey(const Key('focus-selector-button')), findsOneWidget);
    expect(find.byKey(const Key('focus-options')), findsNothing);
  });

  testWidgets('compact focus selector expands, selects, and collapses', (
    tester,
  ) async {
    PlayerAttribute? persisted;
    await tester.pumpWidget(
      _localizedApp(
        GameScreen(
          initialFocus: PlayerAttribute.finishing,
          onFocusPreferenceChanged: (focus) async => persisted = focus,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('focus-selector-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-options')), findsOneWidget);
    for (final attribute in PlayerAttribute.values) {
      expect(find.byKey(Key('focus-option-${attribute.name}')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('focus-option-pace')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-options')), findsNothing);
    expect(find.text('Pace'), findsOneWidget);
    expect(persisted, PlayerAttribute.pace);
  });

  testWidgets('requires an explicit spotlight choice before commit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ElevenwardApp());

    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-continue-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('weekly-continue-button')));
    await tester.pump();

    expect(find.byKey(const Key('matchup-loading-overlay')), findsOneWidget);
    expect(find.byKey(const Key('commit-button')), findsNothing);
    await tester.tap(find.text('Tap to continue'));
    await tester.pumpAndSettle();

    final commit = find.byKey(const Key('commit-button'));
    await tester.scrollUntilVisible(
      commit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(commit).onPressed, isNull);

    await tester.ensureVisible(find.text('Create a shooting lane'));
    await tester.tap(find.text('Create a shooting lane'));
    await tester.pump();
    await tester.ensureVisible(commit);
    expect(tester.widget<FilledButton>(commit).onPressed, isNotNull);

    await tester.tap(commit);
    await tester.pumpAndSettle();
    expect(find.text('WHY IT HAPPENED'), findsNothing);
    expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recap-continue-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-event-prompt')), findsOneWidget);
  });

  testWidgets('matchup overlay auto-dismisses after two seconds', (
    tester,
  ) async {
    await tester.pumpWidget(const ElevenwardApp());
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-continue-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('weekly-continue-button')));
    await tester.pump();

    expect(find.text('Northstar Athletic'), findsWidgets);
    expect(find.byKey(const Key('matchup-home-name')), findsOneWidget);
    expect(find.byKey(const Key('matchup-away-name')), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(find.byKey(const Key('matchup-loading-overlay')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('matchup-loading-overlay')), findsNothing);
    expect(find.byKey(const ValueKey('spotlight')), findsOneWidget);
  });

  testWidgets('recap continues to focus when there is no career event', (
    tester,
  ) async {
    CareerSnapshot? saved;
    final launch = buildLaunchContent();
    final noEvents = ContentCatalog(
      version: launch.version,
      matchSituations: launch.matchSituations,
      careerEvents: const [],
      lifestyleItems: launch.lifestyleItems,
    );
    await tester.pumpWidget(
      _localizedApp(
        GameScreen(
          initialCareer: CareerSnapshot.newCareer(),
          contentCatalog: noEvents,
          onCareerChanged: (snapshot, eventType) async => saved = snapshot,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('training-intensity-intensive')));
    await tester.pump();
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const Key('training-intensity-intensive')),
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-continue-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('weekly-continue-button')));
    await tester.pump();
    await tester.tap(find.text('Tap to continue'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('spotlight-option-safe')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('spotlight-option-safe')));
    await tester.pump();
    final commit = find.byKey(const Key('commit-button'));
    await tester.ensureVisible(commit);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(commit).onPressed, isNotNull);
    await tester.tap(commit);
    await tester.pumpAndSettle();

    expect(saved?.week, 2);
    expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recap-continue-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('focus-selector-button')), findsOneWidget);
    expect(find.byKey(const Key('career-event-prompt')), findsNothing);
    expect(find.text('WHY IT HAPPENED'), findsNothing);
    expect(
      tester
          .widget<Semantics>(
            find.byKey(const Key('training-intensity-balanced')),
          )
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('standalone career event applies and advances', (tester) async {
    final saved = <CareerSnapshot>[];
    final launch = buildLaunchContent();
    final event = launch.careerEvents.firstWhere(
      (candidate) => candidate.category == CareerEventCategory.manager,
    );
    final oneEvent = ContentCatalog(
      version: launch.version,
      matchSituations: launch.matchSituations,
      careerEvents: [event],
      lifestyleItems: launch.lifestyleItems,
    );
    await tester.pumpWidget(
      _localizedApp(
        GameScreen(
          initialCareer: CareerSnapshot.newCareer(),
          contentCatalog: oneEvent,
          onCareerChanged: (snapshot, eventType) async => saved.add(snapshot),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-continue-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('weekly-continue-button')));
    await tester.pump();
    await tester.tap(find.text('Tap to continue'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('spotlight-option-safe')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('spotlight-option-safe')));
    await tester.pump();
    final commit = find.byKey(const Key('commit-button'));
    await tester.ensureVisible(commit);
    await tester.pumpAndSettle();
    await tester.tap(commit);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('match-recap')), findsOneWidget);
    await tester.tap(find.byKey(const Key('recap-continue-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('career-event-prompt')), findsOneWidget);
    await tester.tap(
      find.byKey(Key('career-event-choice-${event.choices.first.id}')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('focus-selector-button')), findsOneWidget);
    expect(saved, hasLength(2));
    expect(saved.last.resolvedEventIds, hasLength(1));
  });

  testWidgets(
    'weekly focus remains scrollable at large text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const ElevenwardApp());
      await tester.scrollUntilVisible(
        find.byKey(const Key('focus-selector-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('focus-selector-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('focus-options')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('weekly-continue-button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('weekly-continue-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _localizedApp(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _revealWorldMapControl(WidgetTester tester, Finder control) async {
  await tester.scrollUntilVisible(
    control,
    220,
    scrollable: find.descendant(
      of: find.byKey(const Key('world-map-view')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
}

Offset _insideFeature(WorldMapFeature feature) =>
    _insideFeatureOrNull(feature) ?? feature.bounds.center;

Offset _insideTopmostFeature(WorldMapData data, WorldMapFeature feature) {
  const samples = 36;
  for (var row = 0; row < samples; row += 1) {
    for (var column = 0; column < samples; column += 1) {
      final point = Offset(
        feature.bounds.left + feature.bounds.width * (column + .5) / samples,
        feature.bounds.top + feature.bounds.height * (row + .5) / samples,
      );
      if (data.featureAt(point)?.code == feature.code) return point;
    }
  }
  throw StateError('No visible sample point for ${feature.name}.');
}

Offset? _insideFeatureOrNull(WorldMapFeature feature) {
  if (feature.contains(feature.bounds.center)) return feature.bounds.center;
  const samples = 24;
  for (var row = 0; row < samples; row += 1) {
    for (var column = 0; column < samples; column += 1) {
      final point = Offset(
        feature.bounds.left + feature.bounds.width * (column + .5) / samples,
        feature.bounds.top + feature.bounds.height * (row + .5) / samples,
      );
      if (feature.contains(point)) return point;
    }
  }
  return null;
}
