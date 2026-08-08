---
name: capture-screenshots
description: Use when refreshing, updating, or replacing the App Store screenshots for the Playola iOS app — capturing new simulator screenshots and filing them for the fastlane deliver/screenshots lane (screenshots are stale/out of date).
---

# Capture App Store Screenshots

## Overview

Capturing a screenshot is one command (`xcrun simctl io <udid> screenshot`). The
work is everything around it: resolving a unique simulator, a clean status bar,
correct resolutions, exact `deliver` filenames, and getting the app to each
screen. The app is **auth-gated and has no deep links**, so navigation is manual
— but `capture.sh` in this skill folder automates all the fiddly parts so you
only tap through the app.

Upload is handled by the existing `fastlane screenshots` lane (see
`fastlane/screenshots/README.md`). This skill only covers *producing* the images.

## Prerequisites

- **Auth is already wired locally.** The `screenshots` lane reads an App Store
  Connect API key from env that is already set on this machine — do **not** go
  hunting for a `.p8`; just run the lane when done.
- **Xcode 26.5** is required for the build (`capture.sh` pins it; the machine
  default is a beta that fails this repo's warnings-as-errors build).
- **A real Playola account** (your own, or ask the team) to sign into on each
  simulator so screens show live data — pick one with a good-looking library and
  followed stations. There is no demo/bypass login. (`setup` builds Debug with
  normal development signing — required so the keychain works; without proper
  signing, Google sign-in fails silently with keychain error -34018. Dev and prod
  point at the same backend, so the content is the real thing regardless.)
- **Simulator language = English** (Settings → General → Language & Region) so the
  captured UI text matches the `en-US` slot.

## Device & filename reference

Standardize on these two devices so every image matches an App Store slot exactly.
`deliver` infers the device from the resolution and the **leading number sets slot
order** — but keep the `IPAD_PRO_3GEN_129` token in the iPad filenames: resolution
alone can misclassify the 12.9" iPad as 2nd- vs 3rd-gen, so that marker is load-bearing:

| Slot set | Simulator | Resolution | Filenames |
|----------|-----------|-----------|-----------|
| iPhone (5 shots) | iPhone 16 Pro Max | 1320×2868 (6.9") | `0_APP_IPHONE_67_0.png` … `4_APP_IPHONE_67_4.png` |
| iPad (2 shots) | iPad Pro (12.9-inch) (6th generation) | 2048×2732 | `0_APP_IPAD_PRO_3GEN_129_0.png`, `1_..._1.png` |

**Put all iPhone shots on the 16 Pro Max (1320×2868).** The old baseline mixed
1320×2868 and 1290×2796 — don't reproduce that; a single resolution avoids ASC
size-mismatch ambiguity. Do **not** use "iPad Pro 13-inch (M4/M5)" (2064×2752 —
wrong size).

## Steps

1. **Set up** — boots both sims, cleans the status bar, builds + installs the
   production app:

   ```sh
   .claude/skills/capture-screenshots/capture.sh setup
   ```

2. **Sign in** on each simulator (Apple or Google) with a real account.
3. **Navigate + capture** each screen. Recommended shot list (mirror the current
   store order): **iPhone** — 0 = Home, 1 = Player / now-playing, 2 = Stations
   list, 3 = Library, 4 = a feature/giveaway screen; **iPad** — 0 = Home,
   1 = Player.

   ```sh
   .claude/skills/capture-screenshots/capture.sh iphone 0   # after navigating to Home
   .claude/skills/capture-screenshots/capture.sh iphone 1   # …and so on
   .claude/skills/capture-screenshots/capture.sh ipad 0
   ```

   The script re-applies the clean status bar and prints the captured resolution
   each time — verify it matches the table above.
4. **Message-match the first slots.** Most installs are direct-referral (FB ad /
   artist post), not App Store browsing, so slots 0–1 should visually echo the
   referring creative (see `fastlane/screenshots/README.md`).
5. **Review & upload.** `git status` the folder, eyeball the diff, then:

   ```sh
   bundle exec fastlane screenshots   # HTML preview → updates the next-release (edit) version
   ```

## Common mistakes

- **Bare device name → "multiple devices matched."** Device-type names aren't
  unique; `capture.sh` resolves a UDID for you. Don't `simctl boot "iPhone 16 Pro Max"`.
- **Partial set wipes the store.** The lane uses `overwrite_screenshots`. If your
  new set has fewer/renamed files than what's in `fastlane/screenshots/en-US/`,
  `rm` the old PNGs first so no stale slot survives.
- **iPad sim on too-old iOS → install fails ("Requires a Newer Version").** The
  app's min is iOS 18.1, but the stock "iPad Pro (12.9-inch) (6th generation)" sim
  may be on an older runtime. Create a compatible one (same name so the script
  resolves it, then re-run `setup`):

  ```sh
  xcrun simctl create "iPad Pro (12.9-inch) (6th generation)" \
    com.apple.CoreSimulator.SimDeviceType.iPad-Pro-12-9-inch-6th-generation-8GB \
    com.apple.CoreSimulator.SimRuntime.iOS-18-1
  ```

- **Live-gated screens are blank when no station is live.** The giveaway banner
  and LIVE badge only render when a station is actually live. Capture those while
  a station is live, or source that slot another way.
- **Hunting for the ASC key.** It's already in the local env — just run the lane.
- **Re-running `setup` every time.** Run it once. After you're set up and logged
  in, just re-capture (`iphone N` / `ipad N`) — you only need `setup` again after
  the app code changes (it rebuilds, which is slow).
- **Marketing captions/frames.** The baseline images are plain simulator
  captures. Adding device frames or caption text is a separate design step, out
  of scope here.
