# Your Library Tab + Rewards-from-Profile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the Rewards tab, put a blank "Your Library" tab (heart icon) in its place, and make the Rewards page reachable via a button that replaces the Liked Songs button on the Profile (ContactPage) page.

**Architecture:** The Rewards page becomes a pushed destination on the Profile nav stack (mirroring the existing Liked Songs push). The listening-mode `.rewards` tab slot is renamed `.yourLibrary` and hosts a new minimal `YourLibraryPage` that renders only a title header. Navigation stays centralized in `MainContainerNavigationCoordinator`.

**Tech Stack:** SwiftUI, Point-Free `swift-dependencies` + `swift-sharing`, `@Observable` MV models, swift-testing.

## Global Constraints

- No environment gating — never `Config.shared.environment != .production` or equivalent.
- `develop` must stay deployable: each commit compiles and all tests pass.
- Models own all display text/behavior; Views are visuals only, zero control flow.
- Every test suite carries `@Suite(.freshSharedState)`; declare `@Shared` locally per test.
- New `.swift` files must be hand-registered in `PlayolaRadio.xcodeproj/project.pbxproj` (explicit refs — App target, Staging target, and Test target).
- Run `make lint` before pushing (pre-commit hook runs swift-format only).
- Build with `DEVELOPER_DIR` pointed at Xcode 26.5.0 to match CI (local default is a beta).

## Key facts (verified)

- `@Shared(.activeTab)` is `.inMemory("activeTab")` (`State/SharedUserDefaults.swift:78`), default `.home`. Renaming the `ActiveTab.rewards` enum case is safe — nothing is persisted.
- `MainContainerNavigationCoordinator` switches over `ActiveTab` exhaustively in `path` get/set (lines 42-67) and `clearAllPaths()` (lines 133-142). All three must be updated when the case is renamed.
- The Liked Songs page stays reachable via `coordinator.navigateToLikedSongs()` (used by a toast action), so removing the Profile button does NOT orphan it. Keep the `.likedSongsPage` Path case and `navigateToLikedSongs()`.
- Two app targets (App + Staging) each compile View+Model; the test target compiles Tests. RewardsPage is the exact registration template.

---

## Task 1: Add `.rewardsPage` push destination to the coordinator

**Files:**
- Modify: `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift`

**Interfaces:**
- Produces: `MainContainerNavigationCoordinator.Path.rewardsPage(RewardsPageModel)` case whose `destinationView` renders `RewardsPageView(model:)`.

- [ ] **Step 1: Add the enum case.** In the `Path` enum (after `case likedSongsPage(LikedSongsPageModel)`, line 71), add:

```swift
case rewardsPage(RewardsPageModel)
```

- [ ] **Step 2: Add the destination arm.** In `destinationView`'s switch (after the `.likedSongsPage` arm, line 88), add:

```swift
case .rewardsPage(let model):
  RewardsPageView(model: model)
```

- [ ] **Step 3: Build to verify it compiles.**

Run: `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer xcodebuild -project PlayolaRadio.xcodeproj -scheme PlayolaRadio -destination 'platform=iOS Simulator,name=iPhone 16' -skipPackagePluginValidation build`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit.**

```bash
git add PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift
git commit -m "feat(nav): add rewardsPage push destination"
```

---

## Task 2: Rewards button replaces Liked Songs button on Profile

**Files:**
- Modify: `PlayolaRadio/Views/Pages/ContactPage/ContactPageModel.swift`
- Modify: `PlayolaRadio/Views/Pages/ContactPage/ContactPageView.swift`
- Test: `PlayolaRadio/Views/Pages/ContactPage/ContactPageTests.swift`

**Interfaces:**
- Consumes: `Path.rewardsPage(RewardsPageModel)` (Task 1).
- Produces: `ContactPageModel.onRewardsTapped()` pushes `.rewardsPage(rewardsPageModel)`.

- [ ] **Step 1: Replace the failing test.** In `ContactPageTests.swift`, replace `testOnLikedSongsTappedNavigatesToLikedSongsPage` (lines 116-134) with:

```swift
@Test
func testOnRewardsTappedNavigatesToRewardsPage() {
  let model = ContactPageModel()

  #expect(model.mainContainerNavigationCoordinator.path.isEmpty)

  model.onRewardsTapped()

  #expect(model.mainContainerNavigationCoordinator.path.count == 1)

  if case .rewardsPage = model.mainContainerNavigationCoordinator.path.first {
    // Successfully navigated to rewards page
  } else {
    Issue.record("Expected navigation to rewards page")
  }
}
```

- [ ] **Step 2: Run test to verify it fails.**

Run: the `PlayolaRadioTests` scheme (see Task 5 for the full test command). Expected: FAIL — `onRewardsTapped` does not exist / no `.rewardsPage` case reachable from the model.

- [ ] **Step 3: Update the model.** In `ContactPageModel.swift`:
  - Replace the `likedSongsPageModel` property (line 33) with:

```swift
var rewardsPageModel: RewardsPageModel = RewardsPageModel()
```

  - Replace `onLikedSongsTapped()` (lines 100-103) with:

```swift
@MainActor
func onRewardsTapped() {
  mainContainerNavigationCoordinator.path.append(.rewardsPage(self.rewardsPageModel))
}
```

- [ ] **Step 4: Update the view.** In `ContactPageView.swift`, replace the Liked Songs button block (the `// Liked Songs Button` comment + Button, lines 153-179) with:

```swift
// Rewards Button
Button(
  action: {
    model.onRewardsTapped()
  },
  label: {
    HStack(spacing: 12) {
      Image(systemName: "gift.fill")
        .foregroundColor(.white)
        .font(.system(size: 16))

      Text("Rewards")
        .font(.custom(FontNames.Inter_500_Medium, size: 16))
        .foregroundColor(.white)

      Image(systemName: "chevron.right")
        .foregroundColor(.white)
        .font(.system(size: 14))
    }
    .frame(maxWidth: .infinity)
    .frame(height: 50)
    .padding(.horizontal, 16)
    .background(Color.playolaRed)
    .cornerRadius(6)
  }
)
.padding(.horizontal, 20)
```

- [ ] **Step 5: Run tests to verify pass.** Run the `PlayolaRadioTests` scheme. Expected: `testOnRewardsTappedNavigatesToRewardsPage` PASSES; the whole ContactPage suite passes.

- [ ] **Step 6: Commit.**

```bash
git add PlayolaRadio/Views/Pages/ContactPage/
git commit -m "feat(profile): replace Liked Songs button with Rewards button"
```

---

## Task 3: Create the blank "Your Library" page

**Files:**
- Create: `PlayolaRadio/Views/Pages/YourLibraryPage/YourLibraryPageModel.swift`
- Create: `PlayolaRadio/Views/Pages/YourLibraryPage/YourLibraryPageView.swift`
- Test: `PlayolaRadio/Views/Pages/YourLibraryPage/YourLibraryPageTests.swift`
- Modify: `PlayolaRadio.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `YourLibraryPageModel` (a `ViewModel` subclass) with `var navigationTitle: String { "Your Library" }`; `YourLibraryPageView(model:)`.

- [ ] **Step 1: Write the failing test.** Create `YourLibraryPageTests.swift`:

```swift
//
//  YourLibraryPageTests.swift
//  PlayolaRadio
//

import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct YourLibraryPageTests {
  @Test
  func testNavigationTitleIsYourLibrary() {
    let model = YourLibraryPageModel()
    #expect(model.navigationTitle == "Your Library")
  }
}
```

- [ ] **Step 2: Create the model.** `YourLibraryPageModel.swift`:

```swift
//
//  YourLibraryPageModel.swift
//  PlayolaRadio
//

import Observation
import SwiftUI

@MainActor
@Observable
class YourLibraryPageModel: ViewModel {
  var navigationTitle: String { "Your Library" }
}
```

- [ ] **Step 3: Create the view.** `YourLibraryPageView.swift` (mirrors the ContactPage sticky-title header, nothing else):

```swift
//
//  YourLibraryPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct YourLibraryPageView: View {
  @Bindable var model: YourLibraryPageModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(model.navigationTitle)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 24)
      .background(Color.black)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }
}

// MARK: - Preview
struct YourLibraryPageView_Previews: PreviewProvider {
  static var previews: some View {
    YourLibraryPageView(model: YourLibraryPageModel())
      .background(Color.black)
  }
}
```

- [ ] **Step 4: Register the three files in `project.pbxproj`.** Mirror the RewardsPage entries exactly. Generate three fresh 24-hex-char UUIDs for the file references and one per build-file membership. Add, mirroring RewardsPage's locations:
  - Three `PBXFileReference` entries (like lines 755-757) for Model, View, Tests.
  - A new `PBXGroup` (`YourLibraryPage`) containing the three file refs, added as a child of the `Pages` group — OR add the three refs to a group next to the `RewardsPage` group. (Mirror how RewardsPage's group is declared near line 1658.)
  - `PBXBuildFile` entries so **both app targets** (App + Staging) compile `YourLibraryPageModel.swift` and `YourLibraryPageView.swift` (RewardsPage has 4 such entries: lines 89, 137, 423, 424), and the **test target** compiles `YourLibraryPageTests.swift` (like line 425).
  - Add the corresponding entries into the two app `Sources` build phases (like View at 1988 & 2184, Model at 2068 & 2264) and the test `Sources` phase (like Tests at 2374).

- [ ] **Step 5: Build both app targets + run tests to verify pass.**

Run the build command from Task 1 Step 3, plus the test command in Task 5. Expected: BUILD SUCCEEDED for `PlayolaRadio` and `PlayolaRadioStaging`; `testNavigationTitleIsYourLibrary` PASSES.

- [ ] **Step 6: Commit.**

```bash
git add PlayolaRadio/Views/Pages/YourLibraryPage/ PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat(library): add blank Your Library page"
```

---

## Task 4: Swap the tab — Rewards tab becomes the Your Library tab

**Files:**
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift`
- Modify: `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift`
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift`

This is an atomic rename: all edits land in one commit so the project compiles.

- [ ] **Step 1: Rename the enum case.** In `MainContainerModel.swift`, in `enum ActiveTab` (line 55), rename `case rewards` → `case yourLibrary`.

- [ ] **Step 2: Swap the model property.** In `MainContainerModel.swift`, replace `var rewardsPageModel = RewardsPageModel()` (line 69) with:

```swift
var yourLibraryPageModel = YourLibraryPageModel()
```

- [ ] **Step 3: Rename the coordinator path.** In `MainContainerNavigationCoordinator.swift`:
  - `var rewardsPath: [Path] = []` (line 26) → `var yourLibraryPath: [Path] = []`.
  - In `path` getter (line 47): `case .rewards: return rewardsPath` → `case .yourLibrary: return yourLibraryPath`.
  - In `path` setter (line 60): `case .rewards: rewardsPath = newValue` → `case .yourLibrary: yourLibraryPath = newValue`.
  - In `clearAllPaths()` (line 137): `rewardsPath = []` → `yourLibraryPath = []`.

- [ ] **Step 4: Swap the tab in MainContainer.** In `MainContainer.swift`:
  - In the `TabView` body (line 28): `rewardsTab` → `yourLibraryTab`.
  - Replace the `rewardsTab` computed property (lines 190-205) with:

```swift
@ViewBuilder
private var yourLibraryTab: some View {
  NavigationStack(path: navigationPathBinding(\.yourLibraryPath)) {
    tabContentWithSmallPlayer {
      YourLibraryPageView(model: model.yourLibraryPageModel)
    }
    .navigationDestination(for: MainContainerNavigationCoordinator.Path.self) { path in
      path.destinationView
    }
  }
  .tabItem {
    Image(systemName: "heart.fill")
    Text("Your Library")
  }
  .tag(MainContainerModel.ActiveTab.yourLibrary)
}
```

- [ ] **Step 5: Build both app targets to verify compile.** Run the Task 1 Step 3 build for `PlayolaRadio` and again for scheme `PlayolaRadioStaging`. Expected: BUILD SUCCEEDED (no remaining `.rewards` / `rewardsPath` / `rewardsPageModel` references).

- [ ] **Step 6: Run the full test suite.** Command in Task 5. Expected: all suites pass (the coordinator/MainContainer tests still compile against the renamed case).

- [ ] **Step 7: Commit.**

```bash
git add PlayolaRadio/Views/Pages/MainContainer/ PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift
git commit -m "feat(tabs): replace Rewards tab with blank Your Library tab"
```

---

## Task 5: Verify end-to-end + lint

**Full test command** (used by earlier tasks):

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -skipPackagePluginValidation
```

- [ ] **Step 1: Run the full test suite.** Expected: all tests pass.
- [ ] **Step 2: Run lint.** `make lint`. Expected: no violations.
- [ ] **Step 3: Sanity-check the app in the simulator** — listening mode shows Home / Radio Stations / Your Library (heart) / Your Profile; the Your Library tab shows only the title; Profile has a Rewards button where Liked Songs was; tapping it pushes the Rewards page with a working back button.

---

## Self-review notes

- **Spec coverage:** Tab replacement (Task 4), blank Your Library page (Task 3), Rewards reachable from Profile (Tasks 1-2), Rewards button replaces Liked Songs (Task 2). ✓
- **Compile order:** Task 1 (add push dest) → Task 2 (use it, remove old button) → Task 3 (new standalone page) → Task 4 (atomic tab rename). Each commit compiles. ✓
- **Liked Songs not orphaned:** `coordinator.navigateToLikedSongs()` + `.likedSongsPage` Path case retained. ✓
- **`.activeTab` in-memory:** enum rename is safe. ✓
