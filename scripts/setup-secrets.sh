#!/bin/bash
set -euo pipefail

# Setup secrets by copying from the original playola-radio-ios repo.
# Usage: ./scripts/setup-secrets.sh [source_repo_path]
# Default source: ~/playola/playola-radio-ios

SOURCE_REPO="${1:-$HOME/playola/playola-radio-ios}"
SOURCE_DIR="$SOURCE_REPO/PlayolaRadio/Config"
DEST_DIR="$(cd "$(dirname "$0")/../PlayolaRadio/Config" && pwd)"

FILES=(
  "Secrets.xcconfig"
  "Secrets-Local.xcconfig"
  "Secrets-Development.xcconfig"
  "Secrets-Staging.xcconfig"
)

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source repo not found at $SOURCE_REPO"
  echo "Usage: $0 [path/to/playola-radio-ios]"
  exit 1
fi

copied=0
skipped=0

for file in "${FILES[@]}"; do
  if [ ! -f "$SOURCE_DIR/$file" ]; then
    echo "  SKIP  $file (not found in source)"
    ((skipped++))
    continue
  fi

  if [ -f "$DEST_DIR/$file" ]; then
    echo "  EXISTS $file (already present, skipping)"
    ((skipped++))
    continue
  fi

  cp "$SOURCE_DIR/$file" "$DEST_DIR/$file"
  echo "  COPIED $file"
  ((copied++))
done

echo ""
echo "Done: $copied copied, $skipped skipped"
