# Elevenward visual system

## Direction

The interface uses a premium night-match broadcast language: deep pitch blacks,
thin chalk-like rules, restrained floodlight bloom, compact statistic modules
and high-contrast lime actions. Decorative atmosphere must never carry meaning.

## Tokens

The source of truth is `lib/src/theme.dart`.

- Color: `ink`, `deep`, `panel`, `panelLight`, `line`, `grass`, `cream`,
  `muted`, `amber`, `coral`, and `sky`.
- Spacing: 4, 8, 12, 16, 24, 32 and 48 logical pixels.
- Radius: 14 for controls, 20 for cards and 28 for hero surfaces.
- Depth: a single dark 24 px blur/12 px offset on broadcast panels. Avoid
  stacked decorative shadows.
- Motion: 180–280 ms ease-out for state changes. Every duration goes through
  `motionDuration`, which becomes zero when reduced motion is requested.

## Component rules

- Filled buttons are the one primary action and have a 56 px minimum height.
- Outlined controls use a 52 px minimum height. Icon-only controls retain the
  Material 48 px interactive region and require a tooltip.
- `BroadcastPanel` is the default elevated information container. Use accent
  borders only for meaning that also has an icon or text label.
- Metrics use an icon, value and label; no state is encoded by color alone.
- Club marks, badges, controls and gamepass icons remain code-native.
- Player identity uses `PlayerIdentityBadge`: a monogram, avatar-specific accent,
  border, and a small symbolic icon. Agents, relationships, sponsorships, and
  news use semantically labeled `RoleIconBadge` components and Material icons.
- Human artwork is not bundled. Identity state must remain understandable without
  relying on color alone.
- Free appearance defaults remain Pitch, Initials, Timeline and Classic.
  Existing premium themes, avatars, archive layouts and share cards are covered
  by VIP and All-Access.

## Atmospheric assets

Only the three text-free originals documented in `assets/visual/README.md` are
approved atmospheric imagery. Crop with `BoxFit.cover`, add a contrast overlay,
and set `excludeFromSemantics: true`. Do not add search-result art without a
recorded CC0/MIT-style commercial license and source URL.

## Geographic assets

The World tab uses the bundled, public-domain Natural Earth 1:50m map-unit
geometry documented in `assets/maps/README.md`. Keep geography offline and use
map-unit boundaries so England can remain a distinct playable football nation.
