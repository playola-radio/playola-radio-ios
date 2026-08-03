# Move Rewards to a Profile button; replace the Rewards tab with a "Your Library" tab

**Date:** 2026-07-28
**Status:** Superseded — the "blank placeholder" scope below was the first step only. The
Your Library page now hosts the Presets carousel and a Liked Songs section (see
`docs/superpowers/plans/2026-07-28-presets-to-library.md`). This document is kept as the
original tab-move spec; sections describing Your Library as blank no longer reflect the code.

## Goal

- Remove the **Rewards** tab from the listening-mode tab bar.
- Add a **"Your Library"** tab in its place (heart icon), for now a blank placeholder showing only a title header.
- Make the Rewards page reachable via a button on the Profile page (the `ContactPage`), pushed onto the Profile nav stack.
- The Rewards button **replaces** the existing Liked Songs button in the Profile button list. Liked Songs becomes unreachable for now.

## Current structure (from exploration)

- Tabs are declared in `PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift` as `@ViewBuilder` computed properties, each with an inline `.tabItem` (icon + title) and a `.tag(ActiveTab.<case>)`. Listening mode shows `home / stations / rewards / profile`.
- `ActiveTab` is a bare enum in `MainContainer/MainContainerModel.swift` (no icon/title metadata on it).
- Navigation is centralized in `Core/Navigation/MainContainerNavigationCoordinator.swift`: per-tab `NavigationStack` paths (`homePath`, `rewardsPath`, `profilePath`, …) plus a `Path` enum for pushes and a `PlayolaSheet` slot for sheets. The `path` getter/setter and `clearAllPaths()` switch exhaustively over `ActiveTab`.
- The Profile tab renders `ContactPageView` / `ContactPageModel` (`Views/Pages/ContactPage/`). It has a vertical list of red action-button rows. **Liked Songs** is the pattern to mirror: `ContactPageView` button → `model.onLikedSongsTapped()` → `mainContainerNavigationCoordinator.path.append(.likedSongsPage(likedSongsPageModel))`.
- Rewards page: `Views/Pages/RewardsPage/RewardsPageView.swift` + `RewardsPageModel.swift`. Currently a tab root; renders its own title and has no back button, so pushing it onto a nav stack fits.
- There is already a **broadcast-mode** `.library` case + `libraryPath` (a distinct concept). The new listening tab must NOT collide with it.

## Changes

### 1. New "Your Library" tab (blank placeholder)

- Rename `ActiveTab.rewards` → `ActiveTab.yourLibrary`.
- Rename coordinator `rewardsPath` → `yourLibraryPath`; update the `path` switch and `clearAllPaths()`.
- New files (registered in `project.pbxproj`):
  - `Views/Pages/YourLibraryPage/YourLibraryPageModel.swift` — `@Observable` model exposing `navigationTitle = "Your Library"`.
  - `Views/Pages/YourLibraryPage/YourLibraryPageView.swift` — renders only the sticky title header (mirroring `ContactPageView`'s header style), nothing else.
- `MainContainer.swift`: replace `rewardsTab` with `yourLibraryTab` — `Image(systemName: "heart.fill")`, `Text("Your Library")`, `.tag(.yourLibrary)`, hosting `YourLibraryPageView(model: model.yourLibraryPageModel)`. Update the `TabView` body list.
- `MainContainerModel`: add `var yourLibraryPageModel = YourLibraryPageModel()`; remove `rewardsPageModel` (ownership moves to `ContactPageModel`).

### 2. Rewards reachable from Profile (pushed)

- Coordinator `Path` enum: add `case rewardsPage(RewardsPageModel)` + its `destinationView` arm returning `RewardsPageView(model:)`.
- `ContactPageModel`: add `rewardsPageModel = RewardsPageModel()` + `func onRewardsTapped()` → `mainContainerNavigationCoordinator.path.append(.rewardsPage(rewardsPageModel))`.

### 3. Rewards button replaces the Liked Songs button

- `ContactPageView`: replace the Liked Songs button row with a Rewards button in the same slot, same red-row styling (`Image(systemName: "gift.fill")`, `Text("Rewards")`, chevron), calling `model.onRewardsTapped()`.
- `ContactPageModel`: remove `onLikedSongsTapped()` and the now-unused `likedSongsPageModel` (verify nothing else references it first).
- Leave the `.likedSongsPage` coordinator `Path` case in place (harmless; may be referenced elsewhere).

## Not touched

- Rewards page internals / `RewardsPageModel` logic.
- Broadcast-mode tabs (`.library` / `libraryPath` etc.).

## Tests

- `ContactPageModel`: `onRewardsTapped()` appends `.rewardsPage` to the coordinator path (case-path assertion). Remove/adjust the Liked Songs test.
- `YourLibraryPageModel`: `navigationTitle == "Your Library"`.
- All model/test suites carry `@Suite(.freshSharedState)`.

## Constraints

- No environment gating (project rule).
- Follow Point-Free patterns (pfw-* skills) for models, sharing, testing.
- `develop` must stay deployable: the app compiles and all tabs render after each commit.
