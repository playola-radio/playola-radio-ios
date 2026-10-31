# Flip to record

Status: scope and all screens approved by Brian on 2026-10-31. Implementation in progress on this branch.

## Target surfaces and bases

- Surface: `ios`. This is a client-only feature with no backend changes.
- iOS repository: `playola-radio-ios`, branch `briankeane/recording-screens-upside-down`, inspected commit `ebbad6ae6a6468c90e4a2359cf4d30bc1c97b4bd`, which equals `origin/develop`.
- Backend repository: `/Users/brian/playola/playola`. Its inspected `origin/develop` is `77513f9569d25a5835a66a0f3ca7f138989b2546`. It was read only to confirm that nothing server-side changes.
- Canvas: `design/playola-ios.pen`, in zone **Proposal · Flip to Record**.
- Delivery: one PR to `develop` that carries both this design folder and the implementation, as Brian decided.

## Problem

The app currently flips upside down based on navigation. Any screen under the Broadcast page or the AMA live page renders upside down (`MainContainerNavigationCoordinator.isShowingUpsideDownFlow`). Two problems follow:

- Broadcasters read lists, pick songs and type while the app is upside down, even when they are not recording.
- Several recording screens never flip at all, including the listener question, giveaway congrats and record-intro screens.

The upside-down position exists so that the iPhone's bottom microphone ends up near the speaker's mouth, held like a handheld mic.

## Scope

Flipping is tied to the act of recording, not to which screen is open.

On every recording screen, tapping **Record** runs the following flow:

1. **Flip prompt.** A prompt appears over the screen: "Flip your phone over and talk into the bottom, like a microphone." It also has a **Record without flipping** link.
   - The prompt is skipped and recording starts exactly as it does today when an external microphone is the active input (AirPods, wired, USB or Bluetooth headset).
   - When the phone is already physically upside down, the prompt is skipped and the flow goes straight to step 2.
2. **Flip detected.** About 250 ms of steady upside-down pose is required. Then the window rotates 180° and a **3-2-1 countdown** runs on the rotated screen. The countdown cannot be skipped. Turning the phone upright during the countdown cancels it, rotates the window back, and returns to the prompt. The countdown overlay blocks touches to the page underneath and has its own **Cancel** button, which cancels the take.
3. **Recording.** Recording starts on the rotated screen and uses the page's existing recording UI, shown flipped.
4. **Flip back to stop.** Holding the phone upright for about 1 second stops the recording and enters the page's existing review state. The Stop button still works. Face-up, face-down and landscape readings are ignored: they neither stop recording nor reset the 1-second timer.
5. **Window returns upright.** The window always rotates back upright when recording ends, whatever the reason: flip back, Stop, duration limit, error, leaving the screen, swipe-dismiss, backgrounding or sign-out.

**Record without flipping** records exactly the way it does today, with the screen upright and no countdown.

### Recording screens in scope (all seven)

| Screen | Model | How it's presented |
| --- | --- | --- |
| Voicetrack recorder | `RecordPageModel` | Full-screen cover from Broadcast |
| Song intro recorder | `RecordIntroPageModel` | Full-screen cover from Library |
| Multi-step prompt recorder (AMA intro and outro, etc.) | `RecordWithMultiStepPromptModel` | Pushed from AMA live |
| AMA answer, record mode only | `AMAAnswerQuestionPageModel` | Pushed from the AMA question picker |
| Broadcaster reply to a listener question | `ListenerQuestionDetailPageModel` | Pushed from Listener Questions |
| Listener asks a question | `AskQuestionPageModel` | Pushed from Player or Contact |
| Owner giveaway congrats | `GiveawayCongratsSheetModel` | Sheet |

### Removed

Navigation-based flipping goes away: `isShowingUpsideDownFlow`, `MainContainerModel.shouldShowUpsideDown`, `upsideDownFlowVisibilityChanged`, the `ContentView` `.onChange`, and their tests. The Broadcast page, the AMA live page, every list and picker, and the AMA trailing-song picker all stay upright.

### Kept

- The upside-down keyboard and the upside-down notification-banner replacements remain, now driven by the recording-time rotation. No recording screen has a text field, so the keyboard path is effectively dormant. It is kept and not redesigned.

## Non-goals (v1)

- **Trimming the trailing noise** from the flip-back motion. Deferred until device testing shows the handling noise is unacceptable (Brian, 2026-10-31).
- **Changing how interruptions and backgrounding behave.** Today's behavior stays (Brian, 2026-10-31). The one exception is the failsafe in step 5: the window always returns upright.
- **Choosing the bottom-mic data source** (`AVAudioSessionDataSourceDescription`). The default route is used.
- **Recovering from a lost audio route** in the middle of a recording.
- **Detecting flips for playback, review or upload.** Only recording uses it.
- **Server, endpoint or model changes.**
- **Fixing the ignored `AVAudioRecorder.record()` return value.** That is a separate pre-existing bug.

## Open questions (to settle on a device)

- **Gravity-Y threshold** for upright and upside-down. The starting point is ±0.65, with Y dominating X but not Z. Needs testing on Face ID and Touch ID iPhones.
- **Motion permission.** Raw `CMDeviceMotion` should not need `NSMotionUsageDescription`. Confirm on a device.
- **External-mic detection** across AirPods, wired EarPods, USB-C mics and CarPlay. AirPods should count as external, meaning no prompt.
- **Safe-area handling** while rotated, on sheets (congrats) versus full-screen covers versus pushed pages.

## Architecture (settled with Codex, 2026-10-31)

The full Codex output is in `.context/codex-flip-to-record-design.md`. It is not committed. The adjudicated summary:

- **Device pose.** A `DevicePose` enum (`upright`, `upsideDown`, `indeterminate`) and a `DevicePoseClient.updates() -> AsyncStream<DevicePose>`. It reads the Core Motion gravity vector, runs only while a recording screen is visible, and yields the latest sample immediately.
- **Input route.** `AudioRecorderClient.usesExternalMicrophone() async -> Bool`, implemented through the existing `AudioSessionCoordinator`. An unreadable route counts as built-in, so the prompt is shown.
- **`FlipToRecordModel`.** A child model owned by each recording page. It holds:
  - The prompt and countdown text and state.
  - The pose subscription.
  - The countdown and upright-debounce tasks.
  - The window-ownership token.

  It calls the page's existing start and stop closures, so each page keeps its own idle → recording → review state machine.
- **`RecordingOrientationController`.** One shared instance. Exposes `acquire(UUID)`, `release(UUID)` and `forceReset()`, and owns the rotation, keyboard and banner sequencing that currently lives in `MainContainerModel`. `forceReset` runs on backgrounding and on sign-out.
- **Safe area.** While rotated, the top and bottom insets are swapped across the root view controller and its presented chain, keeping any existing additional insets.
- **Teardown.** `RecordPage`, `RecordIntroPage` and `AskQuestionPage` get a disappearance hook for flip cleanup, which they lack today.

The implementation plan's "Design decisions" section is the detailed, post-review version of this summary.

## Existing contracts

- **Endpoints:** none touched.
- **Models:** none touched.
- **Screens:** screenshots of the current recorder states are in `exports/existing/`. All seven recording screens share the same visual vocabulary:
  - Idle: a mic button with "Tap to start recording".
  - Recording: a red dot, an elapsed/limit timer, a waveform, and "Stop recording".
  - Review: playback with retry and use controls.

## Design deliverables

- Screens: [screens.md](./screens.md) (in progress: approved screens are added one at a time)
- Endpoints: none. iOS-only behavior; no server contract changes.
- Models: none. No server model changes; client-only enums do not cross the API.

## Plan reviews (2026-10-31)

Phase 5 (Codex, adversarial) failed the first plan with 13 findings. Phase 7 (Codex, simplicity) found one cut. The Claude Opus half of Phase 7 was not run; only Codex reviewed for simplicity.

| # | Finding | Disposition |
| --- | --- | --- |
| P5-1 | A cancelled take could still start recording after an await | Resolved: per-take id re-checked after every await |
| P5-2 | Five hosts accept a late start after leaving the page | Accepted: pre-existing on a plain Record tap followed by Back; the flip path adds its own take check before calling start |
| P5-3 | Background and sign-out reset was dropped | Resolved: shared controller `forceReset()` from `ContentView` |
| P5-4 | Per-page generations can't protect the global window | Resolved: shared `RecordingOrientationController` with owner and transition generation |
| P5-5 | Pose loop could block on rotation; 250 ms skipped on the already-flipped path | Resolved: pose loop never awaits; 250 ms on both paths |
| P5-6 | No way to stop during the countdown | Resolved: countdown overlay has Cancel |
| P5-7 | Pass-through touches expose AMA controls and the tab bar | Resolved: countdown overlay blocks touches. This replaces "Back stays tappable" in the approved countdown mockup |
| P5-8 | Stop causes can race | Resolved: pose stop goes through each host's existing guarded stop action |
| P5-9 | Cleanup at the end of stop paths misses early returns | Resolved: `recordingStopped()` at the top of every stop path, cancelling timers before any await |
| P5-10 | Missing motion samples strand the user | Resolved: stream ending before a sample shows the prompt |
| P5-11 | Route can change between check and start | Accepted: worst case records upright, same as today |
| P5-12 | Direct `AudioRecorderClient(...)` initializers and AMA start/stop tests | Resolved: new field has a default; existing suites run unchanged |
| P5-13 | Safe-area swap deferred | Resolved: implemented in the live window client |
| P7-1 | `recordingStopped()` and `teardown()` duplicate each other | Adopted: one idempotent `recordingStopped()` |

## Approval log

| Date | What | Revision |
| --- | --- | --- |
| 2026-10-31 | Scope: flip-to-record on all seven recording screens; prompt with "Record without flipping"; external mic or already upside down skips the prompt; 3-2-1 countdown; ~1 s upright stops recording; window always returns upright | chat, pre-canvas |
| 2026-10-31 | Deferred trailing-noise trim; kept today's interruption behavior; mockups first; one PR | chat, pre-canvas |
| 2026-10-31 | Flip prompt: direction A (bottom sheet over the recording screen), "Waiting" state, illustration v8 (phone moved closer to the mouth, floating mic badge removed); direction B (full screen) rejected | canvas `z8wAhd`, `generated-assets/recording-position-v8.png` |
| 2026-10-31 | Recording screen, flipped: Countdown state (rotated window, dark backdrop, "Recording in" 3-2-1 ring, "Turn your phone back over to cancel.", Back stays tappable) | canvas `gK9Vw` |
| 2026-10-31 | Recording screen, flipped: Recording state (page's existing recorder unchanged, plus a "Turn your phone upright to stop" hint pill under it). All screens approved; Brian: "let's try it" | canvas `iqEG4` |
