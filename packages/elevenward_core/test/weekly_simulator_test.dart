import 'package:elevenward_core/elevenward_core.dart';
import 'package:test/test.dart';

void main() {
  const simulator = WeeklySimulator();
  const opponent = OpponentContext(
    clubId: 'eng2-harbour',
    clubName: 'Harbour Rovers',
    quality: 64,
    tacticalFit: 72,
    isHome: true,
  );
  const choice = WeeklyChoice(
    focus: PlayerAttribute.finishing,
    intensity: TrainingIntensity.balanced,
    spotlightApproach: SpotlightApproach.balanced,
  );
  final updatedAt = DateTime.utc(2026, 9, 10);

  test('same snapshot and inputs produce byte-identical durable state', () {
    final snapshot = CareerSnapshot.newCareer(seed: 44221);
    final first = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    final second = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );

    expect(first.snapshot.encode(), second.snapshot.encode());
    expect(first.roll, second.roll);
    expect(first.spotlightSucceeded, second.spotlightSucceeded);
    expect(first.homeScore, second.homeScore);
    expect(first.awayScore, second.awayScore);
  });

  test('snapshot JSON round-trips without changing canonical output', () {
    final snapshot = CareerSnapshot.newCareer(seed: 9);
    final decoded = CareerSnapshot.decode(snapshot.encode());
    expect(decoded.encode(), snapshot.encode());
  });

  test('preview and receipt use the same success threshold', () {
    final snapshot = CareerSnapshot.newCareer(seed: 721);
    final preview = simulator.previewSpotlight(
      snapshot: snapshot,
      focus: choice.focus,
      intensity: choice.intensity,
      approach: choice.spotlightApproach,
      opponent: opponent,
    );
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    expect(result.preview.chance, preview.chance);
    expect(result.spotlightSucceeded, result.roll < preview.chance);
  });

  test('risk choices materially change preview odds', () {
    final snapshot = CareerSnapshot.newCareer();
    final safe = simulator.previewSpotlight(
      snapshot: snapshot,
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.balanced,
      approach: SpotlightApproach.safe,
      opponent: opponent,
    );
    final bold = simulator.previewSpotlight(
      snapshot: snapshot,
      focus: PlayerAttribute.finishing,
      intensity: TrainingIntensity.balanced,
      approach: SpotlightApproach.bold,
      opponent: opponent,
    );
    expect(safe.chance - bold.chance, greaterThanOrEqualTo(15));
  });

  test('weekly advance trains focus and moves the career forward', () {
    final snapshot = CareerSnapshot.newCareer();
    final before = snapshot.player.attributes[PlayerAttribute.finishing];
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    expect(
      result.snapshot.player.attributes[PlayerAttribute.finishing],
      before + 1,
    );
    expect(result.snapshot.week, 2);
    expect(result.snapshot.revision, 1);
    expect(result.factors, isNotEmpty);
  });

  test('week 18 enters an explicit offseason without skipping decisions', () {
    final initial = CareerSnapshot.newCareer();
    final snapshot = initial.copyWith(
      revision: 17,
      week: 18,
      points: 30,
    );
    final result = simulator.advance(
      snapshot: snapshot,
      choice: choice,
      opponent: opponent,
      updatedAt: updatedAt,
    );
    expect(result.snapshot.week, 18);
    expect(result.snapshot.season, 1);
    expect(result.snapshot.player.age, 17);
    expect(result.snapshot.phase, CareerPhase.offseason);
  });

  test('500 seeded seasons all advance without an invalid state', () {
    for (var seed = 1; seed <= 500; seed++) {
      var snapshot = CareerSnapshot.newCareer(seed: seed);
      for (var week = 1; week <= 18; week++) {
        final approach = SpotlightApproach.values[(seed + week) % 3];
        final result = simulator.advance(
          snapshot: snapshot,
          choice: WeeklyChoice(
            focus: PlayerAttribute.values[(seed + week) % 8],
            intensity: TrainingIntensity.values[(seed + week) % 3],
            spotlightApproach: approach,
          ),
          opponent: opponent,
          updatedAt: updatedAt.add(Duration(days: week * 7)),
        );
        snapshot = result.snapshot;
        expect(snapshot.player.fitness, inInclusiveRange(1, 100));
        expect(snapshot.player.managerTrust, inInclusiveRange(1, 100));
        expect(result.preview.chance, inInclusiveRange(15, 90));
      }
      expect(snapshot.season, 1);
      expect(snapshot.week, 18);
      expect(snapshot.phase, CareerPhase.offseason);
      expect(snapshot.revision, 18);
    }
  });
}
