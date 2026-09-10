# Elevenward security and privacy threat model

Status: engineering baseline for independent review. Updated 2026-09-05.

This model covers the Flutter client, `howethstudio.com` public and staff pages,
the `/v1/elevenward` API namespace, PostgreSQL schema, private content bucket,
Apple/Google identity, RevenueCat and the release pipelines. It does not certify
a production environment that has not yet been provisioned or inspected.

## Security objectives

1. A guest can play and recover every career without an account or network.
2. Divergent local and cloud careers are preserved until the player chooses.
3. An Elevenward identity or query cannot read or mutate Football Era data.
4. Remote content cannot change executable rules or run code.
5. Staff, signing, store and provider credentials never ship in the app or site.
6. Analytics and error delivery contain only consented, bounded taxonomies.
7. Purchases add convenience and cosmetics, never simulation power or prizes.
8. Account deletion is authenticated, bounded, replay-safe and auditable without
   retaining deleted gameplay data in the audit record.

## Assets and trust boundaries

| Asset | Trust boundary | Required control |
| --- | --- | --- |
| Local career snapshots and journal | Device SQLite database | Transactional writes, SHA-256 corruption detection, versioned decoding, journal recovery and per-slot isolation |
| Account/session tokens | App process to Keychain/Android Keystore | This-device secure-storage accessibility, scoped bearer tokens, expiry/revocation and clearing on sign-out/deletion |
| Cloud careers | API to isolated PostgreSQL schema | Account ownership on every query, parameterized SQL, revision checks, idempotency and conflict preservation |
| Content releases | Staff portal/API to private immutable bucket to app | Staff authorization, validation, immutable version/checksum key, Ed25519 signature, same-origin HTTPS retrieval, size limit and exact career-version pinning |
| Purchase state | Store/RevenueCat to API and local entitlement cache | Stable product mapping, webhook authentication/idempotency, refund/revocation handling, bounded 1.5×/2×/3× rewards and no valuable leaderboard prizes |
| Leaderboards | Offline client to public aggregate board | Explicit opt-in, generated aliases, bounded aggregates, plausibility checks, partitioned rules and no prizes/free text |
| Analytics/error categories | Device to API | Separate explicit consent, allowlisted fields/values, bounded 30-day retry queue, no raw messages/stacks/tokens/paths |
| Staff/release credentials | Protected CI and infrastructure environments | Least privilege, approval gates, rotation, audit history and no browser/client exposure |

## Principal abuse cases and current controls

| Threat | Current engineering control | Production evidence still required |
| --- | --- | --- |
| Forged or modified remote content | Checksum plus Ed25519 verification over exact bytes; signed client/rules compatibility; catalog validation | Production key custody/rotation and observed publish/rollback drill |
| Content update changes an active career | Every career records a content version; all verified releases are retained; open/resolve paths require that exact release | Device forward/rollback test with production-signed releases |
| Redirect, cross-origin or oversized content fetch | HTTPS origin equality including port, redirects disabled, declared and streamed 5 MB limits | Staging proxy/object-storage tests |
| Silent cloud overwrite | Base/server revisions, idempotency keys, HTTP 409, preserved local/remote copies and explicit resolution | Simultaneous multi-device drills |
| Deleted career resurrects during sync | Durable tombstones until cloud confirmation; delete conflicts preserve both states | Offline-delete/reconnect and cross-device delete drills |
| Token crosses product boundary | Elevenward route namespace and database schema; API ownership checks | Staging/production negative isolation tests with real tokens |
| Deletion-code guessing or replay | Short expiry, attempt/rate limits, hashed one-time challenge and audit category | Production clock-skew, replay, expiry and provider-revocation drill |
| Staff portal compromise | Server-side staff gate, action audit and immutable content objects | Replace/bootstrap Basic credentials with managed identity/roles; review session/CSRF policy |
| RevenueCat webhook forgery/replay | Bearer secret and transaction/idempotency constraints | Sandbox duplicate/delayed/refund/revocation matrix and secret rotation |
| Modified-device entitlement cache | No valuable prize or premium currency; boost usage is submitted as validation evidence and server/store remains authority for restoration | Approve informational vs enforced verification policy before launch |
| Offline leaderboard cheating | Plausibility checks, bounded aggregate evidence, partitions and no valuable rewards | Production rate/abuse monitoring and manual integrity review |
| Privacy leakage in diagnostics | Only `area`, exception class category and bounded code are allowed; message and stack are discarded before persistence | Inspect real production payloads/retention/deletion dashboard |
| Supply-chain or secret exposure | Locked dependencies, dependency audit, gitleaks CI and protected release environment | Exact-revision SAST, binary and secret scans with high findings blocking |
| Database/object loss | Append-only migrations and immutable releases | PITR, restore, backup retention and cross-region/key-recovery drills |

## RevenueCat enforcement decision

The source currently uses informational entitlement verification. This preserves
offline access to permanent passes when a validation service is temporarily
unavailable. A modified device may forge its local cache and therefore obtain
bounded development/income multipliers, slots or cosmetics. It cannot change
seeded match odds or win a valuable prize. Leaderboard submissions include the
boost classes used and fractional progress so the backend can validate legitimate
boosted ranges without splitting the public board.

Launch approval must choose one of these documented policies after sandbox tests:

- Keep informational mode if uninterrupted offline ownership is prioritized and
  the bounded pass piracy/leaderboard-integrity risk is accepted.
- Move to enforced mode only if purchase restoration, grace behavior, refunds and
  long outages remain understandable and never damage existing career data.

In either policy, reducing a five-slot entitlement must never delete slots three
through five. They remain preserved but inaccessible until entitlement
restoration; they are never removed as a side effect of an entitlement change.

## Privacy data flow

- Guest careers, journal entries, settings and denied analytics stay local.
- Sign-in sends provider proof to the isolated API and receives a scoped token;
  provider tokens are not analytics fields.
- Cloud sync sends the chosen career snapshot only after sign-in.
- Leaderboard submission is separate, opt-in and uses a generated alias.
- Analytics consent is separate from identity, cloud and leaderboard choices.
- The public web-deletion flow uses account ID plus a short-lived one-time code;
  it never asks for an Apple/Google password or raw career database.
- Server audit records must retain operational category, time and actor reference
  only as legally approved; deleted snapshot bodies and tokens must not be copied
  into logs or staff-action detail.

## Required independent review and drills

Before release, assign an owner and preserve dated evidence for identity/session
review, product-isolation tests, staff-role review, signing-key ceremony, bucket
policy, webhook matrix, multi-device conflicts, deletion, backup restore, content
rollback, binary/SAST/secret scans and incident response. Any blocker or
high-severity finding stops release. The exact evidence checklist remains in
[`PRODUCT_GAP_AUDIT.md`](PRODUCT_GAP_AUDIT.md) and the operational sequence in
[`RELEASE_RUNBOOK.md`](RELEASE_RUNBOOK.md).
