# Elevenward generated art

These original, text-free raster assets were generated for this project
with OpenAI ImageGen on 2026-09-06. They contain no real club identity, trademark,
readable signage or identifiable player.

- `stadium-hero.png`: “Cinematic portrait-format fictional European football
  stadium at night viewed from a dark players' tunnel … no people, players,
  logos, team colors, flags, advertising, signage, lettering or numbers.”
- `stadium-graphite.png`: monochrome, portrait-format football stadium viewed
  from a dark tunnel, generated on 2026-09-28 for the Graphite branding. It
  contains no people, club marks, signage, or readable text and is used on
  onboarding and the career hub.
- `matchday-tunnel.png`: “Wide cinematic dark football players' tunnel opening
  onto a floodlit pitch at night … no people, logos, signage, advertising,
  lettering, numbers, flags or recognizable team branding.”
- `shop-all-access.png`: “Abstract premium stadium floodlights and fine rain in
  a dark night atmosphere … no text, numbers, logos, people, players, crests,
  signage or recognizable branding.”

The atmospheric prompts were intentionally constrained for strong dark overlays
and flexible phone/tablet crops. Those assets are decorative and must use
`excludeFromSemantics`.

## Player portraits

`player_portraits/player_01.webp` through `player_30.webp` are original,
fictional male soccer players generated with the built-in OpenAI ImageGen tool
on 2026-09-28. Each player was generated separately. The prompts specify a
square, front-facing chest-up portrait, centered head and shoulders, soft studio
light, a plain neutral charcoal soccer jersey, and a transparent background.
They ask for varied skin tones and facial features without team marks, numbers,
text, props, or a real athlete's likeness. The source PNGs were converted to
WebP with alpha for the game. Stable IDs are saved per career, so do not rename
these files or reuse an ID for a different face.

The square framing supports circular badges and the crop in the onboarding
picker. Keep the player's head and both shoulders inside the central 80% when
adding a portrait. Portrait images carry the player's visual identity; the
surrounding UI supplies the accessible player name.
