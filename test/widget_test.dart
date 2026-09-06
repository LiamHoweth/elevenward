import 'package:elevenward/main.dart';
import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/screens/onboarding_screen.dart';
import 'package:elevenward/src/screens/world_screen.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding remains scrollable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onComplete: () async {}),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('world renders when the national tournament is not scheduled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: WorldScreen(career: CareerSnapshot.newCareer())),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('England Unity Cup'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('England Unity Cup'));
    await tester.pumpAndSettle();
    expect(find.text('KNOCKOUT BRACKET'), findsOneWidget);
    expect(find.text('ALL FIXTURES'), findsOneWidget);
  });
  testWidgets('opens on a real career focus week', (tester) async {
    await tester.pumpWidget(const ElevenwardApp());

    expect(find.text('ELEVENWARD'), findsOneWidget);
    expect(find.text('Choose your edge.'), findsOneWidget);
    expect(find.text('Mika Vale'), findsOneWidget);
    expect(find.text('Finishing'), findsOneWidget);
  });

  testWidgets('requires an explicit spotlight choice before commit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ElevenwardApp());

    await tester.scrollUntilVisible(
      find.byKey(const Key('set-focus-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('set-focus-button')));
    await tester.pumpAndSettle();

    final commit = find.byKey(const Key('commit-button'));
    await tester.scrollUntilVisible(
      commit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(commit).onPressed, isNull);

    await tester.ensureVisible(find.text('Create a shooting lane'));
    await tester.tap(find.text('Create a shooting lane'));
    await tester.pump();
    await tester.ensureVisible(commit);
    expect(tester.widget<FilledButton>(commit).onPressed, isNotNull);

    await tester.tap(commit);
    await tester.pumpAndSettle();
    expect(find.text('WHY IT HAPPENED'), findsOneWidget);
  });

  testWidgets(
    'weekly focus remains scrollable at large text on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const ElevenwardApp());
      await tester.scrollUntilVisible(
        find.text('Choose your edge.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Choose your edge.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('set-focus-button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('set-focus-button')), findsOneWidget);
    },
  );
}
