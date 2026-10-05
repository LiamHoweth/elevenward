# Graphite branding concepts

These original, AI-generated assets were created for Elevenward on 2026-09-28.
The `11` and stadium variants are used by the app. They contain no club marks,
player likenesses, or readable text.

- `elevenward-11-icon-master.png` — 1254 × 1254 RGB square icon master. Its
  ivory `11` silhouette stays legible at 120 px. The background is opaque;
  use it as a square mark on a near-black surface rather than as a transparent
  overlay.
- `elevenward-e-icon-master.png` — 1254 × 1254 RGB alternate square icon master
  with a bold `E` silhouette. It is a distinct candidate for icon comparison.
- `stadium-portrait-master.png` — 941 × 1672 RGB text-free stadium art. It is
  suitable as decorative onboarding or career-hub background art with a
  contrast overlay and `excludeFromSemantics: true`.

Exports for store preparation are in `artifacts/app-store/branding/graphite/`:

- `app-icon-1024.png` — 1024 × 1024 opaque RGB icon export.
- `app-icon-e-1024.png` — alternate 1024 × 1024 opaque RGB icon export.
- `icon-preview-120.png` and `icon-e-preview-120.png` — small-size review images.
- `screenshot-background-iphone-65.png` — 1284 × 2778 composition background.
  It is not a product-page screenshot by itself. The final screenshot set in
  `artifacts/app-store/product-page/` pairs native simulator captures with
  localized headlines for both supported device classes and four languages.

`tool/generate_app_icons.sh` uses the `11` master for launcher and store icons.
`elevenward-11-ui.png` is the small in-app mark; Android adaptive and monochrome
icons use the vector silhouette in `android/app/src/main/res/drawable/`. The
stadium art is copied to `assets/visual/stadium-graphite.png` for entry screens.
The older production assets remain in the repository for reference.
