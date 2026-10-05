import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/career_feature_panels.dart';
import 'package:elevenward/src/widgets/stat_explanation.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  bool accessible = false,
}) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: buildElevenwardTheme('graphite', brightness),
  builder: (context, child) {
    ElevenwardColors.use(brightness);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(accessible ? 2 : 1),
        disableAnimations: accessible,
      ),
      child: child!,
    );
  },
  home: Scaffold(body: Center(child: child)),
);

void main() {
  tearDown(() => ElevenwardColors.use(Brightness.dark));

  testWidgets(
    'all localized sheets fit narrow screens and remain dismissible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final career = CareerSnapshot.newCareer();
        final before = career.toJson();

        for (final locale in ['en', 'es', 'pt', 'fr']) {
          for (final brightness in [Brightness.dark, Brightness.light]) {
            for (final stat in ExplainedStat.values) {
              await tester.pumpWidget(
                _app(
                  StatExplanationButton(stat: stat, career: career),
                  locale: Locale(locale),
                  brightness: brightness,
                  accessible: true,
                ),
              );
              await tester.pumpAndSettle();
              final button = find.byKey(Key('stat-help-${stat.name}'));
              final label = explainedStatHelpLabel(locale, stat);
              final buttonData = tester.getSemantics(button).getSemanticsData();
              expect(buttonData.label, label);
              expect(buttonData.tooltip, isEmpty);
              expect(buttonData.flagsCollection.isButton, isTrue);
              expect(find.semantics.byLabel(label).evaluate(), hasLength(1));
              expect(
                tester
                    .getSemantics(button)
                    .getSemanticsData()
                    .hasAction(SemanticsAction.tap),
                isTrue,
              );
              expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
              expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
              tester.semantics.tap(find.semantics.byLabel(label));
              await tester.pumpAndSettle();
              expect(
                find.byKey(Key('stat-explanation-${stat.name}')),
                findsOneWidget,
              );
              expect(
                find.text(explainedStatLabel(locale, stat)),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
              await tester.drag(
                find.byKey(const Key('stat-explanation-scroll')),
                const Offset(0, -500),
              );
              await tester.pumpAndSettle();
              final close = find.byKey(const Key('stat-explanation-close'));
              final closeData = tester.getSemantics(close).getSemanticsData();
              expect(
                closeData.label,
                MaterialLocalizations.of(tester.element(close))
                    .closeButtonTooltip,
              );
              expect(closeData.tooltip, isEmpty);
              expect(closeData.flagsCollection.isButton, isTrue);
              expect(
                find.semantics.byLabel(closeData.label).evaluate(),
                hasLength(1),
              );
              tester.semantics.tap(find.semantics.byLabel(closeData.label));
              await tester.pumpAndSettle();
              expect(
                find.byKey(Key('stat-explanation-${stat.name}')),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
            }
          }
        }
        expect(career.toJson(), before);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('help follows the saved tactical and legacy rules', (
    tester,
  ) async {
    final modern = CareerSnapshot.newCareer();
    final older = CareerSnapshot.fromJson({
      ...modern.toJson(),
      'rulesVersion': '2026.4',
    });
    for (final career in [modern, older]) {
      for (final stat in [
        ExplainedStat.tacticalFit,
        ExplainedStat.legacyScore,
      ]) {
        await tester.pumpWidget(
          _app(StatExplanationButton(stat: stat, career: career)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('stat-help-${stat.name}')));
        await tester.pumpAndSettle();
        final body = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('stat-explanation-scroll')),
            matching: find.byType(Text),
          ),
        );
        if (stat == ExplainedStat.tacticalFit) {
          expect(
            body.data!.contains('Developing the skills'),
            career.usesModernCareerRules,
          );
        } else {
          expect(
            body.data!.contains('contributions for your position'),
            career.usesModernCareerRules,
          );
        }
        expect(body.data, isNot(contains('2026.')));
        await tester.tap(find.byKey(const Key('stat-explanation-close')));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('career panels expose their corresponding stat help', (
    tester,
  ) async {
    final career = CareerSnapshot.newCareer();
    final club = buildLaunchWorld().clubs.firstWhere(
      (club) => club.id == career.clubId,
    );
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Column(
            children: [
              LegacyBreakdownPanel(career: career),
              CareerStylePanel(career: career, club: club),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final stat in [ExplainedStat.legacyScore, ExplainedStat.tacticalFit]) {
      final button = find.byKey(Key('stat-help-${stat.name}'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byKey(Key('stat-explanation-${stat.name}')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stat-explanation-close')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}
