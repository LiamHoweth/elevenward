#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_icon="$repo_root/assets/branding/graphite/elevenward-11-icon-master.png"

if [[ ! -f "$source_icon" ]]; then
  echo "Missing $source_icon" >&2
  exit 1
fi

resize() {
  local size="$1"
  local destination="$2"
  mkdir -p "$(dirname "$destination")"
  sips -z "$size" "$size" "$source_icon" --out "$destination" >/dev/null
}

ios="$repo_root/ios/Runner/Assets.xcassets/AppIcon.appiconset"
resize 20 "$ios/Icon-App-20x20@1x.png"
resize 40 "$ios/Icon-App-20x20@2x.png"
resize 60 "$ios/Icon-App-20x20@3x.png"
resize 29 "$ios/Icon-App-29x29@1x.png"
resize 58 "$ios/Icon-App-29x29@2x.png"
resize 87 "$ios/Icon-App-29x29@3x.png"
resize 40 "$ios/Icon-App-40x40@1x.png"
resize 80 "$ios/Icon-App-40x40@2x.png"
resize 120 "$ios/Icon-App-40x40@3x.png"
resize 120 "$ios/Icon-App-60x60@2x.png"
resize 180 "$ios/Icon-App-60x60@3x.png"
resize 76 "$ios/Icon-App-76x76@1x.png"
resize 152 "$ios/Icon-App-76x76@2x.png"
resize 167 "$ios/Icon-App-83.5x83.5@2x.png"
resize 1024 "$ios/Icon-App-1024x1024@1x.png"

for entry in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density="${entry%%:*}"
  size="${entry##*:}"
  resize "$size" "$repo_root/android/app/src/main/res/mipmap-$density/ic_launcher.png"
done

resize 512 "$repo_root/assets/branding/google-play-icon-512.png"
resize 1024 "$repo_root/assets/branding/app-store-icon-1024.png"
resize 256 "$repo_root/assets/branding/graphite/elevenward-11-ui.png"
cp "$repo_root/assets/branding/graphite/elevenward-11-ui.png" \
  "$repo_root/ios/Runner/Assets.xcassets/Brand11.imageset/Brand11.png"
echo "Generated Elevenward app and store icon variants."
