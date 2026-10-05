# Elevenward rules versioning

`CareerSnapshot.rulesVersion` freezes deterministic gameplay formulas for a career. It is separate from the snapshot schema and from authored content versions.

## Current rules

- `2026.5` is assigned to newly created careers. It corrects personal goals/assists
  against team scores and omitted-match ratings, adds role-specific contributions
  to legacy scoring, age-sensitive training and shared tactical fit. Snapshot
  schema 14 stores bounded journals, goals, story flags, durable pending event IDs
  and loan ownership. Latest authored family spending applies only to these new
  rules; previous careers retain their formulas and pinned catalog.
- `2026.4` retains the expanded
  26-system world, regional national-team qualification, dedicated postseason
  international match advancement, and the 32-team World Nations Championship.
  Snapshot schema 13 adds an explicit player transfer request (target league,
  optional preferred club, filing season/week) and its once-per-season trust
  penalty marker. This is player input, not a formula change: careers without a
  request retain the existing `2026.4` transfer interest and offer ordering.
- `2026.3` careers retain their entitlement-aware weekly development/income,
  exact fractional development carry and boost-use evidence.
- `2026.2` careers retain their existing relationship, selection, recovery,
  reputation and team-result formulas when migrated to schema 10. Their
  fractional progress and boost-use list begin empty.
- Relationship reach, manager-selection influence, teammate match influence,
  family recovery, community reputation support, and ongoing equipped-lifestyle
  effects are enabled for `2026.2`, `2026.3`, `2026.4`, and `2026.5` careers.
- Existing `2026.1` careers keep the earlier selection, transfer, recovery, reputation, and team-result formulas when loaded by the new client.
- Authored content is pinned for the whole career. Signed releases are retained
  by version, and a save cannot open against a different event/situation/item
  catalog. A newly downloaded release becomes the default only for new careers
  and for the career-slot surface until a pinned career is opened.
- New bundled content `2026.4.0` requires client `1.1.0` and rules `2026.5`;
  it retains the expanded world and adds four localized mentor events. Previously
  verified older-rule content stays available for exact saved-career pins; it
  cannot become the default for new careers.
- Content `2026.3.0` contains the expanded 520-club world. Bundled content
  `2026.2.0` and its `2026.1.0` compatibility alias retain the original
  120-club world and do not receive new leagues mid-career.
- `2026.1.0` is an explicit compatibility alias for the bundled `2026.2.0`
  authored catalog. That transition changed executable rules and fixture result
  encoding, not the event, situation or lifestyle definitions consumed by the
  client catalog.

Do not change a published formula in place. Add a new rules identifier, branch only the affected calculation, keep deterministic regression fixtures for the older identifier, and partition leaderboards by rules version. Snapshot migrations must never rewrite `rulesVersion`.
