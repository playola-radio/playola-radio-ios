# Move Presets to the Library Page — Implementation Plan

> **For agentic workers:** implement task-by-task; each task ends with a compiling commit and passing tests.

**Goal:** Move the Presets carousel from the Radio Stations page to the top of the Your Library page. Keep the ★ star on Radio Stations rows as the add control. Drop the "Presets" segment tab from Radio Stations.

**Architecture (Codex-reviewed, then simplified):** Extract ONE shared `@Observable @MainActor` model — `PresetsModel` — owned as a single instance by `MainContainerModel` and injected into both pages:
- `PresetsModel` — owns all preset domain + section-UI state (the 3 `@Shared` preset keys, loading/error/edit state, `displayPresets` hydration, `isPreset`, `starTapped`, add/remove/reorder/retry, load-once guard). `StationListModel` uses it for the row ★; `YourLibraryPageModel` uses it for the carousel.

Preset state is already app-wide `@Shared` (`.presets`, `.pendingPresetStationIds`, `.pendingPresetRemovalStationIds`, all `.inMemory`), so a single shared model instance keeps both pages consistent without duplicated logic.

**Playback:** no `StationPlaybackModel` is extracted. The `stationPlayer` dependency already unifies playback, and the player sheet auto-presents off `stationPlayer.$state` (`MainContainerModel.processNewStationState`). `stationSelected` only adds visibility guards, analytics, and the first-time welcome-message intro on top of `stationPlayer.play` — none of which are needed for tapping an already-saved preset. So `YourLibraryPageModel.presetTileTapped` calls `stationPlayer.play(station:)` directly (plus the existing preset-tap analytics). `PresetsModel` does not own playback.

**Tech Stack:** SwiftUI, Point-Free swift-dependencies + swift-sharing + swift-identified-collections, `@Observable` MV models, swift-testing.

## Global Constraints

- No environment gating.
- `develop` must stay deployable: each commit compiles and all tests pass; no user-visible change until Task 3.
- Models own all display text/behavior; Views are visuals only, zero control flow.
- Every test suite carries `@Suite(.freshSharedState)`; declare `@Shared` locally per test.
- New `.swift` files hand-registered in `project.pbxproj` (App + Staging + Test targets), mirroring an existing sibling.
- Use `$shared.withLock` for every optimistic read-modify-write (already the pattern).
- Activate the relevant `pfw-*` skills before writing Swift (pfw-observable-models, pfw-sharing, pfw-dependencies, pfw-testing, pfw-identified-collections).
- Build with Xcode 26.5.0 (`DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer`), iPhone 16 sim id `F5BE1DBA-3185-40E9-9755-5C48D8B1A230`, `-skipPackagePluginValidation`. Run `make lint` before committing.

## Current state (verified)

- All preset logic lives in `PlayolaRadio/Views/Pages/StationListPage/StationListModel.swift`. `PresetDisplayItem` (lines ~15-50) and `PresetListState` (~52-55) are declared at the top of that file.
- The play path `stationSelected(_:)` (lines 329-376) does: coming-soon/inactive guards → analytics → `shouldShowWelcomeMessage`/`presentWelcomeMessage` → `analytics.startedStation` → `stationPlayer.play`. It reads `showSecretStations`, `stationListsForDisplay`, `welcomeMessageEligible`, `welcomeMessageShownThisSession`, and presents via the nav coordinator.
- View components are in `StationListPage/Presets/`: `PresetsCarousel.swift`, `PresetTile.swift`, `PresetStarButton.swift` — all prop/closure-driven, zero model coupling.
- `MainContainerModel` currently does `var stationListModel = StationListModel()` and `var yourLibraryPageModel = YourLibraryPageModel()`.
- Preset tests: `StationListPresetTests.swift`, `StationListPresetErrorReportingTests.swift`, `StationListPresetComingSoonTests.swift` (they exercise the model API that is moving).

---

## Task 1: Extract shared `PresetsModel`

**Deliverable:** A single shared `PresetsModel`; `StationListModel` delegates the row ★ and carousel props to it. Move preset types + view folder to shared locations. No behavior change (carousel + star still render on Radio Stations for now).

**Files:**
- Create: `PlayolaRadio/Views/Shared/Presets/PresetsModel.swift`, `PresetDisplayItem.swift`, `PresetListState.swift` (+ pbxproj)
- Move: `StationListPage/Presets/` view components → `PlayolaRadio/Views/Shared/Presets/` (`PresetsCarousel.swift`, `PresetTile.swift`, `PresetStarButton.swift`) (update pbxproj paths)
- Create: `PlayolaRadio/Views/Shared/Presets/PresetsModelTests.swift` (+ pbxproj) — port from `StationListPreset*Tests.swift`
- Modify: `StationListModel.swift` (remove preset state/logic; hold injected `presetsModel`; delegate `isPreset`, `starTapped`, `displayPresets`, and the carousel-driving computed props)
- Modify: `StationListPage.swift` (carousel + row star read from `model.presetsModel`)
- Modify: `MainContainerModel.swift` (own shared `presetsModel`, inject into `StationListModel`)

**Approach:**
- `PresetsModel`: `@MainActor @Observable`, subclass `ViewModel`. Move the 3 `@Shared` preset keys, `@Dependency(\.api)`, `@Dependency(\.analytics)`, `errorReporting`, `@Shared(.stationLists)`, `@Shared(.showSecretStations)`, `@Shared(.auth)`. Move: `presetListState`, `isLoadingPresets`, `presetsLoadFailed`, section-title/empty/edit/error/retry string constants, `displayPresets`, `isPreset`, `presetStarAccessibilityLabel`, `starTapped`, `presetMoved`, `presetTileLongPressed`, `presetRemoveTapped`, `presetsEditDoneTapped`, `backgroundTappedOutsidePresets`, `retryLoadPresetsTapped`, `addPreset`, `removePreset`, `reportPresetError`, `loadPresets`, and view-helper props (`isEditingPresets`, `showsPresetsSection`/`showsPresetsOnly` may be dropped — they were segment-driven; see Task 3).
- Add a load-once guard: `private var hasLoadedPresets = false; func loadPresetsIfNeeded() async { guard !hasLoadedPresets, !isLoadingPresets else { return }; await loadPresets() }`. `retryLoadPresetsTapped` forces reload.
- Preset tile **play** is NOT on `PresetsModel`. Leave `presetTileTapped` off `PresetsModel`; the owning page handles it (Task 3 wires it to `StationPlaybackModel`).
- `StationListModel`: inject `let presetsModel: PresetsModel`; its `viewAppeared` calls `await presetsModel.loadPresetsIfNeeded()`; row code delegates to `presetsModel.isPreset/starTapped`; keep the carousel rendering here for now (driven by `presetsModel`) so behavior is unchanged this task.

**Tests:** Port `StationListPreset*Tests` to `PresetsModelTests` targeting `PresetsModel`. Verify both builds + full tests + lint. Commit: `refactor(presets): extract shared PresetsModel and move preset views/types`.

---

## Task 2: Move the carousel to the Library page; remove it from Radio Stations

**Deliverable:** The user-visible move. Presets carousel renders at the top of Your Library; tapping a tile plays via `stationPlayer.play`. Radio Stations loses the carousel + "Presets" segment tab but keeps the row ★.

**Files:**
- Modify: `YourLibraryPageModel.swift` (inject `presetsModel`; add `@Dependency(\.stationPlayer)` + `@Dependency(\.analytics)`; add `presetTileTapped(_:)` that tracks the `.presetTileTapped` analytics then `await stationPlayer.play(station: display.stationItem.anyStation)`; call `presetsModel.loadPresetsIfNeeded()` on appear)
- Modify: `YourLibraryPageView.swift` (render `PresetsCarousel` from `model.presetsModel` above the title/section area)
- Modify: `StationListPage.swift` (remove the `PresetsCarousel` block)
- Modify: `StationListModel.swift` (remove the "Presets" segment injection + special-casing in `loadStationListsForDisplay`; drop `showsPresetsSection`/`showsPresetsOnly`/segment-preset logic; keep the row ★ via `presetsModel`)
- Modify: `MainContainerModel.swift` (inject the shared `presetsModel` into `YourLibraryPageModel`)

**Approach:**
- `YourLibraryPageModel` owns `presetTileTapped` (playback handler on the page, not `PresetsModel`), calling `stationPlayer.play(station:)` directly. The player sheet auto-presents via existing `stationPlayer.$state` observation in `MainContainerModel`.
- Radio Stations segmented control: with the "Presets" segment removed, if only "All" remains, drop the segment selector and always show the full list (matches the earlier decision "keep All behavior, drop the Presets tab").
- Confirm the ★ still adds/removes (writes shared state) and the carousel on Library reflects it live.

**Tests:** Update `StationList` tests that asserted on the Presets segment. Add a `YourLibraryPageModel` test for `presetTileTapped` delegating to playback (or asserting the carousel data source). Verify both builds + full tests + lint. Manual sim check: Radio Stations shows no carousel/segment but ★ works; Library shows the carousel at top; tapping a preset plays; reorder/remove/edit work. Commit: `feat(library): move Presets carousel to Your Library page`.

---

## Self-review notes

- Playback kept out of `PresetsModel`; preset taps call `stationPlayer.play` directly (the player already unifies playback + auto-presents the sheet). No `StationPlaybackModel` — that was cut as over-engineering.
- Single shared `PresetsModel` instance (Codex) → no split load state, minimal race surface.
- Each task independently shippable; only Task 2 changes user-visible behavior.
- Load-once guard prevents double-fetch across the two pages.
- ★ stays on Radio Stations as the add control (product decision).
