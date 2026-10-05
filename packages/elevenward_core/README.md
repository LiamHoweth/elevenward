# elevenward_core

Pure-Dart, platform-independent career simulation for Elevenward. The package
owns game state and seeded rules; it has no Flutter or runtime package
dependencies.

The first vertical slice advances one competitive week:

1. Apply the chosen attribute focus and training intensity.
2. Explain the player's starter, bench, or omitted selection.
3. Resolve a risk-based spotlight decision and match if selected.
4. Apply fitness, form, manager trust, reputation, and money changes.
5. Advance the deterministic random state, career revision, week, and season.

Callers provide every external input, including `updatedAt`. The simulator
never reads the clock or platform entropy, so an identical snapshot and input
produce byte-identical canonical JSON on every supported platform. Gameplay also
supplies the catalog pinned by `snapshot.contentVersion`; resolve a durable
`pendingEventId` with `CareerEngine` before advancing again. Role statistics,
bounded journals, goals, mentor flags and loan ownership persist in the snapshot.

```dart
final result = const WeeklySimulator().advance(
  snapshot: snapshot,
  catalog: contentCatalog,
  choice: const WeeklyChoice(
    focus: PlayerAttribute.finishing,
    intensity: TrainingIntensity.balanced,
    spotlightApproach: SpotlightApproach.bold,
  ),
  opponent: const OpponentContext(
    clubId: 'eng-division-2-riverside',
    quality: 62,
    tacticalFit: 74,
    isHome: true,
  ),
  updatedAt: DateTime.utc(2026, 9, 3),
);
```

Run checks with:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```
