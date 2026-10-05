import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = buildLaunchWorld();

  Future<void> showMap(WidgetTester tester, String countryId) async {
    await tester.runAsync(WorldMapData.load);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AccurateFootballWorldMap(
                definition: world,
                homeRegion: FootballMapRegion.northAmerica,
                homeCountryId: 'united-states',
                currentClubCountryId: 'new-zealand',
                selectedRegion: countryId == 'new-zealand'
                    ? FootballMapRegion.oceania
                    : FootballMapRegion.northAmerica,
                selectedCountryId: countryId,
                onRegionSelected: (_) {},
                onCountrySelected: (_) {},
                onUnavailable: (_) {},
                onReset: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('country marks use land rather than whole-country box centers', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    for (final countryId in [
      'united-states',
      'new-zealand',
      'japan',
      'canada',
      'fiji',
    ]) {
      final anchor = data!.anchorForCountry(countryId, definition: world);
      expect(anchor, isNotNull, reason: countryId);
      expect(
        data.features.any(
          (feature) =>
              data.countryIdFor(feature, world) == countryId &&
              feature.contains(anchor!),
        ),
        isTrue,
        reason: '$countryId marker must be on its own land',
      );
    }
    expect(data!.anchorForCountry('unknown', definition: world), isNull);
    expect(
      data.anchorForCountry('fiji', definition: buildLegacyLaunchWorld()),
      isNull,
    );
  });

  testWidgets('date-line countries retain geometry and focus their mainland', (
    tester,
  ) async {
    final data = await tester.runAsync(WorldMapData.load);
    for (final countryId in ['united-states', 'new-zealand', 'fiji']) {
      final all = data!.boundsForCountry(countryId, definition: world);
      final focused = data.focusBoundsForCountry(countryId, definition: world);
      expect(all.width, greaterThan(.75), reason: countryId);
      expect(focused.width, lessThan(.5), reason: countryId);
      expect(
        focused.contains(data.anchorForCountry(countryId, definition: world)!),
        isTrue,
        reason: countryId,
      );
      // Fitting the camera does not change hit-testing or mapped content.
      expect(data.boundsForCountry(countryId, definition: world), all);
    }
    expect(
      data!.focusBoundsForCountry('spain', definition: world),
      data.boundsForCountry('spain', definition: world),
    );
  });

  for (final countryId in ['united-states', 'new-zealand']) {
    testWidgets('$countryId focus zooms and respects map edges', (
      tester,
    ) async {
      await showMap(tester, countryId);
      final mapFinder = find.byKey(const Key('accurate-world-map'));
      final size = tester.getSize(mapFinder);
      final matrix = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value;
      final scale = matrix.getMaxScaleOnAxis();
      expect(scale, greaterThan(1.75));
      expect(scale, lessThanOrEqualTo(7.5));
      final translation = matrix.getTranslation();
      expect(translation.x, greaterThanOrEqualTo(size.width * (1 - scale)));
      expect(translation.y, greaterThanOrEqualTo(size.height * (1 - scale)));
      expect(translation.x, lessThanOrEqualTo(0));
      expect(translation.y, lessThanOrEqualTo(0));
      final anchor = WorldMapData.cached!.anchorForCountry(
        countryId,
        definition: world,
      )!;
      final screenAnchor = MatrixUtils.transformPoint(
        matrix,
        Offset(anchor.dx * size.width, anchor.dy * size.height),
      );
      expect((Offset.zero & size).contains(screenAnchor), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'interactive map does not advertise an unavailable button action',
    (tester) async {
      await showMap(tester, 'united-states');
      final mapSemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('Nationality:') ?? false),
        ),
      );
      expect(mapSemantics.properties.image, isTrue);
      expect(mapSemantics.properties.button, isFalse);
    },
  );
}
