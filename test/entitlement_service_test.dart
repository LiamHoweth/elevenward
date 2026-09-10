import 'package:flutter_test/flutter_test.dart';
import 'package:elevenward/src/services/entitlement_service.dart';
import 'package:elevenward_core/elevenward_core.dart';

void main() {
  test('gamepass product mapping matches permanent storefront products', () {
    expect(gamePassDefinitions.map((item) => item.productId), [
      'com.howethstudio.elevenward.all_access',
      'com.howethstudio.elevenward.vip',
      'com.howethstudio.elevenward.double_development',
      'com.howethstudio.elevenward.double_money',
    ]);
  });

  test('VIP and focused passes stack to exact 3x rewards', () {
    const state = EntitlementState(
      ownedPasses: {
        GamePassId.vip,
        GamePassId.doubleDevelopment,
        GamePassId.doubleMoney,
      },
    );
    expect(state.rewardModifiers.developmentMultiplier, 3);
    expect(state.rewardModifiers.moneyMultiplier, 3);
    expect(state.careerSlotLimit, 5);
    expect(state.premiumCosmetics, isTrue);
  });

  test('VIP and 2x development produce 3x training in gameplay', () {
    const state = EntitlementState(
      ownedPasses: {GamePassId.vip, GamePassId.doubleDevelopment},
    );
    final result = const WeeklySimulator().advance(
      snapshot: CareerSnapshot.newCareer(seed: 51),
      choice: const WeeklyChoice(
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.balanced,
        spotlightApproach: SpotlightApproach.balanced,
      ),
      opponent: const OpponentContext(
        clubId: 'eng2-harbour',
        clubName: 'Harbour Rovers',
        quality: 64,
        tacticalFit: 72,
        isHome: true,
      ),
      updatedAt: DateTime.utc(2026, 9, 10),
      modifiers: state.rewardModifiers,
    );

    expect(state.rewardModifiers.developmentMultiplier, 3);
    expect(state.rewardModifiers.moneyMultiplier, 1.5);
    expect(result.developmentMultiplier, 3);
    expect(result.developmentGain, 3);
    expect(result.developmentRemainder, 0);
    expect(
      result.snapshot.boostIdsUsed,
      containsAll(['vip', 'doubleDevelopment']),
    );
  });

  test('every current entitlement combination resolves deterministically', () {
    for (var mask = 0; mask < 16; mask++) {
      final owned = <GamePassId>{
        for (var index = 0; index < GamePassId.values.length; index++)
          if (mask & (1 << index) != 0) GamePassId.values[index],
      };
      final state = EntitlementState(ownedPasses: owned);
      final allAccess = owned.contains(GamePassId.allAccess);
      final vip = allAccess || owned.contains(GamePassId.vip);
      final development =
          allAccess || owned.contains(GamePassId.doubleDevelopment);
      final money = allAccess || owned.contains(GamePassId.doubleMoney);
      expect(
        state.rewardModifiers.developmentMultiplier,
        (vip ? 1.5 : 1) * (development ? 2 : 1),
        reason: 'mask $mask development',
      );
      expect(
        state.rewardModifiers.moneyMultiplier,
        (vip ? 1.5 : 1) * (money ? 2 : 1),
        reason: 'mask $mask money',
      );
      expect(state.careerSlotLimit, vip ? 5 : 2, reason: 'mask $mask slots');
      expect(state.premiumCosmetics, vip, reason: 'mask $mask cosmetics');
    }
  });

  test('All-Access resolves every benefit without double counting', () {
    const state = EntitlementState(
      ownedPasses: {GamePassId.allAccess, GamePassId.vip},
    );
    expect(state.rewardModifiers.developmentMultiplier, 3);
    expect(state.rewardModifiers.moneyMultiplier, 3);
    expect(state.rewardModifiers.sourceIds, ['allAccess']);
    expect(state.ownsBenefit(GamePassId.doubleDevelopment), isTrue);
    expect(state.ownsBenefit(GamePassId.doubleMoney), isTrue);
    expect(state.careerSlotLimit, 5);
    expect(state.premiumCosmetics, isTrue);
  });

  test('legacy owners keep only their original benefits', () {
    const slots = EntitlementState(legacyExtraCareerSlots: true);
    expect(slots.careerSlotLimit, 5);
    expect(slots.rewardModifiers.developmentMultiplier, 1);
    expect(slots.rewardModifiers.moneyMultiplier, 1);
    expect(slots.premiumCosmetics, isFalse);

    const supporter = EntitlementState(legacySupporterPack: true);
    expect(supporter.careerSlotLimit, 2);
    expect(supporter.premiumCosmetics, isTrue);
    expect(supporter.rewardModifiers.developmentMultiplier, 1);
    expect(supporter.rewardModifiers.moneyMultiplier, 1);
  });

  test('cached legacy entitlement JSON migrates without granting boosts', () {
    final state = EntitlementState.fromJson(const {
      'extraCareerSlots': true,
      'supporterPack': true,
    });
    expect(state.careerSlotLimit, 5);
    expect(state.premiumCosmetics, isTrue);
    expect(state.ownedPasses, isEmpty);
    expect(state.rewardModifiers.developmentMultiplier, 1);
    expect(state.rewardModifiers.moneyMultiplier, 1);
  });

  test('reference prices remain configuration expectations only', () {
    expect(
      {for (final item in gamePassDefinitions) item.id: item.referencePriceUsd},
      {
        GamePassId.vip: 4.99,
        GamePassId.doubleDevelopment: 3.99,
        GamePassId.doubleMoney: 3.99,
        GamePassId.allAccess: 9.99,
      },
    );
  });
}
