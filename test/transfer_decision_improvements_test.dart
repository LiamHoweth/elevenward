import 'package:elevenward/l10n/app_localizations.dart';
import 'package:elevenward/src/theme.dart';
import 'package:elevenward/src/ui_copy.dart';
import 'package:elevenward/src/widgets/transfer_comparison_panel.dart';
import 'package:elevenward/src/widgets/transfer_request_sheet.dart';
import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final world = buildLaunchWorld();
  final club = world.clubs.first;
  final league = world.leagueForClub(club.id);
  final preferred = world.clubs.firstWhere(
    (candidate) =>
        candidate.id != club.id && league.clubIds.contains(candidate.id),
  );
  final career =
      CareerSnapshot.newCareer(
        clubId: club.id,
        clubName: club.name,
        worldDefinition: world,
      ).copyWith(
        transferRequest: TransferRequest(
          targetLeagueId: league.id,
          preferredClubId: preferred.id,
          filedSeason: 1,
          filedWeek: 1,
        ),
      );

  testWidgets('offer compares exact bonuses and singular/new contract terms', (
    tester,
  ) async {
    final snapshot = career.copyWith(
      contract: career.contract.copyWith(
        seasonsRemaining: 1,
        appearanceBonus: 375,
      ),
    );
    final before = snapshot.encode();
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: TransferComparisonPanel(
            career: snapshot,
            world: world,
            marketState: snapshot.world,
            offer: ContractOffer(
              clubId: preferred.id,
              seasons: 4,
              weeklyWage: 2400,
              appearanceBonus: 950,
              promisedRole: 'important',
              tacticalFit: 76,
              interestReason: 'A concrete offer.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('£375'), findsOneWidget);
    expect(find.text('£950'), findsOneWidget);
    expect(find.text('1 season · remaining'), findsOneWidget);
    expect(find.text('4 seasons · new contract'), findsOneWidget);
    expect(snapshot.encode(), before);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const ['en', 'es', 'pt-BR', 'fr']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'transfer request retains filtered choices and scrolls review in $locale $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          TransferRequestDraft? result;
          final before = career.encode();
          await tester.pumpWidget(
            _app(
              Builder(
                builder: (context) => FilledButton(
                  key: const Key('open-transfer'),
                  onPressed: () async {
                    result = await showTransferRequestFlow(
                      context: context,
                      career: career,
                      world: world,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
              locale: locale,
              brightness: brightness,
              scale: 2,
            ),
          );
          await tester.tap(find.byKey(const Key('open-transfer')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('transfer-request-continue')).hitTestable(),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('transfer-league-search')),
            120,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('transfer-request-league-step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.enterText(
            find.byKey(const Key('transfer-league-search')),
            'zzzzzzzz',
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const Key('transfer-request-no-leagues')),
            120,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('transfer-request-league-step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            find.byKey(const Key('transfer-request-no-leagues')),
            findsOneWidget,
          );
          // The selection survives a filter that hides every destination.
          await tester.tap(find.byKey(const Key('transfer-request-continue')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getSize(find.byKey(const Key('transfer-request-club-step')))
                .height,
            greaterThan(120),
            reason: 'The club list must retain enough space to scroll at 200% text.',
          );
          expect(
            find.byKey(const Key('transfer-request-submit')).hitTestable(),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('transfer-club-search')),
            120,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('transfer-request-club-step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.enterText(
            find.byKey(const Key('transfer-club-search')),
            'zzzzzzzz',
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const Key('transfer-request-no-clubs')),
            120,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('transfer-request-club-step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            find.byKey(const Key('transfer-request-no-clubs')),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('transfer-request-selected-club')),
            -120,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('transfer-request-club-step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const Key('transfer-request-selected-club')),
                )
                .data,
            contains(preferred.name),
          );

          // A compact landscape of available space while the native keyboard is
          // present must retain a scrollable search and a dismiss action.
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          expect(
            find.byIcon(Icons.keyboard_hide_rounded).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.keyboard_hide_rounded));
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('transfer-request-submit')));
          await tester.pumpAndSettle();
          expect(
            tester.widget<AlertDialog>(find.byType(AlertDialog)).scrollable,
            isTrue,
          );
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.textContaining(
                uiCopy(locale, 'transferTrustWarning'),
              ),
            ),
            findsOneWidget,
          );
          final cancel = MaterialLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          ).cancelButtonLabel;
          await tester.tap(find.widgetWithText(TextButton, cancel));
          await tester.pumpAndSettle();
          expect(result, isNull);
          await tester.scrollUntilVisible(
            find.byKey(const Key('transfer-request-selected-club')),
            -120,
            scrollable: find
                .descendant(
                  of: find.byKey(const Key('transfer-request-club-step')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const Key('transfer-request-selected-club')),
                )
                .data,
            contains(preferred.name),
          );
          await tester.tap(find.byKey(const Key('transfer-request-submit')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('transfer-request-confirm')));
          await tester.pumpAndSettle();
          expect(result?.targetLeagueId, league.id);
          expect(result?.preferredClubId, preferred.id);
          expect(career.encode(), before);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Widget _app(
  Widget child, {
  String locale = 'en',
  Brightness brightness = Brightness.dark,
  double scale = 1,
}) {
  ElevenwardColors.use(brightness);
  return MaterialApp(
    theme: buildElevenwardTheme('graphite', brightness),
    locale: locale == 'pt-BR' ? const Locale('pt', 'BR') : Locale(locale),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}
