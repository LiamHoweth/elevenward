# Elevenward release and support runbook

Status: local implementation, not approval to launch. Updated 2026-09-05.

## Ownership and domain boundaries

Game: this repository. Website: neighboring `howethstudio.com` checkout, remote
`LiamHoweth/howeth-studio-web`. API: its ignored `backend` checkout, remote
`LiamHoweth/howeth-studio-api`. The game's remote has not been configured.

Public product pages stay under `https://howethstudio.com/elevenward/`, with
`es/`, `pt-br/`, and `fr/` localized sections. API/content endpoints use
`https://api.howethstudio.com/v1/elevenward/`. This is one studio domain, not one
HTTP origin. Keep CORS limited to the studio site. Do not move sibling products
or replace the apex deployment with the game.

## Release gates and accountable roles

| Gate | Responsible role | Required evidence |
| --- | --- | --- |
| Code baseline | Engineering / repository owner | Intentional commits in each repository; review dirty changes; game remote selected; CI on exact release revisions |
| Infrastructure | Studio infrastructure owner | Reviewed Railway plan; staging migration/isolation tests; production backup; successful health/content/sync/deletion smoke |
| Identity and billing | Store/account owner + QA | Provider audiences, capabilities, fingerprints, permanent products and entitlements; sandbox matrix results |
| Simulation | Gameplay engineering | 100k real-engine aggregate pass, all dimensions; device golden parity; economy/content review |
| Accessibility | QA + native-language reviewers | VoiceOver/TalkBack, text scaling, contrast, keyboard/web reflow, eight platform/language combinations |
| Legal and editorial | Studio owner + qualified reviewers | Name/reuse/privacy/consumer review and approved native-language text |
| Distribution | Store/account owner | Signed AAB/archive, store size reports, disclosures, screenshots, closed beta, support coverage |

Roles above are responsibilities to assign, not claims that people have signed off.
The current abuse-case baseline and production evidence requirements are in
[THREAT_MODEL.md](THREAT_MODEL.md).

## Full-career simulation gate

The authoritative verifier uses `CareerSnapshot`, `WeeklySimulator`,
`WorldSimulator` and `CareerEngine`; it is not a synthetic approximation. Run the
same 20 non-overlapping 5,000-career shards as CI, then merge them strictly:

```sh
for shard in $(seq 0 19); do
  dart run packages/elevenward_core/bin/verify_production_careers.dart \
    --careers 5000 --start $((shard * 5000)) \
    --output artifacts/verification/production-shard-$shard.json
done
dart packages/elevenward_core/bin/merge_production_reports.dart \
  --output artifacts/verification/production-100000.json \
  artifacts/verification/production-shard-*.json
```

The merger rejects missing/non-contiguous shards, fewer than 100,000 careers,
any recorded failure, or missing required coverage. Preserve the aggregate as
release evidence, but also run the hosted workflow on the exact pushed revision.

## Configure without putting secrets in source

1. The canonical `.railway/railway.ts` declares an `elevenward-content` private
   bucket and API references for `BUCKET`, `ENDPOINT`, `REGION`, `ACCESS_KEY_ID`,
   and `SECRET_ACCESS_KEY`. Review the generated plan before applying; preserve
   the existing API/database/PITR resources. No Railway resources were applied
   by this implementation pass.
2. Supply server-only `ELEVENWARD_APPLE_CLIENT_ID`,
   `ELEVENWARD_GOOGLE_OAUTH_CLIENT_IDS`, `REVENUECAT_WEBHOOK_SECRET`, and
   `ELEVENWARD_CONTENT_SIGNING_PRIVATE_KEY` through protected Railway variables.
   Existing Apple team/key/encrypted-refresh-token configuration remains required.
   `preserve()` is not a generated credential and does not fill missing values.
3. Generate and escrow an Ed25519 key using approved secret-management tooling.
   Never check in the private key. Set its public base64 key in the app's
   `ELEVENWARD_CONTENT_PUBLIC_KEY_BASE64` build definition.
4. App build definitions also include `ELEVENWARD_API_BASE_URL`,
   `ELEVENWARD_GOOGLE_SERVER_CLIENT_ID`, `REVENUECAT_IOS_PUBLIC_KEY`, and
   `REVENUECAT_ANDROID_PUBLIC_KEY`. Confirm the actual consumed names in source
   before creating CI secrets. These RevenueCat SDK keys are public; webhook,
   signing, admin and provider private keys are server-only.
5. Copy `android/key.properties.example` to the ignored `android/key.properties`.
   Keep the upload keystore outside the repository with separate backup/recovery.
   Register its SHA fingerprints with Google OAuth. Never substitute debug signing
   for a store release.
6. Complete the ignored iOS `Secrets.xcconfig` using its example; register the
   bundle ID, Google callback scheme/client and Sign in with Apple capability.
   Verify the signed provisioning profile contains the entitlement, not just the
   local `.entitlements` file.
7. The manual `Signed release artifacts` GitHub workflow builds an obfuscated,
   signed AAB or App Store IPA only after protected environment approval. Populate
   the `elevenward-production` environment with the public client values plus the
   Android upload-key or Apple distribution-certificate/profile secrets named in
   the workflow. The workflow stages binaries and symbol files for 30 days; it
   intentionally does not submit them to either store.

The Android toolchain update follows [Android's API/AGP compatibility table](https://developer.android.com/build/releases/about-agp)
and the [secure-storage package changelog](https://pub.dev/packages/flutter_secure_storage/changelog).
API 37 compilation does not raise the application's API 26 runtime minimum.

## Content publish and rollback

1. Validate the canonical bundle in the game and staff portal. Structural counts
   and unique titles do not replace editorial/economy/native-language review.
2. Regenerate the API's self-contained fixture with
   `node scripts/sync-elevenward-fixture.mjs /absolute/path/to/launch-bundle.json`
   and run API tests after a contract change.
3. Stage in a non-production environment. Objects use version/checksum keys and
   conditional create (`If-None-Match: *`). A retry verifies existing bytes; it
   cannot overwrite another object.
4. Confirm draft manifests and draft object URLs return 404. Publish, then confirm
   the active manifest and exact object return 200 and the client verifies their
   checksum, Ed25519 signature, signed client compatibility and executable rules.
5. Roll back the active manifest using the staff endpoint. Previously published
   immutable objects remain retrievable for pinned careers. Never overwrite a
   release version with changed bytes. Start a new version instead.
6. Reopen the app offline: cached bytes must be reverified, otherwise the bundled
   catalog loads. Test wrong key/checksum/rules/client range, redirects, over-size
   payloads and unavailable storage. Cache fallback alone is not a full rollback
   drill; verify a real career pinned to the affected content version.

Railway buckets are private; the API exposes only exact previously published
objects. See [Railway bucket documentation](https://docs.railway.com/storage-buckets).
Backup retention, cross-region recovery and signing-key rotation remain release gates.

## Purchases and account lifecycle

The four permanent products, legacy migration, dashboard mapping, restore,
refund/revocation, account-switch and webhook procedures are defined in
[GAMEPASS_OPERATIONS.md](GAMEPASS_OPERATIONS.md). Missing storefront prices show
an unavailable state, never an invented amount.

Current RevenueCat verification mode is **informational**, not enforced. Rationale:
these are offline career modifiers, cosmetics and slot capacity without valuable
leaderboard prizes. Local
cache tampering cannot be made impossible on modified devices. This is an explicit
pre-alpha implementation choice, not approved production fraud policy. Before
launch, review whether enforced verification is compatible with offline use and
exercise refund/revocation, reinstall, delayed webhooks, account switching and
cross-device restoration. Server entitlements and device entitlements need parity
tests; purchase caches are not simulation data.

Account deletion preserves local careers by design. Confirm the server's
account/session/cloud/leaderboard/entitlement cascades and provider revocation in
staging, then verify local session teardown even when RevenueCat logout is offline.
Web deletion codes need real expiry, attempt-limit and replay tests. Do not tell
players a deletion completed if the server request failed.

## Support triage

| Incident | First action | Do not do |
| --- | --- | --- |
| Save needs recovery | Tap the occupied recovery slot; restore the newest readable journal snapshot; collect slot number and opaque support code | Overwrite it with a new career or request the player's raw SQLite file by default |
| Cloud conflict | Compare season/week/club/revision/time and deletion state; preserve both copies until an explicit selection | Use timestamp alone to silently overwrite the other device |
| Purchase missing | Confirm store account, restore purchases, check product/entitlement mappings and webhook health | Request store passwords, receipts with private credentials, or give manual gameplay advantages |
| Sign-in unavailable | Keep offline play usable; check audience/scheme/fingerprint/session expiry | Erase local careers to reset identity |
| Content failure | Keep bundled content available; inspect manifest/object hash/signature/rules and use documented rollback | Disable signature verification or replace immutable bytes |
| Deletion failure | Check server audit and retry the scoped deletion flow with the user | Treat a failed request or expired code as proof of deletion |

Analytics consent is device-local, explicit and replayed after sign-in. The queue
is serialized, bounded to 100 events, retained for at most 30 days when processed,
and sent in batches of 50. Only aggregate gameplay values are allowed; free text,
email and tokens must not enter it. A fully offline, never-reopened installation
cannot run automatic retention cleanup; this limitation needs privacy review.

## Launch evidence still required

No real store purchases, signed store archives, organization enrollment, production
migration, deployment, DNS mutation, legal approval, native copy approval, physical
device accessibility review or production incident drill was performed by these
code changes. Record dates, exact revisions, environments, operators and evidence
links for each gate in `PRODUCT_GAP_AUDIT.md` before release.
