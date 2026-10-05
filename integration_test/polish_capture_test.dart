import 'dart:io';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/online_copy.dart';
import 'package:elevenward/src/screens/career_journal_screen.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
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
import 'package:elevenward/src/training_preset.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward/src/widgets/fitness_guidance.dart';
import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward/src/widgets/recent_performance_strip.dart';
import 'package:elevenward/src/widgets/stat_explanation.dart';
import 'package:elevenward/src/widgets/training_preset_panel.dart';
import 'package:elevenward/src/widgets/transfer_comparison_panel.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  const journalOnly = bool.fromEnvironment('POLISH_CAPTURE_JOURNAL_ONLY');
  const trainingOnly = bool.fromEnvironment('POLISH_CAPTURE_TRAINING_ONLY');
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native polish interactions, persistence, and localized layout', (
    tester,
  ) async {
    final catalog = buildLatestContent();
    final world = catalog.world;
    final career = _playedCareer(catalog);
    final original = career.encode();
    final targetClub = world.clubs.firstWhere(
      (club) =>
          club.countryId == 'spain' &&
          club.id != career.clubId &&
          career.world.leagueParticipants.values.any(
            (participants) => participants.contains(club.id),
          ),
    );
    final targetLeagueId = career.world.leagueIdForClub(targetClub.id);

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
        'elevenward-polish-qa-$tag.sqlite',
      );
      await deleteDatabase(databasePath);
      var session = await _FixtureSession.open(databasePath, career);

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

      if (journalOnly) {
        await _exerciseJournalFilters(
          tester,
          session.controller,
          career,
          tag,
          mount,
        );
        expect((await session.store.loadSlot(0))!.encode(), original);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await session.close();
        await deleteDatabase(databasePath);
        continue;
      }

      if (trainingOnly) {
        await session.controller.saveTrainingPreset(
          const TrainingPreset(
            focus: PlayerAttribute.passing,
            intensity: TrainingIntensity.balanced,
          ),
        );
        await mount(
          _game(session.controller),
          'training-normal',
          compact: false,
        );
        await _assertTrainingLoadLabels(tester, tag);
        await _reveal(
          tester,
          find.byKey(const Key('training-intensity-light')),
        );
        await _capture(tester, tag, 'training-normal');
        await mount(_game(session.controller), 'training-load-controls');
        await _assertTrainingLoadLabels(tester, tag);
        for (final intensity in [
          TrainingIntensity.light,
          TrainingIntensity.balanced,
        ]) {
          await _tap(tester, 'training-intensity-${intensity.name}');
          expect(
            tester
                .widget<Semantics>(
                  find.byKey(Key('training-intensity-${intensity.name}')),
                )
                .properties
                .selected,
            isTrue,
          );
          await _reveal(tester, find.byKey(const Key('fitness-guidance')));
          final actual = tester
              .widget<FitnessGuidance>(find.byType(FitnessGuidance))
              .preview;
          final expected = const WeeklySimulator().previewTraining(
            snapshot: career,
            focus: PlayerAttribute.passing,
            intensity: intensity,
          );
          expect(actual.fitnessBefore, expected.fitnessBefore);
          expect(actual.fitnessAfter, expected.fitnessAfter);
          expect(actual.attributeBefore, expected.attributeBefore);
          expect(actual.attributeAfter, expected.attributeAfter);
        }
        await _reveal(
          tester,
          find.byKey(const Key('training-intensity-light')),
        );
        await _capture(tester, tag, 'training-load-controls');
        expect((await session.store.loadSlot(0))!.encode(), original);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await session.close();
        await deleteDatabase(databasePath);
        continue;
      }

      Widget worldScreen() => Scaffold(
        body: SafeArea(
          child: WorldScreen(
            career: career,
            definition: world,
            controller: session.controller,
          ),
        ),
      );

      // Search a localized country, verify selection, and exercise both zooms.
      await mount(worldScreen(), 'map-search');
      await _tap(tester, 'world-explore-leagues');
      await _search(
        tester,
        world.country('spain').nameFor(tag),
        resultKey: 'world-search-country-spain',
        diagnosticLocale: tag == 'en' ? tag : null,
      );
      await _tap(tester, 'world-search-country-spain');
      expect(
        tester
            .widget<AccurateFootballWorldMap>(
              find.byType(AccurateFootballWorldMap),
            )
            .selectedCountryId,
        'spain',
      );
      await _tap(tester, 'world-map-zoom-in');
      await _tap(tester, 'world-map-zoom-out');
      expect(find.byKey(const Key('world-map-label-spain')), findsOneWidget);
      await _capture(tester, tag, 'map-zoom');

      // Search a club and save both bookmark kinds through their actual UI.
      await _search(
        tester,
        targetClub.name,
        resultKey: 'world-search-club-${targetClub.id}',
      );
      await _tap(tester, 'world-search-club-${targetClub.id}');
      await _tap(tester, 'favorite-club-${targetClub.id}');
      await _waitFor(
        tester,
        () => session.controller.favoriteClubIds.contains(targetClub.id),
      );
      await _tap(tester, 'favorite-league-$targetLeagueId');
      await _waitFor(
        tester,
        () => session.controller.favoriteLeagueIds.contains(targetLeagueId),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await session.close();
      session = await _FixtureSession.open(databasePath, career);
      expect(session.controller.favoriteClubIds, contains(targetClub.id));
      expect(session.controller.favoriteLeagueIds, contains(targetLeagueId));
      await mount(worldScreen(), 'map-favorites');
      await _reveal(tester, find.byKey(const Key('world-favorites')));
      await _capture(tester, tag, 'map-favorites');
      await _tap(tester, 'world-favorite-club-${targetClub.id}');
      expect(
        tester
            .widget<WorldScreen>(find.byType(WorldScreen).last)
            .highlightClubId,
        targetClub.id,
      );
      await mount(worldScreen(), 'favorite-league-open');
      await _tap(tester, 'world-favorite-league-$targetLeagueId');
      expect(
        tester
            .widget<WorldScreen>(find.byType(WorldScreen).last)
            .initialLeagueId,
        targetLeagueId,
      );

      // The strip reads only matches already committed by the real engine.
      await mount(PlayerScreen(controller: session.controller), 'performance');
      await _reveal(tester, find.byKey(const Key('recent-performance-strip')));
      expect(recentPlayedMatches(career), hasLength(5));
      expect(find.byKey(const Key('recent-rating-trend')), findsOneWidget);
      await _capture(tester, tag, 'performance');

      // Save a preset, change load, apply, then reopen SQLite and use it again.
      await mount(_game(session.controller), 'training-save');
      await _tap(tester, 'save-training-preset');
      const preset = TrainingPreset(
        focus: PlayerAttribute.passing,
        intensity: TrainingIntensity.balanced,
      );
      await _waitFor(tester, () => session.controller.trainingPreset == preset);
      await _tap(tester, 'training-intensity-light');
      await _tap(tester, 'apply-training-preset');
      expect(
        tester
            .widget<TrainingPresetPanel>(find.byType(TrainingPresetPanel))
            .intensity,
        TrainingIntensity.balanced,
      );
      expect(
        await session.store.loadWeeklyFocus(career.careerId),
        PlayerAttribute.passing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await session.close();
      session = await _FixtureSession.open(databasePath, career);
      expect(session.controller.trainingPreset, preset);
      await mount(_game(session.controller), 'training-reopen');
      await _tap(tester, 'training-intensity-light');
      await _tap(tester, 'apply-training-preset');
      await _reveal(tester, find.byKey(const Key('training-preset-summary')));
      await _capture(tester, tag, 'training-preset');
      await _reveal(tester, find.byKey(const Key('fitness-guidance')));
      final guidance = tester.widget<FitnessGuidance>(
        find.byType(FitnessGuidance),
      );
      final expected = const WeeklySimulator().previewTraining(
        snapshot: career,
        focus: preset.focus,
        intensity: preset.intensity,
      );
      expect(guidance.preview.fitnessAfter, expected.fitnessAfter);
      await _capture(tester, tag, 'fitness-guidance');
      for (final fitness in [49, 50, 79, 80, 100]) {
        await mount(
          _panel(
            FitnessGuidance(
              preview: TrainingPreview(
                attributeBefore: 70,
                attributeAfter: 71,
                fitnessBefore: fitness,
                fitnessAfter: fitness,
                remainder: 0,
                multiplier: 1,
                paused: fitness == 100,
              ),
            ),
          ),
          'fitness-$fitness',
        );
        expect(find.byKey(const Key('fitness-guidance-band')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      // Compare a real generated offer without accepting or mutating a career.
      final marketCareer = career.copyWith(phase: CareerPhase.offseason);
      final offer = const CareerEngine()
          .contractOffers(marketCareer, definition: world)
          .first;
      await mount(
        _panel(
          TransferComparisonPanel(
            career: marketCareer,
            offer: offer,
            world: world,
          ),
        ),
        'transfer-comparison',
      );
      for (final metric in ['wage', 'role', 'league', 'fit']) {
        await _reveal(
          tester,
          find.byKey(ValueKey('transfer-comparison-$metric')),
        );
      }
      await _reveal(
        tester,
        find.byKey(ValueKey('transfer-comparison-${offer.clubId}')),
      );
      await _capture(tester, tag, 'transfer-comparison');

      // Every explanation opens and closes using its visible controls.
      for (final stat in ExplainedStat.values) {
        await mount(
          _panel(StatExplanationButton(stat: stat, career: career)),
          'explanation-${stat.name}',
        );
        await _tap(tester, 'stat-help-${stat.name}');
        expect(
          find.byKey(Key('stat-explanation-${stat.name}')),
          findsOneWidget,
        );
        if (stat == ExplainedStat.tacticalFit) {
          await _capture(tester, tag, 'stat-explanation');
        }
        await _tap(tester, 'stat-explanation-close');
        expect(find.byKey(Key('stat-explanation-${stat.name}')), findsNothing);
      }

      await _exerciseJournalFilters(
        tester,
        session.controller,
        career,
        tag,
        mount,
      );

      // Native-size scenes also show the normal release presentation.
      await mount(worldScreen(), 'world-normal', compact: false);
      await _capture(tester, tag, 'world-normal');
      await mount(_game(session.controller), 'training-normal', compact: false);
      await _reveal(tester, find.byKey(const Key('focus-selector-button')));
      await _capture(tester, tag, 'training-normal');
      await mount(
        _game(session.controller, careerOverride: marketCareer),
        'offers-normal',
        compact: false,
      );
      await _tap(tester, 'offer-comparison-${offer.clubId}');
      await _reveal(
        tester,
        find.byKey(ValueKey('transfer-comparison-${offer.clubId}')),
      );
      await _capture(tester, tag, 'offers-normal');
      await mount(
        PlayerScreen(controller: session.controller),
        'player-normal',
        compact: false,
      );
      await _reveal(tester, find.byKey(const Key('recent-performance-strip')));
      await _capture(tester, tag, 'player-normal');
      expect((await session.store.loadSlot(0))!.encode(), original);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await session.close();
      await deleteDatabase(databasePath);
    }
  });
}

Future<void> _assertTrainingLoadLabels(WidgetTester tester, String tag) async {
  final balanced = uiCopy(tag, 'balanced').toLowerCase();
  final expected = {
    TrainingIntensity.light: onlineCopy(tag, 'trainingLight'),
    TrainingIntensity.balanced:
        '${balanced.substring(0, 1).toUpperCase()}${balanced.substring(1)}',
    TrainingIntensity.intensive: onlineCopy(tag, 'trainingIntensive'),
  };
  for (final intensity in TrainingIntensity.values) {
    final option = find.byKey(Key('training-intensity-${intensity.name}'));
    await _reveal(tester, option);
    final label = find.descendant(of: option, matching: find.byType(Text));
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).data, expected[intensity]);
  }
}

Future<void> _exerciseJournalFilters(
  WidgetTester tester,
  AppController controller,
  CareerSnapshot career,
  String tag,
  Future<void> Function(Widget, String) mount,
) async {
  await mount(CareerJournalScreen(controller: controller), 'journal-filter');
  await _tap(tester, 'journal-filter-decisions');
  expect(
    tester
        .widget<ChoiceChip>(find.byKey(const Key('journal-filter-decisions')))
        .selected,
    isTrue,
  );
  await _tap(tester, 'journal-filter-matches');
  final (visibleLabel, spokenLabel) = switch (tag) {
    'es' => ('Todas', 'Todas las competiciones'),
    'pt-BR' => ('Todas', 'Todas as competições'),
    'fr' => ('Toutes', 'Toutes les compétitions'),
    _ => ('All', 'All competitions'),
  };
  final allFinder = find.byKey(const Key('journal-competition-all'));
  await _reveal(tester, allFinder);
  final allTile = tester.widget<RadioListTile<String>>(allFinder);
  final title = allTile.title! as Semantics;
  expect((title.child! as Text).data, visibleLabel);
  expect(title.properties.label, spokenLabel);
  expect(title.excludeSemantics, isTrue);
  final competitionId = career.matchJournal.first.competitionId!;
  await _tap(tester, 'journal-competition-$competitionId');
  expect(
    tester
        .widget<RadioListTile<String>>(
          find.byKey(Key('journal-competition-$competitionId')),
        )
        .selected,
    isTrue,
  );
  await _reveal(tester, find.byKey(const Key('journal-filter-matches')));
  await _capture(tester, tag, 'journal-filter');
}

CareerSnapshot _playedCareer(ContentCatalog catalog) {
  var career = CareerSnapshot.newCareer(
    careerId: 'polish-qa',
    seed: 811,
    player: PlayerState.newCareer(
      id: 'polish-player',
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

Widget _game(AppController controller, {CareerSnapshot? careerOverride}) =>
    ListenableBuilder(
      listenable: controller,
      builder: (context, _) => GameScreen(
        initialCareer: careerOverride ?? controller.activeCareer,
        initialFocus: PlayerAttribute.passing,
        contentCatalog: controller.activeContent!.catalog,
        trainingPreset: controller.trainingPreset,
        onSaveTrainingPreset: controller.saveTrainingPreset,
        onClearTrainingPreset: controller.clearTrainingPreset,
        onFocusPreferenceChanged: controller.changeWeeklyFocus,
        quickTransitions: true,
        showCoachingTips: false,
        showCareerTarget: false,
      ),
    );

Widget _panel(Widget child) => Scaffold(
  body: SafeArea(
    child: ListView(padding: const EdgeInsets.all(16), children: [child]),
  ),
);

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
      accessToken: () async => null,
      client: MockClient((request) async {
        throw StateError(
          'Native polish QA attempted HTTP: ${request.url.path}',
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

Future<void> _search(
  WidgetTester tester,
  String query, {
  required String resultKey,
  String? diagnosticLocale,
}) async {
  expect(find.byKey(const Key('world-explorer')), findsOneWidget);
  final field = find.byKey(const Key('world-search-field'));
  final pane = find.byKey(const Key('world-explorer-options'));
  await _reveal(tester, field, scrollRoot: pane);
  final controller = tester.widget<TextField>(field).controller!;
  // Give the native IME time to reconnect before injecting editing text.
  // Otherwise its delayed initial empty state can overwrite a second query.
  await tester.tap(field);
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(field).focusNode!.hasFocus,
    isTrue,
    reason: 'The visible native search field received focus.',
  );
  await _waitForNativeKeyboard(tester, visible: true);
  await tester.pumpAndSettle();
  await tester.enterText(field, query);
  await tester.pumpAndSettle();
  expect(
    controller.text,
    query,
    reason: 'The native search input was entered.',
  );
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(field).controller,
    same(controller),
    reason:
        'The explorer kept the same search controller across keyboard layout.',
  );
  expect(
    controller.text,
    query,
    reason: 'The entered query survived a settled native editing frame.',
  );
  debugPrint(
    'POLISH_SEARCH|$query|beforeDismissInsets=${tester.view.viewInsets.bottom}',
  );
  // Exercise the actual keyboard Search action and its production dismissal.
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
  await _waitForNativeKeyboard(tester, visible: false);
  await tester.pumpAndSettle();
  expect(controller.text, query, reason: 'Dismissing kept the entered query.');
  debugPrint(
    'POLISH_SEARCH|$query|afterSearchInsets=${tester.view.viewInsets.bottom}',
  );
  expect(tester.takeException(), isNull, reason: 'After native search input');
  if (diagnosticLocale != null) {
    await _capture(tester, diagnosticLocale, 'diagnostic-search-country');
  }
  await _reveal(tester, find.byKey(Key(resultKey)), scrollRoot: pane);
  expect(
    find.byKey(Key(resultKey)),
    findsOneWidget,
    reason: 'The entered query must expose its expected search result.',
  );
}

Future<void> _waitForNativeKeyboard(
  WidgetTester tester, {
  required bool visible,
}) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    double? previousInset;
    DateTime? stableSince;
    while (true) {
      final now = DateTime.now();
      final inset = tester.view.viewInsets.bottom;
      if ((visible ? inset > 0 : inset == 0) && inset == previousInset) {
        stableSince ??= now;
        if (now.difference(stableSince) >= const Duration(milliseconds: 200)) {
          return;
        }
      } else {
        stableSince = null;
      }
      previousInset = inset;
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          'The native search keyboard did not ${visible ? 'open' : 'dismiss'} '
          'and settle (physical inset $inset).',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'After tapping $key');
}

Future<void> _waitFor(WidgetTester tester, bool Function() completed) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (!completed()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('The native polish preference did not commit.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pumpAndSettle();
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
    'POLISH_CAPTURE_LAYOUT|$locale|$name|${media.size.width}|'
    '${media.size.height}|${media.textScaler.scale(1)}|'
    '${Theme.of(context).brightness.name}',
  );
  final ack = File(
    p.join(Directory.systemTemp.path, 'elevenward-polish-$locale-$name.ack'),
  );
  if (await ack.exists()) await ack.delete();
  debugPrint('POLISH_CAPTURE_READY|$locale|$name|${ack.path}');
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
