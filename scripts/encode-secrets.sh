#!/bin/bash
set -euo pipefail

# Encode the four Secrets-*.xcconfig files as base64 for CircleCI env vars.
# Prints `VAR=<base64>` lines to stdout, one per file, suitable for pasting
# into the CircleCI `ios-release` context.
#
# Usage: ./scripts/encode-secrets.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../PlayolaRadio/Config"

# File -> env var name pairs.
FILES=(
  "Secrets.xcconfig:SECRETS_XCCONFIG_B64"
  "Secrets-Local.xcconfig:SECRETS_LOCAL_XCCONFIG_B64"
  "Secrets-Development.xcconfig:SECRETS_DEVELOPMENT_XCCONFIG_B64"
  "Secrets-Staging.xcconfig:SECRETS_STAGING_XCCONFIG_B64"
)

missing=()
for pair in "${FILES[@]}"; do
  file="${pair%%:*}"
  if [ ! -f "$CONFIG_DIR/$file" ]; then
    missing+=("$CONFIG_DIR/$file")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Error: required secrets file(s) not found:" >&2
  for path in "${missing[@]}"; do
    echo "  $path" >&2
  done
  echo "Run ./scripts/setup-secrets.sh first to copy them from the release machine." >&2
  exit 1
fi

for pair in "${FILES[@]}"; do
  file="${pair%%:*}"
  var="${pair##*:}"
  encoded="$(base64 -i "$CONFIG_DIR/$file")"
  echo "${var}=${encoded}"
done
