import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/league_presentation.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/transfer_comparison_panel.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = buildLaunchWorld();
  final currentClub = world.clubs.firstWhere(
    (club) =>
        club.countryId == 'england' && club.division == DivisionLevel.first,
  );
  final offeredClub = world.clubs.firstWhere(
    (club) =>
        club.countryId == 'england' && club.division == DivisionLevel.second,
  );
  final base = CareerSnapshot.newCareer(
    clubId: currentClub.id,
    clubName: currentClub.name,
    worldDefinition: world,
  ).copyWith(phase: CareerPhase.offseason);
  final offer = ContractOffer(
    clubId: offeredClub.id,
    seasons: 2,
    weeklyWage: 2450,
    appearanceBonus: 400,
    promisedRole: 'important',
    tacticalFit: calculateTacticalFit(base, offeredClub),
    interestReason: 'Your level and profile fit an immediate first-team need.',
  );

  test('comparison uses dynamic league membership and the exact offer fit', () {
    final first = world.leagues.firstWhere(
      (league) =>
          league.countryId == 'england' &&
          league.division == DivisionLevel.first,
    );
    final second = world.leagues.firstWhere(
      (league) =>
          league.countryId == 'england' &&
          league.division == DivisionLevel.second,
    );
    final currentState = base.world.copyWith(
      leagueParticipants: {
        ...base.world.leagueParticipants,
        first.id: first.clubIds.where((id) => id != currentClub.id).toList(),
        second.id: [...second.clubIds, currentClub.id],
      },
    );
    final marketState = currentState.copyWith(
      leagueParticipants: {
        ...currentState.leagueParticipants,
        first.id: [
          ...currentState.leagueParticipants[first.id]!,
          offeredClub.id,
        ],
        second.id: currentState.leagueParticipants[second.id]!
            .where((id) => id != offeredClub.id)
            .toList(),
      },
    );
    final career = base.copyWith(world: currentState);
    final before = career.encode();
    final comparison = transferComparison(
      career: career,
      offer: offer,
      world: world,
      marketState: marketState,
    );
    expect(currentClub.division, DivisionLevel.first);
    expect(comparison.currentLeague, second);
    expect(offeredClub.division, DivisionLevel.second);
    expect(comparison.offeredLeague, first);
    expect(comparison.currentFit, calculateTacticalFit(career, currentClub));
    expect(comparison.offeredFit, offer.tacticalFit);
    expect(career.encode(), before);
  });

  test('default market projection matches canonical season movement', () {
    final market = const WorldSimulator().beginNextSeason(
      base.world,
      base.seed,
      definition: world,
    );
    final comparison = transferComparison(
      career: base,
      offer: offer,
      world: world,
    );
    expect(
      comparison.offeredLeague?.id,
      market.leagueIdForClub(offeredClub.id),
    );
  });

  test('legacy fit follows the legacy rule formula', () {
    final legacy = CareerSnapshot.fromJson({
      ...base.toJson(),
      'rulesVersion': '2026.4',
    });
    final comparison = transferComparison(
      career: legacy,
      offer: offer,
      world: world,
      marketState: legacy.world,
    );
    expect(comparison.currentFit, calculateTacticalFit(legacy, currentClub));
  });

  test('incomplete legacy world has no fabricated league or fit', () {
    final career = base.copyWith(
      contract: base.contract.copyWith(clubId: 'retired-content-club'),
      world: const CareerWorldState(
        season: 1,
        leagueParticipants: {},
        leagueRecords: {},
      ),
    );
    final comparison = transferComparison(
      career: career,
      offer: offer,
      world: world,
    );
    expect(comparison.currentClub, isNull);
    expect(comparison.currentLeague, isNull);
    expect(comparison.currentFit, isNull);
    expect(comparison.offeredLeague, isNull);
  });

  testWidgets('contract values and changed role remain visible and readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        TransferComparisonPanel(
          career: base,
          offer: offer,
          world: world,
          marketState: base.world,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('£1,200 / week'), findsOneWidget);
    expect(find.text('£2,450 / week'), findsOneWidget);
    expect(find.text('Weekly wage change: +£1,250 / week'), findsOneWidget);
    expect(find.text('rotation'), findsOneWidget);
    expect(find.text('important player'), findsOneWidget);
    expect(
      find.text(
        '${leagueDisplayName(world.leagueForClub(currentClub.id))} · this season',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '${leagueDisplayName(world.leagueForClub(offeredClub.id))} · next season',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (offeredWage, expectedChange) in [
    (1200, 'Weekly wage change: £0 / week'),
    (900, 'Weekly wage change: −£300 / week'),
  ]) {
    testWidgets('weekly wage $offeredWage shows the exact signed change', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          TransferComparisonPanel(
            career: base,
            offer: ContractOffer(
              clubId: offer.clubId,
              seasons: offer.seasons,
              weeklyWage: offeredWage,
              appearanceBonus: offer.appearanceBonus,
              promisedRole: offer.promisedRole,
              tacticalFit: offer.tacticalFit,
              interestReason: offer.interestReason,
            ),
            world: world,
            marketState: base.world,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expectedChange), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    for (final locale in const [
      Locale('en'),
      Locale('es'),
      Locale('pt', 'BR'),
      Locale('fr'),
    ]) {
      testWidgets('320px at 200% has no overflow in $locale $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(
            TransferComparisonPanel(
              career: base,
              offer: offer,
              world: world,
              marketState: base.world,
            ),
            locale: locale,
            brightness: brightness,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        final metric = find.byKey(const Key('transfer-comparison-wage'));
        final values = find.descendant(of: metric, matching: find.byType(Text));
        final currentRect = tester.getRect(values.at(2));
        final offerRect = tester.getRect(values.at(4));
        expect(offerRect.top, greaterThan(currentRect.bottom));
        await tester.ensureVisible(
          find.byKey(const Key('transfer-comparison-fit')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Compare with your current contract'),
          locale.languageCode == 'en' ? findsOneWidget : findsNothing,
        );
      });
    }
  }
}

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.dark,
  double scale = 1,
}) {
  ElevenwardColors.use(brightness);
  return MaterialApp(
    locale: locale,
    theme: buildElevenwardTheme('graphite', brightness),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}
