# Elevenward product gap audit

Audited 2026-09-05 against the original Elevenward brief, the Flutter game,
the `howethstudio.com` Next.js project, the isolated Elevenward API surface, and
the local verification evidence.

Checked items mean implemented and verified in local source. They do **not** mean
deployed, legally approved, store-approved, or tested with production accounts.
Operational steps and accountable roles are in
[RELEASE_RUNBOOK.md](RELEASE_RUNBOOK.md); rules compatibility is in
[RULES_VERSIONING.md](RULES_VERSIONING.md), and the abuse-case baseline is in
[THREAT_MODEL.md](THREAT_MODEL.md).

## Bottom line

The main product systems requested by the original brief now exist in local code:
the complete offline career loop, 120-club world, persisted domestic and
international competitions, explicit national-team decisions, contracts and
free-agency safety, cross-system relationships/sponsors/lifestyle effects,
versioned saves, conflict-preserving cloud sync, purchases/entitlements,
leaderboards, signed content, privacy-safe analytics/error categories, the
localized website, and staff operations.

Elevenward is still **not ready for public release**. What remains is concentrated
in four areas that source code alone cannot honestly complete: production
deployment and credentials, professional editorial/art/legal review, physical
device and store-sandbox qualification, and hosted verification on the exact
release revision.

## Canonical domain and repository boundary

- Public product, support, privacy, deletion and press pages:
  `https://howethstudio.com/elevenward/` with `es/`, `pt-br/`, and `fr/` variants.
- Staff page: `https://howethstudio.com/elevenward/admin/`.
- App/API/content namespace: `https://api.howethstudio.com/v1/elevenward/`.
- The API subdomain is part of the same `howethstudio.com` domain but is a
  separate HTTP origin. CORS and credentials must continue to treat it that way.
- The existing Howeth Studio site remains the apex site. Elevenward is one product
  section; it does not replace sibling products or create a competing domain.

## Current verification evidence

| Surface | Local result |
| --- | --- |
| Flutter analysis | Clean |
| Flutter tests | 84 passed, including exact content pins, recovery isolation, transfer-request flows, all entitlement combinations, Shop states, localization, match recap and portrait viewport coverage |
| Pure-Dart core analysis | Clean |
| Pure-Dart core tests | 79 passed, including schema-12 migration, transfer-request validation/prioritization/clearing, and unchanged no-request offer ordering |
| Elevenward/Football Era API tests | 40 passed, including exact product mapping and bounded boosted-leaderboard evidence |
| Site and API dependency audits | 0 reported vulnerabilities |
| Howeth Studio website | ESLint clean; Next.js static production build generated 41 routes, including same-domain sitemap and robots metadata |
| Website visual smoke | Localized press routes render with landmarks, skip links, localized navigation and all downloads—including original launch artwork—exposed to accessibility APIs |
| Content bundle | `2026.2.0`, executable rules `2026.3`; 120 clubs, 24 national teams, 160 situations, 200 events, 120 lifestyle items; API fixture regeneration remains an external-repository release step |
| Static release guards | Android/iOS release assets, non-debug Android signing configuration, content bundle and iOS export options pass |
| Native smoke builds | Android debug APK and unsigned iOS device app passed locally; signed artifacts still require protected credentials |
| Production-engine simulation | Existing [100,000-career aggregate](../artifacts/verification/production-100000.json): 32,178,240 weeks across 20 real-engine shards and zero failures. A new 100-career smoke passed 28,800 weeks with 25 careers each under standard, VIP, focused-double and All-Access profiles (`cf5b0f6c`); the updated hosted 100k profile-aware gate remains outstanding. |
| Production routes, checked 2026-09-05 | Product page, privacy page and API health endpoint still return HTTP 404; local work is not deployed |

The same scheduled workflow runs 5,000 real careers per shard and refuses the
release gate unless all 100,000 careers, reward profiles and coverage dimensions
merge cleanly. The pre-gamepass 100k artifact remains historical evidence; rerun
all shards with the new four-profile gate. The game repository still has no
configured remote, so a hosted run on an intentional, pushed release revision
remains outstanding; local evidence is not substituted for that
supply-chain/reproducibility gate.

## Original brief coverage

| Brief area | Current local state | Remaining acceptance gap |
| --- | --- | --- |
| Distinct Football Era sibling | Standalone Flutter/pure-Dart product, original fictional data and separate Elevenward site/API namespaces | Formal owned-IP inventory plus golden behavior comparisons against the supplied Football Era baseline |
| Age 17 through retirement, maximum 20 seasons, legacy verdict | Implemented | Balance, native-copy and full-career device review |
| Four positions, 12 archetypes, eight explainable attributes | Implemented | 100k balance certification and richer archetype tuning |
| Weekly focus → pregame matchup → spotlight → optional life event → next week | Implemented and persisted; completed scores remain in World | Physical-device UX/performance qualification |
| Explainable outcomes | Selection and localized odds factors are previewed before commitment; seeded result details remain deterministic in the engine | Production proof that every displayed reason stays aligned after future balance changes |
| Six countries, two divisions, promotion/relegation and schedules | 120 original clubs, 12 leagues, double round robins and two-up/two-down | Final club identity/art/editorial review |
| Domestic cups | Persisted rounds, fixtures, results, player participation, extra-time/penalty decisions, knockout bracket and permanent honors history | Native-language editorial review and physical-device QA |
| International club competition | Dynamic qualification, groups, knockouts, persisted results, qualification rules, tie-break explanation and bracket UI | Native-language editorial review and physical-device QA |
| National teams and four-year tournament | 24 teams, explicit accept/decline call-up state, caps/goals/assists, eligibility, persisted matches and tournament | Balance, native-copy and physical-device review; full squad management was not required by the brief |
| Relationships and off-pitch systems | Manager, teammates, agent, sponsors, press, family, reputation, wellness and community affect weekly outcomes | More authored multi-season arcs and balance review |
| Lifestyle | Ownership/equipment, category cooldowns, ongoing category effects and visible cosmetic previews | Final item art and long-career economy review |
| Contracts and transfers | Expiry, renewal, role satisfaction, bounded negotiation, reasons, guaranteed free-agency fallbacks, and player-requested next-offseason moves by league/optional club | Balance/native-copy review; loans, midseason moves, and a formal transfer window were not required by the brief |
| Monetization constraints | Four permanent passes, exact 1.5×/2×/3× development and positive-income profiles, five-slot/cosmetic benefits, localized storefront prices, no random rewards | Real products, store configuration and sandbox qualification |
| Offline plus optional account/cloud | SQLite snapshot+journal, secure token storage, explicit progress, remote-only download and conflict preservation | Production providers/API and multi-device/outage drills |
| Prize-free leaderboards | Opt-in, generated aliases, plausibility checks and partitions by position/difficulty/rules | Production abuse monitoring and integrity review |
| Signed remote content | Immutable bundles, validation, Ed25519 checks, exact career-version pins, retained verified releases, client/rules compatibility, cache revalidation, publish and rollback | Production keys/bucket and an observed rollback drill |
| Analytics and error reporting | Explicit consent, bounded retry queue, server allowlist and message/stack/token-free error taxonomy | Production delivery/retention dashboard and privacy approval |
| Four-language website | Marketing, support, privacy, deletion, press downloads and admin are implemented in the existing site | Deployment plus native/legal review and approved screenshots |
| Staff content portal | Validate, preview, stage, publish, rollback, service pulse and staff-action history | Production identity/authorization and release drill |
| Signed releases | Protected manual AAB/IPA workflow, symbols and preflight checks | Supply credentials, run successfully, inspect and upload artifacts |

## Implemented gap closures

### Game and simulation

- [x] Persist competition participants, fixtures, stages, results and winners.
- [x] Simulate domestic cups and the 12-club international competition through
  real world state instead of selecting a winner from a threshold.
- [x] Record regulation, extra-time and penalty decisions for knockout fixtures.
- [x] Add a durable national-team call-up offer with accept/decline, caps, goals,
  assists, season state and tournament eligibility.
- [x] Make manager and teammate relationships affect selection and team results;
  make agent/community relationships affect transfer interest; make family and
  lifestyle choices affect recovery and reputation.
- [x] Model sponsor duration, installments, payouts, expiration/termination and
  persist their effects without interrupting the weekly flow.
- [x] Add persistent lifestyle equipment with category-specific ongoing effects.
- [x] Guarantee safe one-year second-division free-agent offers when a career has
  no renewal or standard interest, preventing an offseason dead end.
- [x] Add a durable player-directed transfer request with a once-per-season
  manager-trust consequence, projected post-promotion league targeting,
  preferred-club prioritization, rejection feedback, and offseason clearing.
- [x] Run and strictly merge 100,000 seeded full careers through the production
  engine with zero failures across 32,178,240 weeks and every required coverage
  dimension. Hosted repetition on the exact release revision remains a release
  operation, not an unimplemented game feature.
- [x] Version the changed formulas as rules `2026.2` and align new saves, the
  bundled content, remote-content checks and the API release fixture.
- [x] Preserve the old `2026.1` formula path for existing careers during the
  compatibility period.
- [x] Add rules `2026.3` and schema 10 with fractional development carry,
  boost-use evidence, exact multiplier tests and boosted production-verifier
  profiles while preserving `2026.2` career formulas.

### Saves, cloud and privacy

- [x] Migrate snapshot schemas 1–8 to schema 9 with deterministic tests.
- [x] Refuse unsafe pre-world midseason reconstruction explicitly instead of
  inventing historical results; season-boundary saves migrate deterministically.
- [x] Show sync preparation/progress/success/failure/retry state and a detailed
  conflict comparison before the player chooses a copy.
- [x] Download cloud-only careers as well as reconciling matching local slots.
- [x] Revalidate cached content checksum, Ed25519 signature, client range and
  executable rules before activation.
- [x] Retain every verified signed content release needed by a saved career,
  resolve its exact version on open, and refuse unavailable pins without mutating
  the slot. New content only becomes active for new careers.
- [x] Isolate malformed or unrecoverable slots, restore the newest readable
  journal state, and preserve premium-slot data through entitlement loss and
  restoration.
- [x] Serialize consent and analytics persistence, cap the queue, expire old
  entries and replay consent after sign-in/startup.
- [x] Deliver `client_error` as an allowlisted taxonomy only. Exception messages,
  stack traces, paths, email addresses, tokens and career data are never queued.
- [x] Rate-limit authentication and public web-deletion confirmation endpoints;
  exercise the deletion limiter in API tests.

### UI, website and operations

- [x] Localize national-team, sponsor, sync, transfer, legacy, archive and
  competition-decision surfaces in English, Spanish, Brazilian Portuguese and
  French.
- [x] Show selected avatars, theme previews, archive layouts and share-card
  treatments, with premium choices included in VIP and All-Access.
- [x] Refactor the portrait app around Career, World, Life and a focused More
  hub; split Player, Legacy, Appearance, Settings, and Account into dedicated
  live routes; add a player-initiated Shop, three-step career creation, Life
  Overview/Market/Collection and compact match recap.
- [x] Add original code-native fictional club marks using each club's palette.
- [x] Add visual knockout brackets, explicit qualification/tie-break guidance and
  a permanent career honors cabinet.
- [x] Add visual and haptic confirmation without making haptics the only signal.
- [x] Keep all Elevenward web pages inside the existing `howethstudio.com` Next.js
  project and add downloadable localized fact sheets, studio/usage guidance, and
  original SVG press marks.
- [x] Add an original downloadable launch-art master/optimized preview, and expose
  the complete public page set through a same-domain static sitemap and robots
  policy while excluding staff routes.
- [x] Add staff operational metrics and auditable stage/publish/rollback actions.
- [x] Reject content releases with invalid league, cup or international fixture
  references, duplicate fixture IDs, impossible schedules or unsafe economy bounds.
- [x] Add a protected manual release workflow for signed AAB/IPA artifacts and
  symbols. Store submission stays a deliberate human action.

## Everything still required

### P0 — production, identity, stores and legal

- [ ] Put the game under intentional version control, select/configure its remote,
  review the dirty state of all three repositories, and commit/push exact release
  revisions without absorbing unrelated Howeth Studio work.
- [ ] Deploy the existing site build so the apex-domain Elevenward and localized
  support/privacy/deletion/press routes are live.
- [ ] Apply the isolated PostgreSQL migrations and deploy the API so the
  `/v1/elevenward/health`, auth, sync, content, leaderboard, entitlement,
  analytics and deletion routes are live.
- [ ] Provision the private immutable object bucket, least-privilege API access,
  backups/PITR, retention policy and restore/rollback procedure in Railway.
- [ ] Supply and rotate production API, OAuth, RevenueCat webhook, staff-auth and
  Ed25519 signing values through protected environments; never place private keys
  or store credentials in source.
- [ ] Finish Apple organization/service-ID/capability/profile configuration and
  verify Sign in with Apple against the production audience and nonce flow.
- [ ] Finish Google Android/iOS OAuth configuration, SHA fingerprints, iOS URL
  scheme and production server-client audience.
- [ ] Create VIP Starter Pack, 2× Development, 2× Money and All-Access as
  permanent products and mapped entitlements in App Store Connect, Play Console
  and RevenueCat. Keep legacy Extra Career Slots and Supporter Pack hidden.
- [ ] Decide and approve RevenueCat verification enforcement for offline reward
  modifiers, cosmetics and slots. The current informational policy, threats and required evidence are
  documented in [THREAT_MODEL.md](THREAT_MODEL.md), but independent review is
  still required.
- [ ] Run purchase, restore, delayed/duplicate webhook, refund, revocation,
  anonymous-to-account, account-switch and cross-device tests in both sandboxes.
- [ ] Complete Elevenward/Elevenreach trademark clearance and document the exact
  owned Football Era code/data/art reuse boundary.
- [ ] Obtain qualified privacy, consumer-law, age-rating and regional review for
  the 13+ audience, analytics, cloud retention, deletion and purchases.
- [ ] Perform a production deletion drill covering challenge expiry/replay,
  provider revocation, sessions, cloud saves, leaderboards, entitlements, audit
  retention and local sign-out behavior.

### P1 — editorial, art and remaining product depth

- [ ] Replace structurally valid but templated launch material with 160 genuinely
  authored position-specific situations, 200 authored career/life/contract events
  and 120 distinctive lifestyle items. The current bundle has unique situation
  prompts and event/item titles, but only 40 unique event bodies across 200 events
  and 20 unique item descriptions across 120 items; count compliance is not the
  requested editorial depth.
- [ ] Have every app, content, web, privacy, support and store string reviewed by
  native English, Spanish, Brazilian Portuguese and French editors. Automated
  completeness checks are not native review.
- [ ] Run pseudo-localization across every app and website screen before native
  review to expose expansion, clipping and hard-coded-string defects.
- [ ] Complete the original editorial art direction: review the generated launch
  master, then finish club/competition identity, polished avatars, lifestyle art,
  approved app/store icons and screenshots, with documented non-infringement
  review.
- [ ] Add more authored relationship/sponsor/press/family arcs with multi-season
  triggers, recovery paths and culturally reviewed consequences.
- [ ] Perform native editorial and physical-device review of the implemented
  bracket, qualification, tie-break and honors presentation; refine only where
  that evidence identifies a usability defect.
- [ ] Tune wages, sponsors, purchases, agent effects, progression, retirement and
  legacy thresholds across 16–20 seasons so choices remain meaningful without a
  purchasable advantage.
- [ ] Route production error categories and health signals to an operated alerting
  destination with retention/deletion controls; the game intentionally does not
  transmit raw exception text.

### P1 — release verification, security and accessibility

- [ ] Obtain the Football Era source/baseline evidence, confirm that the existing
  Swift app remains intact and backward-compatible, and run golden comparisons for
  every deliberately reused simulation/backend behavior. The current checkout can
  verify Elevenward determinism but cannot certify an absent source baseline.
- [ ] Push the game workflow and complete its 20-shard **100,000 real full-career**
  gate on the exact release revision. Retain the strict aggregate artifact and
  confirm zero stuck states plus every required coverage dimension.
- [ ] Compare golden career outputs for identical seeds and inputs on iOS and
  Android release builds.
- [ ] Exercise every shipped migration/content version on device, including
  forward/rollback behavior and the documented refusal of unsafe legacy midseason
  reconstruction.
- [ ] Run interrupted-write, low-disk, locked-database, malformed snapshot,
  checksum, truncated-journal and recovery drills on devices.
- [ ] Test cold offline startup, airplane mode, mid-request disconnects, long API
  outages, expired sessions, clock skew and recovery after reconnect.
- [ ] Test multi-device create/update/delete conflicts, simultaneous edits,
  sign-out during sync and account changes while entitlements are active.
- [ ] Verify database-level product isolation and token boundaries in staging and
  production, not only mocked route tests.
- [ ] Have the documented threat model independently reviewed, resolve accepted
  risks, and attach staging/production drill evidence for identity, sessions,
  deletion codes, staff access, signing-key custody, storage, webhooks and offline
  leaderboard abuse. Replace long-lived staff Basic credentials with managed
  production identity/roles where feasible.
- [ ] Run secret, dependency, SAST and mobile-binary scans on the exact signed
  release revisions and keep high-severity findings blocking.
- [ ] Qualify the RevenueCat Flutter/plugin upgrade that removes its legacy Kotlin
  Gradle Plugin application before Flutter turns the current build warning into a
  hard failure; do not jump to AGP 10 without that compatibility pass.
- [ ] Audit every screen with VoiceOver and TalkBack in all four languages,
  including reading order, values, selected state, errors, dialogs and share flow.
- [ ] Verify full text scaling, contrast, 44/48-point targets, reduced motion,
  safe areas, cutouts, system bars, keyboard, display scaling, small phones,
  tablets and RTL resilience.
- [ ] Profile startup, frame time, memory, battery, SQLite and long-career screens
  on low-end Android API 26 hardware and supported iOS devices.
- [ ] Validate share-card rendering and native share sheets for all locales, long
  names, large text and platform file/permission paths.
- [ ] Run a deployed-site accessibility audit for keyboard navigation, focus,
  zoom/reflow, contrast, landmarks and reduced motion.

### P2 — distribution, marketing and live operations

- [ ] Complete Apple/Google organization verification, D-U-N-S/identity, banking,
  tax and agreements; create store records with final ownership roles.
- [ ] Run the protected signed-artifact workflow with real credentials, inspect
  signatures/entitlements/symbols and verify final AAB/IPA/store download sizes are
  under 100 MB.
- [ ] Complete store age/content ratings, privacy/data-safety disclosures,
  localized names/subtitles/descriptions/keywords and the US “Soccer” strategy.
- [ ] Produce approved localized device screenshots, feature graphics, press
  screenshots, short vertical trailers, icon and launch copy. The current press
  kit supplies marks and fact sheets, not approved gameplay captures.
- [ ] Keep launch-update contact as direct email unless a real consent, retention
  and unsubscribe system is operated.
- [ ] Configure monitors and alerts for health, latency, error rate, capacity,
  storage, webhooks, auth, conflicts, content publishing and deletion failures.
- [ ] Create privacy-safe Elevenward retention/funnel/balance/leaderboard
  dashboards and assign an accountable operator for each signal.
- [ ] Run TestFlight and Play closed testing across iOS/Android × four languages,
  with device/OS coverage and zero blocker/high-severity defects.
- [ ] Perform backup restore, database migration rollback, content rollback,
  signing-key recovery, store-account recovery and incident-response drills.
- [ ] Assign launch support coverage, private-beta/community moderation and
  creator outreach; keep launch marketing below $5,000 and defer mainland China
  until the required local publishing route/approvals exist.
- [ ] After launch, measure 10,000 installs, 4.5+ rating, 99.5% crash-free
  sessions, D1 25% and D7 10%, then make explicit continue/fix/scale decisions.

## Explicit v1 exclusions still enforced

Goalkeeper careers, manager mode, direct-control matches, live multiplayer, chat,
public free text, licensed real-world data and paid random rewards are not present.
They are not gaps unless the approved product scope changes.

## Recommended order from here

1. Review and commit the three local codebases, configure the game remote, and run
   CI plus the 100k workflow on exact revisions.
2. Deploy a staging API/database/bucket and the same-domain site; prove identity,
   sync, content, deletion and purchases end to end.
3. Complete professional content, art, localization, legal and economy review.
4. Run security, recovery, accessibility, performance and eight-matrix closed beta.
5. Produce signed store artifacts, complete store disclosures/assets and perform a
   coordinated worldwide release only after every P0/P1 acceptance gate has evidence.
