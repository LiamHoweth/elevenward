import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/app_controller.dart';
import 'package:elevenward/src/screens/more_detail_screens.dart';
import 'package:elevenward/src/services/analytics_service.dart';
import 'package:elevenward/src/services/auth_service.dart';
import 'package:elevenward/src/services/content_service.dart';
import 'package:elevenward/src/services/elevenward_api.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward/src/services/sync_service.dart';
import 'package:elevenward/src/storage/career_store.dart';
import 'package:elevenward/src/storage/secure_credentials.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CareerStore store;
  late ElevenwardApi api;
  late ContentService content;
  late AppController controller;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    store = await CareerStore.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    final credentials = SecureCredentials();
    api = ElevenwardApi(
      baseUri: Uri.parse('https://example.test'),
      accessToken: credentials.readAccountToken,
      client: MockClient((_) async => http.Response('{}', 404)),
    );
    content = ContentService(api: api, store: store);
    controller =
        AppController(
            store: store,
            auth: AuthService(api: api, credentials: credentials),
            entitlements: EntitlementService(
              credentials: credentials,
              store: store,
            ),
            sync: SyncService(api, store),
            analytics: AnalyticsService(api, store),
            content: content,
          )
          ..activeCareer = CareerSnapshot.newCareer(
            player: PlayerState.newCareer(
              id: 'player-detail-fixture',
              name: 'Alex Montgomery',
              archetype: Archetype.playmaker,
              portraitId: 'player_01',
            ),
          );
  });
  tearDown(() async {
    controller.dispose();
    content.close();
    api.close();
    await store.close();
    ElevenwardColors.use(Brightness.dark);
  });

  for (final locale in const ['en', 'es', 'pt-BR', 'fr']) {
    testWidgets('Player identity and attributes stay readable in $locale', (
      tester,
    ) async {
      _compactLargeText(tester);
      final original = controller.activeCareer!.encode();
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _app(PlayerScreen(controller: controller), locale: locale),
        );
        await tester.pumpAndSettle();

        final name = find.text('Alex Montgomery');
        expect(tester.getSize(name).width, greaterThan(230));
        final nameParagraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: name, matching: find.byType(RichText)),
        );
        expect(
          nameParagraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
          ),
          hasLength(1),
          reason: 'The first name should not split into letter fragments',
        );
        // Static profile content may share a semantics node. Verify the spoken
        // score and its label without assuming a separate accessibility stop.
        final overallSemantics = tester.getSemantics(
          find.byKey(const Key('player-overall-badge')),
        );
        expect(overallSemantics.label, contains(uiCopy(locale, 'overall')));
        expect(
          overallSemantics.value,
          '${controller.activeCareer!.player.overall}',
        );
        final overallText = '${controller.activeCareer!.player.overall}';
        final scoreParagraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byKey(const Key('player-overall-badge')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText() == overallText,
            ),
          ),
        );
        final scoreBoxes = scoreParagraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: overallText.length),
        );
        expect(
          scoreBoxes,
          hasLength(1),
          reason: 'Both overall digits must fit',
        );
        // Glyph bounds can differ fractionally from rounded paragraph metrics.
        // Permit at most one physical pixel while requiring one complete line.
        final roundingTolerance = 1 / tester.view.devicePixelRatio;
        expect(
          scoreBoxes.single.right,
          lessThanOrEqualTo(scoreParagraph.size.width + roundingTolerance),
        );
        expect(
          scoreBoxes.single.bottom,
          lessThanOrEqualTo(scoreParagraph.size.height + roundingTolerance),
        );

        final nationalityLabel = find.text(uiCopy(locale, 'nationality'));
        await _reveal(tester, nationalityLabel);
        expect(
          tester.getSize(nationalityLabel).width,
          greaterThan(230),
          reason: 'The profile label should use the full row at 200% text',
        );

        final attributes = find.byKey(const Key('player-attributes'));
        await _reveal(tester, attributes);
        final label = localizedPlayerAttribute(locale, PlayerAttribute.passing);
        final attributeLabel = find.descendant(
          of: attributes,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == label,
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(attributeLabel);
        final firstWordLength = label.split(' ').first.length;
        expect(
          paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: firstWordLength),
          ),
          hasLength(1),
          reason: 'Attribute labels must preserve complete words at 200% text',
        );
        expect(tester.takeException(), isNull);
        expect(controller.activeCareer!.encode(), original);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('unrated current season shows unavailable instead of zero', (
    tester,
  ) async {
    controller.activeCareer = controller.activeCareer!.copyWith(
      seasonPerformance: const SeasonPerformance(appearances: 2),
    );
    final original = controller.activeCareer!.encode();
    await tester.pumpWidget(_app(PlayerScreen(controller: controller)));
    await tester.pumpAndSettle();
    final metrics = find.byKey(const Key('player-season-metrics'));
    await _reveal(tester, metrics);
    expect(
      find.descendant(of: metrics, matching: find.text('Unavailable')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: metrics, matching: find.text('0.0')),
      findsNothing,
    );
    expect(controller.activeCareer!.encode(), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rated current season preserves the actual average', (
    tester,
  ) async {
    controller.activeCareer = controller.activeCareer!.copyWith(
      seasonPerformance: const SeasonPerformance(
        appearances: 2,
        ratedMatches: 2,
        ratingTenths: 166,
      ),
    );
    await tester.pumpWidget(_app(PlayerScreen(controller: controller)));
    await tester.pumpAndSettle();
    final metrics = find.byKey(const Key('player-season-metrics'));
    await _reveal(tester, metrics);
    expect(
      find.descendant(of: metrics, matching: find.text('8.3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
  locale: locale == 'pt-BR' ? const Locale('pt', 'BR') : Locale(locale),
  theme: buildElevenwardTheme('graphite'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void _compactLargeText(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}
