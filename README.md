# Elevenward

Elevenward is a portrait-first football career and life RPG for iOS and Android.
This repository contains a playable, local-first pre-alpha: four positions,
12 archetypes, 120 fictional clubs, 12 leagues, scheduled cup competitions,
explicit national-team call-ups, career/life choices, and progression from age
17 through retirement.

## What is playable

1. Choose a persistent weekly attribute focus and a fresh training load.
2. Preview the home-versus-away matchup and review selection status.
3. Resolve a spotlight moment with safe, balanced, or bold intent.
4. Read a compact score, rating, development and income recap.
5. Resolve an occasional compact off-pitch choice between fixtures, then inspect
   completed scores in World.

The interface only previews outcomes. All ratings, odds, seeded randomness,
season progression, and durable state live in the platform-independent
`packages/elevenward_core` Dart package.

## Run it

```sh
flutter pub get
flutter run
```

The bundle identifier/application ID is `com.howethstudio.elevenward`. The app
targets portrait iOS 15.1+ and Android API 26+, compiling and targeting Android
API 37 (required by secure storage) and targeting API 36. Android Gradle Plugin
9.1.1 is required for the API 37 SDK packaging. Release builds require a protected
upload keystore; they never fall back to the debug key.

## Verify it

```sh
flutter analyze
flutter test
(cd packages/elevenward_core && dart analyze && dart test)
```

The core suite verifies deterministic replay, canonical snapshot JSON,
preview/result consistency, meaningful risk differences, weekly progression,
and season rollover.

## Architecture boundary

- `lib/`: Flutter presentation and local flow coordination.
- `packages/elevenward_core/`: pure-Dart domain models, explainable simulation,
  versioned `CareerSnapshot`, and tests.
- `ios/` and `android/`: native mobile runners only; no web client is generated.

SQLite journaling/recovery, optional account/cloud sync, purchase entitlements,
four-language onboarding, opt-in leaderboards, and signed-content loading are
implemented locally. Online/store flows still require production configuration
and sandbox qualification. The website lives at `howethstudio.com/elevenward/`;
the API uses `api.howethstudio.com/v1/elevenward/` within the same studio domain.

The player-initiated Shop supports VIP Starter Pack, 2× Development, 2× Money
and All-Access as permanent non-consumables. See
[gamepass operations](docs/GAMEPASS_OPERATIONS.md) and the
[experience specifications](docs/design/EXPERIENCE_SPEC.md).

The game is not launch-ready. See [the live gap audit](docs/PRODUCT_GAP_AUDIT.md),
[the release runbook](docs/RELEASE_RUNBOOK.md), and
[the threat model](docs/THREAT_MODEL.md) for evidence, partial systems, and
external requirements. Procedural content counts are not editorial approval.

## Production-engine verification

```sh
cd packages/elevenward_core
dart run bin/verify_production_careers.dart --careers 100 --output ../../artifacts/verification/production-smoke.json
```

The separate 100k CI workflow runs 20 non-overlapping 5,000-career shards and
requires an aggregate coverage gate for positions, archetypes, difficulties,
starting leagues, retirement seasons, competition completions, transfer types,
national-team decisions, and promotion/relegation paths. The merger emits a
durable aggregate JSON artifact. The current local
[100,000-career report](artifacts/verification/production-100000.json) passes with
zero failures across 32,178,240 simulated weeks. The release revision still
requires a successful hosted workflow run.

The manual `Signed release artifacts` workflow builds protected Android AAB and
iOS IPA artifacts plus symbol files after environment approval. It requires real
store signing material and production public-client configuration and does not
upload to a store automatically.
