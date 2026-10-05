import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/career_engagement.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward/src/widgets/career_progress_panel.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every new role first targets its first actual appearance', () {
    for (final role in Archetype.values) {
      final career = _career(role);
      expect(careerTarget(career), (
        kind: CareerMilestoneKind.appearances,
        current: 0,
        goal: 1,
      ));
      final after = career.copyWith(
        player: career.player.copyWith(appearances: 1),
      );
      expect(
        careerMilestones(career, after),
        contains((kind: CareerMilestoneKind.appearances, value: 1)),
      );
    }
  });

  test(
    'role targets correspond to actual recap milestones at every boundary',
    () {
      for (final role in Archetype.values) {
        for (final current in [
          0,
          1,
          9,
          10,
          24,
          25,
          49,
          50,
          99,
          100,
          299,
          300,
          499,
          500,
          599,
          600,
        ]) {
          final before = _career(
            role,
            appearances: current == 0 ? 1 : current,
            goals: current,
            assists: current,
          );
          final saved = before.encode();
          final target = careerTarget(before)!;
          expect(target.goal, greaterThan(target.current));
          expect(before.encode(), saved);
          final after = before.copyWith(
            player: before.player.copyWith(
              appearances: target.kind == CareerMilestoneKind.appearances
                  ? target.goal
                  : before.player.appearances,
              goals: target.kind == CareerMilestoneKind.goals
                  ? target.goal
                  : before.player.goals,
              assists: target.kind == CareerMilestoneKind.assists
                  ? target.goal
                  : before.player.assists,
            ),
          );
          expect(
            careerMilestones(before, after),
            contains((kind: target.kind, value: target.goal)),
            reason: '${role.name} $current should recap the displayed target',
          );
          expect(careerMilestones(after, after), isEmpty);
          expect(careerTarget(after)!.goal, greaterThan(target.goal));
        }
      }
    },
  );

  test('a target close to a milestone does not skip it', () {
    final striker = _career(Archetype.poacher, appearances: 25, goals: 24);
    final defender = _career(Archetype.stopper, appearances: 9);
    expect(careerTarget(striker)!.goal, 25);
    expect(careerTarget(defender)!.goal, 10);
  });

  test(
    'long careers keep actual milestones without duplicate celebrations',
    () {
      final before = _career(Archetype.poacher, appearances: 599, goals: 399);
      final after = before.copyWith(
        player: before.player.copyWith(appearances: 601, goals: 502),
      );
      expect(careerMilestones(before, after), [
        (kind: CareerMilestoneKind.appearances, value: 600),
        (kind: CareerMilestoneKind.goals, value: 400),
        (kind: CareerMilestoneKind.goals, value: 500),
      ]);
      expect(careerMilestones(after, before), isEmpty);
      expect(careerMilestones(after, after), isEmpty);
    },
  );

  testWidgets('retired careers have no unfinished automatic target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_career(Archetype.poacher).copyWith(retired: true)),
    );
    expect(find.byKey(const Key('career-target-panel')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${locale.toLanguageTag()} ${brightness.name} target fits 320px at 200% text',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final career = _career(Archetype.poacher, appearances: 25, goals: 24);
          final saved = career.encode();
          await tester.pumpWidget(
            _app(career, locale: locale, brightness: brightness),
          );
          final contentLocale = locale.languageCode == 'pt'
              ? 'pt-BR'
              : locale.languageCode;
          final remaining = formatUiCopy(contentLocale, 'targetRemaining', {
            'remaining': 1,
            'metric': milestoneLabel(contentLocale, CareerMilestoneKind.goals),
          });
          expect(find.text(remaining), findsOneWidget);
          final progress = tester.widget<LinearProgressIndicator>(
            find.byKey(const Key('career-target-progress')),
          );
          expect(progress.value, 24 / 25);
          expect(progress.semanticsLabel, contains(remaining));
          expect(progress.semanticsLabel, isNot(contains('{goal}')));
          expect(progress.semanticsLabel, isNot(contains('{remaining}')));
          expect(progress.semanticsValue, isNull);
          expect(career.encode(), saved);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

CareerSnapshot _career(
  Archetype role, {
  int appearances = 0,
  int goals = 0,
  int assists = 0,
}) => CareerSnapshot.newCareer(
  player: PlayerState.newCareer(
    id: 'progress-test',
    name: 'Progress Test',
    archetype: role,
  ).copyWith(appearances: appearances, goals: goals, assists: assists),
);

Widget _app(
  CareerSnapshot career, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
}) {
  ElevenwardColors.use(brightness);
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildElevenwardTheme('graphite', brightness),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: CareerTargetPanel(career: career),
      ),
    ),
  );
}
