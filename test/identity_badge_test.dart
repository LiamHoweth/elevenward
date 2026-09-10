import 'package:elevenward/src/widgets/identity_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all saved avatar IDs render as code-native identity badges', (
    tester,
  ) async {
    const avatarIds = ['initials', 'captain', 'creator', 'finisher'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (final avatarId in avatarIds)
                PlayerIdentityBadge(
                  playerName: 'Mika Vale',
                  avatarId: avatarId,
                ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(PlayerIdentityBadge), findsNWidgets(4));
    expect(find.text('MV'), findsNWidgets(4));
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('Mika Vale'), findsNWidgets(4));
  });
}
