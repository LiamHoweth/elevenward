# Engagement improvements and release evidence

Updated 2026-09-30. The twelve requested improvements are implemented. Local
engineering checks pass; production distribution is still blocked by the
configuration and acceptance gates below. Engagement uplift has not been
measured in a released cohort.

## Delivered scope

| Improvement | Implemented behavior |
| --- | --- |
| Role-aware starting focus | All twelve archetypes receive a relevant initial training focus. Existing saved choices are preserved. |
| Continue career | A prominent resume card uses the last opened stable career ID, with the newest readable career as fallback. Deleted and unreadable slots are excluded. |
| Accurate training preview | Attribute, fitness, fractional development, bonuses, caps, and international training pauses use the same calculation as weekly advancement. |
| Personal match recap | Selection, goals, assists, fitness/form changes, and attribute before/after values come from the saved result. |
| Match stakes | Competition/stage, opponent table rank, and second-division promotion context come from the pinned career world. |
| Selection explanation | The actual selection score, starter/bench thresholds, and strongest contributing factors replace the misleading probability label. |
| Beginner guidance | Contextual first-match tips can be dismissed; Settings includes a localized How to Play page. |
| Milestones | Appearance, goal, assist, cap, and trophy thresholds appear inline when crossed. National trophies require recorded participation; completed league titles are included. |
| Optional personal target | A role-based target uses existing career totals, with no rewards, expiry, or save-schema changes. |
| Localized feedback | New call-up, recap, match-report, news, and stat-label presentation supports English, Spanish, Brazilian Portuguese, and French. Historical saved prose is preserved. |
| Quick transitions | A persisted preference skips the match introduction. Reduced motion also skips it; explicit choices and recaps remain. |
| Season comparisons and sharing | Season summaries/archive entries compare goals, assists, rating, and trophies with the previous season; the existing share card is available nearby. |

Training previews are exposed by `WeeklySimulator.previewTraining`. Read-only
engagement and localization projections live in `lib/src/career_engagement.dart`
and `lib/src/match_feedback.dart`; reusable presentation lives in
`widgets/career_progress_panel.dart`. Preferences use the existing store and
controller. No new backend service, reward economy, timer, notification, or
analytics consent change was introduced.

GameScreen now saves match, career-event, call-up, transfer-request, and offseason
decisions before publishing their resulting state. A failed match save retains
the selected choice and offers Retry. The regression test injects a failure and
checks that no recap is published before the retry succeeds.

## Verified evidence

Evidence is in `artifacts/verification/engagement-2026-09-30/`.

| Check | Result and limits |
| --- | --- |
| Flutter analysis | No issues. |
| Flutter suite | 119 tests passed, including four-language resume, match/help, tournament, and season-summary flows at 320×568 and 200% text. |
| Core analysis and suite | No issues; 86 tests passed. Training-preview tests cover all loads, caps, fractions, and development multipliers. |
| Fresh complete careers | 1,000 actual-engine careers, 329,070 weeks, all 52 leagues, all archetypes/difficulties/reward profiles; no failures. `production-1000.json` is current-source evidence. |
| Historical 100k gate | The 20 real hosted shards from GitHub run 36412851585 were remerged successfully: 100,000 careers and 32,910,032 weeks. This is historical September 28 evidence, not a fresh run of the final checkout. |
| Native iOS flow | 32 acknowledged native Simulator screenshots across four languages; explicit choice, commit, SQLite save/reload, recap continuation, help, settings, resume, and season comparison exercised in a disposable QA database. |
| Visual review | Representative native captures reviewed for readable controls, preview/selection/recap content, resume hierarchy, and localized help/settings/season presentation. This does not establish physical-device accessibility or native-language editorial acceptance. |
| iOS release | App Store archive and IPA exported as `com.howethstudio.elevenward`, 1.0.0 build 5, iOS 15.1 minimum. Package signature/profile evidence is in `ios-package.json`. |
| Android compile | Debug APK builds successfully. Store AAB stops at the existing release-signing guard because the upload keystore configuration is absent. |
| Static release assets | Existing asset and signing guards pass. |

The hosted aggregate originally failed because its merger expected twelve
leagues while the shipped world contains 52. The gate now derives the expected
count and IDs from `buildLaunchWorld()`, rejects unknown/missing IDs, and retains
the contiguous-shard, completed-career, minimum-count, failure, and other coverage
checks. Three metadata-fixture regression tests cover this correction; those
fixtures are not playthrough evidence. The aggregate CI job now restores the
core package dependencies before running the merger.

Native screenshots are captured with an acknowledgement handshake in
`tool/capture_engagement.py`: the game waits until simctl has completed each
image before advancing. Capture filenames therefore correspond to the shown
screens. Fixtures are QA examples, not App Store promotional screenshots.

The checkout already contained substantial uncommitted creator, portrait,
branding, leaderboard, and other work. Those changes were preserved and are
included by local builds. `source-manifest.json` records the baseline HEAD,
task-source hashes, and build-input hashes. No release commit, push, PR, store
upload, or physical-device installation is implied by these local results.

## Remaining production gates

1. Supply the existing protected Android upload keystore and
   `android/key.properties`, plus the Android RevenueCat public SDK key. The
   local release build failed specifically at `:app:checkReleaseSigning`.
2. Supply the trusted remote-content Ed25519 public verification key through the
   existing build configuration. It is absent from the current production
   defines; bundled offline play remains available, but verified remote-content
   updates cannot be exercised without it. Do not generate a replacement trust
   key or bypass signature checks to satisfy this gate.
3. Review and commit the intended release baseline, then run CI and the hosted
   100k workflow on that exact revision. The repository currently has no GitHub
   Actions repository secrets configured; protected release-workflow settings
   also need the release owner's existing configuration.
4. Complete the existing store/provider sandbox matrix and physical-device
   acceptance: purchases/restores/refunds, sign-in/account switching, sync,
   VoiceOver/TalkBack, offline restart, and device golden parity. Automated
   mocks and Simulator play do not establish these results.
5. Record the existing native-copy, legal/editorial, beta, support, and store
   acceptance gates in `RELEASE_RUNBOOK.md` and `PRODUCT_GAP_AUDIT.md` before
   production distribution. The exported IPA has not been uploaded or approved.

## Reproduce the scoped checks

```sh
flutter analyze --no-pub
flutter test --no-pub
(cd packages/elevenward_core && dart analyze && dart test)
python3 tool/capture_engagement.py --device-id <dedicated-simulator-uuid> \
  --output-root artifacts/verification/engagement-2026-09-30/ui
flutter build ipa --release --no-pub \
  --dart-define-from-file=config/production.json --build-number=5 \
  --export-options-plist=ios/ExportOptions.plist
```

Use the existing release runbook for protected configuration and the full 100k
workflow. Keep screenshots, logs, simulation reports, package hashes, and source
hashes together when reviewing a release candidate.
