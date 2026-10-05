import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const simulator = WeeklySimulator();
  test('preview equals committed training across loads, caps and bonuses', () {
    final world = buildLaunchWorld();
    for (final multiplier in [1.0, 1.5, 2.0, 3.0]) {
      for (final intensity in TrainingIntensity.values) {
        for (final rating in [50, 98, 99]) {
          final base = CareerSnapshot.newCareer(worldDefinition: world);
          final attributes = {
            for (final a in PlayerAttribute.values)
              a: base.player.attributes[a],
            PlayerAttribute.finishing: rating
          };
          final snapshot = base.copyWith(
            player: base.player.copyWith(
                attributes: PlayerAttributes(attributes), fitness: 98),
            developmentProgress: {PlayerAttribute.finishing: .5},
          );
          final original = snapshot.encode();
          final modifiers = RewardModifiers(developmentMultiplier: multiplier);
          final preview = simulator.previewTraining(
              snapshot: snapshot,
              focus: PlayerAttribute.finishing,
              intensity: intensity,
              modifiers: modifiers);
          final result = simulator.advance(
              snapshot: snapshot,
              choice: WeeklyChoice(
                  focus: PlayerAttribute.finishing,
                  intensity: intensity,
                  spotlightApproach: SpotlightApproach.safe),
              opponent: const WorldSimulator()
                  .opponentFor(snapshot, definition: world),
              updatedAt: DateTime.utc(2026, 9, 30),
              modifiers: modifiers,
              definition: world);
          expect(preview.gain, result.developmentGain);
          expect(preview.attributeAfter,
              result.snapshot.player.attributes[PlayerAttribute.finishing]);
          expect(preview.remainder, result.developmentRemainder);
          expect(preview.fitnessAfter, inInclusiveRange(1, 100));
          expect(snapshot.encode(), original,
              reason: 'A preview must be read-only.');
        }
      }
    }
  });
  test(
      'international postseason pauses training and preserves fractional progress',
      () {
    final base = CareerSnapshot.newCareer().copyWith(
        phase: CareerPhase.internationalTournament,
        developmentProgress: {PlayerAttribute.finishing: .5});
    final preview = simulator.previewTraining(
        snapshot: base,
        focus: PlayerAttribute.finishing,
        intensity: TrainingIntensity.intensive,
        modifiers: const RewardModifiers(developmentMultiplier: 3));
    expect(preview.paused, isTrue);
    expect(preview.gain, 0);
    expect(preview.fitnessChange, 0);
    expect(preview.remainder, .5);
  });
  test('every archetype has a role-relevant initial suggestion', () {
    for (final role in Archetype.values) {
      expect(PlayerAttribute.values, contains(recommendedTrainingFocus(role)));
    }
    expect(
        recommendedTrainingFocus(Archetype.stopper), PlayerAttribute.defending);
    expect(
        recommendedTrainingFocus(Archetype.playmaker), PlayerAttribute.passing);
    expect(recommendedTrainingFocus(Archetype.ballPlayingCentreBack),
        PlayerAttribute.passing);
  });
}
