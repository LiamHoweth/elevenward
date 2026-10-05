import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/marketing_links.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward/src/widgets/share_career_card.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const links = StudioMarketingLinks(websiteBaseUrl: 'https://studio.example');

  test('missing or invalid configuration disables outbound discovery', () {
    for (final value in const [
      '',
      'not a URL',
      'http://studio.example',
      'https://user:password@studio.example',
      'https://studio.example/private',
      'https://studio.example?account=private',
      'https://studio.example#private',
      'mailto:studio@example.com',
    ]) {
      final invalid = StudioMarketingLinks(websiteBaseUrl: value);
      expect(invalid.productUrl, isNull, reason: value);
      expect(invalid.careerShareUrl, isNull, reason: value);
      expect(invalid.studioDiscoveryUrl, isNull, reason: value);
    }
  });

  test('discovery links use fixed campaigns without private identifiers', () {
    expect(links.productUrl.toString(), 'https://studio.example/elevenward/');
    expect(links.careerShareUrl!.queryParameters, {
      'utm_source': 'elevenward',
      'utm_medium': 'share',
      'utm_campaign': 'career-share-v1',
    });
    expect(links.studioDiscoveryUrl!.path, '/');
    expect(links.studioDiscoveryUrl!.queryParameters, {
      'utm_source': 'elevenward',
      'utm_medium': 'cross-promotion',
      'utm_campaign': 'portfolio-v1',
    });
    expect(links.productDisplayUrl, 'studio.example/elevenward/');
  });

  test(
    'captions preserve the career and add a localized discoverable link',
    () {
      final career = CareerSnapshot.newCareer();
      final before = career.encode();
      for (final locale in ['en', 'es', 'pt-BR', 'fr']) {
        final caption = careerShareText(career, locale: locale, links: links);
        expect(caption, contains(career.player.name));
        expect(caption, contains(career.clubName));
        expect(caption, contains(uiCopy(locale, 'discoverElevenward')));
        expect(caption, contains(links.careerShareUrl.toString()));
      }
      expect(career.encode(), before);
      final offline = careerShareText(
        career,
        locale: 'en',
        links: const StudioMarketingLinks(),
      );
      expect(offline, contains('Elevenward'));
      expect(offline, isNot(contains('https://')));
    },
  );

  testWidgets(
    'card discovery remains visible on a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildElevenwardTheme(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ShareCareerCard(
                    career: CareerSnapshot.newCareer(),
                    styleId: 'classic',
                    avatarId: 'initials',
                    marketingLinks: links,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('studio.example/elevenward/'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(tester.takeException(), isNull, reason: locale.toString());
      }
    },
  );
}
