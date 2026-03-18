#!/bin/bash
set -euo pipefail

# Setup secrets by copying from the original playola-radio-ios repo.
# Usage: ./scripts/setup-secrets.sh [source_repo_path]
# Default source: ~/playola/playola-radio-ios

SOURCE_REPO="${1:-$HOME/playola/playola-radio-ios}"
SOURCE_DIR="$SOURCE_REPO/PlayolaRadio/Config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/../PlayolaRadio/Config"

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

if [ ! -d "$DEST_DIR" ]; then
  echo "Error: Destination directory not found at $DEST_DIR"
  exit 1
fi

copied=0
skipped=0

for file in "${FILES[@]}"; do
  if [ ! -f "$SOURCE_DIR/$file" ]; then
    echo "  SKIP  $file (not found in source)"
    skipped=$((skipped + 1))
    continue
  fi

  if [ -f "$DEST_DIR/$file" ]; then
    echo "  EXISTS $file (already present, skipping)"
    skipped=$((skipped + 1))
    continue
  fi

  cp "$SOURCE_DIR/$file" "$DEST_DIR/$file"
  echo "  COPIED $file"
  copied=$((copied + 1))
done

echo ""
echo "Done: $copied copied, $skipped skipped"
