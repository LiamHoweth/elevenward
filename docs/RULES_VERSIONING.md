# Elevenward rules versioning

`CareerSnapshot.rulesVersion` freezes deterministic gameplay formulas for a career. It is separate from the snapshot schema and from authored content versions.

## Current rules

- `2026.2` is assigned to every newly created career.
- Relationship reach, manager-selection influence, teammate match influence, family recovery, community reputation support, and ongoing equipped-lifestyle effects are enabled only for `2026.2` careers.
- Existing `2026.1` careers keep the earlier selection, transfer, recovery, reputation, and team-result formulas when loaded by the new client.
- Authored content is pinned for the whole career. Signed releases are retained
  by version, and a save cannot open against a different event/situation/item
  catalog. A newly downloaded release becomes the default only for new careers
  and for the career-slot surface until a pinned career is opened.
- `2026.1.0` is an explicit compatibility alias for the bundled `2026.2.0`
  authored catalog. That transition changed executable rules and fixture result
  encoding, not the event, situation or lifestyle definitions consumed by the
  client catalog.

Do not change a published formula in place. Add a new rules identifier, branch only the affected calculation, keep deterministic regression fixtures for the older identifier, and partition leaderboards by rules version. Snapshot migrations must never rewrite `rulesVersion`.
