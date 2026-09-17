# AMA Opening-Playlist Assembly Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Before writing any Swift, invoke the relevant `pfw-*` skills (pfw-observable-models, pfw-identified-collections, pfw-case-paths, pfw-modern-swiftui, pfw-testing, pfw-custom-dump, pfw-dependencies).

**Goal:** Let an AMA curator append songs and voicetracks to an ordered opening playlist, tracking staged *ready* audio, and enable "Start Show" the moment ≥ 10:00 (600,000 ms) of ready audio is staged.

**Architecture:** Replace the scalar `introDuration` on `AskMeAnythingSetupPageModel` with an ordered `IdentifiedArrayOf<AMAOpeningItem>` (per-occurrence UUID id + `Content` enum: `intro`/`song`/`voicetrack`). The generic recorder gains a synchronous deferred-acceptance callback so a voicetrack recorder pops immediately and its upload runs as a background `Task` owned by the AMA model. Songs come from the reused `SongSearchPageModel` sheet. The page view renders resolved row view-data (zero control flow).

**Tech Stack:** Swift, SwiftUI, `@Observable` MV models, swift-dependencies, swift-sharing, swift-identified-collections, swift-case-paths, swift-custom-dump, swift-testing.

**Spec:** `docs/superpowers/specs/2026-09-16-ama-opening-playlist-design.md`

## Global Constraints

- **Readiness threshold:** `readyThresholdMS = 600_000` (10:00). `isStartShowEnabled` iff staged *ready* audio ≥ 600,000 ms. (spec §S39)
- **iOS is an API consumer only.** No backend work; go-live POST is out of scope. "Start Show" is a no-op tap. (D4)
- **Append-only** (D2). The only automatic removal is rollback of a *failed* voicetrack add.
- **Duration is authoritative from `AudioBlock.durationMS`**, never the recorder's `recordedDuration` estimate. Processing voicetracks contribute **0** until complete.
- **No environment gating**; keep `develop` shippable in one PR.
- **Point-Free idioms:** `@ObservationIgnored @Dependency`, `@Dependency(\.uuid)`/`@Dependency(\.date.now)` (never `UUID()`/`Date()`), `IdentifiedArrayOf` with `[id:]`, `@CasePathable` + `.modify`, no comments in generated code, no unnecessary `self`, methods named after user actions, `async` methods (Task created in view), custom bindings via dynamic member lookup.
- **Test reality:** this target has **no** `DependenciesTestSupport` — use `withDependencies { } operation:` in the test body, NOT the `.dependencies` trait. Suites are `@Suite(.freshSharedState) @MainActor`, colocated, camelCase names. **Never** `Task.sleep` in tests (`Task.yield()` loops are fine). Seed auth with `Auth(jwt: "test-jwt")` (never a bare `Auth(jwtToken:)`).
- **New `.swift` files must be hand-registered** in `PlayolaRadio.xcodeproj/project.pbxproj` (explicit file refs — not synced folders).

**Reference test command** (executors run this; the user also runs in Xcode):

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild test \
  -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -skipPackagePluginValidation \
  -only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests \
  -only-testing:PlayolaRadioTests/RecordWithMultiStepPromptTests
```

(Adjust `-only-testing` per task; a full run is ~9 min so scope it while iterating.)

---

## File Structure

- **Create** `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift` — the `AMAOpeningItem` value type (struct + `@CasePathable` `Content` enum) and its readiness/duration helpers. One responsibility: model the ordered playlist element.
- **Create** `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningRowView.swift` — the `AMAOpeningRowData` value struct + the dedicated row component that renders one row (the icon/art/processing/pin conditionals live here, not in the page view).
- **Modify** `PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptModel.swift` — add the deferred-acceptance callback, branch in `useRecordingButtonTapped()`, and the `askMeAnythingVoicetrack` factory.
- **Modify** `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift` — replace scalar state with the collection; wire song + voicetrack adds; readiness; copy fix.
- **Modify** `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageView.swift` — render rows from `model.openingRows`; add the alert binding.
- **Modify** tests: `RecordWithMultiStepPromptTests.swift` (create if absent) and `AskMeAnythingSetupPageTests.swift`.

---

## Task 1: Recorder deferred-upload mode

**Files:**
- Modify: `PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptModel.swift`
- Test: `PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptTests.swift` (create if it does not exist; register in pbxproj)

**Interfaces:**
- Produces:
  - `var onRecordingAccepted: (@MainActor (URL, TimeInterval) throws -> Void)?` on `RecordWithMultiStepPromptModel` (annotated `@ObservationIgnored`).
  - `static func askMeAnythingVoicetrack(stationId: String) -> RecordWithMultiStepPromptModel`.
- Consumes: existing `recordingPhase`, `recordingURL`, `recordedDuration`, `navigationCoordinator`, `presentedAlert`, `.recordingSaveFailed(_)`.

- [ ] **Step 1: Write the failing test — deferred accept hands off URL, pops, keeps the file**

Add to `RecordWithMultiStepPromptTests.swift`:

```swift
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct RecordWithMultiStepPromptTests {

  @Test func deferredAcceptHandsOffUrlPopsAndDoesNotDeleteFile() async throws {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    var deletedURLs: [URL] = []
    try await withDependencies {
      $0.audioRecorder.deleteRecording = { url in deletedURLs.append(url) }
    } operation: {
      let model = RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(stationId: "s")
      coordinator.push(.recordWithMultiStepPromptPage(model))
      let url = URL(fileURLWithPath: "/tmp/vt.wav")
      model.recordingURL = url
      model.recordedDuration = 42
      model.recordingPhase = .review

      var handoff: (URL, TimeInterval)?
      model.onRecordingAccepted = { u, d in handoff = (u, d) }

      await model.useRecordingButtonTapped()

      #expect(handoff?.0 == url)
      expectNoDifference(handoff?.1, 42)
      #expect(model.recordingURL == nil)
      #expect(coordinator.path.isEmpty)
      expectNoDifference(deletedURLs, [])
    }
  }

  @Test func deferredAcceptThrowingKeepsRecorderOnReviewWithAlert() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(stationId: "s")
    coordinator.push(.recordWithMultiStepPromptPage(model))
    model.recordingURL = URL(fileURLWithPath: "/tmp/vt.wav")
    model.recordingPhase = .review
    model.onRecordingAccepted = { _, _ in throw RecordPromptError.notAuthenticated }

    await model.useRecordingButtonTapped()

    #expect(model.recordingPhase == .review)
    #expect(model.recordingURL != nil)
    #expect(model.presentedAlert != nil)
    #expect(coordinator.path.count == 1)
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the reference command with `-only-testing:PlayolaRadioTests/RecordWithMultiStepPromptTests`.
Expected: FAIL to compile — `onRecordingAccepted` and `askMeAnythingVoicetrack` do not exist.

- [ ] **Step 3: Add the callback property**

In `RecordWithMultiStepPromptModel.swift`, directly after the `onCompleted` declaration (currently line 72):

```swift
  @ObservationIgnored var onRecordingAccepted: (@MainActor (URL, TimeInterval) throws -> Void)?
```

- [ ] **Step 4: Branch in `useRecordingButtonTapped()`**

Replace the body of `useRecordingButtonTapped()` (currently lines 158-180) with:

```swift
  func useRecordingButtonTapped() async {
    guard recordingPhase == .review, let url = recordingURL else { return }
    if let onRecordingAccepted {
      if onUseRecording != nil {
        reportIssue("RecordWithMultiStepPromptModel has both acceptance callbacks set")
      }
      do {
        try onRecordingAccepted(url, recordedDuration)
        recordingURL = nil
        navigationCoordinator.pop()
      } catch {
        presentedAlert = .recordingSaveFailed(error.localizedDescription)
      }
      return
    }
    uploadProgress = 0
    recordingPhase = .uploading
    await stopPlayback()
    do {
      let audioBlock = try await onUseRecording?(url) { [weak self] progress in
        self?.applyUploadProgress(progress)
      }
      await audioRecorder.deleteRecording(url)
      recordingURL = nil
      stopProcessingTimer()
      guard !isLeaving else { return }
      processingProgress = 1
      if let audioBlock { await onCompleted?(audioBlock) }
      navigationCoordinator.pop()
    } catch {
      stopProcessingTimer()
      guard !isLeaving else { return }
      recordingPhase = .review
      presentedAlert = .recordingSaveFailed(error.localizedDescription)
    }
  }
```

Add `import IssueReporting` at the top of the file if `reportIssue` does not already resolve (it is re-exported by `Dependencies`; add the import only if the build complains).

- [ ] **Step 5: Add the `askMeAnythingVoicetrack` factory**

In the `extension RecordWithMultiStepPromptModel` block (after `askMeAnythingIntro`, before line 558's closing brace):

```swift
  static func askMeAnythingVoicetrack(stationId: String) -> RecordWithMultiStepPromptModel {
    RecordWithMultiStepPromptModel(
      screenTitle: "Record Voicetrack",
      eyebrow: "RECORD A VOICETRACK",
      guideBadge: "OPTIONAL GUIDE",
      title: "Record a short voicetrack.",
      subtitle: "Talk over the intro to a song or set up what\u{2019}s coming next.",
      steps: [
        RecordPromptStep(id: 1, label: "SET UP", detail: "Tease the song or moment you\u{2019}re leading into."),
        RecordPromptStep(id: 2, label: "KEEP IT TIGHT", detail: "A few seconds is plenty \u{2014} keep the energy up."),
      ],
      trackLabel: "VOICETRACK",
      isUpsideDown: true)
  }
```

(`stationId` is accepted for call-site symmetry with `askMeAnythingIntro`; the AMA model owns the upload, so the factory does not wire `onUseRecording`.)

- [ ] **Step 6: Run the tests to verify they pass**

Run `-only-testing:PlayolaRadioTests/RecordWithMultiStepPromptTests`. Expected: PASS.

- [ ] **Step 7: Run the existing recorder-related suite (touched-area regression)**

The intro path is shared behavior. Run the full `RecordWithMultiStepPromptTests` and any suite that drives `RecordWithMultiStepPromptModel` / `askMeAnythingIntro`. Expected: PASS (blocking intro path unchanged).

- [ ] **Step 8: Commit**

```bash
git add PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/ PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feature: add deferred-acceptance mode to the multi-step recorder"
```

---

## Task 2: `AMAOpeningItem` value type

**Files:**
- Create: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift` (register in pbxproj)
- Test: add cases to `AskMeAnythingSetupPageTests.swift` (new `AMAOpeningItemTests` suite in the same file, or a dedicated file — either is fine; keep colocated)

**Interfaces:**
- Produces:
  - `struct AMAOpeningItem: Identifiable, Equatable { let id: UUID; var content: Content }`
  - `@CasePathable enum Content: Equatable { case intro(AudioBlock); case song(AudioBlock); case voicetrack(LocalVoicetrack, completedDurationMS: Int?) }`
  - `var AMAOpeningItem.isReady: Bool`
  - `var AMAOpeningItem.readyDurationMS: Int`

- [ ] **Step 1: Write the failing test**

```swift
@Suite(.freshSharedState)
@MainActor
struct AMAOpeningItemTests {
  private func block(_ ms: Int) -> AudioBlock { .mockWith(id: "b", durationMS: ms) }

  @Test func introAndSongAreAlwaysReadyAndCountFullDuration() {
    let intro = AMAOpeningItem(id: UUID(0), content: .intro(block(30_000)))
    let song = AMAOpeningItem(id: UUID(1), content: .song(block(200_000)))
    #expect(intro.isReady)
    expectNoDifference(intro.readyDurationMS, 30_000)
    #expect(song.isReady)
    expectNoDifference(song.readyDurationMS, 200_000)
  }

  @Test func processingVoicetrackIsNotReadyAndCountsZero() {
    let vt = LocalVoicetrack(
      id: UUID(2), originalURL: URL(fileURLWithPath: "/tmp/a.wav"),
      status: .uploading(progress: 0.5), createdAt: Date(timeIntervalSince1970: 0),
      title: "VT")
    let item = AMAOpeningItem(id: UUID(3), content: .voicetrack(vt, completedDurationMS: nil))
    #expect(!item.isReady)
    expectNoDifference(item.readyDurationMS, 0)
  }

  @Test func completedVoicetrackWithDurationIsReadyAndCountsThatDuration() {
    var vt = LocalVoicetrack(
      id: UUID(4), originalURL: URL(fileURLWithPath: "/tmp/a.wav"),
      status: .completed, createdAt: Date(timeIntervalSince1970: 0), title: "VT")
    vt.audioBlockId = "vt-block"
    let item = AMAOpeningItem(id: UUID(5), content: .voicetrack(vt, completedDurationMS: 45_000))
    #expect(item.isReady)
    expectNoDifference(item.readyDurationMS, 45_000)
  }
}
```

(`UUID(_ :Int)` is the deterministic initializer swift-dependencies provides in tests; if it is unavailable in this target, use `UUID(uuidString:)` literals like `UUID(uuidString: "00000000-0000-0000-0000-000000000000")!`.)

- [ ] **Step 2: Run to verify failure**

Expected: FAIL to compile — `AMAOpeningItem` undefined.

- [ ] **Step 3: Create the type**

`PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift`:

```swift
import CasePaths
import Foundation
import PlayolaPlayer

struct AMAOpeningItem: Identifiable, Equatable {
  let id: UUID
  var content: Content

  @CasePathable
  enum Content: Equatable {
    case intro(AudioBlock)
    case song(AudioBlock)
    case voicetrack(LocalVoicetrack, completedDurationMS: Int?)
  }
}

extension AMAOpeningItem {
  var isReady: Bool {
    switch content {
    case .intro, .song:
      return true
    case .voicetrack(let voicetrack, let completedDurationMS):
      return voicetrack.isComplete && voicetrack.audioBlockId != nil && completedDurationMS != nil
    }
  }

  var readyDurationMS: Int {
    guard isReady else { return 0 }
    switch content {
    case .intro(let block), .song(let block):
      return block.durationMS
    case .voicetrack(_, let completedDurationMS):
      return completedDurationMS ?? 0
    }
  }
}
```

- [ ] **Step 4: Run to verify pass**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feature: add AMAOpeningItem playlist element type"
```

---

## Task 3: AMA model — collection state, intro append, readiness, copy fix

**Files:**
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift`
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift`

**Interfaces:**
- Consumes: `AMAOpeningItem` (Task 2).
- Produces (relied on by Tasks 4-6):
  - `var openingItems: IdentifiedArrayOf<AMAOpeningItem>`
  - `var presentedAlert: PlayolaAlert?`
  - `var isStartShowEnabled: Bool`, `var readyProgress: Double`, `var preparedAudioLabel: String`, `var readinessHint: String`
  - `var hasRecordedIntro: Bool`
  - `private func durationLabel(_ ms: Int) -> String`, `private func durationLabelCeil(_ ms: Int) -> String`

- [ ] **Step 1: Rewrite the affected tests (red)**

In `AskMeAnythingSetupPageTests.swift`:

Replace `hiddenSetupLayerAccessibilityFlipsWithRecordedIntro` and any test that assigns `model.introDuration = 30` so they drive the collection instead. Add a helper at the top of the suite:

```swift
  private func introItem(durationMS: Int) -> AMAOpeningItem {
    AMAOpeningItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
      content: .intro(.mockWith(id: "intro", durationMS: durationMS)))
  }
```

Update these tests:

```swift
  @Test func hiddenSetupLayerAccessibilityFlipsWithRecordedIntro() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    #expect(!model.introPromptAccessibilityHidden)
    #expect(model.openingPlaylistAccessibilityHidden)

    model.openingItems.append(introItem(durationMS: 30_000))

    #expect(model.introPromptAccessibilityHidden)
    #expect(!model.openingPlaylistAccessibilityHidden)
  }

  @Test func bottomBarReflectsRecordedIntroProgress() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    expectNoDifference(model.preparedAudioLabel, "0:30 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Add 9:30 more")
    expectNoDifference(model.readyProgress, 0.05)
    #expect(!model.isStartShowEnabled)
  }

  @Test func startShowEnablesAtTenMinutesOfReadyAudio() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    model.openingItems.append(introItem(durationMS: 599_999))
    #expect(!model.isStartShowEnabled)
    expectNoDifference(model.readinessHint, "Add 0:01 more")

    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!,
        content: .song(.mockWith(id: "s", durationMS: 1))))
    #expect(model.isStartShowEnabled)
    expectNoDifference(model.readyProgress, 1)
    expectNoDifference(model.readinessHint, "Ready to start")
  }
```

Update `displaysOpeningPlaylistCopyAfterIntroRecorded` to (a) append an intro item instead of setting `introDuration`, and (b) assert the corrected `addSectionExplanation` (no "past Q&As"):

```swift
  @Test func displaysOpeningPlaylistCopyAfterIntroRecorded() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    model.openingItems.append(introItem(durationMS: 30_000))

    expectNoDifference(model.openingPlaylistTitle, "Your opening playlist")
    expectNoDifference(
      model.openingPlaylistSubtitle, "Your station keeps playing while you prepare.")
    expectNoDifference(model.addSectionTitle, "Let\u{2019}s get a little ahead")
    expectNoDifference(
      model.addSectionExplanation,
      "Build the first 10 minutes of your show with songs and voicetracks. "
        + "Use Voicetrack to record a quick intro for a song.")
    expectNoDifference(model.voicetrackActionLabel, "Voicetrack")
    expectNoDifference(model.songActionLabel, "Song")
    expectNoDifference(model.qaActionLabel, "Q/A")
  }
```

Update `recordIntroButtonPushesRecorderThatFlipsToOpeningPlaylist` — after `await recorder.onCompleted?(.mockWith(durationMS: 30000))`, additionally assert the intro item landed:

```swift
    #expect(model.hasRecordedIntro)
    expectNoDifference(model.openingItems.count, 1)
    #expect(model.openingItems.first?.content.is(\.intro) == true)
```

Update `startShowIsDisabledAtZeroProgress`: it already expects `"0:00 / 10:00 ready"`, `"Record your intro"`, `readyProgress 0`, disabled — keep as-is (must still pass against the new ms-based helpers).

- [ ] **Step 2: Run to verify failure**

Expected: FAIL to compile — `openingItems` does not exist; `introDuration` removed references.

- [ ] **Step 3: Rewrite the model state and helpers**

In `AskMeAnythingSetupPageModel.swift`:

Add imports and dependencies. At the top, ensure `import IdentifiedCollections` and `import Dependencies` and `import CasePaths` are present. Under `// MARK: - Dependencies` add:

```swift
  @ObservationIgnored @Dependency(\.uuid) var uuid
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.voicetrackUploadService) var voicetrackUploadService
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Shared(.auth) var auth
```

Replace the `// MARK: - Properties` block. Remove `private let targetDuration: TimeInterval = 600` and `var introDuration: TimeInterval?`. Add:

```swift
  let stationId: String
  private let targetMilliseconds = 600_000

  var openingItems: IdentifiedArrayOf<AMAOpeningItem> = []
  var presentedAlert: PlayolaAlert?
```

Replace `recordIntroButtonTapped()`:

```swift
  func recordIntroButtonTapped() {
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingIntro(stationId: stationId)
    recorder.onCompleted = { [weak self] audioBlock in
      guard let self, audioBlock.durationMS > 0 else { return }
      guard !openingItems.contains(where: { $0.content.is(\.intro) }) else { return }
      openingItems.insert(
        AMAOpeningItem(id: uuid(), content: .intro(audioBlock)), at: 0)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }
```

Replace the readiness/label helpers. Change `hasRecordedIntro`, remove `introRowDurationLabel` (moves to row data in Task 6), and rewrite the bottom-bar helpers:

```swift
  var hasRecordedIntro: Bool { openingItems.contains { $0.content.is(\.intro) } }

  private var readyMilliseconds: Int {
    openingItems.reduce(0) { $0 + $1.readyDurationMS }
  }

  var preparedAudioLabel: String {
    "\(durationLabel(readyMilliseconds)) / \(durationLabel(targetMilliseconds)) ready"
  }
  var readinessHint: String {
    guard hasRecordedIntro else { return "Record your intro" }
    if isStartShowEnabled { return "Ready to start" }
    return "Add \(durationLabelCeil(max(0, targetMilliseconds - readyMilliseconds))) more"
  }
  var readyProgress: Double {
    min(1, Double(readyMilliseconds) / Double(targetMilliseconds))
  }

  var isStartShowEnabled: Bool { readyMilliseconds >= targetMilliseconds }
```

Fix the `addSectionExplanation` copy (remove "past Q&As"):

```swift
  var addSectionExplanation: String {
    "Build the first 10 minutes of your show with songs and voicetracks. "
      + "Use Voicetrack to record a quick intro for a song."
  }
```

Replace `durationLabel` and add `durationLabelCeil` (ms-based, floor for elapsed, ceil for remaining):

```swift
  private func durationLabel(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func durationLabelCeil(_ milliseconds: Int) -> String {
    let total = Int((Double(max(0, milliseconds)) / 1000).rounded(.up))
    return String(format: "%d:%02d", total / 60, total % 60)
  }
```

Keep `voicetrackActionTapped()`, `songActionTapped()`, `qaActionTapped()`, `startShowButtonTapped()` as inert stubs for now (Tasks 4-5 fill the first two). Delete the `introRowDurationLabel` line (line 80). Keep `introRowTitle`/`introRowSubtitle` for now — Task 6 folds them into row data.

- [ ] **Step 4: Fix the `#Preview` in the view file so it still compiles**

In `AskMeAnythingSetupPageView.swift`, the "Build your opening" preview sets `model.introDuration = 30`. Change it to:

```swift
#Preview("Build your opening") {
  let model = AskMeAnythingSetupPageModel(stationId: "station-preview")
  model.openingItems.append(
    AMAOpeningItem(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
      content: .intro(.mockWith(id: "intro", durationMS: 30_000))))
  return NavigationStack {
    AskMeAnythingSetupPageView(model: model)
  }
  .preferredColorScheme(.dark)
}
```

- [ ] **Step 5: Run the AMA suite to verify pass**

Run `-only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests`. Expected: PASS (including the 599,999-vs-600,000 boundary and the formatting invariant).

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/
git commit -m "feature: track AMA opening playlist as an ordered collection with 10:00 readiness gate"
```

---

## Task 4: Song add

**Files:**
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift`
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift`

**Interfaces:**
- Consumes: `openingItems`, `navigationCoordinator.presentedSheet`, `PlayolaSheet.songSearchPage`, `SongSearchPageModel`.
- Produces: `func songActionTapped()`, `func addSong(_:)` behavior (append `.song`), sheet self-dismiss.

- [ ] **Step 1: Write the failing test**

```swift
  @Test func songActionPresentsSearchAndSelectingAppendsAndDismisses() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.uuid = .incrementing
    } operation: {
      AskMeAnythingSetupPageModel(stationId: testStationId)
    }
    coordinator.push(.askMeAnythingSetupPage(model))

    model.songActionTapped()

    guard case .songSearchPage(let search) = coordinator.presentedSheet else {
      Issue.record("Expected song search sheet")
      return
    }

    search.onSongSelected?(.mockWith(id: "song-1", durationMS: 180_000))

    expectNoDifference(model.openingItems.count, 1)
    #expect(model.openingItems.first?.content.is(\.song) == true)
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func selectingSameSongTwiceKeepsBothOccurrences() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = withDependencies { $0.uuid = .incrementing } operation: {
      AskMeAnythingSetupPageModel(stationId: testStationId)
    }
    coordinator.push(.askMeAnythingSetupPage(model))

    model.songActionTapped()
    if case .songSearchPage(let s) = coordinator.presentedSheet {
      s.onSongSelected?(.mockWith(id: "dup", durationMS: 10_000))
    }
    model.songActionTapped()
    if case .songSearchPage(let s) = coordinator.presentedSheet {
      s.onSongSelected?(.mockWith(id: "dup", durationMS: 10_000))
    }

    expectNoDifference(model.openingItems.count, 2)
  }
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `songActionTapped` is an empty stub, so no sheet is presented and nothing appends.

- [ ] **Step 3: Implement `songActionTapped()` and `addSong`**

Replace the `songActionTapped()` stub:

```swift
  func songActionTapped() {
    let search = SongSearchPageModel(searchMode: .all, stationId: stationId)
    search.onDismiss = { [weak self] in
      self?.navigationCoordinator.presentedSheet = nil
    }
    search.onSongSelected = { [weak self] audioBlock in
      guard let self else { return }
      addSong(audioBlock)
      navigationCoordinator.presentedSheet = nil
    }
    navigationCoordinator.presentedSheet = .songSearchPage(search)
  }
```

In `// MARK: - Private Helpers`:

```swift
  private func addSong(_ audioBlock: AudioBlock) {
    openingItems.append(AMAOpeningItem(id: uuid(), content: .song(audioBlock)))
  }
```

(No dedupe: duplicates are allowed per spec; the immediate `presentedSheet = nil` prevents a double-append from one presentation. Song *requests* are intentionally not wired — only `onSongSelected` contributes.)

- [ ] **Step 4: Run to verify pass**

Run `-only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/
git commit -m "feature: add songs to the AMA opening playlist via the song-search sheet"
```

---

## Task 5: Voicetrack add — background upload owned by the model

**Files:**
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift`
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift`

**Interfaces:**
- Consumes: `RecordWithMultiStepPromptModel.askMeAnythingVoicetrack` + `onRecordingAccepted` (Task 1), `voicetrackUploadService`, `audioRecorder.deleteRecording`, `auth.jwt`.
- Produces:
  - `func voicetrackActionTapped()`
  - `func waitForPendingUploads() async` (internal test seam — awaits all in-flight upload tasks; load-bearing for deterministic tests)
  - background upload lifecycle keyed by item id.

- [ ] **Step 1: Write the failing tests**

```swift
  @Test func voicetrackAcceptAppendsProcessingRowThenCompletesAndCounts() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    var deleted: [URL] = []
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { deleted.append($0) }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, onStatus in
        await onStatus(.completed)
        return .mockWith(id: "vt-block", durationMS: 605_000)
      }
    } operation: {
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push"); return
      }
      let url = URL(fileURLWithPath: "/tmp/vt.wav")
      try recorder.onRecordingAccepted?(url, 60)

      expectNoDifference(model.openingItems.count, 1)
      #expect(model.openingItems.first?.content.is(\.voicetrack) == true)

      await model.waitForPendingUploads()

      #expect(model.isStartShowEnabled)
      expectNoDifference(deleted, [url])
      #expect(model.presentedAlert == nil)
    }
  }

  @Test func voicetrackUploadFailureRemovesRowAndAlertsAndDeletesFile() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    var deleted: [URL] = []
    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { deleted.append($0) }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        throw NSError(domain: "test", code: 1)
      }
    } operation: {
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
        Issue.record("Expected recorder push"); return
      }
      let url = URL(fileURLWithPath: "/tmp/vt.wav")
      try recorder.onRecordingAccepted?(url, 60)
      await model.waitForPendingUploads()

      #expect(model.openingItems.isEmpty)
      #expect(model.presentedAlert != nil)
      expectNoDifference(deleted, [url])
    }
  }

  @Test func acceptWithoutAuthThrowsAndAddsNothing() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

    model.voicetrackActionTapped()
    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected recorder push"); return
    }

    #expect(throws: RecordPromptError.self) {
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/vt.wav"), 60)
    }
    #expect(model.openingItems.isEmpty)
  }

  @Test func outOfOrderCompletionsPreserveRowOrder() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { vt, _, _, onStatus in
        await onStatus(.completed)
        let ms = vt.title.contains("first") ? 100_000 : 200_000
        return .mockWith(id: vt.title, durationMS: ms)
      }
    } operation: {
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))

      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let r1) = coordinator.path.last else { return }
      try r1.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/first.wav"), 10)
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let r2) = coordinator.path.last else { return }
      try r2.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/second.wav"), 10)

      await model.waitForPendingUploads()

      expectNoDifference(model.openingItems.count, 2)
      expectNoDifference(model.openingItems.map(\.readyDurationMS), [100_000, 200_000])
    }
  }
```

(The out-of-order test relies on the model building the voicetrack `title` deterministically; see Step 3's `voicetrackTitle`. Adjust the `.contains("first")` discriminator to match whatever the title format yields for the two accept-times, or set `date.now` differently per accept — the point is that two ready rows keep their append order.)

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `voicetrackActionTapped` is an empty stub; `waitForPendingUploads` undefined.

- [ ] **Step 3: Implement the voicetrack wiring**

Add the task registry under `// MARK: - Properties`:

```swift
  @ObservationIgnored private var uploadTasks: [UUID: Task<Void, Never>] = [:]
```

Replace the `voicetrackActionTapped()` stub and add the helpers:

```swift
  func voicetrackActionTapped() {
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(stationId: stationId)
    recorder.onRecordingAccepted = { [weak self] url, _ in
      guard let self else { return }
      try acceptVoicetrack(url: url)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func waitForPendingUploads() async {
    for task in Array(uploadTasks.values) {
      await task.value
    }
  }
```

In `// MARK: - Private Helpers`:

```swift
  private func acceptVoicetrack(url: URL) throws {
    guard let jwt = auth.jwt else { throw RecordPromptError.notAuthenticated }
    let voicetrack = LocalVoicetrack(
      id: uuid(), originalURL: url, createdAt: now, title: voicetrackTitle(for: now))
    let itemId = uuid()
    openingItems.append(
      AMAOpeningItem(id: itemId, content: .voicetrack(voicetrack, completedDurationMS: nil)))
    let stationId = stationId
    uploadTasks[itemId] = Task { [weak self] in
      await self?.runVoicetrackUpload(
        itemId: itemId, voicetrack: voicetrack, stationId: stationId, jwt: jwt, originalURL: url)
    }
  }

  private func runVoicetrackUpload(
    itemId: UUID, voicetrack: LocalVoicetrack, stationId: String, jwt: String, originalURL: URL
  ) async {
    defer { uploadTasks[itemId] = nil }
    do {
      let audioBlock = try await voicetrackUploadService.processVoicetrack(
        voicetrack, stationId, jwt
      ) { [weak self] status in
        self?.updateVoicetrackStatus(itemId: itemId, status: status)
      }
      guard openingItems[id: itemId] != nil else {
        await audioRecorder.deleteRecording(originalURL)
        return
      }
      completeVoicetrack(itemId: itemId, audioBlock: audioBlock)
      await audioRecorder.deleteRecording(originalURL)
    } catch {
      await audioRecorder.deleteRecording(originalURL)
      guard !Task.isCancelled else { return }
      openingItems.remove(id: itemId)
      presentedAlert = .voicetrackUploadFailed(error.localizedDescription)
    }
  }

  private func updateVoicetrackStatus(itemId: UUID, status: LocalVoicetrackStatus) {
    openingItems[id: itemId]?.content.modify(\.voicetrack) { $0.0.status = status }
  }

  private func completeVoicetrack(itemId: UUID, audioBlock: AudioBlock) {
    openingItems[id: itemId]?.content.modify(\.voicetrack) {
      $0.0.status = .completed
      $0.0.audioBlockId = audioBlock.id
      $0.1 = audioBlock.durationMS
    }
  }

  private func voicetrackTitle(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    return "Voicetrack \(formatter.string(from: date).lowercased())"
  }

  private func cancelUploads() {
    for task in uploadTasks.values { task.cancel() }
  }
```

Wire abandonment cancellation into `backButtonTapped()`:

```swift
  func backButtonTapped() {
    cancelUploads()
    navigationCoordinator.pop()
  }
```

> **Note on `.modify(\.voicetrack)`:** the associated values are the tuple `(LocalVoicetrack, completedDurationMS: Int?)`, so inside the closure `$0.0` is the voicetrack and `$0.1` is the duration. Verify `@CasePathable` synthesizes the `voicetrack` case key path with tuple access; if the tuple binding is awkward, read `pfw-case-paths` and use the generated `AllCasePaths` accessor.

- [ ] **Step 4: Run to verify pass**

Run `-only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests`. Expected: PASS.

- [ ] **Step 5: Add the abandonment-cancellation test (deterministic via `Task.yield()`)**

```swift
  @Test func backButtonCancelsInFlightUploads() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    try await withDependencies {
      $0.uuid = .incrementing
      $0.date.now = Date(timeIntervalSince1970: 0)
      $0.audioRecorder.deleteRecording = { _ in }
      $0.voicetrackUploadService = VoicetrackUploadService { _, _, _, _ in
        while !Task.isCancelled { await Task.yield() }
        throw CancellationError()
      }
    } operation: {
      let model = AskMeAnythingSetupPageModel(stationId: testStationId)
      coordinator.push(.askMeAnythingSetupPage(model))
      model.voicetrackActionTapped()
      guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else { return }
      try recorder.onRecordingAccepted?(URL(fileURLWithPath: "/tmp/vt.wav"), 60)

      model.backButtonTapped()
      await model.waitForPendingUploads()

      #expect(model.presentedAlert == nil)
      #expect(coordinator.path.isEmpty)
    }
  }
```

Run it. Expected: PASS (cancellation short-circuits before the failure alert; navigation popped).

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/
git commit -m "feature: record AMA voicetracks with background upload, rollback, and cleanup"
```

---

## Task 6: Data-driven view + row component + alert binding

**Files:**
- Create: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningRowView.swift` (register in pbxproj)
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift` (add `openingRows`)
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageView.swift`
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift`

**Interfaces:**
- Consumes: `openingItems`, `AMAOpeningItem`.
- Produces:
  - `struct AMAOpeningRowData: Identifiable, Equatable { let id: UUID; let title: String; let subtitle: String; let subtitleColor: Color; let iconSystemName: String?; let albumImageUrl: URL?; let trailingText: String?; let isProcessing: Bool; let showsPin: Bool }`
  - `var AskMeAnythingSetupPageModel.openingRows: [AMAOpeningRowData]`
  - `struct AMAOpeningRowView: View`

- [ ] **Step 1: Write the failing test for `openingRows`**

```swift
  @Test func openingRowsResolveIntroSongAndVoicetrackDisplayData() {
    let model = withDependencies { $0.uuid = .incrementing } operation: {
      AskMeAnythingSetupPageModel(stationId: testStationId)
    }
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!,
        content: .intro(.mockWith(id: "intro", durationMS: 30_000))))
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!,
        content: .song(.mockWith(id: "song", title: "Song X", artist: "Artist Y", durationMS: 200_000))))
    var vt = LocalVoicetrack(
      id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!,
      originalURL: URL(fileURLWithPath: "/tmp/a.wav"),
      status: .uploading(progress: 0.5), createdAt: Date(timeIntervalSince1970: 0), title: "VT")
    model.openingItems.append(
      AMAOpeningItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!,
        content: .voicetrack(vt, completedDurationMS: nil)))

    let rows = model.openingRows
    expectNoDifference(rows.count, 3)
    expectNoDifference(rows[0].title, "Show Intro")
    expectNoDifference(rows[0].subtitle, "Your voice")
    expectNoDifference(rows[0].trailingText, "0:30")
    #expect(rows[0].showsPin)
    expectNoDifference(rows[1].title, "Song X")
    expectNoDifference(rows[1].subtitle, "Artist Y")
    expectNoDifference(rows[1].trailingText, "3:20")
    #expect(rows[2].isProcessing)
    #expect(rows[2].trailingText == nil)
  }
```

- [ ] **Step 2: Run to verify failure**

Expected: FAIL — `openingRows` / `AMAOpeningRowData` undefined.

- [ ] **Step 3: Create `AMAOpeningRowData` + `AMAOpeningRowView`**

`PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningRowView.swift`:

```swift
import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct AMAOpeningRowData: Identifiable, Equatable {
  let id: UUID
  let title: String
  let subtitle: String
  let subtitleColor: Color
  let iconSystemName: String?
  let albumImageUrl: URL?
  let trailingText: String?
  let isProcessing: Bool
  let showsPin: Bool
}

struct AMAOpeningRowView: View {
  @Environment(\.displayScale) private var displayScale
  let data: AMAOpeningRowData

  var body: some View {
    HStack(spacing: 12) {
      leading
      VStack(alignment: .leading, spacing: 2) {
        Text(data.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaTextPrimary)
          .lineLimit(1)
        Text(data.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(data.subtitleColor)
          .lineLimit(1)
      }
      Spacer()
      trailing
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceRow)
  }

  @ViewBuilder private var leading: some View {
    if let url = data.albumImageUrl {
      WebImage(
        url: url,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 45, height: 45), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
      .frame(width: 45, height: 45)
      .clipShape(RoundedRectangle(cornerRadius: 4))
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.playolaRed)
          .frame(width: 45, height: 45)
        Image(systemName: data.iconSystemName ?? "music.note")
          .font(.system(size: 20))
          .foregroundColor(.playolaTextPrimary)
      }
    }
  }

  @ViewBuilder private var trailing: some View {
    if data.isProcessing {
      ProgressView()
        .tint(.playolaTextPrimary)
        .scaleEffect(0.8)
    } else {
      HStack(spacing: 8) {
        Text(data.trailingText ?? "")
          .font(.custom(FontNames.Inter_400_Regular, size: 11))
          .foregroundColor(.playolaTextDisabled)
        Image(systemName: data.showsPin ? "pin" : "checkmark")
          .font(.system(size: 14))
          .foregroundColor(.playolaTextDisabled)
      }
    }
  }
}
```

(Confirm `RemoteArtwork.downsampleContext` and `Color.playolaSurfaceRow` exist — both are used by `StagingRowView`/the current AMA view. Match project artwork convention: `WebImage`, never `AsyncImage`.)

- [ ] **Step 4: Add `openingRows` to the model**

In `// MARK: - View Helpers`:

```swift
  var openingRows: [AMAOpeningRowData] {
    openingItems.map { item in
      switch item.content {
      case .intro(let block):
        return AMAOpeningRowData(
          id: item.id, title: "Show Intro", subtitle: "Your voice",
          subtitleColor: .playolaTextDisabled, iconSystemName: "mic", albumImageUrl: nil,
          trailingText: durationLabel(block.durationMS), isProcessing: false, showsPin: true)
      case .song(let block):
        return AMAOpeningRowData(
          id: item.id, title: block.title, subtitle: block.artist,
          subtitleColor: .playolaTextDisabled, iconSystemName: nil, albumImageUrl: block.imageUrl,
          trailingText: durationLabel(block.durationMS), isProcessing: false, showsPin: false)
      case .voicetrack(let voicetrack, let completedDurationMS):
        return AMAOpeningRowData(
          id: item.id, title: voicetrack.title, subtitle: voicetrack.subtitleText,
          subtitleColor: voicetrack.subtitleColor, iconSystemName: "mic", albumImageUrl: nil,
          trailingText: completedDurationMS.map { durationLabel($0) },
          isProcessing: voicetrack.isProcessing, showsPin: false)
      }
    }
  }
```

Remove the now-unused `introRowTitle`/`introRowSubtitle` helpers (their strings moved into `openingRows`). If any test still references them, update it.

- [ ] **Step 5: Make the view data-driven**

In `AskMeAnythingSetupPageView.swift`:

Replace `openingPlaylistContent` (lines 122-130) so it renders rows instead of the single hardcoded `showIntroRow`:

```swift
  private var openingPlaylistContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      openingPlaylistHeading
        .padding(.horizontal, 16)
      VStack(spacing: 0) {
        ForEach(model.openingRows) { row in
          AMAOpeningRowView(data: row)
        }
      }
      addToShowCard
        .padding(.horizontal, 16)
    }
  }
```

Delete the `showIntroRow` computed property (lines 143-174) — it is replaced by `AMAOpeningRowView`.

Add the alert binding to the root view. In `body`, after `.safeAreaInset(edge: .bottom) { bottomBar }` (line 31), add:

```swift
    .playolaAlert($model.presentedAlert)
```

- [ ] **Step 6: Run to verify pass + build the app target**

Run `-only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests` (PASS) and a full `xcodebuild build` of the `PlayolaRadio` scheme to confirm the view compiles (zero control flow in the page view; conditionals live in `AMAOpeningRowView`).

- [ ] **Step 7: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/ PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feature: render the AMA opening playlist as data-driven rows with an alert"
```

---

## Task 7: Full-suite regression + lint

**Files:** none (verification task).

- [ ] **Step 1: Run the touched-area suites in full**

Run `AskMeAnythingSetupPageTests`, `RecordWithMultiStepPromptTests`, and `BroadcastPageTests` (Broadcast shares `voicetrackUploadService` / `LocalVoicetrack` / `SongSearchPageModel` patterns). Expected: all PASS.

- [ ] **Step 2: Lint + format**

```bash
make format
make lint
```

Fix any violations. (Pre-commit runs swift-format only; CI runs SwiftLint unpinned — `make lint` locally catches CI-only failures.)

- [ ] **Step 3: Full build under the CI Xcode**

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
xcodebuild build -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,name=iPhone 16' -skipPackagePluginValidation
```

Expected: BUILD SUCCEEDED with warnings-as-errors clean.

- [ ] **Step 4: Commit any lint/format fixups**

```bash
git add -A && git commit -m "chore: format and lint AMA opening-playlist changes"
```

---

## Self-Review (checked against the spec)

**Spec coverage:**
- §2 D1 (song + voicetrack adds; Q/A stub) → Tasks 4, 5; Q/A stub left inert in Task 3.
- §2 D2 (append-only; failure rollback the only removal) → Task 5 rollback.
- §2 D3 (recorder deferred mode) → Task 1.
- §2 D4 (Start Show no-op, enable at 10:00) → Task 3 readiness; `startShowButtonTapped()` stays inert.
- §3.1 (no `any StagingItem` as source of truth) → Task 2 concrete type; Task 6 resolves `AMAOpeningRowData`.
- §3.2 (authoritative `durationMS`) → Task 2 `readyDurationMS`; Task 5 `completedDurationMS = block.durationMS`.
- §3.3 (processing excluded) → Task 2 `isReady`.
- §3.6 (AMA owns original-`.wav` cleanup, success + failure) → Task 5 `deleteRecording` on both paths.
- §3.7 (song requests don't count) → Task 4 wires only `onSongSelected`.
- §3.8 (song sheet self-dismiss) → Task 4.
- §3.9 ("past Q&As" copy removed) → Task 3.
- §3.10 / §9 (floor/ceil formatting) → Task 3 `durationLabel` (floor) + `durationLabelCeil`.
- §9 (data-driven view + alert binding) → Task 6.
- §11 test boundaries → Tasks 1-6 tests (599,999/600,000, processing exclusion, returned-duration accounting, out-of-order order, duplicate acceptance, file handoff without premature deletion, failure rollback, abandonment, unchanged blocking intro, formatting invariant).

**Placeholder scan:** no TBD/TODO; every code step carries real code. Two intentional implementer-judgment notes are flagged inline (the `.modify(\.voicetrack)` tuple access; the out-of-order title discriminator) — both are verification hooks, not missing content.

**Type consistency:** `openingItems`, `AMAOpeningItem.Content` cases (`intro`/`song`/`voicetrack`), `readyDurationMS`, `isReady`, `onRecordingAccepted`, `askMeAnythingVoicetrack`, `waitForPendingUploads`, `AMAOpeningRowData`, `openingRows`, `durationLabel`/`durationLabelCeil`, `voicetrackUploadFailed` — names are used identically across tasks.
