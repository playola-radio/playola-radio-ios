# App Store Screenshots

Git is the source of truth for our App Store screenshots. The images that live
under `fastlane/screenshots/<locale>/` are exactly what appears on the store —
edit them here, review the diff in a PR, and upload with one command.

Managed **screenshots only**. Metadata (description, keywords, promo text) and
the binary are intentionally out of scope — the `screenshots` lane and the
`Deliverfile` are locked so a run can never touch them.

## The loop

### 1. Seed / re-sync the baseline (first time, or to check for drift)

Pull whatever is currently on the store into this folder. Download into a clean
temp dir and replace, because `download_screenshots` only *writes* files — it
never deletes local ones, so a stale PNG (removed on ASC) would otherwise survive
with a clean `git status` and get re-uploaded:

```sh
rm -rf /tmp/asc_shots && mkdir -p /tmp/asc_shots
bundle exec fastlane deliver download_screenshots \
  --use_live_version true \
  --screenshots_path /tmp/asc_shots
rm -rf fastlane/screenshots/en-US && mv /tmp/asc_shots/en-US fastlane/screenshots/
```

`--use_live_version true` pulls the **currently live** set (without it, deliver
targets the editable "Prepare for Submission" version instead). Uses the Apple ID
in `fastlane/Appfile` (expect a 2FA prompt). Commit the result so the repo
reflects the live state — after the replace above, a clean `git status` means git
and the store match.

### 2. Replace the images

**iPhone shots are generated** — build the Debug app and run
`fastlane/capture-screenshots.sh` (see the header of that script and
`PlayolaRadio/ScreenshotHarness.swift`). Every shot is deterministic fixture
data; no account or manual navigation needed.

**iPad shots are still manual**: create an iPad Pro (12.9-inch) (6th generation)
sim on iOS 18.1+, sign in with a real account, navigate, and
`xcrun simctl io <udid> screenshot`.

Notes on the files in `fastlane/screenshots/en-US/`:

- **Device is auto-detected from the image resolution**, so all sizes live in the
  same locale folder together — **except iPad Pro 12.9", which needs an explicit
  device marker in the filename** (`IPAD_PRO_3GEN_129`, as in the existing files);
  resolution alone can misclassify 2nd- vs 3rd-gen. Keep that token in iPad names.
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

Opens an HTML preview for confirmation, then replaces the screenshot set on the
editable "Prepare for Submission" version — i.e. staged for the **next** App Store
release, not the currently-live listing. No review submission.

## Keeping in sync

Tie a refresh to the release process: when a `release/X.Y.Z` branch involves a
material UI change, refresh the relevant screenshots in the **same PR** (steps 2–3)
so the store never drifts from the shipped UI. The re-sync in step 1 (download to
a temp dir, replace, then `git status`) is the cheap way to audit whether they've
gone stale.

## Message-match (why the first shots matter most)

Most installs arrive via direct links (Facebook ads, artist posts), not App Store
browsing. For that traffic the first 1–2 screenshots do a **reassurance** job, not
a cold-sell job: make them visually echo the referring ad/post so the tapper sees
"yes, this is the thing I was just told about." Match the ad's language and station
art in slots 0–1; skip generic marketing-caption polish.
