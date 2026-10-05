import 'dart:convert';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/feature_copy.dart';
import 'package:elevenward/src/online_copy.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward/src/screens/career_hub_screen.dart';
import 'package:elevenward/src/screens/career_journal_screen.dart';
import 'package:elevenward/src/screens/hall_of_fame_screen.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
import 'package:elevenward/src/screens/support_screen.dart';
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

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  bool light = false,
}) => MaterialApp(
  locale: locale,
  theme: buildElevenwardTheme(
    'graphite',
    light ? Brightness.light : Brightness.dark,
  ),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) {
    ElevenwardColors.use(Theme.of(context).brightness);
    return child!;
  },
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;
  late Future<http.Response> Function(http.Request) respond;
  final requests = <http.Request>[];

  setUpAll(() => sqfliteFfiInit());
  setUp(() async {
    requests.clear();
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Elevenward',
      packageName: 'com.howethstudio.elevenward',
      version: '1.0.0',
      buildNumber: '4',
      buildSignature: 'test',
    );
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    respond = (_) async => http.Response('{}', 404);
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => 'fixture-token',
      client: MockClient((request) {
        requests.add(request);
        return respond(request);
      }),
    );
    content = ContentService(api: api, store: store);
    controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    await controller.refreshSlots();
  });
  tearDown(() async {
    ElevenwardColors.use(Brightness.dark);
    controller.dispose();
    content.close();
    api.close();
    await store.close();
  });

  testWidgets('fresh device can reach account and settings without a career', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(CareerHubScreen(controller: controller)));
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const Key('hub-account')));
    await tester.tap(find.byKey(const Key('hub-account')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await store.listConflicts();
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more-account-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    Navigator.of(tester.element(find.byKey(const Key('more-account-screen'))))
        .pop();
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(const Key('hub-settings')));
    await tester.tap(find.byKey(const Key('hub-settings')));
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('VERSION DETAILS'));
    expect(controller.activeCareer, isNull);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      await store.listConflicts();
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('account conflict list refreshes when synchronization finishes', (
    tester,
  ) async {
    controller.account = const ElevenwardAccount(
      id: 'fixture-account',
      alias: 'Fixture',
      provider: 'apple',
    );
    await tester.pumpWidget(_app(AccountScreen(controller: controller)));
    await tester.pump();
    await tester.runAsync(() => store.listConflicts());
    await tester.pumpAndSettle();
    final base = CareerSnapshot.newCareer();
    await tester.runAsync(() async {
      await store.preserveConflict(
        local: base.copyWith(revision: 4),
        remote: base.copyWith(revision: 3),
        createdAt: DateTime.utc(2026, 10, 1),
      );
      controller.syncStatus = SyncUiStatus.complete;
      controller.notifyListeners();
    });
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('CLOUD CONFLICTS'));
    expect(find.text('CLOUD CONFLICTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'explicit equal or older cloud generation replaces the displayed career',
    (tester) async {
      final base = CareerSnapshot.newCareer();
      final local = base.copyWith(
        revision: 9,
        player: PlayerState.newCareer(
          id: base.player.id,
          name: 'Local Player',
          archetype: base.player.archetype,
        ),
      );
      for (final revision in [9, 3]) {
        await tester.pumpWidget(
          _app(
            GameScreen(
              key: ValueKey(revision),
              initialCareer: local,
              activeCareerGeneration: 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Local Player'), findsOneWidget);
        await tester.pumpWidget(
          _app(
            GameScreen(
              key: ValueKey(revision),
              initialCareer: local.copyWith(
                revision: revision,
                player: PlayerState.newCareer(
                  id: base.player.id,
                  name: 'Cloud Player',
                  archetype: base.player.archetype,
                ),
              ),
              activeCareerGeneration: 2,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cloud Player'), findsOneWidget);
        expect(find.text('Local Player'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('a saved pending story resumes before the next fixture', (
    tester,
  ) async {
    final catalog = buildLatestContent();
    final event = catalog.careerEvents.firstWhere(
      (event) => event.id == 'mentor-01-introduction',
    );
    final career = const CareerEngine().queueEvent(
      CareerSnapshot.newCareer().copyWith(week: 3),
      event,
    );
    final restored = await tester.runAsync(() async {
      await store.saveSlot(0, career);
      return store.loadSlot(0);
    });
    CareerSnapshot? committed;
    await tester.pumpWidget(
      _app(
        GameScreen(
          initialCareer: restored,
          contentCatalog: catalog,
          onCareerChanged: (snapshot, _) async => committed = snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('career-event')), findsOneWidget);
    expect(find.byKey(const Key('weekly-continue-button')), findsNothing);
    final choice = find.byKey(const Key('career-event-choice-share'));
    await _reveal(tester, choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(committed?.pendingEventId, isNull);
    expect(committed?.decisionJournal.first.eventId, event.id);
    expect(find.byKey(const Key('weekly-continue-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hall of Fame survives deleting a playable slot', (tester) async {
    final retired = CareerSnapshot.newCareer().copyWith(
      phase: CareerPhase.retired,
      retired: true,
    );
    await tester.runAsync(() async {
      await store.saveSlot(0, retired);
      await controller.archiveCareer(retired);
      await controller.refreshSlots();
      await controller.deleteSlot(0);
      expect(await store.loadSlot(0), isNull);
      expect(
        (await controller.localHallOfFame()).single.careerId,
        retired.careerId,
      );
    });
    await tester.pumpWidget(_app(HallOfFameScreen(controller: controller)));
    await tester.runAsync(() async {
      await controller.localHallOfFame();
    });
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('archived-career-${retired.careerId}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete confirmation preserves a replaced slot', (tester) async {
    final opening = CareerSnapshot.newCareer();
    final replacement = CareerSnapshot.newCareer(
      careerId: 'replacement-career',
    );
    await tester.runAsync(() async {
      await store.saveSlot(0, opening);
      await controller.refreshSlots();
    });
    await tester.pumpWidget(
      _app(
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CareerHubScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final deleteSlot = find.byTooltip(uiCopy('en', 'deleteTooltip'));
    await _reveal(tester, deleteSlot);
    await tester.tap(deleteSlot);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await store.saveSlot(0, replacement);
      await controller.refreshSlots();
    });
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, uiCopy('en', 'delete')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect((await store.loadSlot(0))!.careerId, replacement.careerId);
    });
    expect(
      find.text(featureCopy('en', 'careerChangedBeforeDeletion')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Hall retry uploads pending archives before refreshing the list',
    (tester) async {
      controller.account = const ElevenwardAccount(
        id: 'fixture-account',
        alias: 'Fixture',
        provider: 'apple',
        leaderboardSharingEnabled: false,
      );
      respond = (request) async => http.Response(
        jsonEncode({
          if (request.url.path.endsWith('/career-slots')) 'slots': [],
          if (request.url.path.endsWith('/career-archives')) 'archives': [],
        }),
        200,
      );
      final retired = CareerSnapshot.newCareer().copyWith(
        retired: true,
        phase: CareerPhase.retired,
      );
      await tester.runAsync(() async {
        await store.saveArchive(retired, accountId: 'fixture-account');
        await controller.refreshSlots();
      });
      expect(controller.archiveBackupPending, isTrue);
      await tester.pumpWidget(_app(HallOfFameScreen(controller: controller)));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      final retry = find.text('Retry cloud sync');
      await _reveal(tester, retry);
      await tester.tap(retry);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (controller.archiveBackupPending || controller.busy) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Archive retry did not finish.');
        }
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (request) =>
              request.method == 'POST' &&
              request.url.path.endsWith('/career-archives'),
        ),
        isTrue,
      );
      expect(
        await tester.runAsync(() => store.pendingArchives('fixture-account')),
        isEmpty,
      );
      expect(await tester.runAsync(controller.localHallOfFame), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Hall of Fame refreshes when a new local archive arrives', (
    tester,
  ) async {
    await tester.pumpWidget(_app(HallOfFameScreen(controller: controller)));
    await tester.runAsync(controller.localHallOfFame);
    await tester.pumpAndSettle();
    final retired = CareerSnapshot.newCareer().copyWith(
      retired: true,
      phase: CareerPhase.retired,
    );
    await tester.runAsync(() => controller.archiveCareer(retired));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(Key('archived-career-${retired.careerId}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'costly story choices explain affordability and retain a free path',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final catalog = buildLatestContent();
      final event = catalog.careerEvents.firstWhere(
        (event) => event.choices.any((choice) => choice.moneyDelta < 0),
      );
      final base = CareerSnapshot.newCareer();
      final career = const CareerEngine().queueEvent(
        base.copyWith(player: base.player.copyWith(money: 0)),
        event,
      );
      CareerSnapshot? committed;
      await tester.pumpWidget(
        _app(
          GameScreen(
            initialCareer: career,
            contentCatalog: catalog,
            onCareerChanged: (snapshot, _) async => committed = snapshot,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final costly = event.choices.firstWhere(
        (choice) => choice.moneyDelta < 0,
      );
      final paidButton = find.byKey(Key('career-event-choice-${costly.id}'));
      await _reveal(tester, paidButton);
      expect(tester.widget<OutlinedButton>(paidButton).onPressed, isNull);
      expect(find.textContaining('Not enough money'), findsWidgets);
      expect(committed, isNull);
      final free = event.choices.firstWhere((choice) => choice.moneyDelta >= 0);
      final freeButton = find.byKey(Key('career-event-choice-${free.id}'));
      await _reveal(tester, freeButton);
      expect(tester.widget<OutlinedButton>(freeButton).onPressed, isNotNull);
      await tester.tap(freeButton);
      await tester.pumpAndSettle();
      expect(committed?.pendingEventId, isNull);
      expect(committed?.decisionJournal.first.choiceId, free.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one-season loan is reviewed before the durable career changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final base = CareerSnapshot.newCareer();
    final career = base.copyWith(
      phase: CareerPhase.offseason,
      player: base.player.copyWith(
        attributes: PlayerAttributes({
          for (final attribute in PlayerAttribute.values) attribute: 75,
        }),
        reputation: 80,
      ),
      contract: base.contract.copyWith(seasonsRemaining: 4),
    );
    final offer = const CareerEngine().loanOffers(career).first;
    CareerSnapshot? committed;
    await tester.pumpWidget(
      _app(
        GameScreen(
          initialCareer: career,
          onCareerChanged: (snapshot, _) async => committed = snapshot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final loanButton = find.byKey(Key('offseason-loan-${offer.clubId}'));
    await _reveal(tester, loanButton);
    await tester.tap(loanButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(committed, isNull);
    final confirm = find.byKey(const Key('confirm-offseason-loan'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(committed?.activeLoan?.hostClubId, offer.clubId);
    expect(committed?.activeLoan?.parentClubId, career.clubId);
    expect(committed?.season, career.season + 1);
    expect(committed?.activeLoan?.returnSeason, career.season + 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loan review cannot change an explicitly replaced career', (
    tester,
  ) async {
    final base = CareerSnapshot.newCareer();
    final career = base.copyWith(
      phase: CareerPhase.offseason,
      player: base.player.copyWith(
        attributes: PlayerAttributes({
          for (final attribute in PlayerAttribute.values) attribute: 75,
        }),
        reputation: 80,
      ),
      contract: base.contract.copyWith(seasonsRemaining: 4),
    );
    final offer = const CareerEngine().loanOffers(career).first;
    CareerSnapshot? committed;
    Widget game(CareerSnapshot snapshot, int generation) => _app(
      GameScreen(
        initialCareer: snapshot,
        activeCareerGeneration: generation,
        onCareerChanged: (snapshot, _) async => committed = snapshot,
      ),
    );
    await tester.pumpWidget(game(career, 1));
    await tester.pumpAndSettle();
    final loanButton = find.byKey(Key('offseason-loan-${offer.clubId}'));
    await _reveal(tester, loanButton);
    await tester.tap(loanButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.pumpWidget(game(career.copyWith(revision: 0), 2));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirm-offseason-loan'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(committed, isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ambition picker writes the chosen goal and progress survives reload',
    (tester) async {
      final career = CareerSnapshot.newCareer();
      await tester.runAsync(() async {
        await store.saveSlot(0, career);
      });
      controller.activeCareer = career;
      controller.activeSlotIndex = 0;
      await tester.pumpWidget(_app(PlayerScreen(controller: controller)));
      await _reveal(tester, find.byKey(const Key('choose-career-ambition')));
      await tester.tap(find.byKey(const Key('choose-career-ambition')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('career-ambition-goals')));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 50 && controller.activeCareer!.careerGoal == null;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(controller.activeCareer!.careerGoal?.kind, CareerGoalKind.goals);
      final restored = await tester.runAsync(() => store.loadSlot(0));
      expect(restored!.careerGoal?.target, 20);
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
      'selected support category fits 320px at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          _app(
            SupportScreen(controller: controller),
            locale: locale,
            light: true,
          ),
        );
        await tester.pumpAndSettle();
        final category = find.byKey(const Key('feedback-category'));
        await _reveal(tester, category);
        final label = find.text(onlineCopy(locale.toLanguageTag(), 'bug'));
        expect(label, findsOneWidget);
        final categoryBounds = tester.getRect(category);
        final labelBounds = tester.getRect(label);
        expect(labelBounds.top, greaterThanOrEqualTo(categoryBounds.top));
        expect(labelBounds.bottom, lessThanOrEqualTo(categoryBounds.bottom));
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      'cloud deletion conflict is truthful in both entry points in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        controller.account = const ElevenwardAccount(
          id: 'fixture-account',
          alias: 'Fixture',
          provider: 'apple',
        );
        final career = CareerSnapshot.newCareer();
        await tester.runAsync(() async {
          await store.saveSlot(0, career);
          await store.preserveConflict(
            local: career,
            remote: null,
            createdAt: DateTime.utc(2026, 10, 1),
            remoteConflictId: 'cloud-deletion',
            remoteRevision: 3,
          );
          await controller.refreshSlots();
          expect((await store.listConflicts()).single.remoteSnapshot, isNull);
        });
        final tag = locale.toLanguageTag();
        final deletedLabel =
            '${uiCopy(tag, 'cloud')}: ${uiCopy(tag, 'deleted')}';
        final actionLabel = featureCopy(tag, 'useCloudDeletion');
        for (final screen in [
          CareerHubScreen(controller: controller),
          AccountScreen(controller: controller),
        ]) {
          await tester.pumpWidget(_app(screen, locale: locale));
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pumpAndSettle();
          await _reveal(tester, find.text(deletedLabel));
          expect(find.text(deletedLabel), findsOneWidget);
          await _reveal(tester, find.text(actionLabel));
          final button = find.ancestor(
            of: find.text(actionLabel),
            matching: find.byType(OutlinedButton),
          );
          expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
        }
      },
    );
    testWidgets(
      'journal, match detail and archive fit 320px at 200% in ${locale.toLanguageTag()}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final base = CareerSnapshot.newCareer();
        final result = const WeeklySimulator().advance(
          snapshot: base,
          choice: const WeeklyChoice(
            focus: PlayerAttribute.finishing,
            intensity: TrainingIntensity.balanced,
            spotlightApproach: SpotlightApproach.safe,
          ),
          opponent: const WorldSimulator().opponentFor(base),
          updatedAt: DateTime.utc(2026, 10, 1),
        );
        controller.activeCareer = result.snapshot;
        await tester.pumpWidget(
          _app(
            CareerJournalScreen(controller: controller),
            locale: locale,
            light: locale.languageCode == 'fr',
          ),
        );
        await tester.pumpAndSettle();
        final match = result.snapshot.matchJournal.first;
        final tile = find.byKey(Key('journal-match-${match.id}'));
        await _reveal(tester, tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('journal-match-screen')), findsOneWidget);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          _app(
            ArchivedCareerScreen(
              controller: controller,
              career: result.snapshot.copyWith(
                retired: true,
                phase: CareerPhase.retired,
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 15000));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).last,
      maxScrolls: 80,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
