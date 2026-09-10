# Permanent gamepass operations

## Product mapping

| RevenueCat entitlement | Store product | Type | Reference QA price |
| --- | --- | --- | ---: |
| `vip_starter_pack` | `com.howethstudio.elevenward.vip` | non-consumable | USD 4.99 |
| `double_development` | `com.howethstudio.elevenward.double_development` | non-consumable | USD 3.99 |
| `double_money` | `com.howethstudio.elevenward.double_money` | non-consumable | USD 3.99 |
| `all_access` | `com.howethstudio.elevenward.all_access` | non-consumable | USD 9.99 |

Reference prices are configuration/test expectations only. The UI renders only
the localized `StoreProduct.priceString` returned by the storefront.

Legacy `extra_career_slots` and `supporter_pack` entitlements stay mapped for
existing owners but their products are hidden. The former grants five slots;
the latter grants premium cosmetics. Neither grants a reward multiplier.

## Dashboard setup

Create all four products as permanent non-consumables in App Store Connect and
Play Console. Attach each to the identically mapped RevenueCat entitlement and
the current offering. Confirm tax category, translations, review screenshot and
availability in every intended territory. Do not create subscriptions or
consumable aliases for these identifiers.

## Lifecycle behavior

- Restore calls RevenueCat restore, reconciles active entitlements, expands slot
  capacity, and updates the encrypted local cache.
- Sign-in links RevenueCat to the studio account; sign-out returns to an
  anonymous purchaser without deleting local careers.
- Refunds and revocations must arrive through store notifications and RevenueCat
  webhooks. The next customer-info refresh removes inactive current products;
  a cache-only legacy grant survives the first upgrade reconciliation, while
  login/logout and later refreshes require that legacy grant on the active
  RevenueCat customer so it cannot leak across accounts.
- Webhooks are server-authenticated and idempotent by event ID. Store raw event
  IDs and product/entitlement/account identifiers, not complete receipts in
  application logs.
- Account switching must test anonymous purchase → login merge, logout, second
  account login, reinstall and cross-platform restoration. A pass never follows
  a different studio account unless the store/RevenueCat transfer policy says so.

## Sandbox matrix

On physical iOS and Android devices test each product, cancellation, pending
payment, failed payment, restoration, refund/revocation, offline launch, delayed
webhook and account switching. Test VIP plus each focused pass for exact 3×
stacking. Test partial ownership disables All-Access and leaves remaining passes
available. Capture storefront price/locale and RevenueCat customer ID with each
result.

Client verification is currently informational. The backend contract maps each
entitlement to its exact product, persists authenticated webhook state, and
accepts bounded leaderboard evidence containing `boostIdsUsed` and fractional
`developmentProgress`. Deploy the accompanying entitlement-constraint migration
before enabling products; its plausibility ceiling covers legitimate 1.5×, 2×
and 3× careers without creating a separate leaderboard.
