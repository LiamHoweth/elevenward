# Elevenward visual system

## Direction

The default interface uses graphite and black surfaces, warm ivory text, thin
neutral rules, compact statistic modules, and muted steel-blue actions. Light
mode uses warm ivory surfaces and charcoal text. Follow System tracks the device
appearance. Decorative atmosphere must never carry meaning.

## Tokens

The source of truth is `lib/src/theme.dart`.

- Color: `ElevenwardPalette` defines semantic surfaces, text, action, warning,
  danger, and information roles for both brightness modes. Legacy presentation
  aliases in `ElevenwardColors` resolve to the active palette.
- Spacing: 4, 8, 12, 16, 24, 32 and 48 logical pixels.
- Radius: 14 for controls, 20 for cards and 28 for hero surfaces.
- Depth: use one restrained shadow on broadcast panels. Avoid stacked
  decorative shadows.
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
- Player identity uses `PlayerIdentityBadge`: a selected portrait when available,
  with a monogram fallback for older saves, an avatar-specific accent border,
  and an optional symbolic cosmetic icon. Agents, relationships, sponsorships,
  and news use semantically labeled `RoleIconBadge` components and Material icons.
- Identity state must remain understandable without relying on color alone.
- Free appearance defaults are Graphite, Initials, Timeline and Classic.
  Stored `pitch` values resolve to Graphite. Dark, Light, and Follow System are
  free display settings; premium appearance themes affect small accents.
  Existing premium themes, avatars, archive layouts and share cards are covered
  by VIP and All-Access.

## Atmospheric assets

The entry screens use the generated monochrome `stadium-graphite.png` image.
The earlier text-free assets remain available for other themed screens. The 30
player portraits are character art for creation and identity surfaces. Crop
atmospheric assets with `BoxFit.cover`, add a contrast overlay for each display
mode, and set `excludeFromSemantics: true`. Do not add search-result art without
a recorded CC0/MIT-style commercial license and source URL.

## Geographic assets

The World tab uses the bundled, public-domain Natural Earth 1:50m map-unit
geometry documented in `assets/maps/README.md`. Keep geography offline and use
map-unit boundaries so England can remain a distinct playable football nation.
