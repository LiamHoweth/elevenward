#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
required=(
  "$repo_root/assets/branding/app-store-icon-1024.png"
  "$repo_root/assets/branding/google-play-icon-512.png"
  "$repo_root/ios/Runner/Runner.entitlements"
  "$repo_root/ios/ExportOptions.plist"
  "$repo_root/android/key.properties.example"
  "$repo_root/assets/content/launch-2026.2.0.json"
)

for target in "${required[@]}"; do
  [[ -s "$target" ]] || { echo "Missing release asset: $target" >&2; exit 1; }
done

grep -q 'android.permission.INTERNET' "$repo_root/android/app/src/main/AndroidManifest.xml"
grep -q 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements' "$repo_root/ios/Runner.xcodeproj/project.pbxproj"
if grep -q 'signingConfigs.getByName("debug")' "$repo_root/android/app/build.gradle.kts"; then
  echo "Release build still uses the debug signing key." >&2
  exit 1
fi
echo "Static release assets and production-safety guards are present."
