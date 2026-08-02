# CarPlay Model Refactor — make CarPlay resemble our other view models

**Date:** 2026-08-02
**Status:** Design approved (three-part split, Option C). **Implementation parked
until the 0.20.0 (host-owned-audio) incorporation lands** — re-read the final
`CarPlaySceneDelegate` before executing (see Sequencing).
**Branch:** refactor gets its own branch off `develop` once 0.20.0 settles.

## Goal

`CarPlaySceneDelegate` is the one screen that does not follow the app's "MV with
`@Observable` models" pattern. It is a `UIResponder` +
`CPTemplateApplicationSceneDelegate` that mixes three concerns in one class:
system scene plumbing, CarPlay template construction, and a race-prone
business-logic state machine (the "Now Playing" visibility reconciler). Make
CarPlay resemble every other page: a testable, dependency-injected `@Observable`
model owns the logic; a thin delegate only forwards system events in and executes
the model's navigation intents out.

## Why CarPlay legitimately differs (and what we keep)

CarPlay is imperative UIKit (`CPInterfaceController.pushTemplate/popTemplate`,
delegate callbacks, `CPListItem.handler` closures). There is **no SwiftUI view to
bind an `@Observable` model to**, so we cannot literally reproduce the
View↔Model binding. The delegate is also **system-instantiated** from the
`Info.plist` scene manifest, so it cannot take init-injected dependencies the way
page models do. Those constraints are real and stay. What we *can* recover is the
actual prize: a **UIKit-free, unit-testable model** that owns the decision logic,
with the imperative CarPlay calls isolated in a thin, dumb layer.

`CarPlayPlaybackTransition` already demonstrates the direction — pure, testable
decision logic extracted so it can be tested without a `CPInterfaceController`.
This refactor finishes that move.

## Approach: three-part split + explicit desired-state output (Option C)

Reviewed with Codex (consult). Two rejected alternatives:
- **Two-file (model + delegate, model builds `CP*` objects):** simpler, but leaks
  `import CarPlay` into the model and breaks the app's "model is framework-free /
  portable" rule. Rejected.
- **Add `swift-navigation` for Point-Free's `observe {}`:** not worth a new SPM
  dependency across the app + Staging targets, and it does not solve the real
  problem — CarPlay is imperative and completion-driven, so we still need explicit
  desired state and explicit navigation commands. Rejected.

**Chosen:** a three-part split where the model emits an explicit, `Equatable`
"desired CarPlay state" value, and the delegate diffs it against what is currently
on screen and executes one navigation intent at a time. No new dependency; the
whole race-prone reconciler becomes pure value logic we can unit-test.

## Decisions (locked with user)

1. **Three-part split (recommended)** over the lighter two-file version — one extra
   small file (the renderer) buys a truly UIKit-free model and full testability.
2. **Observation bridge = Option C** (model emits `CarPlayOutput`; delegate diffs +
   executes). **No `swift-navigation` dependency.**
3. **Reconciler moves into the model**, reasoning over value snapshots, never over
   `CPTemplate` instances. The delegate only reports "push finished" / "push
   rejected"; the model decides recovery and "latest wins".
4. **Preserve the existing regression fixes**: dedup on the CarPlay *action* (not
   raw `playbackStatus`) via `CarPlayPlaybackTransition`; `topTemplate`-based
   "is Now Playing showing" checks (never `templates.contains(_:)`); the
   "same template instance" push-rejection recovery; and no pop while seeking.

## Architecture

### 1. `CarPlayModel` — `@MainActor @Observable`, does **not** import CarPlay

Owns dependencies (`@Dependency(\.analytics)`, `\.stationPlayer`), `@Shared`
state (`.stationLists`, `.showSecretStations`), station-list filtering, row/tab
**display specs** (plain value types, not `CP*` objects), station-tap behavior,
playback-status→action mapping (through `CarPlayPlaybackTransition`), error-alert
decisions, and the Now Playing reconciler state machine (today's
`navigationInFlight` / `pendingNowPlayingVisible` / `setNowPlaying` logic).

Emits a single observable output the delegate renders:

```swift
struct CarPlayOutput: Equatable {
  var tabs: [CarPlayTabSpec]                 // value specs, no CP* types
  var navigation: CarPlayNavigationIntent?   // at most one pending intent
}

struct CarPlayNavigationIntent: Equatable, Identifiable {
  var id: Int                                // revision/identity — see Risks
  var command: CarPlayNavigationCommand
}

enum CarPlayNavigationCommand: Equatable {
  case setRootTabs, updateTabs, dismissPresented
  case pushNowPlaying, popToNowPlaying, popToRoot
  case presentErrorAlert(CarPlayAlertSpec)
}
```

The model reasons about the live surface via a value snapshot, never `CPTemplate`
instances:

```swift
struct CarPlaySurfaceSnapshot: Equatable {
  var isConnected: Bool
  var isNowPlayingTop: Bool
  var hasPresentedTemplate: Bool
  var isErrorAlertPresented: Bool
  var stackDepth: Int
}

enum CarPlayNavigationResult: Equatable {
  case succeeded(CarPlaySurfaceSnapshot)
  case failed(CarPlayNavigationFailure, CarPlaySurfaceSnapshot)
}
enum CarPlayNavigationFailure: Equatable { case pushRejected, unknown }
```

The Combine subscriptions currently in `didConnect` (`$stationLists.publisher`)
and `observePlaybackErrors` (`stationPlayer.$state`) move into
`CarPlayModel.start()` / `stop()`.

### 2. `CarPlaySceneDelegate` — thin

Keeps only: system callbacks (`didConnect` / `didDisconnect`), ownership of the
`CPInterfaceController`, CarPlay delegate conformances, and **execution** of
model-emitted commands. It observes `model.output`, diffs against the last-applied
output, asks the renderer to build/update tabs, executes **one** navigation intent,
and reports completion back via `model.navigationCompleted(result:)`. It makes no
"latest wins" decision itself.

System-instantiated, so it keeps `override init()` plus a DI init for tests:

```swift
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private let model: CarPlayModel
  private let renderer: CarPlayTemplateRendering

  override init() {                                  // system path (Info.plist)
    model = CarPlayModel()
    renderer = LiveCarPlayTemplateRenderer()
    super.init()
  }
  init(model: CarPlayModel, renderer: CarPlayTemplateRendering) {  // tests
    self.model = model; self.renderer = renderer
    super.init()
  }
}
```

### 3. `CarPlayTemplateRenderer` — the only file that imports `CarPlay`

Maps the model's value specs → `CPListItem` / `CPListTemplate` / `CPTabBarTemplate`
/ `CPAlertTemplate`, and wires their handlers back to the model
(`model.stationTapped(id:)`, `model.errorAlertButtonTapped()`). Keeps every UIKit
object out of the model.

### Testing seam

The delegate implements a protocol so the model/tests never touch a real
`CPInterfaceController`:

```swift
@MainActor
protocol CarPlayInterfaceDriving: AnyObject {
  var snapshot: CarPlaySurfaceSnapshot { get }
  func setRootTabs(_ tabs: [CarPlayTabSpec]) async -> CarPlayNavigationResult
  func updateTabs(_ tabs: [CarPlayTabSpec])
  func dismissPresented() async -> CarPlayNavigationResult
  func pushNowPlaying() async -> CarPlayNavigationResult
  func popToNowPlaying() async -> CarPlayNavigationResult
  func popToRoot() async -> CarPlayNavigationResult
  func presentErrorAlert(_ alert: CarPlayAlertSpec) async -> CarPlayNavigationResult
}
```

Production adapter wraps `CPInterfaceController`. Tests use a
`FakeCarPlayInterfaceDriver` with a command log and scripted completions/failures.

## Data flow

1. Playback status changes → `CarPlayModel` maps it through
   `CarPlayPlaybackTransition.action(for:)`, deduping on the *action*.
2. Model reconciles desired Now Playing visibility against `CarPlaySurfaceSnapshot`
   and emits `CarPlayOutput` (tabs + at most one `CarPlayNavigationIntent`).
3. Delegate diffs output, renders tabs via the renderer, executes the one intent
   (`pushNowPlaying` / `popToRoot` / `popToNowPlaying` / `presentErrorAlert` …).
4. Delegate reports `navigationCompleted(result:)`; the model applies "latest wins"
   for any request that arrived mid-flight and emits the next intent if needed.

## Error handling

- Push rejected ("Pushing the same template instance more than once") →
  `.failed(.pushRejected, snapshot)` → model emits `popToNowPlaying`, never a
  second push.
- Playback `.error` → single error alert; model suppresses a duplicate while one is
  already presented.
- `.stopped` while `stationPlayer.isSeeking` → no pop (mid-station-change).

## Testing

Unit-test `CarPlayModel` directly (`withDependencies`, local `@Shared`, fake
driver):
- station-list filtering incl. `showSecretStations`;
- station tap calls `stationPlayer.play`;
- loading flood emits exactly one `pushNowPlaying`;
- `.stopped` while seeking emits no pop;
- push rejection emits `popToNowPlaying`, not a second push;
- pending stop/play during in-flight navigation resolves latest-wins;
- error does not present a duplicate alert;
- alert action dismisses then pops to root, in serialized order.

Keep `CarPlayPlaybackTransitionTests` as-is (still the pure action mapping).

## Sequencing

Do **not** start until the 0.20.0 host-owned-audio incorporation is merged — that
work is actively rewriting `CarPlaySceneDelegate` (~270-line diff observed). Design
against the **final** delegate; re-read it before executing, since its post-0.20.0
shape may shift a couple of these decisions. Ship as its own single-concern PR off
`develop`.

## Risks

1. **Edge-triggered observation.** Do not emit raw one-shot events without identity;
   observation can replay or miss. Give each `CarPlayNavigationIntent` an
   `id`/revision and have the delegate acknowledge completion back into the model so
   the imperative bridge is deterministic.
2. **`@MainActor` isolation** — model, delegate, renderer, and driver are all
   `@MainActor`.
3. **Regression surface.** This touches the exact code paths behind the "stuck on
   the station list" bugs; the existing race fixes (dedup-on-action, `topTemplate`
   checks, push-rejection recovery, no-pop-while-seeking) must be preserved and are
   now unit-tested rather than only reasoned about.
4. **System instantiation** — keep `override init()`; the DI init is test-only.

## New project files (hand-register in `project.pbxproj`)

- `CarPlayModel.swift` (+ `CarPlayModelTests.swift`)
- `CarPlayTemplateRenderer.swift`
- `CarPlayInterfaceDriver.swift` (protocol + live adapter; fake lives in tests)
- Value specs (`CarPlayOutput` / `CarPlayTabSpec` / `CarPlayAlertSpec` /
  snapshot + intent enums) — colocated with `CarPlayModel.swift` unless they grow.

Keep `CarPlayPlaybackTransition.swift` and its tests.

## Out of scope

- Adding `swift-navigation` / `observe {}`.
- Any behavior change — this is a structure-only refactor; the CarPlay UX and the
  existing bug fixes stay identical.
- The unrelated `URLStreamBackend` replacement noted in `.superpowers/sdd/progress.md`.
