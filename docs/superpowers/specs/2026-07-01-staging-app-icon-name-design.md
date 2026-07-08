# Staging App Icon & Name — Design

**Date:** 2026-07-01
**Branch:** `briankeane/staging-app-icon-name`

## Problem

The `PlayolaRadio Staging` build is visually indistinguishable from production. All
three staging build configurations set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`
— the *same* icon production uses — and the display name `"Playola Radio Staging"`
truncates on the home screen to roughly "Playola Ra…". Testers who have both apps
installed confuse the two.

Goal: make the staging app unmistakable at a glance (home screen, app switcher,
Spotlight) while leaving production completely untouched.

## Changes

### 1. Display name (staging configs only)

`INFOPLIST_KEY_CFBundleDisplayName`: `"Playola Radio Staging"` → **`⚠️ Playola Staging`**

- Home screen shows ~"⚠️ Playola…"; the ⚠️ flag distinguishes it instantly.
- Spotlight/search matches the full display name, so searching "Staging" finds it.
- Must remain non-empty: an empty `CFBundleDisplayName` silently breaks Siri App
  Shortcuts SSU phrase templates, which this app relies on.

### 2. New staging icon set

New `AppIcon-Staging.appiconset` inside the existing `PlayolaRadio/Assets.xcassets`.

- Asset catalogs are folder-referenced (the whole `.xcassets` is a single project
  reference), so adding a new `.appiconset` inside it does **not** require a
  `project.pbxproj` file registration. Only the build-setting change in #3 is needed.
- Restyled from the same coral "P" master:
  - **Background:** near-black → **deep purple** (~`#4A1D96`).
  - **P glyph:** kept coral (contrasts well on purple).
  - **Ribbon:** diagonal **amber "STAGING" banner** across the lower-left corner.
- Generated at 1024×1024 with ImageMagick, then downscaled to all 25 sizes used by
  the production `AppIcon.appiconset`. `Contents.json` mirrors the production set
  exactly (same size/idiom/scale entries, same filenames).

### 3. Build-setting wiring (staging configs only)

`ASSETCATALOG_COMPILER_APPICON_NAME`: `AppIcon` → **`AppIcon-Staging`**

Applied to all three `PlayolaRadio Staging` build configurations (Debug / Release /
Staging). Production configs are not touched.

## Out of scope / untouched

- Production `AppIcon.appiconset` and the production target's display name (`Playola`).
- Any runtime code, bundle identifiers, signing, or the `Info-Staging.plist` contents
  (unless it turns out `CFBundleDisplayName` is hard-set in the plist rather than via
  the `INFOPLIST_KEY_*` build setting — verify during implementation and set it in the
  correct place, but do not otherwise modify the plist).

## Verification

1. `AppIcon-Staging.appiconset` contains all 25 PNGs referenced by `Contents.json`,
   each at correct pixel dimensions.
2. Render the generated 1024 icon for visual eyeball before completion.
3. Build the `PlayolaRadio Staging` scheme — must compile with no asset-catalog
   warnings (warnings are errors on the staging target).
4. Production `AppIcon` files and prod build settings are byte-for-byte unchanged
   (confirm via `git diff`).
