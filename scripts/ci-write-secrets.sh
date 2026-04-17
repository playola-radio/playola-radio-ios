#!/bin/bash
set -euo pipefail

# Decode the four SECRETS_*_B64 env vars and write them into
# PlayolaRadio/Config/ so that xcodebuild can find the xcconfig files.
# Intended to run on CircleCI before `fastlane build_app`.
#
# Usage: ./scripts/ci-write-secrets.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../PlayolaRadio/Config"

# Env var -> destination filename pairs.
VARS=(
  "SECRETS_XCCONFIG_B64:Secrets.xcconfig"
  "SECRETS_LOCAL_XCCONFIG_B64:Secrets-Local.xcconfig"
  "SECRETS_DEVELOPMENT_XCCONFIG_B64:Secrets-Development.xcconfig"
  "SECRETS_STAGING_XCCONFIG_B64:Secrets-Staging.xcconfig"
)

missing=()
for pair in "${VARS[@]}"; do
  var="${pair%%:*}"
  if [ -z "${!var:-}" ]; then
    missing+=("$var")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Error: required env var(s) not set:" >&2
  for var in "${missing[@]}"; do
    echo "  $var" >&2
  done
  echo "Set them in the CircleCI context that runs this job." >&2
  exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Error: config directory not found at $CONFIG_DIR" >&2
  exit 1
fi

for pair in "${VARS[@]}"; do
  var="${pair%%:*}"
  file="${pair##*:}"
  printf '%s' "${!var}" | base64 --decode > "$CONFIG_DIR/$file"
  echo "  WROTE $file"
done
