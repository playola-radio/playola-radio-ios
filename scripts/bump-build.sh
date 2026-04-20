#!/bin/bash

set -e

echo "Create Hotfix Build Bump PR"
echo "==========================="
echo ""

current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "develop" ]; then
  echo "Error: Must be on 'develop' branch (currently on '$current_branch')"
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: Working tree is not clean. Commit or stash changes first."
  exit 1
fi

git fetch origin main develop --quiet
git fetch origin --tags --quiet

current_version=$(agvtool what-marketing-version -terse1 | head -1)
current_build=$(agvtool what-version -terse | sort -n | tail -1)
new_build=$((current_build + 1))

last_tag=$(git describe --tags --abbrev=0 origin/main 2>/dev/null || echo "")

echo "Hotfix Summary"
echo "--------------"
echo "  Version:       $current_version (unchanged)"
echo "  Build number:  $current_build -> $new_build"
echo "  Last tag:      ${last_tag:-<none>}"
echo ""

if [ -n "$last_tag" ]; then
  echo "PRs since $last_tag:"
  echo "----------------------"
  git log "$last_tag..origin/develop" --first-parent --pretty=format:"%s" 2>/dev/null | grep -oE '#[0-9]+' | sort -t'#' -k1 -rn | uniq | while read pr; do
    num=${pr#\#}
    title=$(gh pr view "$num" --json title --jq '.title' 2>/dev/null)
    echo "  $pr: $title"
  done
  echo ""
fi

read -p "Proceed? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
  echo "Aborted."
  exit 1
fi

hotfix_branch="hotfix/${current_version}-b${new_build}"

echo ""
echo "Creating hotfix branch..."
git checkout -b "$hotfix_branch"

echo ""
echo "Bumping build number..."
agvtool new-version -all "$new_build"

echo ""
echo "Committing..."
git add -A
git commit -m "Bump build number to $new_build"

echo ""
echo "Pushing hotfix branch..."
git push -u origin "$hotfix_branch"

echo ""
echo "Creating PR..."

changes_section=""
if [ -n "$last_tag" ]; then
  changes_section=$(git log "$last_tag..origin/develop" --first-parent --pretty=format:"%s" 2>/dev/null | grep -oE '#[0-9]+' | sort -t'#' -k1 -rn | uniq | while read pr; do
    num=${pr#\#}
    title=$(gh pr view "$num" --json title --jq '.title' 2>/dev/null)
    echo "- $pr: $title"
  done)
fi

pr_body="Build-only bump — no version change. Rebuilds \`$current_version\` as build \`$new_build\` so CircleCI uploads a fresh TestFlight build under the same version.

> ⚠️ **Merge this PR using \"Create a merge commit\". Do NOT squash.**
>
> Squashing collapses merge history on \`main\` and the next release's PR list will re-include PRs that already shipped. Use a merge commit to preserve the first-parent chain.

### Changes since last build
${changes_section:-_No PRs merged to develop since ${last_tag:-initial}._}

### Version
\`$current_version\` (build \`$new_build\`)"

gh pr create \
  --base main \
  --head "$hotfix_branch" \
  --title "Hotfix: $current_version build $new_build" \
  --body "$pr_body"

echo ""
echo "Switching back to develop..."
git checkout develop

echo ""
echo "Done! Merge the PR on GitHub using 'Create a merge commit'."
