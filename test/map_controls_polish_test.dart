import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/widgets/football_world_map.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = buildLaunchWorld();

  Future<void> showMap(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double textScale = 1,
    Brightness brightness = Brightness.dark,
    FootballMapRegion? region,
    String? countryId,
    bool interactive = true,
    ValueChanged<String>? onCountrySelected,
    VoidCallback? onReset,
  }) async {
    await tester.runAsync(WorldMapData.load);
    ElevenwardColors.use(brightness);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: AccurateFootballWorldMap(
                definition: world,
                homeRegion: FootballMapRegion.europe,
                homeCountryId: 'england',
                currentClubCountryId: 'japan',
                selectedRegion: region,
                selectedCountryId: countryId,
                interactive: interactive,
                onRegionSelected: (_) {},
                onCountrySelected: onCountrySelected ?? (_) {},
                onUnavailable: (_) {},
                onReset: onReset ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder labels() => find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('world-map-label-'),
  );

  TransformationController transform(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!;

  testWidgets(
    'zoom controls are bounded, immediate with reduced motion, and reset',
    (tester) async {
      var resetCount = 0;
      await showMap(tester, onReset: () => resetCount++);
      expect(labels(), findsNothing);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('world-map-zoom-out')))
            .onPressed,
        isNull,
      );
      for (var step = 0; step < 8; step++) {
        final button = tester.widget<IconButton>(
          find.byKey(const Key('world-map-zoom-in')),
        );
        if (button.onPressed == null) break;
        await tester.tap(find.byKey(const Key('world-map-zoom-in')));
        await tester.pump();
      }
      expect(transform(tester).value.getMaxScaleOnAxis(), 8);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('world-map-zoom-in')))
            .onPressed,
        isNull,
      );
      expect(resetCount, 0);
      await tester.tap(find.byKey(const Key('world-map-zoom-out')));
      await tester.pump();
      expect(
        transform(tester).value.getMaxScaleOnAxis(),
        closeTo(8 / 1.5, .001),
      );
      await tester.tap(find.byKey(const Key('world-map-reset')));
      await tester.pump();
      expect(transform(tester).value, Matrix4.identity());
      expect(resetCount, 1);
      expect(labels(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zoom retains transformed country selection and screen-sized labels',
    (tester) async {
      String? selected;
      await showMap(
        tester,
        region: FootballMapRegion.europe,
        countryId: 'spain',
        onCountrySelected: (id) => selected = id,
      );
      final label = find.byKey(const Key('world-map-label-spain'));
      expect(label, findsOneWidget);
      final initialHeight = tester.getSize(label).height;
      await tester.tap(find.byKey(const Key('world-map-zoom-out')));
      await tester.pump();
      expect(transform(tester).value.getMaxScaleOnAxis(), closeTo(5, .001));
      expect(tester.getSize(label).height, initialHeight);

      final data = WorldMapData.cached!;
      final spain = data.features.firstWhere(
        (feature) => feature.code == 'ESP',
      );
      Offset? interior;
      for (var y = 1; y < 20 && interior == null; y++) {
        for (var x = 1; x < 20 && interior == null; x++) {
          final point = Offset(
            spain.bounds.left + spain.bounds.width * x / 20,
            spain.bounds.top + spain.bounds.height * y / 20,
          );
          if (spain.contains(point)) interior = point;
        }
      }
      final map = find.byKey(const Key('accurate-world-map'));
      final box = tester.renderObject<RenderBox>(map);
      final local = MatrixUtils.transformPoint(
        transform(tester).value,
        Offset(interior!.dx * box.size.width, interior.dy * box.size.height),
      );
      await tester.tapAt(box.localToGlobal(local));
      await tester.pump();
      expect(selected, 'spain');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('two-finger pinch remains available alongside zoom buttons', (
    tester,
  ) async {
    await showMap(tester);
    final center = tester.getCenter(
      find.byKey(const Key('accurate-world-map')),
    );
    final first = await tester.startGesture(
      center + const Offset(-35, 0),
      pointer: 11,
    );
    final second = await tester.startGesture(
      center + const Offset(35, 0),
      pointer: 12,
    );
    await tester.pump();
    await first.moveTo(center + const Offset(-80, 0));
    await second.moveTo(center + const Offset(80, 0));
    await tester.pump();
    // Scale recognition begins after touch slop. Continue the same real
    // gesture once recognized instead of assuming its baseline is touch-down.
    await first.moveTo(center + const Offset(-130, 0));
    await second.moveTo(center + const Offset(130, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pumpAndSettle();
    expect(transform(tester).value.getMaxScaleOnAxis(), greaterThan(1.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('same map inputs repaint when the display mode changes', (
    tester,
  ) async {
    await showMap(tester, brightness: Brightness.dark);
    final paintFinder = find.descendant(
      of: find.byKey(const Key('accurate-world-map')),
      matching: find.byType(CustomPaint),
    );
    final oldPainter = tester.widget<CustomPaint>(paintFinder).painter!;
    await showMap(tester, brightness: Brightness.light);
    final newPainter = tester.widget<CustomPaint>(paintFinder).painter!;
    expect(newPainter.shouldRepaint(oldPainter), isTrue);
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
        'map at 320px and 200% text: ${locale.toLanguageTag()} $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await showMap(
            tester,
            locale: locale,
            textScale: 2,
            brightness: brightness,
            region: FootballMapRegion.europe,
            countryId: 'spain',
          );
          final localeKey = locale.languageCode == 'pt'
              ? 'pt-BR'
              : locale.languageCode;
          final selectedLabel = find.byKey(const Key('world-map-label-spain'));
          expect(
            tester
                .widget<IconButton>(find.byKey(const Key('world-map-zoom-in')))
                .tooltip,
            {
              'en': 'Zoom in',
              'es': 'Acercar',
              'pt-BR': 'Aproximar',
              'fr': 'Agrandir',
            }[localeKey],
          );
          expect(selectedLabel, findsOneWidget);
          expect(
            find.descendant(
              of: selectedLabel,
              matching: find.text(world.country('spain').nameFor(localeKey)),
            ),
            findsOneWidget,
          );
          final mapRect = tester.getRect(
            find.byKey(const Key('accurate-world-map')),
          );
          final controls = [
            for (final key in [
              'world-map-zoom-in',
              'world-map-zoom-out',
              'world-map-reset',
            ])
              tester.getRect(find.byKey(Key(key))),
          ];
          for (final control in controls) {
            expect(control.width, greaterThanOrEqualTo(48));
            expect(control.height, greaterThanOrEqualTo(48));
          }
          final rectangles = [
            for (final label in labels().evaluate())
              tester.getRect(find.byWidget(label.widget)),
          ];
          for (var index = 0; index < rectangles.length; index++) {
            final rect = rectangles[index];
            expect(mapRect.contains(rect.topLeft), isTrue);
            expect(mapRect.contains(rect.bottomRight), isTrue);
            for (final other in [...controls, ...rectangles.skip(index + 1)]) {
              expect(rect.overlaps(other), isFalse);
            }
          }
          final legend = find.byKey(const Key('world-map-legend'));
          final scroll = tester.widget<SingleChildScrollView>(legend);
          expect(scroll.scrollDirection, Axis.horizontal);
          await tester.drag(legend, const Offset(-220, 0));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'overview keeps its existing explore interaction without controls',
    (tester) async {
      await showMap(tester, interactive: false);
      expect(find.byKey(const Key('world-map-overview')), findsOneWidget);
      expect(find.byKey(const Key('world-map-zoom-in')), findsNothing);
      expect(labels(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
