# Move Presets to the Library Page — Implementation Plan

> **For agentic workers:** implement task-by-task; each task ends with a compiling commit and passing tests.

**Goal:** Move the Presets carousel from the Radio Stations page to the top of the Your Library page. Keep the ★ star on Radio Stations rows as the add control. Drop the "Presets" segment tab from Radio Stations.

**Architecture (Codex-reviewed):** Extract two shared `@Observable @MainActor` models, both owned as single instances by `MainContainerModel` and injected into the pages that need them:
- `StationPlaybackModel` — owns `stationSelected(_:)` + the welcome-message presentation flow (the station-play policy). `StationListModel` delegates to it; `YourLibraryPageModel` uses it for preset-tile taps.
- `PresetsModel` — owns all preset domain + section-UI state (the 3 `@Shared` preset keys, loading/error/edit state, `displayPresets` hydration, `isPreset`, `starTapped`, add/remove/reorder/retry, load-once guard). `StationListModel` uses it for the row ★; `YourLibraryPageModel` uses it for the carousel.

Preset state is already app-wide `@Shared` (`.presets`, `.pendingPresetStationIds`, `.pendingPresetRemovalStationIds`, all `.inMemory`), so a single shared model instance keeps both pages consistent without duplicated logic.

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

## Task 1: Extract `StationPlaybackModel`

**Deliverable:** A shared `StationPlaybackModel` owning the station-play policy; `StationListModel` delegates `stationSelected` to it. No behavior change.

**Files:**
- Create: `PlayolaRadio/Views/Shared/Playback/StationPlaybackModel.swift` (+ pbxproj registration)
- Create: `PlayolaRadio/Views/Shared/Playback/StationPlaybackModelTests.swift` (+ pbxproj)
- Modify: `StationListModel.swift` (delegate `stationSelected`; keep its signature so callers are unchanged)
- Modify: `MainContainerModel.swift` (own the shared instance, inject into `StationListModel`)

**Approach:**
- Move `stationSelected(_:)`, `shouldShowWelcomeMessage`, `presentWelcomeMessage`, and `welcomeMessageShownThisSession` (and only the dependencies/shared they need: `stationPlayer`, `analytics`, `@Shared(.showSecretStations)`, `@Shared(.welcomeMessageEligible)`, `@Shared(.stationLists)`, `@Shared(.mainContainerNavigationCoordinator)`) into `StationPlaybackModel`. Position analytics may use `stationLists` (full catalog) instead of the page-local `stationListsForDisplay`.
- `StationListModel` gets `let playbackModel: StationPlaybackModel` injected; its `stationSelected(_:)` becomes `await playbackModel.stationSelected(item)`. Preserve existing behavior.
- `MainContainerModel`: `let stationPlaybackModel = StationPlaybackModel()`, pass into `StationListModel(playbackModel:)`.

**Tests:** Move/port the station-selection + welcome-message tests that currently target `StationListModel.stationSelected` to target `StationPlaybackModel`. Keep coming-soon/inactive/welcome/play assertions. Verify build (both app targets) + full test suite + lint. Commit: `refactor(playback): extract StationPlaybackModel from StationListModel`.

---

## Task 2: Extract shared `PresetsModel`

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

## Task 3: Move the carousel to the Library page; remove it from Radio Stations

**Deliverable:** The user-visible move. Presets carousel renders at the top of Your Library; tapping a tile plays via `StationPlaybackModel`. Radio Stations loses the carousel + "Presets" segment tab but keeps the row ★.

**Files:**
- Modify: `YourLibraryPageModel.swift` (inject `presetsModel` + `playbackModel`; add `presetTileTapped(_:)` that tracks position analytics then `await playbackModel.stationSelected(display.stationItem)`; call `presetsModel.loadPresetsIfNeeded()` on appear)
- Modify: `YourLibraryPageView.swift` (render `PresetsCarousel` from `model.presetsModel` above the title/section area)
- Modify: `StationListPage.swift` (remove the `PresetsCarousel` block)
- Modify: `StationListModel.swift` (remove the "Presets" segment injection + special-casing in `loadStationListsForDisplay`; drop `showsPresetsSection`/`showsPresetsOnly`/segment-preset logic; keep the row ★ via `presetsModel`)
- Modify: `MainContainerModel.swift` (inject `presetsModel` + `stationPlaybackModel` into `YourLibraryPageModel`)

**Approach:**
- `YourLibraryPageModel` owns `presetTileTapped` (Codex's guidance: playback handler on the page, not `PresetsModel`), delegating to the shared `playbackModel`.
- Radio Stations segmented control: with the "Presets" segment removed, if only "All" remains, drop the segment selector and always show the full list (matches the earlier decision "keep All behavior, drop the Presets tab").
- Confirm the ★ still adds/removes (writes shared state) and the carousel on Library reflects it live.

**Tests:** Update `StationList` tests that asserted on the Presets segment. Add a `YourLibraryPageModel` test for `presetTileTapped` delegating to playback (or asserting the carousel data source). Verify both builds + full tests + lint. Manual sim check: Radio Stations shows no carousel/segment but ★ works; Library shows the carousel at top; tapping a preset plays; reorder/remove/edit work. Commit: `feat(library): move Presets carousel to Your Library page`.

---

## Self-review notes

- Playback kept out of `PresetsModel` (Codex). Single shared instances of both models (Codex) → no split load state, minimal race surface.
- Each task independently shippable; only Task 3 changes user-visible behavior.
- Load-once guard prevents double-fetch across the two pages.
- ★ stays on Radio Stations as the add control (product decision).
