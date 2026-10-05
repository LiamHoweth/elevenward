import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/screens/world_screen.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = buildLaunchWorld();
  final career = CareerSnapshot.newCareer(
    worldDefinition: world,
    clubId: 'spain-ciudad-azahar',
    clubName: 'Ciudad Azahar',
  );

  testWidgets('club overview opens its current league after promotion', (
    tester,
  ) async {
    final participants = {
      for (final entry in career.world.leagueParticipants.entries)
        entry.key: [...entry.value],
    };
    final oldLeague = career.world.leagueIdForClub(career.clubId);
    final nextLeague = oldLeague == 'spain-first'
        ? 'spain-second'
        : 'spain-first';
    final swappedClub = participants[nextLeague]!.first;
    participants[nextLeague]![0] = career.clubId;
    participants[oldLeague]![participants[oldLeague]!.indexOf(career.clubId)] =
        swappedClub;
    final promoted = career.copyWith(
      world: career.world.copyWith(leagueParticipants: participants),
    );
    final encoded = promoted.encode();
    await _openTab(tester, promoted, world, 'club');
    final shortcut = find.byKey(const Key('world-club-open-league'));
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    final route = tester.widget<WorldScreen>(find.byType(WorldScreen).last);
    expect(route.initialLeagueId, nextLeague);
    expect(route.highlightClubId, promoted.clubId);
    expect(identical(route.definition, world), isTrue);
    expect(promoted.encode(), encoded);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rankings search accepts translated country names without accents',
    (tester) async {
      final encoded = career.encode();
      await _openTab(tester, career, world, 'rankings');
      final search = find.byKey(const Key('world-ranking-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Espana');
      await tester.pumpAndSettle();
      final count = world.clubs
          .where((club) => club.countryId == 'spain')
          .length;
      expect(find.text('$count CLUBS'), findsOneWidget);
      expect(find.byKey(const Key('world-ranking-empty')), findsNothing);
      final clear = find.byKey(const Key('world-ranking-clear-search'));
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        find.byKey(const Key('world-ranking-reset-filters')),
        findsNothing,
      );
      expect(career.encode(), encoded);
    },
  );

  testWidgets('no rankings results provides a working filter reset', (
    tester,
  ) async {
    final encoded = career.encode();
    await _openTab(tester, career, world, 'rankings');
    final search = find.byKey(const Key('world-ranking-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'club-that-does-not-exist');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world-ranking-empty')), findsOneWidget);
    final reset = find.byKey(const Key('world-ranking-reset-filters'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    expect(find.byKey(const Key('world-ranking-empty')), findsNothing);
    expect(find.byKey(const Key('world-ranking-reset-filters')), findsNothing);
    expect(career.encode(), encoded);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [
    Locale('en'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
  ]) {
    testWidgets('ranking help and club names remain readable at 200% $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openTab(tester, career, world, 'rankings', locale: locale);
      final current = find.byKey(const Key('world-ranking-current-club'));
      await tester.scrollUntilVisible(
        current,
        100,
        scrollable: find.descendant(
          of: find.byKey(const Key('world-rankings-tab')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      await tester.ensureVisible(current);
      final title = find.descendant(
        of: current,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data?.endsWith('Ciudad Azahar') == true,
        ),
      );
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).maxLines, isNull);
      expect(
        tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
        isFalse,
      );
      final rankingsScroll = find.descendant(
        of: find.byKey(const Key('world-rankings-tab')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      );
      tester.state<ScrollableState>(rankingsScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('world-ranking-info')));
      await tester.pumpAndSettle();
      final help = find.byKey(const Key('world-ranking-help-scroll'));
      expect(help, findsOneWidget);
      await tester.drag(help, const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

Future<void> _openTab(
  WidgetTester tester,
  CareerSnapshot career,
  WorldDefinition world,
  String section, {
  Locale locale = const Locale('en'),
}) async {
  await tester.runAsync(WorldMapData.load);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: buildElevenwardTheme('graphite'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WorldScreen(career: career, definition: world),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final tab = find.byKey(Key('world-tab-$section'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
