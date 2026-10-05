# Gameplay improvement loop — October 1, 2026

The requested improvement window ran from 7:33:55 to 8:03:55 p.m. America/Chicago (00:33:55–01:03:55 UTC), using the integration owner plus 19 delegated agents. Follow-up work is limited to validation, fixing introduced failures, visual inspection, and documenting evidence.

The baseline contained 154 source/test/tool files and a substantial dirty tree. No baseline file was removed. Published simulation formulas, core production source, career schemas, content pins, stable portrait identities, and the existing account-consent model were preserved. No deployment, store upload, phone install, or Git publication is part of this batch.

## Delivered behavior

| Area | Improvement |
| --- | --- |
| Weekly flow | Stale save completions/retry actions cannot unlock a newer decision. Saving has visible feedback. Focus publishes after persistence; failed saves retain the previous choice. |
| Reviewed mutations | Career identity, revision and generation guards are checked atomically inside the existing controller queue. Life and weekly-flow saves use them. |
| Training | Expandable comparison of exact light/balanced/intense previews, with explicit selection, projected partial progress, and cap/pause handling. Matched favorite controls become a compact status. |
| Match recap | Shows the recorded approach, original odds, actual outcome and influential preview factors. Omitted players receive selection context. English cup reports do not claim league points. |
| Retirement | Mandatory final careers show an explicit final-season wrap-up and Finish career action instead of transfers/loans/stay that the engine would ignore. |
| Progression | Presentation targets and recap milestones share thresholds and keep advancing in long careers; remaining progress is localized and accessible. Saved ambitions stay separate. |
| Player | Responsive identity and attribute layouts, labeled Overall, visible metric denominators, and unavailable ratings before rated appearances. Fabricated jersey number removed. |
| Life | Full readable market details, localized rarity, visible balance/affordability, and scrollable purchase reviews using exact capped core effects and equipment disclosure. Duplicate and stale actions are guarded. |
| Transfers | Exact appearance-bonus and contract-length comparisons; retained search preferences, clear/empty recovery, keyboard handling, and readable confirmations. |
| Career hub | Visible slot numbers, truthful saved phase/next opponent context, concrete deletion identity, and stacked conflict actions on narrow layouts. |
| Creator | Searches reveal matching nationalities, provide clear/empty feedback, preserve review-cancel/back behavior, show step progress, and retain choices after failed creation. |
| Journal | Season filters and entry counts; useful empty-filter recovery; complete decision narratives with recorded effects and an explicit no-stat-change state. Journal order stays intact. |
| World | Current-league shortcut follows actual membership after promotion; normalized translated search, filter recovery, scrollable help, wrapping rankings/standings and spoken summaries. |
| Map | Seam-aware country focus for distant date-line islands, bounded camera transforms, markers anchored on land, and truthful map accessibility semantics. |
| Challenge | Exact provisional replay score, restored saved plan, next-match numbering, labeled result/club context, training preview, expandable rules, and large-text dropdowns. |
| Hall | Clear legacy score/portrait hierarchy, labeled totals/trophies, readable season records, and archive-specific deletion reviews with duplicate protection. |
| Learning | Localized weekly overview and expandable training, decisions, off-pitch, contracts, World and glossary guidance. |

Presentation uses existing Flutter widgets, palettes, localized copy patterns, SQLite preferences, and the platform-independent core. No new paid service or dependency was added. Root owns the combined build/test result; scoped agent passes are supporting evidence.

## Verification and visual evidence

Evidence lives in `artifacts/verification/gameplay-loop-2026-10-01/`. The baseline/final manifests distinguish this batch from pre-existing edits. `verification-summary.json` contains final check results; logs provide the exact test/build output.

The initial parallel Flutter test runs collided in shared native-asset output. Testing was centralized into one full-suite invocation, followed by focused reruns when failures justified them. The first full run also encountered 30-second timeouts under severe machine contention; those are reported separately from assertion failures.

The native Simulator capture attempt failed before compilation/install with missing Xcode build settings. Its manifest records zero captures and refuses a stale binary. The dedicated Simulator was shut down and deleted; unrelated Simulators and other projects were preserved. The new native harness remains available for a later run.

Final-widget raster evidence uses actual production widgets with an isolated in-memory database and blocked HTTP. It is clearly identified as Flutter widget rendering, not Simulator or physical-device evidence. The renderer loads the host's system font for readable images and is opt-in. Earlier polish screenshots only establish the prior interface.

All 16 final images were inspected: eight English dark 390×844 surfaces at 100% text and eight French light 320×568 surfaces at 200% text. They cover Career, training comparison, Player, attributes, Life, purchase review, creator, and Hall. This raster matrix does not cover World, journal, challenge, selection, or post-match recap. See `widget-ui/visual-review.md` for corrected findings and `widget-ui/widget-capture-manifest.json` for image and source hashes.

Final verification completed after the improvement window:

| Check | Result |
| --- | --- |
| Flutter and core analysis | Passed, no issues. |
| Core suite | 101 passed; two independent 36-career verifier runs produced matching checksums. |
| App cases | 457 unique cases passed across the final full run and focused corrective rerun. The full run had 452 passes, five visual-fixture failures and one intentional skip; all 14 cases in the two corrected test files then passed. |
| Opt-in widget raster test | Passed; all 16 final images inspected and image/source hashes matched. |
| iOS release build | Passed from the frozen production source; unsigned `Runner.app`, 58.9 MB, version 1.1.0 build 5. |
| Native capture | Failed during Xcode build-setting discovery; zero screenshots, no install or launch. |
| Source/whitespace | No missing baseline files, no core production changes, no production drift during final checks; `git diff --check` passed. |

The final five full-run failures were test-fixture expectations: fractional glyph bounds exceeded the rounded paragraph height by 0.125 logical pixels, and the dummy monospaced font could not fit a French word that fits the actual system font. The corrective tests retain single-line score checks, complete text, full-width natural wrapping, visible price and reachable actions. The passing actual-font raster test retains its whole-word assertions. Production source was unchanged during these corrections. The entire suite was not repeated after these test-only corrections; the focused run covers both corrected files completely.

The opt-in raster test is intentionally skipped by the ordinary app suite and passed separately. Earlier failed/interrupted runs remain in the evidence logs. Do not infer release readiness or native/device acceptance from analysis, widget tests, widget images, or an unsigned build.

## Remaining opportunities

- Measure whether moving recent performance below weekly training choices reduces scroll friction.
- Complete the native locale/size/accessibility matrix, including public leaderboard layouts.
- Review new-rule experiments separately: persistent injuries, meaningful minutes for clean sheets, and squad competition/promised-role selection. These require versioned formulas and balance evidence.
- Preserve pending account consent if adding clearer leaderboard preference failure handling.

## Reproduce

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=4 --timeout=2m --reporter expanded
flutter test --no-pub --concurrency=2 --timeout=2m test/player_detail_clarity_test.dart test/life_screen_test.dart --reporter expanded
(cd packages/elevenward_core && dart analyze && dart test)
flutter test --no-pub --dart-define=GAMEPLAY_WIDGET_CAPTURE=true test/gameplay_loop_visual_test.dart --reporter expanded
python3 tool/capture_gameplay_loop.py --device-id <dedicated-simulator-uuid> --output-root artifacts/verification/gameplay-loop-2026-10-01/ui
flutter build ios --release --no-pub --no-codesign
```
