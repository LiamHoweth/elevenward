# App Store screenshot production

These internal tools reproduce Elevenward's localized product-page screenshots. They do not upload anything to App Store Connect and do not add screenshot-only behavior to the shipping app.

## Prerequisites

- macOS with Xcode and Flutter installed
- A booted iPhone 14 Plus simulator and a booted 13-inch iPad simulator
- Python 3.10 or newer with the local image dependency installed:

```sh
python3 -m pip install -r tool/app_store/requirements.txt
```

Use default text scaling, dark appearance, portrait orientation, and a normalized 9:41 status bar before capturing.

## Capture authentic localized UI

The integration test builds seed 2 with the production career engine, writes only to simulator-local SQLite storage, and visits eight real app screens in English, Spanish, Brazilian Portuguese, and French.

```sh
python3 tool/app_store/capture_simulator.py \
  --device-id <SIMULATOR_UDID> \
  --device-class iphone-65 \
  --output-root artifacts/app-store/product-page/raw

python3 tool/app_store/capture_simulator.py \
  --device-id <SIMULATOR_UDID> \
  --device-class ipad-13 \
  --output-root artifacts/app-store/product-page/raw
```

## Compose the final product-page artwork

The compositor accepts exactly the capture directory, locale, device class, and output directory. It uses `assets/visual/stadium-graphite.png` and the `11` mark for framing. Every inset screen must come from a fresh simulator capture of the finished theme; the artwork alone is not a gameplay screenshot. It writes eight RGB/sRGB PNG files plus a contact sheet.

```sh
python3 tool/app_store/compose_screenshots.py \
  --captures artifacts/app-store/product-page/raw/en/iphone-65 \
  --locale en \
  --device-class iphone-65 \
  --output artifacts/app-store/product-page/en/iphone-65
```

Repeat for `en`, `es`, `pt-BR`, and `fr`, and for `iphone-65` and `ipad-13`.

## Validate and manifest

```sh
python3 tool/app_store/validate_screenshots.py \
  --root artifacts/app-store/product-page
```

Validation covers the complete 64-file matrix, exact dimensions, PNG format, RGB/no-alpha final output, embedded sRGB profiles, raw capture provenance, contact-sheet count, and SHA-256 checksums. Upload only after the contact sheets are approved.
