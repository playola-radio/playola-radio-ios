# Artist Congrats Recording (M3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use `- [ ]` checkboxes. Invoke the applicable `pfw-*` skills before writing Swift (pfw-observable-models, pfw-dependencies, pfw-sharing, pfw-modern-swiftui, pfw-testing, pfw-custom-dump).

**Goal:** The station owner records an audio congrats for a giveaway winner; it uploads via the existing voicetrack pipeline and is submitted to the server, which airs it.

**Architecture:** Mirrors M2. The owner-only `giveaway_winner_pending` push writes a durable `CongratsAction` into `@Shared(.pendingCongratsActions)` (keyed by eventId); `MainContainerModel` (the existing arbiter) presents a dedicated congrats sheet; the sheet records (reusing RecordPage components) → uploads via `VoicetrackUploadService` → POSTs the congrats. The push handler/arbiter only mutate/present; the sheet model drives record→upload→submit with durable resume/retry.

**Tech Stack:** SwiftUI, `@Observable` MV models, swift-dependencies, swift-sharing, XCTest/Swift Testing.

## Global Constraints

- Inherits `GiveawayFeature.isLiveDataEnabled` (dark in prod, live in staging) — same gate as M1/M2; no new gating machinery. `develop` stays deployable.
- Keyed by the **per-airing event id** (`eventId`), never `giveawayId`.
- Reuse, don't reinvent: `VoicetrackUploadService.processVoicetrack`, RecordPage's `@Dependency(\.audioRecorder)`/`@Dependency(\.audioPlayer)` + `LiveWaveformView`/`WaveformView`, `LocalVoicetrack`, the M2 `MainContainerModel` arbiter + APNs delegate wiring.
- New `.swift` files hand-registered in `project.pbxproj` (explicit refs, app+staging targets; tests → test target). Exclude Xcode pbxproj churn (`name =`/`plugin:` re-normalization) from commits.
- Every `@DependencyClient` property needs an explicit default/`testValue`.
- Views contain **zero control flow** (opacity/`allowsHitTesting` off model booleans; bindings via dynamic-member, never `Binding(get:set:)`).
- **Run `make lint` AND `make format-check` before every push** (the pre-commit hook runs swift-format only, NOT SwiftLint). Use `Button(action:label:)` (never trailing-closure label). Revert Xcode pbxproj churn.
- Tests: Swift Testing (`@Test`, `@MainActor struct`), `expectNoDifference` for value compares, no `Task.sleep`. For file-backed `@Shared` (`pendingCongratsActions`), set values with an explicit `$shared.withLock { $0 = … }` and wrap arbiter tests in `await withMainSerialExecutor { … }` (see `.claude/TESTING.md`).
- `xcodebuild test` with `-skipPackagePluginValidation -skipMacroValidation` + a concrete sim id.

**Spec:** `docs/superpowers/specs/2026-06-25-artist-congrats-design.md`

---

## Stage 1 — Foundations

### Task 1: Revise `CongratsAction` (state model + eventId key)

**Files:**
- Modify: `PlayolaRadio/Models/CongratsAction.swift`
- Test: `PlayolaRadio/Models/CongratsActionTests.swift`

**Interfaces:**
- Produces:
  - `enum CongratsActionState: Codable, Equatable, Sendable { case pending; case recorded(localRecordingPath: String); case uploaded(audioBlockId: String); case submitted; case alreadyClosed; case skipped }`
  - `struct CongratsAction { let eventId; let stationId; var winnerName: String?; var prizeName: String?; var congratsExpiresAt: Date?; var state; var startedAt; var id: String { eventId } }`
  - helpers: `var audioBlockId: String?` (from `.uploaded`), `var localRecordingPath: String?` (from `.recorded`), `var isTerminal: Bool` (submitted/alreadyClosed/skipped).

- [ ] **Step 1: Write the failing tests** (extend the existing `CongratsActionTests`):

```swift
@Test func terminalStates() {
  var a = CongratsAction.mock
  a.state = .pending; #expect(!a.isTerminal)
  a.state = .recorded(localRecordingPath: "/x.m4a"); #expect(!a.isTerminal)
  a.state = .uploaded(audioBlockId: "ab1"); #expect(!a.isTerminal)
  a.state = .submitted; #expect(a.isTerminal)
  a.state = .alreadyClosed; #expect(a.isTerminal)
  a.state = .skipped; #expect(a.isTerminal)
}

@Test func associatedValueAccessors() {
  var a = CongratsAction.mock
  a.state = .recorded(localRecordingPath: "/tmp/rec.m4a")
  #expect(a.localRecordingPath == "/tmp/rec.m4a")
  #expect(a.audioBlockId == nil)
  a.state = .uploaded(audioBlockId: "ab1")
  #expect(a.audioBlockId == "ab1")
  #expect(a.localRecordingPath == nil)
}

@Test func codableRoundTripsWithAssociatedValues() throws {
  var a = CongratsAction.mock
  a.state = .uploaded(audioBlockId: "ab1")
  let data = try JSONEncoder().encode(a)
  expectNoDifference(try JSONDecoder().decode(CongratsAction.self, from: data), a)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** the revised enum + struct:

```swift
import Foundation

enum CongratsActionState: Codable, Equatable, Sendable {
  case pending
  case recorded(localRecordingPath: String)
  case uploaded(audioBlockId: String)
  case submitted
  case alreadyClosed
  case skipped
}

struct CongratsAction: Codable, Equatable, Sendable, Identifiable {
  let eventId: String
  let stationId: String
  var winnerName: String?
  var prizeName: String?
  var congratsExpiresAt: Date?
  var state: CongratsActionState
  var startedAt: Date

  var id: String { eventId }

  var audioBlockId: String? {
    if case .uploaded(let audioBlockId) = state { return audioBlockId }
    return nil
  }

  var localRecordingPath: String? {
    if case .recorded(let path) = state { return path }
    return nil
  }

  var isTerminal: Bool {
    switch state {
    case .submitted, .alreadyClosed, .skipped: return true
    case .pending, .recorded, .uploaded: return false
    }
  }

  static var mock: CongratsAction {
    CongratsAction(
      eventId: "event-1", stationId: "station-1", winnerName: "Jo", prizeName: "Two tickets",
      congratsExpiresAt: nil, state: .pending,
      startedAt: Date(timeIntervalSince1970: 1_781_722_800))
  }
}
```

- [ ] **Step 4: Run, verify pass. Commit** — `feat(congrats): revise CongratsAction state model, key by eventId`.

---

### Task 2: `pendingCongratsActions` shared dict + `GiveawayWinnerPendingPush`

**Files:**
- Modify: `PlayolaRadio/State/SharedUserDefaults.swift` (replace the `pendingCongratsAction` single-optional key)
- Create: `PlayolaRadio/Models/GiveawayWinnerPendingPush.swift`
- Test: `PlayolaRadio/Models/GiveawayWinnerPendingPushTests.swift`
- Register the new file in `project.pbxproj`.

**Interfaces:**
- Produces:
  - `@Shared(.pendingCongratsActions) var pendingCongratsActions: [String: CongratsAction]` (file storage `pending-congrats-actions.json`, default `[:]`).
  - `GiveawayWinnerPendingPush` — `init?(userInfo: [String: any Sendable])`; nil unless `type == "giveaway_winner_pending"` and `eventId`/`stationId` present. Fields: `eventId, stationId, giveawayId?, winnerName?, prizeName?, congratsExpiresAt?`.

- [ ] **Step 1: Failing test** (`GiveawayWinnerPendingPushTests`):

```swift
@Test func parsesValidPendingPush() {
  let p = GiveawayWinnerPendingPush(userInfo: [
    "type": "giveaway_winner_pending", "eventId": "e1", "stationId": "s1",
    "winnerName": "Jo", "prizeName": "Two tickets",
    "congratsExpiresAt": "2026-06-25T20:00:00.000Z",
  ])
  expectNoDifference(p?.eventId, "e1")
  expectNoDifference(p?.winnerName, "Jo")
  #expect(p?.congratsExpiresAt != nil)
}

@Test func rejectsWrongTypeOrMissingIds() {
  #expect(GiveawayWinnerPendingPush(userInfo: ["type": "giveaway_closed", "eventId": "e1"]) == nil)
  #expect(GiveawayWinnerPendingPush(userInfo: ["type": "giveaway_winner_pending"]) == nil)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** the shared key (in `SharedUserDefaults.swift`, replacing the old single-optional key):

```swift
extension SharedKey where Self == FileStorageKey<[String: CongratsAction]>.Default {
  /// Durable artist congrats progress, keyed by per-airing event id. Survives a kill and holds the
  /// recorded file path (`.recorded`) and uploaded audioBlockId (`.uploaded`) for resume/retry.
  static var pendingCongratsActions: Self {
    Self[
      .fileStorage(.documentsDirectory.appending(component: "pending-congrats-actions.json")),
      default: [:]]
  }
}
```

And `GiveawayWinnerPendingPush.swift`:

```swift
import Foundation

struct GiveawayWinnerPendingPush: Equatable, Sendable {
  let eventId: String
  let stationId: String
  let giveawayId: String?
  let winnerName: String?
  let prizeName: String?
  let congratsExpiresAt: Date?

  init?(userInfo: [String: any Sendable]) {
    guard userInfo["type"] as? String == "giveaway_winner_pending",
      let eventId = userInfo["eventId"] as? String,
      let stationId = userInfo["stationId"] as? String
    else { return nil }
    self.eventId = eventId
    self.stationId = stationId
    self.giveawayId = userInfo["giveawayId"] as? String
    self.winnerName = userInfo["winnerName"] as? String
    self.prizeName = userInfo["prizeName"] as? String
    self.congratsExpiresAt = (userInfo["congratsExpiresAt"] as? String).flatMap {
      ISO8601DateFormatter.playolaInternetDateTime.date(from: $0)
    }
  }
}
```

> Use the project's existing ISO-8601 parsing helper (grep for how `serverTime`/`opensAt` strings are parsed in `GiveawayEvent`/the shared decoder); match it rather than introducing a new formatter if one exists.

- [ ] **Step 4: Register file; remove any remaining references to the old `pendingCongratsAction` key (none expected — it's unused). Run, verify pass.**

- [ ] **Step 5: Commit** — `feat(congrats): event-keyed pendingCongratsActions store + winner-pending push model`.

---

### Task 3: APIClient `recordGiveawayEventCongrats`

**Files:**
- Modify: `PlayolaRadio/Core/API/APIClient.swift` (giveaway section), `PlayolaRadio/Core/API/APIClient+Live.swift`

**Interfaces:**
- Produces: `var recordGiveawayEventCongrats: @Sendable (_ jwt: String, _ eventId: String, _ audioBlockId: String) async throws -> Void = { _,_,_ in }`.

- [ ] **Step 1: Add the client property** (after the M2 giveaway methods):

```swift
/// Owner submits a recorded congrats (an uploaded voicetrack `audioBlockId`) for an event; the
/// server inserts it as a spin. Idempotent per (eventId, audioBlockId) on the server.
var recordGiveawayEventCongrats:
  @Sendable (_ jwtToken: String, _ eventId: String, _ audioBlockId: String) async throws -> Void = {
    _, _, _ in
  }
```

- [ ] **Step 2: Live impl** (in `APIClient+Live.swift`, after `submitGiveawayWinnerDetails`):

```swift
recordGiveawayEventCongrats: { jwtToken, eventId, audioBlockId in
  try await authenticatedPostVoid(
    path: "/v1/giveaway-events/\(eventId)/congrats",
    token: jwtToken, parameters: ["audioBlockId": audioBlockId])
},
```

- [ ] **Step 3: Build (run a fast suite to compile). Commit** — `feat(api): record giveaway event congrats endpoint`.

---

## Stage 2 — Push handler

### Task 4: `handleGiveawayWinnerPendingPush` + APNs wiring

**Files:**
- Modify: `PlayolaRadio/Core/PushNotifications/PushNotifications.swift`
- Modify: `PlayolaRadio/PlayolaRadioApp.swift` (3 delegate entry points)
- Test: `PlayolaRadio/Core/PushNotifications/PushNotificationsTests.swift`

**Interfaces:**
- Produces: `PushNotificationsClient.handleGiveawayWinnerPendingPush: @Sendable ([String: any Sendable]) async -> Void` — gated on `isLiveDataEnabled`; writes/merges a `CongratsAction(.pending)` keyed by eventId; **never clobbers a non-terminal action** (only refresh metadata).

- [ ] **Step 1: Failing tests** (mirror the M2 winner-push tests):

```swift
@Test func pendingPushCreatesPendingCongrats() async {
  @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
  await PushNotificationsClient.liveValue.handleGiveawayWinnerPendingPush([
    "type": "giveaway_winner_pending", "eventId": "e1", "stationId": "s1",
    "winnerName": "Jo", "prizeName": "Two tickets",
  ])
  #expect(actions["e1"]?.state == .pending)
  #expect(actions["e1"]?.winnerName == "Jo")
}

@Test func pendingPushDoesNotClobberInProgressRecording() async {
  @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
  $actions.withLock {
    $0 = ["e1": CongratsAction(
      eventId: "e1", stationId: "s1", winnerName: "Jo", prizeName: "P",
      congratsExpiresAt: nil, state: .recorded(localRecordingPath: "/tmp/r.m4a"), startedAt: Date())]
  }
  await PushNotificationsClient.liveValue.handleGiveawayWinnerPendingPush([
    "type": "giveaway_winner_pending", "eventId": "e1", "stationId": "s1", "winnerName": "Jo",
  ])
  // The in-progress recording must survive a duplicate push.
  #expect(actions["e1"]?.state == .recorded(localRecordingPath: "/tmp/r.m4a"))
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** the handler (live client closure):

```swift
handleGiveawayWinnerPendingPush: { userInfo in
  guard GiveawayFeature.isLiveDataEnabled else { return }
  guard let push = GiveawayWinnerPendingPush(userInfo: userInfo) else {
    if userInfo["type"] as? String == "giveaway_winner_pending" {
      reportIssue("Dropped malformed giveaway_winner_pending push: \(userInfo)")
    }
    return
  }
  @Shared(.pendingCongratsActions) var actions
  let actionsShared = $actions
  await MainActor.run {
    actionsShared.withLock { dict in
      if let existing = dict[push.eventId] {
        // Never reset a non-terminal in-progress action; only refresh metadata.
        if !existing.isTerminal {
          var updated = existing
          updated.winnerName = push.winnerName ?? existing.winnerName
          updated.prizeName = push.prizeName ?? existing.prizeName
          updated.congratsExpiresAt = push.congratsExpiresAt ?? existing.congratsExpiresAt
          dict[push.eventId] = updated
          return
        }
      }
      dict[push.eventId] = CongratsAction(
        eventId: push.eventId, stationId: push.stationId, winnerName: push.winnerName,
        prizeName: push.prizeName, congratsExpiresAt: push.congratsExpiresAt,
        state: .pending, startedAt: Date())
    }
  }
}
```

Add the property to the `@DependencyClient` struct (with default). Wire the 3 delegate entry points in `PlayolaRadioApp.swift` for `type == "giveaway_winner_pending"` exactly like the M2 `giveaway_winner` branch (background `didReceiveRemoteNotification` → call then `completionHandler(.newData)`; `willPresent` → call, `completionHandler([])`; `didReceive` → call inside the Task, then `completionHandler()`).

- [ ] **Step 4: Run, verify pass. Commit** — `feat(congrats): winner-pending push handler writes pending CongratsAction`.

---

## Stage 3 — Congrats sheet model

### Task 5: `GiveawayCongratsSheetModel` (record → upload → submit, resume/retry/skip)

**Files:**
- Create: `PlayolaRadio/Views/Pages/GiveawayCongratsSheet/GiveawayCongratsSheetModel.swift`
- Test: `PlayolaRadio/Views/Pages/GiveawayCongratsSheet/GiveawayCongratsSheetModelTests.swift`
- Register both in `project.pbxproj`.

**Interfaces:**
- Consumes: `@Dependency(\.audioRecorder)`, `@Dependency(\.audioPlayer)`, `@Dependency(\.voicetrackUploadService)` (or `VoicetrackUploadService` key — grep its dependency key), `@Dependency(\.api)`, `@Shared(.auth)`, `@Shared(.pendingCongratsActions)`. Reuse the recording-phase pattern from `RecordPageModel` (audioRecorder.requestPermission/startRecording/stopRecording→URL/currentTime/getAudioLevel; audioPlayer for playback).
- Produces: `@MainActor @Observable final class GiveawayCongratsSheetModel: ViewModel`:
  - `init(action: CongratsAction, onClose: @escaping () -> Void)`
  - `headline: String` ("Congratulate \<winnerName\> on winning \<prizeName\>", with sensible fallbacks)
  - record/review state mirroring RecordPage (`recordingPhase`, `waveformSamples`, `recordingDuration`, playback)
  - `onRecordTapped()/onStopTapped()/onPlayTapped()` async
  - `sendButtonTapped() async` (record→persist→upload→submit), `skipButtonTapped()`, `closeButtonTapped()`
  - view helpers (`canSend`, `sendButtonTitle`, `isUploading`, `uploadStatusText`, opacity swaps, `presentedAlert`)

- [ ] **Step 1: Failing tests** (use a `VoicetrackUploadService` test double + `api` override):

```swift
@Test func sendUploadsThenSubmitsAndMarksSubmitted() async {
  @Shared(.auth) var auth = Auth(jwt: "jwt")
  @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
  $actions.withLock {
    $0 = ["e1": CongratsAction(
      eventId: "e1", stationId: "s1", winnerName: "Jo", prizeName: "P", congratsExpiresAt: nil,
      state: .recorded(localRecordingPath: "/tmp/r.m4a"), startedAt: Date())]
  }
  var congratsPosted: (String, String)?
  let model = withDependencies {
    $0.voicetrackUploadService.processVoicetrack = { _, _, _, _ in AudioBlock.mock(id: "ab1") }
    $0.api.recordGiveawayEventCongrats = { _, eventId, audioBlockId in
      congratsPosted = (eventId, audioBlockId)
    }
  } operation: {
    GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {})
  }
  await model.sendButtonTapped()
  expectNoDifference(actions["e1"]?.state, .submitted)
  expectNoDifference(congratsPosted?.0, "e1")
  expectNoDifference(congratsPosted?.1, "ab1")
}

@Test func uploadFailureStaysRecordedForRetry() async {
  struct Boom: Error {}
  @Shared(.auth) var auth = Auth(jwt: "jwt")
  @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
  $actions.withLock {
    $0 = ["e1": CongratsAction(eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil,
      congratsExpiresAt: nil, state: .recorded(localRecordingPath: "/tmp/r.m4a"), startedAt: Date())]
  }
  let model = withDependencies {
    $0.voicetrackUploadService.processVoicetrack = { _, _, _, _ in throw Boom() }
  } operation: { GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {}) }
  await model.sendButtonTapped()
  // Recording is not lost; user can retry.
  #expect(actions["e1"]?.localRecordingPath == "/tmp/r.m4a")
  #expect(model.presentedAlert != nil)
}

@Test func postFailureStaysUploadedForRetry() async {
  struct Boom: Error {}
  @Shared(.auth) var auth = Auth(jwt: "jwt")
  @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
  $actions.withLock {
    $0 = ["e1": CongratsAction(eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil,
      congratsExpiresAt: nil, state: .uploaded(audioBlockId: "ab1"), startedAt: Date())]
  }
  let model = withDependencies {
    $0.api.recordGiveawayEventCongrats = { _, _, _ in throw Boom() }
  } operation: { GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: {}) }
  await model.sendButtonTapped()  // reached at .uploaded → re-POST only
  #expect(actions["e1"]?.audioBlockId == "ab1")  // stays uploaded, retryable
}

@Test func skipMarksSkippedAndCloses() {
  @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
  $actions.withLock { $0 = ["e1": .mock] }
  var closed = false
  let model = GiveawayCongratsSheetModel(action: actions["e1"]!, onClose: { closed = true })
  model.skipButtonTapped()
  expectNoDifference(actions["e1"]?.state, .skipped)
  #expect(closed)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** following `pfw-observable-models`. Key logic:
  - **Send** routes on the current persisted state: `.pending`/just-recorded → persist the stopped recording's file into Application Support, set `.recorded(path)`, then upload; `.recorded` → upload from the path; `.uploaded` → POST only.
  - Upload: build `LocalVoicetrack(originalURL: URL(fileURLWithPath: path))`, read a **fresh** `auth.jwt`, call `voicetrackUploadService.processVoicetrack(_, action.stationId, jwt, { status in self.uploadStatus = status })`; on the returned `AudioBlock`, `$pendingCongratsActions.withLock { $0[eventId]?.state = .uploaded(audioBlockId: block.id) }`.
  - Submit: read a **fresh** `auth.jwt` again, `api.recordGiveawayEventCongrats(jwt, eventId, audioBlockId)`; success → `.submitted` + delete the local file + `onClose()`. Failure → keep `.uploaded`, set `presentedAlert`. A closed/expired error (map from the server's distinct error) → `.alreadyClosed` + `onClose()`.
  - Persist the recording file under `Application Support` (a small `CongratsRecordingStore` helper or inline `FileManager`); delete on submitted/skipped/alreadyClosed.
  - Reuse RecordPage's record/stop/playback methods verbatim where possible (extract shared helpers only if clean).

- [ ] **Step 4: Run, verify pass. Commit** — `feat(congrats): congrats sheet model (record/upload/submit, resume + retry)`.

---

## Stage 4 — Sheet view + presentation

### Task 6: Congrats sheet view + `PlayolaSheet.giveawayCongrats`

**Files:**
- Create: `PlayolaRadio/Views/Pages/GiveawayCongratsSheet/GiveawayCongratsSheetView.swift`
- Modify: `PlayolaRadio/Views/Reusable Components/PlayolaSheet.swift` (add case)
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainer.swift` (host the case **and** add it to the `.sheet` binding getter allow-list — the M2 P1 lesson: the content case alone is unreachable)
- Register the view in `project.pbxproj`.

**Interfaces:**
- Produces: `case giveawayCongrats(GiveawayCongratsSheetModel)`; `GiveawayCongratsSheetView(model:)`.

- [ ] **Step 1:** Add the enum case + host it in MainContainer's `.sheet` content switch **and** add `.giveawayCongrats` to the getter's `case .player, …:` allow-list (line ~51). Build the view from RecordPage's layout (`LiveWaveformView`/`WaveformView`, record/stop/play buttons, Send, Skip) — **zero control flow** (opacity/disabled off model booleans), `Button(action:label:)` form, `.playolaAlert($model.presentedAlert)`.
- [ ] **Step 2:** Add `#Preview`s (pending/recorded/uploading). Build; verify previews render. (Model covered in Task 5.)
- [ ] **Step 3: Commit** — `feat(congrats): congrats sheet view + PlayolaSheet case + host wiring`.

---

### Task 7: MainContainer arbiter — present congrats (priority, expiry, no re-prompt same session)

**Files:**
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift`
- Test: `PlayolaRadio/Views/Pages/MainContainer/MainContainerTests.swift`

**Interfaces:**
- Consumes: `@Shared(.pendingCongratsActions)`, `@Dependency(\.date.now)`, the nav coordinator, `GiveawayCongratsSheetModel`.
- Produces: extends `processGiveawayResolutions()` (or a sibling `processPendingCongrats()`) — present the most-urgent non-terminal, non-expired congrats when no blocking sheet AND no pending winner sheet is up (winner sheet wins). Track a per-session "dismissed this foreground" set so a dismissed congrats doesn't immediately re-present. Gated on `isLiveDataEnabled`.

- [ ] **Step 1: Failing tests** (wrap in `withMainSerialExecutor`, explicit `withLock`, per the M2 deflake lesson):

```swift
@Test func presentsPendingCongratsWhenNoWinnerSheet() async {
  await withMainSerialExecutor {
    @Shared(.mainContainerNavigationCoordinator) var nav
    nav.presentedSheet = nil
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
    $participations.withLock { $0 = [:] }
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = ["e1": CongratsAction(eventId: "e1", stationId: "s1", winnerName: "Jo", prizeName: "P",
        congratsExpiresAt: nil, state: .pending, startedAt: Date(timeIntervalSince1970: 100))]
    }
    let model = MainContainerModel()
    await model.processGiveawayResolutions()
    if case .giveawayCongrats = nav.presentedSheet {} else { Issue.record("expected congrats sheet") }
  }
}

@Test func winnerSheetTakesPriorityOverCongrats() async {
  await withMainSerialExecutor {
    @Shared(.mainContainerNavigationCoordinator) var nav
    nav.presentedSheet = nil
    @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
    $participations.withLock {
      $0 = ["w": GiveawayParticipation(id: "w", stationId: "s", prizeName: "P", winningNumber: 9,
        tapNumber: 9, status: .resolvedWon(submissionCompleted: false), tappedAt: Date())]
    }
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock { $0 = ["e1": .mock] }
    let model = MainContainerModel()
    await model.processGiveawayResolutions()
    if case .giveawayWinner = nav.presentedSheet {} else { Issue.record("winner sheet should win") }
  }
}

@Test func expiredCongratsNotPresented() async {
  await withMainSerialExecutor {
    @Shared(.mainContainerNavigationCoordinator) var nav
    nav.presentedSheet = nil
    @Shared(.pendingCongratsActions) var actions: [String: CongratsAction] = [:]
    $actions.withLock {
      $0 = ["e1": CongratsAction(eventId: "e1", stationId: "s1", winnerName: nil, prizeName: nil,
        congratsExpiresAt: Date(timeIntervalSince1970: 50), state: .pending,
        startedAt: Date(timeIntervalSince1970: 10))]
    }
    let model = withDependencies { $0.date = .constant(Date(timeIntervalSince1970: 100)) }
      operation: { MainContainerModel() }
    await model.processGiveawayResolutions()
    #expect(nav.presentedSheet == nil)
  }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement.** After the winner-sheet/loser-toast logic, add congrats presentation: if a winner sheet was just presented or is up, return (priority). Filter `pendingCongratsActions.values` to non-terminal AND not-expired (`congratsExpiresAt > now`, or — when nil — `startedAt + Self.congratsClientCutoff > now`, `congratsClientCutoff = 60 * 60`) AND not in the per-foreground dismissed set; sort by `congratsExpiresAt` (nil last) then `startedAt`; present the first as `.giveawayCongrats(GiveawayCongratsSheetModel(action:onClose:))`. `onClose` adds the eventId to the dismissed-this-foreground set and clears the sheet. Reset the dismissed set on each foreground (`refreshOnForeground`).

- [ ] **Step 4: Run, verify pass. Commit** — `feat(congrats): MainContainer arbiter presents congrats (priority + expiry)`.

---

## Final verification

- [ ] Full `xcodebuild test` (not just build) on a concrete sim, `-skipPackagePluginValidation -skipMacroValidation`. All giveaway + container + push + record suites green.
- [ ] `make lint` (0 violations) AND `make format-check` (PASS). Revert Xcode pbxproj churn; confirm only new file refs in the pbxproj diff.
- [ ] Simulator smoke (staging): simulate a `giveaway_winner_pending` push (or a DEBUG inject) → congrats sheet → record → Send → submitted; kill mid-upload → reopen → resumes from the recording.
- [ ] Codex review (pass/fail gate) + challenge on the diff; fix findings.
- [ ] PR against `develop`; body notes the server deps (spec §8: structured push fields + idempotent congrats POST) and that the feature is gated dark in prod.

## Self-review notes (spec coverage)

- Discovery push → Task 4. State model (recorded/uploaded + persisted recording) → Task 1. Event-keyed store → Task 2. APIClient → Task 3. Sheet model (record/upload/submit/resume/retry/skip, fresh JWT) → Task 5. View + PlayolaSheet case + binding allow-list → Task 6. Arbiter (priority, expiry, no-re-prompt-same-session) → Task 7.
- Server deps (structured push fields, idempotent congrats POST) = external (spec §8).
- Out of scope (spec §7): listener hearing the congrats, pending-congrats list endpoint, video.
- Confirm during impl: the exact `VoicetrackUploadService` dependency key name, `AudioBlock.mock(id:)` availability (add a test helper if absent), the project's ISO-8601 date parsing helper, and `RecordPage` component visibility (extract shared helpers only if clean — don't fork the recorder).
