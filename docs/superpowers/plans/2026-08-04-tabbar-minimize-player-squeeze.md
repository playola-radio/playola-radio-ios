# Tab-Bar Minimize + Mini-Player Squeeze Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On iOS 26.1+, minimize the Liquid Glass tab bar on scroll-down and let the glass mini-player squeeze into the inline slot, dropping only its heart button in that state.

**Architecture:** All iOS-26 API forking stays inside the existing compat boundary `TabBarPlatformChrome.swift`. A new `playolaTabBarMinimize()` shim applies `.tabBarMinimizeBehavior(.onScrollDown)`, and a `PlayolaAccessoryPlacementReader` wrapper reads `tabViewBottomAccessoryPlacement` and hands `SmallPlayer` a plain `Bool isInline`. `SmallPlayer` never references an iOS 26 symbol, so the 18.1-deployment view and the legacy embed stay clean.

**Tech Stack:** SwiftUI, iOS 26 tab APIs (`tabBarMinimizeBehavior`, `tabViewBottomAccessoryPlacement`), existing `@Observable` MV pattern.

## Global Constraints

- iOS 26.1+ for all new behavior; legacy (iOS 18.0 through 26.0) path byte-for-byte unchanged.
- Deployment target iOS 18.1. `SmallPlayer` must contain NO direct iOS 26 API reference (it is compiled at 18.1 and reused in the legacy embed).
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` on app + staging targets (tests target excluded). Availability isolation must be exact or the build fails.
- Must compile under Xcode 26.5 (CI) **and** local Xcode 27 beta. Build with `DEVELOPER_DIR=Xcode-26.5.0` locally to match CI.
- Pre-commit hook runs swift-format only; run `make lint` (SwiftLint) manually before pushing or CI fails.
- No environment gates. Feature ships on for all qualifying (26.1+) users.
- Presentation-only change: no model logic, no new model tests. `hidesHeart` is a view-layer/OS-placement concern and correctly lives in the view.

---

### Task 1: Add minimize shim + placement reader to the compat boundary, and wire the call site

**Files:**
- Modify: `PlayolaRadio/Views/Pages/MainContainer/TabBarPlatformChrome.swift` (add one shim + two wrapper views)
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift:33` (add `.playolaTabBarMinimize()`)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `func playolaTabBarMinimize() -> some View` (View extension)
  - `struct PlayolaAccessoryPlacementReader<Content: View>: View` with initializer taking `@ViewBuilder content: @escaping (_ isInline: Bool) -> Content` — renders `content(true)` only when the glass accessory is squeezed inline, else `content(false)`. Task 2 consumes this.

- [ ] **Step 1: Add the `playolaTabBarMinimize()` shim inside the existing `extension View` in `TabBarPlatformChrome.swift`**

Place it after `playolaTabBarChrome()`:

```swift
  /// Minimizes the tab bar on scroll-down (Apple Music style).
  /// - iOS 26.1+: `.tabBarMinimizeBehavior(.onScrollDown)`.
  /// - Legacy: no-op (no glass tab bar to minimize).
  @ViewBuilder
  func playolaTabBarMinimize() -> some View {
    if #available(iOS 26.1, *) {
      self.tabBarMinimizeBehavior(.onScrollDown)
    } else {
      self
    }
  }
```

- [ ] **Step 2: Add the placement reader wrapper views at the bottom of `TabBarPlatformChrome.swift`, after the closing brace of `extension View`**

```swift
/// Hands `content` a plain `isInline` bool so `SmallPlayer` (deployment target
/// 18.1, also used in the legacy embed) never references an iOS 26 symbol.
/// - iOS 26.1+: `isInline == true` when the bottom accessory has squeezed inline
///   with a minimized tab bar.
/// - Legacy: always `false`.
struct PlayolaAccessoryPlacementReader<Content: View>: View {
  @ViewBuilder let content: (_ isInline: Bool) -> Content

  var body: some View {
    if #available(iOS 26.1, *) {
      PlacementEnvReader(content: content)
    } else {
      content(false)
    }
  }
}

@available(iOS 26.1, *)
private struct PlacementEnvReader<Content: View>: View {
  @Environment(\.tabViewBottomAccessoryPlacement) private var placement
  @ViewBuilder let content: (_ isInline: Bool) -> Content

  var body: some View {
    content(placement == .inline)
  }
}
```

- [ ] **Step 3: Wire the call site in `MainContainer.swift`**

Insert `.playolaTabBarMinimize()` between `.playolaTabBarChrome()` and `.playolaBottomAccessory(...)` on the root `TabView` (currently line 33):

```swift
    .accentColor(.white)  // Makes the selected tab icon white
    .playolaTabBarChrome()
    .playolaTabBarMinimize()
    .playolaBottomAccessory(isEnabled: model.shouldShowSmallPlayer) {
      smallPlayer(isGlassAccessory: true)
    }
```

- [ ] **Step 4: Build to verify compilation on the CI SDK (and confirm availability isolation)**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild build -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation
```
Expected: BUILD SUCCEEDED. `SmallPlayer` isn't changed yet, so `PlayolaAccessoryPlacementReader` compiles as unused — that's fine (it's referenced in Task 2). No warnings (warnings are errors).

- [ ] **Step 5: Lint**

Run: `make lint`
Expected: no violations.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Views/Pages/MainContainer/TabBarPlatformChrome.swift \
        PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift
git commit -m "feat: add tab bar minimize-on-scroll shim + accessory placement reader (iOS 26.1+)"
```

---

### Task 2: Hide the heart when the mini-player is squeezed inline

**Files:**
- Modify: `PlayolaRadio/Views/Reusable Components/SmallPlayer/SmallPlayer.swift` (body + heart gate)

**Interfaces:**
- Consumes: `PlayolaAccessoryPlacementReader` from Task 1.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Extract the current body into a `playerBody(hidesHeart:)` method and wrap `body` in the placement reader**

Replace the current `body` (lines 110-190) so that `body` delegates to the reader, and the existing content moves verbatim into `playerBody(hidesHeart:)`:

```swift
  // MARK: - Body
  var body: some View {
    PlayolaAccessoryPlacementReader { isInline in
      playerBody(hidesHeart: isGlassAccessory && isInline)
    }
  }

  @ViewBuilder
  private func playerBody(hidesHeart: Bool) -> some View {
    VStack(spacing: 0) {
      // Player bar
      HStack(spacing: isGlassAccessory ? 12 : 16) {
        // ... existing artwork + title/subtitle block UNCHANGED ...
```

Everything from the `VStack(spacing: 0)` down to its closing `.background(...)` moves into `playerBody(hidesHeart:)` unchanged EXCEPT the heart gate in the next step.

- [ ] **Step 2: Gate the heart button on `!hidesHeart`**

Change the heart condition (currently line 154) from:

```swift
        // Heart button (only for songs)
        if let audioBlock = currentAudioBlock, audioBlock.type == "song" {
```

to:

```swift
        // Heart button (only for songs; hidden when the glass player is squeezed inline)
        if !hidesHeart, let audioBlock = currentAudioBlock, audioBlock.type == "song" {
```

- [ ] **Step 3: Build on the CI SDK**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild build -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation
```
Expected: BUILD SUCCEEDED, no warnings.

- [ ] **Step 4: Run the test suite (regression — nothing should break)**

Run the existing tests to confirm no regression (use a concrete booted simulator id; `-skipPackagePluginValidation` required):
```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,name=iPhone 16' -skipPackagePluginValidation
```
Expected: all existing tests pass. (No new tests — presentation-only change.)

- [ ] **Step 5: Lint**

Run: `make lint`
Expected: no violations.

- [ ] **Step 6: Commit**

```bash
git add "PlayolaRadio/Views/Reusable Components/SmallPlayer/SmallPlayer.swift"
git commit -m "feat: drop heart button when glass mini-player squeezes inline"
```

---

### Task 3: Runtime verification + legacy regression + adversarial review

**Files:** none (verification only). Any fix discovered here appends to Task 2's commit or a new small commit.

**Interfaces:** none.

- [ ] **Step 1: Runtime check on iOS 26.1+ (feature visible)**

Boot an iOS 26.1 simulator, run the app, start playback so the mini-player shows, open a tab with vertical scroll (Home / Stations / Your Library), and scroll down. Confirm:
  - Tab bar minimizes to a pill.
  - Glass mini-player squeezes into the inline slot.
  - Heart button disappears in the squeezed state; artwork/title/subtitle/stop remain.
  - Scrolling back up restores the full-width player WITH the heart (for a song).

- [ ] **Step 2: Judge the heart transition; add a scoped transition ONLY if it pops**

If the heart blinks out harshly (rather than the surrounding layout sliding smoothly), add `.transition(.opacity)` to just the heart `Button`. If it already looks clean via the OS morph, add nothing. Do NOT add a blanket `.animation(...)`.

If you add the transition, rebuild + relint + amend the Task 2 commit:
```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild build -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation
make lint
git add "PlayolaRadio/Views/Reusable Components/SmallPlayer/SmallPlayer.swift"
git commit --amend --no-edit
```

- [ ] **Step 3: Legacy regression on iOS 18**

Boot an iOS 18 simulator, run the app, start playback. Confirm the embedded opaque-black mini-player is identical to before: full-bleed 64pt artwork, heart present for songs, stop button as a white circle, no tab-bar minimize behavior.

- [ ] **Step 4: Adversarial Codex review of the final diff**

Per the project's Architect-with-Codex pipeline, run `/codex review` then `/codex challenge` on the branch diff (this touches real product view logic, so it clears the triviality threshold). Fix anything surfaced; re-run if fixes are non-trivial.

- [ ] **Step 5: Final confirmation**

Confirm: builds clean on Xcode 26.5, `make lint` clean, tests pass, iOS 26.1 behavior correct, iOS 18 unchanged, Codex clear. Ready for PR against `develop`.

---

## Self-Review

**Spec coverage:**
- Minimize trigger (`.onScrollDown`, 26.1-gated) → Task 1, Steps 1 & 3. ✅
- Expanded state unchanged → Task 2 preserves all styling; only the heart gate changes. ✅
- Inline state = expanded minus heart → Task 2, Step 2 (`hidesHeart = isGlassAccessory && isInline`). ✅
- Legacy untouched → `PlayolaAccessoryPlacementReader` returns `content(false)` on legacy; verified in Task 3, Step 3. ✅
- iOS 26 API isolated from `SmallPlayer` → placement read lives in `PlacementEnvReader` in the compat file. ✅
- OS-driven animation, transition only if needed → Task 3, Step 2. ✅
- Scrollable-tab verification → already confirmed pre-plan (recorded in spec Risks #1). ✅
- Build under both Xcode versions, warnings-as-errors, lint → Tasks 1-3 build/lint steps. ✅

**Placeholder scan:** No TBD/TODO; all code shown verbatim; the one conditional step (heart transition) has explicit criteria and exact commands. ✅

**Type consistency:** `PlayolaAccessoryPlacementReader` / `playolaTabBarMinimize()` names match between Task 1 (produce) and Task 2 (consume). `playerBody(hidesHeart:)` used consistently in Task 2 Steps 1-2. `hidesHeart` bool threads correctly. ✅
