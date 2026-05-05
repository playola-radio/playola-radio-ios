#!/bin/bash

set -e

echo "Create Release PR"
echo "=================="
echo ""

# Verify we're on develop with a clean working tree
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "develop" ]; then
  echo "Error: Must be on 'develop' branch (currently on '$current_branch')"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

# Fetch latest refs
git fetch origin main develop --quiet

echo "PRs in this release:"
echo "--------------------"
git log origin/main..origin/develop --merges --pretty=format:"%s" 2>/dev/null | grep "^Merge pull request" | grep -oE '#[0-9]+' | sort -t'#' -k1 -rn | uniq | while read pr; do
  num=${pr#\#}
  title=$(gh pr view "$num" --json title --jq '.title' 2>/dev/null)
  echo "  $pr: $title"
done
echo ""

read -p "Release title: " release_title

if [ -z "$release_title" ]; then
  echo "Release title is required. Exiting."
  exit 1
fi

echo ""
echo "Select version bump type:"
echo "  1) patch  - Bug fixes, small changes (0.0.X)"
echo "  2) minor  - New features, backwards compatible (0.X.0)"
echo "  3) major  - Breaking changes (X.0.0)"
echo ""

read -p "Enter choice [1-3]: " choice

case $choice in
  1) bump_type="patch" ;;
  2) bump_type="minor" ;;
  3) bump_type="major" ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

PBXPROJ="PlayolaRadio.xcodeproj/project.pbxproj"

# Get current version info
current_version=$(grep -m1 'MARKETING_VERSION' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' ')
current_build=$(grep 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);.*/\1/' | tr -d ' ' | sort -n | tail -1)

if [ -z "$current_version" ]; then
  echo "Error: could not detect MARKETING_VERSION from $PBXPROJ" >&2
  exit 1
fi

if ! [[ "$current_build" =~ ^[0-9]+$ ]]; then
  echo "Error: could not detect a numeric CURRENT_PROJECT_VERSION from $PBXPROJ (got '$current_build')" >&2
  exit 1
fi

# Calculate new version
IFS='.' read -r major minor patch <<< "$current_version"
case $bump_type in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
esac
new_version="${major}.${minor}.${patch}"
new_build=$((current_build + 1))

echo ""
echo "Release Summary"
echo "---------------"
echo "  Title:         $release_title"
echo "  Bump type:     $bump_type"
echo "  Version:       $current_version -> $new_version"
echo "  Build number:  $current_build -> $new_build"
echo ""

read -p "Proceed? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 1
fi

release_branch="release/${new_version}"

echo ""
echo "Creating release branch..."
git checkout -b "$release_branch"

echo ""
echo "Bumping version..."
sed -i '' "s/MARKETING_VERSION = ${current_version};/MARKETING_VERSION = ${new_version};/g" "$PBXPROJ"
agvtool new-version -all "$new_build"

echo ""
echo "Committing..."
git add -A
git commit -m "Bump version to $new_version ($new_build)"

echo ""
echo "Pushing release branch..."
git push -u origin "$release_branch"

echo ""
echo "Creating PR..."

# Build PR body with changelog
pr_body="## $release_title

### Changes
$(git log origin/main..origin/develop --merges --pretty=format:"%s" 2>/dev/null | grep "^Merge pull request" | grep -oE '#[0-9]+' | sort -t'#' -k1 -rn | uniq | while read pr; do
  num=${pr#\#}
  title=$(gh pr view "$num" --json title --jq '.title' 2>/dev/null)
  echo "- $pr: $title"
done)

### Version
\`$new_version\` (build \`$new_build\`)"

gh pr create \
  --base main \
  --head "$release_branch" \
  --title "Release $new_version: $release_title" \
  --body "$pr_body"

echo ""
echo "Switching back to develop..."
git checkout develop

echo ""
echo "Done! Merge the PR on GitHub — main will auto-merge back to develop."
