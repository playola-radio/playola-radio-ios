# Tab-Bar Minimize + Mini-Player Squeeze (Apple Music style)

**Date:** 2026-08-04
**Branch:** `briankeane/apple-music-player-squeeze`
**Status:** Design approved, ready for implementation plan

## Goal

Match Apple Music's behavior on the phone: when the user scrolls down, the Liquid
Glass tab bar minimizes (truncates to a pill), and the persistent glass mini-player
"squeezes" into the inline slot beside the minimized tab bar. In that squeezed
(inline) state the mini-player drops its Favorites (heart) button; everything else
stays exactly as it is today.

This is an **additive iOS 26.1+ enhancement**. The pre-iOS-26 (legacy) path — opaque
black tab bar with the mini-player embedded beneath each tab's content — is untouched.

## Scope (decided with the user — do not relitigate)

- **Trigger:** `.tabBarMinimizeBehavior(.onScrollDown)` on the root `TabView`, gated to
  the existing iOS 26.1+ floor.
- **Expanded accessory state:** exactly today's glass mini-player (station artwork +
  title + subtitle + heart (songs only) + stop).
- **Inline (minimized) accessory state:** identical to expanded **except the heart
  button is removed**. Nothing else changes.
- **Legacy (pre-26):** no glass tab bar exists, so minimize never applies. Byte-for-byte
  unchanged.

Out of scope: converting the app's search field to the iOS 26 glass search style. Search
is a custom `TextField` in a full-screen-cover modal (`SongSearchPageView`); it is not a
tab and does not interact with the tab bar. It is a separate future project.

## Architecture

All OS-version forking stays inside the existing compatibility boundary,
`PlayolaRadio/Views/Pages/MainContainer/TabBarPlatformChrome.swift`. `SmallPlayer`
never references any iOS 26 API directly — it receives a plain `Bool`. This is what
keeps the 18.1-deployment-target view and the legacy embed path clean.

API availability note: `tabBarMinimizeBehavior` and `tabViewBottomAccessoryPlacement`
are iOS 26.0 APIs (verified against the Xcode 26.5 and Xcode 27 beta SwiftUI
`.swiftinterface` files). We still gate this feature at **iOS 26.1** to match the
existing glass floor — iOS 26.0 is intentionally on the legacy path in this app because
`tabViewBottomAccessory(isEnabled:)` is 26.1+. Consistency over theoretical availability.

### 1. New minimize shim — `TabBarPlatformChrome.swift`

```swift
/// Minimizes the tab bar on scroll (Apple Music style).
/// - iOS 26.1+: `.tabBarMinimizeBehavior(.onScrollDown)`.
/// - Legacy: no-op.
@ViewBuilder
func playolaTabBarMinimize() -> some View {
  if #available(iOS 26.1, *) {
    self.tabBarMinimizeBehavior(.onScrollDown)
  } else {
    self
  }
}
```

Call site in `MainContainer.swift` (root `TabView`, ~line 33), between chrome and
accessory:

```swift
.accentColor(.white)
.playolaTabBarChrome()
.playolaTabBarMinimize()          // new
.playolaBottomAccessory(isEnabled: model.shouldShowSmallPlayer) {
  smallPlayer(isGlassAccessory: true)
}
```

Ordering relative to the accessory is not functionally significant; keep the three
tab-bar chrome modifiers adjacent for readability.

### 2. Placement reader — `TabBarPlatformChrome.swift`

A small wrapper view isolates the iOS 26 environment read and hands the content a plain
`Bool isInline`. Defined as a proper wrapper view (not a `View` extension that ignores
its subject — that was a smell in the draft snippet):

```swift
/// Reads the tab view bottom-accessory placement and hands `isInline` to `content`.
/// - iOS 26.1+: `isInline == true` when the accessory has squeezed inline with a
///   minimized tab bar.
/// - Legacy: always `isInline == false` (no glass accessory exists).
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

The environment value propagates into the `.tabViewBottomAccessory` content closure
(that is the documented, supported way to adapt inline vs expanded). On the legacy embed
path the env is never installed, and the wrapper short-circuits to `content(false)`, so
the heart logic there is unchanged.

### 3. `SmallPlayer.swift` — one behavioral change

Today the body is a `VStack` containing the player-bar `HStack` and the progress
`Rectangle`, with the heart rendered at lines 154-167 whenever
`currentAudioBlock.type == "song"`.

Change:
- Extract the current `body` contents into a private `playerBody(hidesHeart:)` method.
- Wrap the body in the placement reader:

```swift
var body: some View {
  PlayolaAccessoryPlacementReader { isInline in
    playerBody(hidesHeart: isGlassAccessory && isInline)
  }
}
```

- Gate the heart on `!hidesHeart`:

```swift
if !hidesHeart, let audioBlock = currentAudioBlock, audioBlock.type == "song" {
  // existing heart Button, unchanged
}
```

Result: `hidesHeart` is `true` only in the glass accessory's inline state. Expanded
glass and the legacy embed both pass `hidesHeart == false`, so their heart behavior is
identical to today. All other styling (artwork, title/subtitle, stop, progress, spacing,
`subtitleIsMultiline` state) is unchanged.

### 4. Animation — rely on the OS, add a transition only if needed

The tab-bar collapse and the accessory's expanded↔inline morph are OS-driven and
animated; the placement change is delivered inside the system's animation transaction.
The layout reflow of the remaining elements rides along for free — **do not add a
blanket `.animation(...)`**, which can fight the system's timing.

The one element that may pop (a conditionally-removed view has no implicit transition) is
the heart itself. Verify at runtime. **If** the heart's removal pops harshly, add a
scoped transition to just the heart:

```swift
.transition(.opacity)
```

Nothing more.

## Testing / Verification

- **Runtime (primary):** on an iOS 26.1 simulator/device, scroll a tab with real
  scrollable content and confirm: tab bar minimizes, mini-player squeezes inline, heart
  disappears, remaining layout reflows cleanly, and scrolling back up restores the
  expanded player with the heart. Check the heart pop and add `.transition(.opacity)`
  only if needed.
- **Legacy regression:** on an iOS 18 simulator, confirm the embedded mini-player is
  visually and behaviorally identical to before (heart present for songs, no minimize).
- **Build:** must compile under Xcode 26.5 (CI) and the local Xcode 27 beta, with
  `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` — so the availability isolation must be exact.
- **Unit tests:** this is presentation-only (no model logic changes), so no new model
  tests are expected. If we later move the "should the heart show" decision into a
  computed value, add a test then.

## Risks / things to verify during implementation

1. **Scrollable tab content — VERIFIED.** `.onScrollDown` only triggers on tabs whose
   content is a real `ScrollView`/`List`. Confirmed all primary tabs qualify:
   `HomePageView` (ScrollView), `StationListPage` (vertical ScrollView), `YourLibraryPageView`
   (ScrollView), `ContactPageView` = Profile/Settings (ScrollView), `LibraryPageView` (List),
   `BroadcastPageView` (List). Note `StationListPage` also has a *horizontal* ScrollView at
   top which will not drive minimize; the main vertical ScrollView beneath it will. Feature
   will be visible on every tab.
2. **iPhone-only:** tab-bar minimization is a phone behavior; do not expect inline on
   iPad/sidebar-adapted layouts. Not a concern for this phone-first app but worth noting.
3. **`safeAreaInset(edge: .bottom)` search bar:** lives inside a full-screen cover that
   owns its own presentation/safe area, so interaction risk with root tab-bar minimize is
   low. Sanity-check anyway.
4. **`TabViewBottomAccessoryPlacement` equality/optionality:** `placement == .inline`
   works whether the env value is optional or not; confirm it compiles against both SDKs.

## Files touched

- `PlayolaRadio/Views/Pages/MainContainer/TabBarPlatformChrome.swift` — add
  `playolaTabBarMinimize()` shim + `PlayolaAccessoryPlacementReader` (and private
  `PlacementEnvReader`).
- `PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift` — add
  `.playolaTabBarMinimize()` to the root `TabView`.
- `PlayolaRadio/Views/Reusable Components/SmallPlayer/SmallPlayer.swift` — wrap body in
  the placement reader, extract `playerBody(hidesHeart:)`, gate the heart.

No new files, so no `project.pbxproj` registration needed.
