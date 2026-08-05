# App Store Screenshots

Git is the source of truth for our App Store screenshots. The images that live
under `fastlane/screenshots/<locale>/` are exactly what appears on the store —
edit them here, review the diff in a PR, and upload with one command.

Managed **screenshots only**. Metadata (description, keywords, promo text) and
the binary are intentionally out of scope — the `screenshots` lane and the
`Deliverfile` are locked so a run can never touch them.

## The loop

### 1. Seed / re-sync the baseline (first time, or to check for drift)

Pull whatever is currently live into this folder:

```sh
bundle exec fastlane deliver download_screenshots
```

Uses the Apple ID in `fastlane/Appfile` (expect a 2FA prompt). Commit the result
so the repo reflects the live state. Running this later is also how you confirm
git and the store haven't drifted apart — a clean `git status` means they match.

### 2. Replace the images

Drop new PNGs into `fastlane/screenshots/en-US/`. Notes:

- **Device is auto-detected from the image resolution**, so all sizes live in the
  same locale folder together.
- **Ordering is alphabetical.** Prefix filenames to control slot order, e.g.
  `0_home.png`, `1_player.png`, `2_giveaway.png`.
- **Provide the full set per device size before uploading.** The lane uses
  `overwrite_screenshots`, which replaces the entire live set — a partial folder
  means missing sizes get wiped. If unsure which sizes are required, re-run the
  download in step 1 and match what's there.

### 3. Upload

```sh
bundle exec fastlane screenshots
```

Opens an HTML preview for confirmation, then replaces the live screenshots. No
review submission — the assets are staged on the next version.

## Keeping in sync

Tie a refresh to the release process: when a `release/X.Y.Z` branch involves a
material UI change, refresh the relevant screenshots in the **same PR** (steps 2–3)
so the store never drifts from the shipped UI. A quick `download_screenshots` +
`git status` is the cheap way to audit whether they've gone stale.

## Message-match (why the first shots matter most)

Most installs arrive via direct links (Facebook ads, artist posts), not App Store
browsing. For that traffic the first 1–2 screenshots do a **reassurance** job, not
a cold-sell job: make them visually echo the referring ad/post so the tapper sees
"yes, this is the thing I was just told about." Match the ad's language and station
art in slots 0–1; skip generic marketing-caption polish.
