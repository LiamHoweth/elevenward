#!/usr/bin/env bash
set -euo pipefail

platform="${1:-}"
required=(API_URL GOOGLE_CLIENT REVENUECAT_KEY CONTENT_KEY)

case "$platform" in
  android)
    required+=(KEYSTORE_B64 KEY_ALIAS KEY_PASSWORD STORE_PASSWORD)
    ;;
  ios)
    required+=(
      IOS_CERTIFICATE_B64
      IOS_CERTIFICATE_PASSWORD
      IOS_PROFILE_B64
      KEYCHAIN_PASSWORD
      GOOGLE_IOS_CLIENT
      GOOGLE_REVERSED_CLIENT
    )
    ;;
  *)
    echo "Usage: $0 android|ios" >&2
    exit 2
    ;;
esac

missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done

if (( ${#missing[@]} > 0 )); then
  printf 'Missing required release configuration: %s\n' "${missing[*]}" >&2
  exit 1
fi

[[ "$API_URL" == https://* ]] || {
  echo "API_URL must use HTTPS." >&2
  exit 1
}

echo "Required $platform release configuration is present."
