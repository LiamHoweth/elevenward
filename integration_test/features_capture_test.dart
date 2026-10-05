import 'dart:convert';
import 'dart:io';

import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/game_screen.dart';
import 'package:elevenward/src/screens/career_hub_screen.dart';
import 'package:elevenward/src/screens/career_journal_screen.dart';
import 'package:elevenward/src/screens/friends_screen.dart';
import 'package:elevenward/src/screens/hall_of_fame_screen.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
import 'package:elevenward/src/screens/support_screen.dart';
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
import 'package:elevenward/src/widgets/career_feature_panels.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native feature fixtures in four languages at large text', (
    tester,
  ) async {
    // Only this disposable database and an in-memory HTTP fixture are used.
    final databasePath = p.join(
      Directory.systemTemp.path,
      'elevenward-features-qa.sqlite',
    );
    await deleteDatabase(databasePath);
    final store = await CareerStore.open(path: databasePath);
    final credentials = SecureCredentials();
    final api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: () async => 'fixture-token',
      client: MockClient((request) async {
        final body = switch (request.url.path) {
          '/v1/elevenward/career-archives' => {'archives': []},
          '/v1/elevenward/friends' => {
            'comparisonSharingEnabled': true,
            'friends': [
              {
                'profileId': 'fixture-friend',
                'alias': 'Alex North',
                'comparisonAvailable': true,
                'careers': [
                  {
                    'position': 'midfielder',
                    'difficulty': 'balanced',
                    'rulesVersion': '2026.5',
                    'legacyScore': 530,
                    'aggregateMetrics': {'seasons': 3, 'trophies': 1},
                  },
                ],
              },
            ],
            'incomingRequests': [],
            'outgoingRequests': [],
            'blocked': [],
          },
          '/v1/elevenward/challenges/current' => {
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
            'entries': [
              {'rank': 1, 'alias': 'Alex North', 'score': 724},
            ],
          },
          _ => <String, Object?>{},
        };
        return http.Response(jsonEncode(body), 200);
      }),
    );
    final content = ContentService(api: api, store: store);
    final controller = AppController(
      store: store,
      auth: AuthService(api: api, credentials: credentials),
      entitlements: EntitlementService(credentials: credentials, store: store),
      sync: SyncService(api, store),
      analytics: AnalyticsService(api, store),
      content: content,
    );
    final catalog = buildLatestContent();
    final base = CareerSnapshot.newCareer(
      careerId: 'features-qa',
      seed: 811,
      player: PlayerState.newCareer(
        id: 'features-player',
        name: 'Mika Vale',
        archetype: Archetype.playmaker,
        portraitId: 'player_01',
      ),
    );
    final match = const WeeklySimulator()
        .advance(
          snapshot: base,
          choice: const WeeklyChoice(
            focus: PlayerAttribute.passing,
            intensity: TrainingIntensity.balanced,
            spotlightApproach: SpotlightApproach.balanced,
          ),
          opponent: const WorldSimulator().opponentFor(base),
          updatedAt: DateTime.utc(2026, 10, 1),
        )
        .snapshot;
    final career = const CareerEngine().chooseCareerGoal(
      snapshot: match,
      kind: CareerGoalKind.assists,
      target: 20,
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    final retired = career.copyWith(retired: true, phase: CareerPhase.retired);
    await store.saveArchive(retired);
    controller.activeContent = await content.load();
    Future<void> commit(CareerSnapshot snapshot, String eventType) async {
      await store.saveSlot(0, snapshot, eventType: eventType);
      expect((await store.loadSlot(0))!.encode(), snapshot.encode());
    }

    for (final locale in [
      const Locale('en'),
      const Locale('es'),
      const Locale('pt', 'BR'),
      const Locale('fr'),
    ]) {
      final tag = locale.toLanguageTag();
      Widget app(Widget child) => MaterialApp(
        key: ValueKey('$tag-${child.runtimeType}'),
        locale: locale,
        theme: buildElevenwardTheme(
          'graphite',
          tag == 'fr' || tag == 'pt-BR' ? Brightness.light : Brightness.dark,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          ElevenwardColors.use(Theme.of(context).brightness);
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          );
        },
        home: child,
      );
      controller.account = null;
      controller.activeCareer = null;
      controller.activeSlotIndex = null;
      controller.slots = [];
      await tester.pumpWidget(app(CareerHubScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('hub-account')));
      await _capture(tester, tag, 'hub-fresh');

      controller.activeCareer = career;
      controller.activeSlotIndex = 0;
      await store.saveSlot(0, career);
      await tester.pumpWidget(app(PlayerScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byType(CareerAmbitionPanel));
      await _capture(tester, tag, 'ambition');
      await tester.tap(find.byKey(const Key('choose-career-ambition')));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('career-ambition-goals')));
      await tester.tap(find.byKey(const Key('career-ambition-goals')));
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (controller.activeCareer!.careerGoal?.kind !=
            CareerGoalKind.goals) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Native goal save did not complete.');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await tester.pumpAndSettle();
      expect((await store.loadSlot(0))!.careerGoal?.kind, CareerGoalKind.goals);
      controller.activeCareer = career;

      await tester.pumpWidget(app(CareerJournalScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'journal');
      await tester.pumpWidget(app(HallOfFameScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _reveal(
        tester,
        find.byKey(Key('archived-career-${retired.careerId}')),
      );
      await _capture(tester, tag, 'hall');
      await tester.tap(find.byKey(Key('archived-career-${retired.careerId}')));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'archive');

      final pending = const CareerEngine().queueEvent(
        career.copyWith(week: 3),
        catalog.careerEvents.firstWhere(
          (event) => event.id == 'mentor-01-introduction',
        ),
      );
      await tester.pumpWidget(
        app(
          GameScreen(
            initialCareer: pending,
            contentCatalog: catalog,
            onCareerChanged: commit,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'mentor');
      final mentorChoice = find.byKey(const Key('career-event-choice-share'));
      await _reveal(tester, mentorChoice);
      await tester.tap(mentorChoice);
      await tester.pumpAndSettle();
      final savedStory = (await store.loadSlot(0))!;
      expect(savedStory.pendingEventId, isNull);
      expect(savedStory.storyFlags['mentor.stage'], '1');
      expect(savedStory.decisionJournal.first.choiceId, 'share');

      final offseason = career.copyWith(
        phase: CareerPhase.offseason,
        player: career.player.copyWith(
          attributes: PlayerAttributes({
            for (final attribute in PlayerAttribute.values) attribute: 75,
          }),
          reputation: 80,
        ),
        contract: career.contract.copyWith(seasonsRemaining: 4),
      );
      final loan = const CareerEngine().loanOffers(offseason).first;
      await tester.pumpWidget(
        app(
          GameScreen(
            key: ValueKey('loan-$tag'),
            initialCareer: offseason,
            contentCatalog: catalog,
            onCareerChanged: commit,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(Key('offseason-loan-${loan.clubId}')));
      await tester.tap(find.byKey(Key('offseason-loan-${loan.clubId}')));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'loan-review');
      await tester.tap(find.byKey(const Key('confirm-offseason-loan')));
      await tester.pumpAndSettle();
      expect((await store.loadSlot(0))!.activeLoan?.hostClubId, loan.clubId);

      controller.account = const ElevenwardAccount(
        id: 'fixture-account',
        alias: 'Mika',
        provider: 'apple',
      );
      await tester.pumpWidget(app(FriendsScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'friends');
      await tester.pumpWidget(
        app(WeeklyChallengeScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const Key('challenge-start')));
      await _capture(tester, tag, 'challenge');
      await tester.pumpWidget(app(SupportScreen(controller: controller)));
      await tester.pumpAndSettle();
      await _capture(tester, tag, 'support');
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
    p.join(Directory.systemTemp.path, 'elevenward-features-$locale-$name.ack'),
  );
  if (await ack.exists()) await ack.delete();
  debugPrint('FEATURE_CAPTURE_READY|$locale|$name|${ack.path}');
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
