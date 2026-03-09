#!/bin/bash

set -e

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

current_build=$(agvtool what-version -terse | sort -n | tail -1)
new_build=$((current_build + 1))

echo "Bumping build number: $current_build -> $new_build"
agvtool new-version -all "$new_build"

git add -A
git commit -m "Bump build number to $new_build"

current_version=$(agvtool what-marketing-version -terse1 | head -1)
echo ""
echo "Done: $current_version ($new_build)"

if [ "$1" = "--push" ]; then
  echo "Pushing..."
  git push
  echo "Pushed."
fi
