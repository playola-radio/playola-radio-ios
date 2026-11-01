# Flip to record — Implementation plan

**Consumer:** `superpowers:executing-plans` (single PR to `develop`, design folder + implementation together).
**Repo:** `playola-radio-ios`, branch `briankeane/recording-screens-upside-down`, base `ebbad6ae` (= `origin/develop`).
**Contracts:** [spec.md](./spec.md), [screens.md](./screens.md). Endpoints and models: none.

Before writing Swift, invoke `pfw-dependencies`, `pfw-observable-models`, `pfw-testing`, `pfw-custom-dump`. Tests are swift-testing with `@Suite(.freshSharedState)` and `@MainActor`. New files are registered by hand in `project.pbxproj`.

## Acceptance criteria

1. On each of the seven recording screens, Record with the built-in mic and the phone not upside down shows the flip prompt.
2. Record with an external mic active starts recording immediately, upright, exactly as today.
3. Record with the phone already upside down skips the prompt and goes straight to the countdown.
4. ~250 ms of steady upside-down pose while prompting rotates the window and runs 3-2-1, then the page's existing start runs.
5. Turning upright during the countdown rotates back and shows the prompt again. Leaving the page during the countdown rotates back and never starts recording.
6. "Cancel" (or tapping the scrim) returns to idle. There is no "Record without flipping" link (removed 2026-11-01).
7. While recording flipped, ~1 s of upright pose calls the page's existing stop, which lands in its existing review state. Upside-down cancels the pending stop. Indeterminate samples (flat, landscape) neither stop nor reset the timer.
8. The window returns upright whenever a flipped recording ends: flip back, Stop, AMA's 2-minute limit, start failure, leaving the page.
9. The Broadcast page and AMA live page no longer rotate.

## Design decisions (after Phase 5 + Phase 7 review, 2026-10-31)

- **Shared orientation controller.** `RecordingOrientationController` (one live instance) owns the window: `acquire(id) -> Bool`, `release(id)`, `forceReset()`, `isOwner(id)`. It keeps the owner and a transition generation, rotates first and only then enables the upside-down keyboard and banner, and disables them before rotating back. A stale page's release can't undo a newer owner's rotation.
- **Background and sign-out.** `ContentView` calls `forceReset()` when the scene enters `.background` and when the user signs out. The overlay also forwards the scene phase: backgrounding while checking, prompting or counting down returns the page to idle, and a countdown that loses ownership goes idle too. A recording that is already running keeps today's behavior (it continues in the background); the window comes back upright, and flipping upright still stops it.
- **Per-take generation.** `FlipToRecordModel` bumps a take id on every cleanup and re-checks it after every await (permission, route, rotation, each countdown tick, start). A take that was cancelled while suspended never starts recording; if the phone was held upright while the host's start was still running, the model calls the host's stop once the start returns so that recording ends. A start invalidated by leaving the page is left alone (the accepted Record→Back race). Recording upright (no permission, external mic, or no motion readings) keeps the model busy until the host's start returns, so a second Record tap is ignored.
- **Pose consumption never awaits.** The pose loop updates state synchronously and starts or cancels the 250 ms stability timer, the countdown task and the 1 s upright timer. 250 ms of stability is required on both entry paths (already upside down at tap, and flipping from the prompt). If the stream finishes before showing anything (no motion hardware, e.g. the simulator), recording starts upright, the same as today. The same happens if it finishes while the prompt is showing.
- **Countdown blocks touches and has its own Cancel.** Passing touches through would let AMA's song picker, playback and tab bar act during a countdown. This replaces "Back stays tappable" from the approved countdown mockup.
- **One cleanup entry point.** `recordingStopped()` cancels flip timers synchronously before its first await, then releases orientation. Hosts call it at the top of every stop path (button, pose, duration limit, error), on disappear and on close, so cleanup can't be skipped by early returns or delayed behind review preparation.
- **Input route** is `AudioRecorderClient.usesExternalMicrophone: () async -> Bool`. Live: configure `.playAndRecord` through the coordinator, then any non-`.builtInMic` input counts as external; empty or failed reads count as built-in (prompt shown). The stub default is `true` so the existing page tests and direct `AudioRecorderClient(...)` initializers stay on the no-flip path.
- **Safe area.** While rotated, the live window client adds `max(0, top - bottom)` to `additionalSafeAreaInsets.bottom` on the root controller and every presented controller, and removes exactly that amount on reset. This keeps controls clear of the Dynamic Island, which now sits at the logical bottom.
- **Permission first.** `recordTapped` asks for mic permission before showing anything, so the system dialog never appears rotated. If denied, it calls the host's start, which shows the host's existing denied alert.
- **Accepted, not changed:** existing start/teardown races on the low-level hosts (they exist today on a plain Record tap followed by Back); a route change between the check and the recorder start (the worst case is recording upright); trailing-noise trim (deferred by Brian).

## Stage 1: Device pose
**Goal:** `DevicePose` + `DevicePoseClient` in `PlayolaRadio/Core/DevicePose/`.
- `enum DevicePose { upright, upsideDown, indeterminate }` with `init(gravityX:gravityY:)`: `y <= -0.65 && |y| > |x|` → upright, `y >= 0.65 && |y| > |x|` → upsideDown, else indeterminate.
- `@DependencyClient struct DevicePoseClient { var updates: @Sendable () -> AsyncStream<DevicePose> }`. Live: `CMMotionManager` device motion at 20 Hz on a private `OperationQueue`, yields classified samples, stops in `onTermination`. `testValue` = unimplemented default from the macro.
**Tests:** classification boundaries (upright, upside down, flat on table, landscape, 45° mic tilt).
**Status:** Complete

## Stage 2: External mic check
**Goal:** `AudioRecorderClient.usesExternalMicrophone`.
**Tests:** port classification helper (`builtInMic` → false; `headsetMic`, `bluetoothHFP`, `usbAudio`, `carAudio` → true; empty → false).
**Status:** Complete

## Stage 3: FlipToRecordModel + overlay
**Goal:** `PlayolaRadio/Views/Reusable Components/FlipToRecord/FlipToRecordModel.swift`, `FlipToRecordOverlay.swift`, tests.
- Phases: `idle`, `checkingPose`, `prompting`, `countdown(Int)`, `recordingFlipped`.
- Hooks set by the host page: `start: () async -> Bool` (returns whether recording actually began) and `stop: () async -> Void`.
- API: `recordTapped()`, `recordWithoutFlippingTapped()`, `cancelTapped()` (prompt and countdown), `recordingStopped()` (host calls from every stop path and on disappear; idempotent).
- Also `RecordingOrientationController` + `RecordingOrientationClient` in `Core/WindowOrientation/`, with `ContentView` calling `forceReset()` on background and sign-out. Safe-area adjustment goes in the live `WindowOrientationClient`.
- All display text lives on the model (title, body, waiting label, cancel title, "Recording in", cancel hint, "Turn your phone upright to stop"), plus opacity/hit-testing booleans so the overlay has no control flow.
**Tests:** controller: acquire/release ownership, stale release ignored, forceReset during an in-flight acquire leaves keyboard/banner off. Flip model (TestClock): external mic skips prompt; stream ending while checking shows prompt; take cancelled during rotation never starts; forceReset during countdown cancels it; denied permission calls start directly; already upside down → countdown; prompt → 250 ms steady flip → countdown → start; brief flip under 250 ms does nothing; upright during countdown → prompt + rotated back; leaving the page during the countdown never starts and rotates back; without-flipping starts with no rotation; cancel; upright 1 s → stop + rotate back; upside-down mid-timer cancels stop; indeterminate keeps the timer; start failure rotates back; duplicate taps ignored.
**Status:** Complete

## Stage 4: Seven-screen cutover + removal
**Goal:** every screen owns `let flipToRecord = FlipToRecordModel()`, wires hooks in `init` with `[weak self]`, routes its idle Record action through `flipToRecord.recordTapped()`, calls `recordingStopped()` at the top of every stop path and on disappear. Views add `.flipToRecordOverlay(model.flipToRecord)`.
- RecordPage, RecordIntroPage, AskQuestionPage: add `viewDisappeared()` + `.onDisappear` (flip cleanup only; existing recorder lifecycle unchanged).
- Pose stop hook goes through each host's guarded stop path (`recordButtonTapped` toggle for MultiStep / ListenerQuestion / AMA; `onStopTapped` / `stopTapped` elsewhere).
- Remove `isShowingUpsideDownFlow`, `shouldShowUpsideDown`, `upsideDownFlowVisibilityChanged`, `upsideDownTransition`, the three deps on `MainContainerModel`, the `ContentView` `.onChange`, and their tests.
**Tests:** per page, external mic path still records (existing tests), built-in path shows the prompt and doesn't start; full pre-existing suites for all seven pages, MainContainer, navigation coordinator.
**Status:** Complete

## Stage 5: Device validation (Brian)
Thresholds, motion permission, AirPods/wired/USB routing, rotated safe areas on sheet vs cover vs push, banners while rotated, rapid flip cycles.
**Status:** Not Started
