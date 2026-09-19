# AMA Live Show — PR1 (Start Show → Live Monitor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the inert "Start Show" button on `AskMeAnythingSetupPage` to schedule an Ask-Me-Anything live show on the server and navigate to a new AMA Live monitor page that shows waiting-to-air → running states, live listener count, schedule-derived now-playing, a read-only upcoming queue, a client-computed preparedness meter, and an End Show (record outro → server end) flow.

**Architecture:** MV with `@Observable` `@MainActor` models (views are visual-only, zero control flow). The monitor derives everything from a periodically-refetched `Schedule` (never from the listener's `@Shared(.nowPlaying)`), polling schedule + listener count concurrently every 10s from a structured `.task`. Start Show uses an explicit submission-state machine; navigation replace targets the originating setup-model identity (not "whatever is on top"). The recorder owns its own pop; the live model owns the End POST.

**Tech Stack:** Swift, SwiftUI, Point-Free swift-dependencies / swift-sharing / swift-identified-collections / swift-case-paths / swift-custom-dump, Alamofire, PlayolaPlayer SDK (Spin/Schedule/AudioBlock), swift-testing.

**Spec:** `docs/superpowers/specs/2026-09-18-ama-live-show-design.md`

## Global Constraints

- **PlayolaPlayer SDK floor: 0.21.1** — `Spin.liveShowId: String?` and `Spin.isFiller: Bool?` are the load-bearing new fields. Both SPM package refs in `project.pbxproj` (PlayolaRadio + Staging targets) must be at 0.21.1.
- **iOS is a pure API consumer** — never design/implement/branch server authz. All server contracts in §2 of the spec are fixed.
- **No environment gate anywhere** — never `Config.shared.environment != .production` or any equivalent (repo policy).
- **New `.swift` files must be hand-registered in `project.pbxproj`** (explicit refs, not synced folders).
- **Views contain zero control flow** — no `if`/`if let`/`switch`/ternary in page views; push all conditional rendering into the model (opacity/enabled/hidden flags + precomputed strings).
- **Models own ALL text/logic** — every label, button title, formatted duration, and error message lives in the model.
- **Tests:** swift-testing (`@Test`/`@Suite`), every suite `@Suite(.freshSharedState)` + `@MainActor`; declare `@Shared` locally inside each test; use `withDependencies` (no DependenciesTestSupport trait); NEVER `Task.sleep` in tests (use `TestClock`); camelCase test names, no underscores; use `expectNoDifference` for value comparisons; assert enum cases via case-paths.
- **Commits:** no `Co-Authored-By` / co-sign trailers.
- **Copy is fixed by the design (D-A/D-C):** meter reads `"6:32 buffered"` + `"65% of 10 min"`; waiting footer is `"Show starts automatically"` (NOT "Listeners notified").

---

### Task 1: API types, closures, and typed conflict errors

**Files:**
- Modify: `PlayolaRadio/Core/API/APIClient.swift` (add closures near `getActiveListeningSessions` ~:924; add types + error cases near `APIError` :956-968)
- Test: covered by Task 2's live-impl tests (this task is type/closure scaffolding; the `@DependencyClient` default closures throw `unimplemented`, so there is nothing to unit-test in isolation).

**Interfaces:**
- Produces:
  - `struct StartLiveShowResponse: Decodable, Equatable, Sendable { let liveShowId: String; let scheduledStartsAt: Date; let scheduledEndsAt: Date }`
  - `struct EndLiveShowResponse: Decodable, Equatable, Sendable { let endingSpinId: String; let effectiveEndsAt: Date }`
  - `APIClient.startLiveShow: @Sendable (_ token: String, _ stationId: String, _ audioBlockIds: [String]) async throws -> StartLiveShowResponse`
  - `APIClient.endLiveShow: @Sendable (_ token: String, _ stationId: String, _ liveShowId: String, _ audioBlockId: String) async throws -> EndLiveShowResponse`
  - `APIError.liveShowUnavailable(delayUntil: Date?)` (start 409) and `APIError.liveShowReplaced` (end 409) and `APIError.liveShowFinished` (end 400 finished/unsafe)

- [ ] **Step 1: Add the response types**

Add above `enum APIError` in `APIClient.swift`:

```swift
struct StartLiveShowResponse: Decodable, Equatable, Sendable {
  let liveShowId: String
  let scheduledStartsAt: Date
  let scheduledEndsAt: Date
}

struct EndLiveShowResponse: Decodable, Equatable, Sendable {
  let endingSpinId: String
  let effectiveEndsAt: Date
}
```

- [ ] **Step 2: Add the two closures to `@DependencyClient struct APIClient`**

Insert after `getActiveListeningSessions` (~:930), keeping the `= { ... }` default that returns a placeholder (the `@DependencyClient` macro also synthesizes a throwing `unimplemented` for tests that don't override):

```swift
  // MARK: - Live Shows (Ask Me Anything)

  /// Schedules an Ask-Me-Anything live show: the ordered opening `audioBlockIds` plus three
  /// trailing fillers at a safe song boundary ≥2 min ahead. Duplicates allowed, order preserved.
  /// - Throws: `APIError.liveShowUnavailable(delayUntil:)` on a 409 conflict (unfinished show or a
  ///   materialized Episode/Q&A airing spin blocks go-live); the envelope's `delayUntil` is nil for
  ///   the unfinished-show case.
  var startLiveShow:
    @Sendable (_ token: String, _ stationId: String, _ audioBlockIds: [String]) async throws ->
      StartLiveShowResponse = { _, _, _ in
        StartLiveShowResponse(liveShowId: "", scheduledStartsAt: .distantPast, scheduledEndsAt: .distantPast)
      }

  /// Ends a live show by appending the outro `audioBlockId`; removes replaceable fillers. Idempotent.
  /// - Throws: `APIError.liveShowReplaced` on a 409 (the show was replaced);
  ///   `APIError.liveShowFinished` on a 400 (already finished / unsafe placement).
  var endLiveShow:
    @Sendable (_ token: String, _ stationId: String, _ liveShowId: String, _ audioBlockId: String)
      async throws -> EndLiveShowResponse = { _, _, _, _ in
        EndLiveShowResponse(endingSpinId: "", effectiveEndsAt: .distantPast)
      }
```

- [ ] **Step 3: Add the typed error cases**

Extend `APIError`:

```swift
enum APIError: Error, LocalizedError {
  case dataNotValid
  case validationError(String)
  case liveShowUnavailable(delayUntil: Date?)
  case liveShowReplaced
  case liveShowFinished

  var errorDescription: String? {
    switch self {
    case .dataNotValid:
      return "Invalid data received from server"
    case .validationError(let message):
      return message
    case .liveShowUnavailable:
      return "This station can\u{2019}t go live right now."
    case .liveShowReplaced:
      return "This live show was replaced."
    case .liveShowFinished:
      return "This live show has already finished."
    }
  }
}
```

- [ ] **Step 4: Build to verify the client compiles**

Run: `make lint` (or a build). Expected: compiles; `APIClient` has the two new closures and `APIError` the three new cases. No behavior yet.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/API/APIClient.swift
git commit -m "feature: add live-show API client types, closures, and conflict errors"
```

---

### Task 2: Live impls for `startLiveShow` / `endLiveShow` with 409/400 parsing

**Files:**
- Modify: `PlayolaRadio/Core/API/APIClient+Live.swift` (add a request struct near :23; a `delayUntil` parse helper near `parsePlayolaErrorMessage`; the two live closures in the `APIClient(...)` initializer literal, alongside `createVoicetrack` ~:568)
- Test: `PlayolaRadioTests/APIClientLiveShowTests.swift` (new) — pure decode/parse-helper tests (no network).

**Interfaces:**
- Consumes: `StartLiveShowResponse`, `EndLiveShowResponse`, `APIError.liveShowUnavailable/liveShowReplaced/liveShowFinished` (Task 1); existing `isoDecoder` (`JSONDecoderWithIsoFull`), `apiSession`, `transportFailure(_:)`, `parsePlayolaErrorMessage(from:)`.
- Produces: `func parseLiveShowDelayUntil(from data: Data) -> Date?` (fileprivate-visible to the test via `@testable import`).

- [ ] **Step 1: Write the failing decode/parse test**

Create `PlayolaRadioTests/APIClientLiveShowTests.swift`:

```swift
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct APIClientLiveShowTests {
  @Test func parsesDelayUntilFromConflictEnvelope() throws {
    let json = """
      { "error": { "message": "Not yet", "data": { "delayUntil": "2026-09-18T18:30:00.000Z" } } }
      """.data(using: .utf8)!
    let delayUntil = parseLiveShowDelayUntil(from: json)
    #expect(delayUntil != nil)
  }

  @Test func delayUntilNilWhenAbsent() {
    let json = #"{ "error": { "message": "An unfinished live show exists" } }"#.data(using: .utf8)!
    #expect(parseLiveShowDelayUntil(from: json) == nil)
  }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/APIClientLiveShowTests` (with the repo's standard sim id + `-skipPackagePluginValidation`).
Expected: FAIL — `parseLiveShowDelayUntil` not defined.

- [ ] **Step 3: Add the request struct and parse helper**

In `APIClient+Live.swift`, add next to `CreateVoicetrackParameters` (~:26):

```swift
private struct StartLiveShowParameters: Encodable, Sendable {
  let type: String
  let audioBlockIds: [String]
}

private struct EndLiveShowParameters: Encodable, Sendable {
  let audioBlockId: String
}
```

And near `parsePlayolaErrorMessage` (or just below the request helpers, ~:78) add the delayUntil parser. Keep it non-`private` (file-scope) so `@testable import` reaches it:

```swift
/// Parses the `delayUntil` timestamp out of a live-show 409 conflict envelope
/// (`{ error: { data: { delayUntil: ISO8601 } } }`). Returns nil when absent (e.g. the
/// unfinished-show conflict, which carries no delayUntil).
func parseLiveShowDelayUntil(from data: Data) -> Date? {
  struct Envelope: Decodable {
    struct ErrorBody: Decodable {
      struct DataBody: Decodable { let delayUntil: Date? }
      let data: DataBody?
    }
    let error: ErrorBody?
  }
  let decoder = JSONDecoderWithIsoFull()
  return (try? decoder.decode(Envelope.self, from: data))?.error?.data?.delayUntil
}
```

- [ ] **Step 4: Run the parse tests to verify they pass**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/APIClientLiveShowTests`
Expected: PASS.

- [ ] **Step 5: Add the two live closures**

In the `APIClient(...)` initializer literal in `APIClient+Live.swift`, add alongside `createVoicetrack` (mirror its manual status-code handling at :568-598):

```swift
      startLiveShow: { token, stationId, audioBlockIds in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/liveShow"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
        let parameters = StartLiveShowParameters(type: "ask-me-anything", audioBlockIds: audioBlockIds)

        let dataResponse = await apiSession.request(
          url, method: .post, parameters: parameters,
          encoder: JSONParameterEncoder.default, headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw transportFailure(dataResponse.error)
        }
        guard let data = dataResponse.value else { throw APIError.dataNotValid }

        if statusCode >= 200, statusCode < 300 {
          return try isoDecoder.decode(StartLiveShowResponse.self, from: data)
        } else if statusCode == 409 {
          throw APIError.liveShowUnavailable(delayUntil: parseLiveShowDelayUntil(from: data))
        } else {
          throw APIError.validationError(
            parsePlayolaErrorMessage(from: data) ?? "Failed to start live show")
        }
      },
      endLiveShow: { token, stationId, liveShowId, audioBlockId in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/liveShow/\(liveShowId)/end"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
        let parameters = EndLiveShowParameters(audioBlockId: audioBlockId)

        let dataResponse = await apiSession.request(
          url, method: .post, parameters: parameters,
          encoder: JSONParameterEncoder.default, headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw transportFailure(dataResponse.error)
        }
        guard let data = dataResponse.value else { throw APIError.dataNotValid }

        if statusCode >= 200, statusCode < 300 {
          return try isoDecoder.decode(EndLiveShowResponse.self, from: data)
        } else if statusCode == 409 {
          throw APIError.liveShowReplaced
        } else if statusCode == 400 {
          throw APIError.liveShowFinished
        } else {
          throw APIError.validationError(
            parsePlayolaErrorMessage(from: data) ?? "Failed to end live show")
        }
      },
```

- [ ] **Step 6: Build + run the parse tests again**

Run: `make lint` then `xcodebuild test -only-testing:PlayolaRadioTests/APIClientLiveShowTests`
Expected: compiles; tests PASS.

- [ ] **Step 7: Commit**

```bash
git add PlayolaRadio/Core/API/APIClient+Live.swift PlayolaRadioTests/APIClientLiveShowTests.swift
git commit -m "feature: implement live-show start/end API calls with conflict parsing"
```

---

### Task 3: Persisted `ActiveLiveShow` shared key (D-D bounded recovery)

**Files:**
- Create: `PlayolaRadio/Models/ActiveLiveShow.swift`
- Modify: `PlayolaRadio/State/SharedUserDefaults.swift` (add the `FileStorageKey` extension, mirror `lastPlayedStation` :116-122)
- Test: `PlayolaRadioTests/ActiveLiveShowKeyTests.swift` (new)

**Interfaces:**
- Produces:
  - `struct ActiveLiveShow: Codable, Equatable, Sendable { let liveShowId: String; let stationId: String }`
  - `@Shared(.activeLiveShow)` of type `ActiveLiveShow?` (FileStorage, default nil)

- [ ] **Step 1: Write the failing test**

Create `PlayolaRadioTests/ActiveLiveShowKeyTests.swift`:

```swift
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ActiveLiveShowKeyTests {
  @Test func persistsAndClears() {
    @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow? = nil
    #expect(activeLiveShow == nil)

    $activeLiveShow.withLock { $0 = ActiveLiveShow(liveShowId: "show-1", stationId: "station-1") }
    #expect(activeLiveShow?.liveShowId == "show-1")

    $activeLiveShow.withLock { $0 = nil }
    #expect(activeLiveShow == nil)
  }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/ActiveLiveShowKeyTests`
Expected: FAIL — `ActiveLiveShow` / `.activeLiveShow` not defined.

- [ ] **Step 3: Create the model**

`PlayolaRadio/Models/ActiveLiveShow.swift`:

```swift
import Foundation

/// The active AMA live show, persisted on Start Show success so the monitor can be resumed
/// after relaunch (bounded recovery, spec D-D). Cleared on confirmed end.
struct ActiveLiveShow: Codable, Equatable, Sendable {
  let liveShowId: String
  let stationId: String
}
```

- [ ] **Step 4: Add the shared key**

In `SharedUserDefaults.swift`, mirror `lastPlayedStation` (:116-122):

```swift
extension SharedKey where Self == FileStorageKey<ActiveLiveShow?>.Default {
  static var activeLiveShow: Self {
    Self[
      .fileStorage(.documentsDirectory.appending(component: "active-live-show.json")),
      default: nil]
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/ActiveLiveShowKeyTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Models/ActiveLiveShow.swift PlayolaRadio/State/SharedUserDefaults.swift PlayolaRadioTests/ActiveLiveShowKeyTests.swift
git commit -m "feature: persist active live show for bounded recovery"
```

---

### Task 4: `AMAOpeningItem.audioBlockId` + setup model `readyAudioBlockIds`

**Files:**
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift` (add `audioBlockId`)
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift` (add `readyAudioBlockIds`)
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift` (add cases; create the file if absent with `@Suite(.freshSharedState) @MainActor`)

**Interfaces:**
- Consumes: `AMAOpeningItem.Content` (`.intro(AudioBlock)`/`.song(AudioBlock)`/`.voicetrack(LocalVoicetrack, completedDurationMS: Int?)`), existing `isReady`.
- Produces:
  - `AMAOpeningItem.audioBlockId: String?` — `.intro`/`.song` → `block.id`; `.voicetrack` → `voicetrack.audioBlockId`.
  - `AskMeAnythingSetupPageModel.readyAudioBlockIds: [String]` — ordered `audioBlockId`s of ready items.
  - `AskMeAnythingSetupPageModel.allOpeningItemsReady: Bool`.

- [ ] **Step 1: Write the failing test**

Add to `AskMeAnythingSetupPageTests.swift`:

```swift
@Test func readyAudioBlockIdsAreOrderedAndSkipUnreadyVoicetracks() {
  @Shared(.auth) var auth = Auth(jwt: "test-token")

  let model = AskMeAnythingSetupPageModel(stationId: "station-1")
  let introBlock = AudioBlock.mockWith(id: "intro-1")
  let songBlock = AudioBlock.mockWith(id: "song-1")
  model.openingItems = [
    AMAOpeningItem(id: UUID(0), content: .intro(introBlock)),
    AMAOpeningItem(id: UUID(1), content: .song(songBlock)),
    AMAOpeningItem(
      id: UUID(2),
      content: .voicetrack(LocalVoicetrack(originalURL: URL(string: "file:///v.wav")!, title: "V"),
        completedDurationMS: nil)),
  ]

  expectNoDifference(model.readyAudioBlockIds, ["intro-1", "song-1"])
  #expect(model.allOpeningItemsReady == false)
}
```

(If `AudioBlock.mockWith(id:)` needs other args, use the defaulted `AudioBlock.mockWith(...)` signature the SDK exposes; only `id` matters here.)

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests/readyAudioBlockIdsAreOrderedAndSkipUnreadyVoicetracks`
Expected: FAIL — `readyAudioBlockIds` / `allOpeningItemsReady` not defined.

- [ ] **Step 3: Add `audioBlockId` to `AMAOpeningItem`**

In `AMAOpeningItem.swift`, add to the `extension AMAOpeningItem`:

```swift
  var audioBlockId: String? {
    switch content {
    case .intro(let block), .song(let block):
      return block.id
    case .voicetrack(let voicetrack, _):
      return voicetrack.audioBlockId
    }
  }
```

- [ ] **Step 4: Add the model accessors**

In `AskMeAnythingSetupPageModel.swift` (View Helpers section):

```swift
  var readyAudioBlockIds: [String] {
    openingItems.compactMap { $0.isReady ? $0.audioBlockId : nil }
  }

  var allOpeningItemsReady: Bool {
    openingItems.allSatisfy { $0.isReady }
  }
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests/readyAudioBlockIdsAreOrderedAndSkipUnreadyVoicetracks`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift
git commit -m "feature: expose ordered ready audioBlockIds for AMA opening"
```

---

### Task 5: `RecordWithMultiStepPromptModel.askMeAnythingOutro(stationId:)` factory

**Files:**
- Modify: `PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptModel.swift` (add factory in the `extension`, mirror `askMeAnythingIntro` :538-575)
- Test: `PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptTests.swift` (add a case; create file if absent)

**Interfaces:**
- Consumes: `RecordWithMultiStepPromptModel.init(...)`, `onUseRecording` (blocking upload mode), `RecordUploadProgress`, `voicetrackUploadService`, `RecordPromptError.notAuthenticated`.
- Produces: `static func askMeAnythingOutro(stationId: String) -> RecordWithMultiStepPromptModel` with `onUseRecording` set (mirrors intro), `onCompleted`/`onRecordingAccepted` left nil for the caller to set.

- [ ] **Step 1: Write the failing test**

```swift
@Test func askMeAnythingOutroConfiguresBlockingUploadFactory() {
  let model = RecordWithMultiStepPromptModel.askMeAnythingOutro(stationId: "station-1")
  #expect(model.screenTitle == "Record Outro")
  #expect(model.onUseRecording != nil)
  #expect(model.onRecordingAccepted == nil)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/RecordWithMultiStepPromptTests/askMeAnythingOutroConfiguresBlockingUploadFactory`
Expected: FAIL — `askMeAnythingOutro` not defined.

- [ ] **Step 3: Add the factory**

In the `extension RecordWithMultiStepPromptModel` (after `askMeAnythingVoicetrack`):

```swift
  static func askMeAnythingOutro(stationId: String) -> RecordWithMultiStepPromptModel {
    let model = RecordWithMultiStepPromptModel(
      screenTitle: "Record Outro",
      eyebrow: "RECORD AN OUTRO",
      guideBadge: "OPTIONAL GUIDE",
      title: "Wrap up your show.",
      subtitle: "Thank your listeners and let them know the AMA is ending.",
      steps: [
        RecordPromptStep(
          id: 1, label: "THANK", detail: "Thank listeners for their questions."),
        RecordPromptStep(
          id: 2, label: "WRAP UP",
          detail: "Let them know the AMA is ending and the station keeps playing."),
      ],
      trackLabel: "OUTRO",
      isUpsideDown: true)
    model.onUseRecording = { url, reportProgress in
      @Dependency(\.voicetrackUploadService) var voicetrackUploadService
      @Shared(.auth) var auth
      guard let jwt = auth.jwt else { throw RecordPromptError.notAuthenticated }
      let voicetrack = LocalVoicetrack(originalURL: url, title: "Outro")
      return try await voicetrackUploadService.processVoicetrack(voicetrack, stationId, jwt) {
        status in
        switch status {
        case .converting:
          reportProgress(.uploading(0))
        case .uploading(let progress):
          reportProgress(.uploading(progress))
        case .normalizing, .finalizing, .completed, .failed:
          reportProgress(.processing)
        }
      }
    }
    return model
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/RecordWithMultiStepPromptTests/askMeAnythingOutroConfiguresBlockingUploadFactory`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptModel.swift PlayolaRadio/Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptTests.swift
git commit -m "feature: add AMA outro recorder factory"
```

---

### Task 6: `AskMeAnythingLivePageModel` — phase, refresh, meter, listener count, End flow

**Files:**
- Create: `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageModel.swift`
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageTests.swift` (new)

**Interfaces:**
- Consumes: `APIClient.fetchSchedule`, `.getActiveListeningSessions`, `.endLiveShow` (Task 1/2); `@Shared(.auth)`, `@Shared(.activeLiveShow)` (Task 3), `@Shared(.mainContainerNavigationCoordinator)`; `DependencyDateProvider` (BroadcastPageModel.swift:15-21); `Schedule`, `Spin` (`airtime`, `endtime`, `liveShowId`, `isFiller`, `audioBlock`), `Spin.progress(at:)`; `RecordWithMultiStepPromptModel.askMeAnythingOutro` (Task 5).
- Produces (Task 7 & 9 depend on these):
  - `AskMeAnythingLivePageModel(stationId: String, liveShowId: String, scheduledStartsAt: Date)`
  - `enum Phase: Equatable { case loading, waiting, running, ending, ended, unavailable }`; `var phase: Phase`
  - `func startMonitoring() async` (structured refresh loop for the view's `.task`)
  - `func refreshNow() async`
  - `func endShowButtonTapped()`, `func submitEnd(outroAudioBlock: AudioBlock) async`, `func retryEndButtonTapped() async`, `func doneButtonTapped()`
  - View-helper strings/flags used by the view (Task 9).

- [ ] **Step 1: Write the failing tests**

Create `AskMeAnythingLivePageTests.swift`:

```swift
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AskMeAnythingLivePageTests {
  private func makeSpin(
    id: String, airtimeOffset: TimeInterval, durationMS: Int, now: Date,
    liveShowId: String?, isFiller: Bool? = nil
  ) -> Spin {
    Spin.mockWith(
      id: id,
      airtime: now.addingTimeInterval(airtimeOffset),
      audioBlock: .mockWith(endOfMessageMS: durationMS),
      liveShowId: liveShowId,
      isFiller: isFiller)
  }

  @Test func phaseIsRunningWhenNowPlayingBelongsToShow() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let spins = [
      makeSpin(id: "s1", airtimeOffset: -30, durationMS: 120_000, now: now, liveShowId: "show-1")
    ]
    let model = withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 1, uniqueUsers: 38, uniqueDevices: 1, anonymousSessions: 0))
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)
    }

    await model.refreshNow()

    #expect(model.phase == .running)
    #expect(model.listenerCountLabel == "38 listening")
  }

  @Test func phaseIsWaitingWhenShowSpinsAreUpcoming() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let spins = [
      makeSpin(id: "cur", airtimeOffset: -10, durationMS: 60_000, now: now, liveShowId: nil),
      makeSpin(id: "s1", airtimeOffset: 50, durationMS: 120_000, now: now, liveShowId: "show-1"),
    ]
    let model = withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)
    }

    await model.refreshNow()
    #expect(model.phase == .waiting)
  }

  @Test func neverRevertsRunningToWaitingOnEmptySchedule() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let running = [
      makeSpin(id: "s1", airtimeOffset: -5, durationMS: 120_000, now: now, liveShowId: "show-1")
    ]
    let empty: [Spin] = []
    let box = LockIsolated([running, empty])
    let model = withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in box.withValue { $0.removeFirst() } }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)
    }

    await model.refreshNow()   // running
    #expect(model.phase == .running)
    await model.refreshNow()   // schedule momentarily empty
    #expect(model.phase != .waiting)
  }

  @Test func bufferedMeterStopsAtFillerBoundary() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    // running show spin (60s remaining) + a contiguous show spin (120s) + a filler (should stop).
    let spins = [
      makeSpin(id: "s1", airtimeOffset: -60, durationMS: 120_000, now: now, liveShowId: "show-1"),
      makeSpin(id: "s2", airtimeOffset: 60, durationMS: 120_000, now: now, liveShowId: "show-1"),
      makeSpin(id: "f1", airtimeOffset: 180, durationMS: 180_000, now: now, liveShowId: "show-1", isFiller: true),
    ]
    let model = withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)
    }

    await model.refreshNow()
    // s1 ends at now+60, s2 ends at now+180; filler excluded → 180s buffered.
    #expect(model.bufferedMilliseconds == 180_000)
    #expect(model.bufferedMeterLabel == "3:00 buffered")
  }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingLivePageTests`
Expected: FAIL — `AskMeAnythingLivePageModel` not defined.

- [ ] **Step 3: Write the model**

Create `AskMeAnythingLivePageModel.swift`:

```swift
//
//  AskMeAnythingLivePageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class AskMeAnythingLivePageModel: ViewModel {

  enum Phase: Equatable { case loading, waiting, running, ending, ended, unavailable }

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.activeLiveShow) var activeLiveShow
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String, liveShowId: String, scheduledStartsAt: Date) {
    self.stationId = stationId
    self.liveShowId = liveShowId
    self.scheduledStartsAt = scheduledStartsAt
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let liveShowId: String
  let scheduledStartsAt: Date

  private let targetMilliseconds = 600_000
  private let pollInterval: Duration = .seconds(10)
  private let contiguityToleranceSeconds: TimeInterval = 2

  private var schedule: Schedule?
  private(set) var listenerCount: Int?
  private(set) var isStale = false
  private(set) var hasConfirmedRunning = false
  private(set) var endOutcome: EndLiveShowResponse?
  private var pendingOutroBlock: AudioBlock?
  var presentedAlert: PlayolaAlert?

  // MARK: - Lifecycle (driven by the view's .task)

  func startMonitoring() async {
    await refreshNow()
    while !Task.isCancelled {
      do { try await clock.sleep(for: pollInterval) } catch { return }
      if Task.isCancelled { return }
      await refreshNow()
    }
  }

  func refreshNow() async {
    async let scheduleFetch = fetchScheduleSafely()
    async let listenerFetch = fetchListenerCountSafely()
    let (newSchedule, scheduleOK) = await scheduleFetch
    let (count, listenerOK) = await listenerFetch

    if let newSchedule { schedule = newSchedule }
    if let count { listenerCount = count }
    isStale = !(scheduleOK && listenerOK)

    if let np = schedule?.nowPlaying(), np.liveShowId == liveShowId {
      hasConfirmedRunning = true
    }
  }

  // MARK: - Phase

  var phase: Phase {
    guard let schedule else { return endOutcome != nil ? .ending : .loading }

    if let np = schedule.nowPlaying(), np.liveShowId == liveShowId {
      return endOutcome != nil ? .ending : .running
    }

    if endOutcome != nil {
      return hasShowSpinsRemaining(in: schedule) ? .ending : .ended
    }

    if hasConfirmedRunning {
      return hasShowSpinsRemaining(in: schedule) ? .running : .ended
    }

    if hasUpcomingShowSpins(in: schedule) { return .waiting }

    return .unavailable
  }

  // MARK: - Now playing / queue

  var nowPlaying: Spin? { schedule?.nowPlaying() }

  var upcomingSpins: [Spin] {
    guard let schedule else { return [] }
    return schedule.current().filter { $0.airtime > now }
  }

  var nowPlayingProgress: Double {
    guard let spin = nowPlaying else { return 0 }
    return spin.progress(at: now)
  }

  // MARK: - Preparedness meter (spec §7.4 / D-A)

  var bufferedMilliseconds: Int {
    guard let schedule else { return 0 }
    let ordered = schedule.current().sorted { $0.airtime < $1.airtime }
    guard
      let startIdx = ordered.firstIndex(where: { $0.endtime > now && isShowSpin($0) })
    else { return 0 }

    var lastEnd = ordered[startIdx].endtime
    var idx = startIdx + 1
    while idx < ordered.count, isShowSpin(ordered[idx]) {
      guard ordered[idx].airtime <= lastEnd.addingTimeInterval(contiguityToleranceSeconds) else {
        break
      }
      lastEnd = ordered[idx].endtime
      idx += 1
    }

    let effectiveStart = max(now, ordered[startIdx].airtime)
    return max(0, Int(lastEnd.timeIntervalSince(effectiveStart) * 1000))
  }

  var bufferedMeterFraction: Double {
    min(1, Double(bufferedMilliseconds) / Double(targetMilliseconds))
  }

  private func isShowSpin(_ spin: Spin) -> Bool {
    spin.liveShowId == liveShowId && spin.isFiller != true
  }

  private func hasUpcomingShowSpins(in schedule: Schedule) -> Bool {
    schedule.current().contains { $0.liveShowId == liveShowId && $0.airtime > now }
  }

  private func hasShowSpinsRemaining(in schedule: Schedule) -> Bool {
    schedule.current().contains { $0.liveShowId == liveShowId && $0.endtime > now }
  }

  // MARK: - End Show flow (spec §9)

  func endShowButtonTapped() {
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingOutro(stationId: stationId)
    recorder.onCompleted = { [weak self] outroBlock in
      await self?.submitEnd(outroAudioBlock: outroBlock)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func submitEnd(outroAudioBlock: AudioBlock) async {
    pendingOutroBlock = outroAudioBlock
    guard let jwt = auth.jwt else {
      presentedAlert = .liveShowEndFailed { [weak self] in await self?.retryEndButtonTapped() }
      return
    }
    do {
      let outcome = try await api.endLiveShow(jwt, stationId, liveShowId, outroAudioBlock.id)
      endOutcome = outcome
      await refreshNow()
    } catch APIError.liveShowFinished {
      // The show already wrapped (natural exhaustion / race). Treat as ended; discard the outro.
      endOutcome = nil
      pendingOutroBlock = nil
      hasConfirmedRunning = true
      presentedAlert = .liveShowAlreadyEnded
    } catch {
      presentedAlert = .liveShowEndFailed { [weak self] in await self?.retryEndButtonTapped() }
    }
  }

  func retryEndButtonTapped() async {
    guard let block = pendingOutroBlock else { return }
    await submitEnd(outroAudioBlock: block)
  }

  func doneButtonTapped() {
    $activeLiveShow.withLock { $0 = nil }
    navigationCoordinator.switchToBroadcastMode(stationId: stationId)
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Ask Me Anything" }
  var listenerCountLabel: String { "\(listenerCount ?? 0) listening" }

  var nowPlayingTitle: String { nowPlaying?.audioBlock.title ?? "" }
  var nowPlayingArtist: String { nowPlaying?.audioBlock.artist ?? "" }
  var liveNowLabel: String { "LIVE NOW" }

  var bufferedMeterLabel: String { "\(durationLabel(bufferedMilliseconds)) buffered" }
  var bufferedPercentLabel: String {
    "\(Int((bufferedMeterFraction * 100).rounded()))% of 10 min"
  }

  var waitingCountdownLabel: String {
    let target = firstShowSpinAirtime ?? scheduledStartsAt
    let remaining = max(0, Int(target.timeIntervalSince(now)))
    return "Your Show Starts in \(durationLabel(remaining * 1000))"
  }

  var waitingSubtitleLabel: String {
    let target = firstShowSpinAirtime ?? scheduledStartsAt
    guard let np = nowPlaying else { return "Starts \(airtimeLabel(for: target))" }
    return "After \(np.audioBlock.title) finishes \u{00B7} \(timeString(for: target))"
  }

  var waitingFooterLabel: String { "Show starts automatically" }

  var addToShowTitle: String { "Add to Show" }
  var isAddToShowEnabled: Bool { false }  // PR2 wires this; rendered disabled in PR1.

  var endShowButtonTitle: String { "End Show" }
  var endingButtonTitle: String { "Ending\u{2026}" }
  var doneButtonTitle: String { "Done" }
  var unavailableMessage: String {
    "This show is no longer live. Your station is back to its regular schedule."
  }

  func airtimeLabel(for date: Date) -> String { "at \(timeString(for: date))" }

  // MARK: - Private Helpers

  private var firstShowSpinAirtime: Date? {
    schedule?.current()
      .filter { $0.liveShowId == liveShowId }
      .map(\.airtime)
      .min()
  }

  private func fetchScheduleSafely() async -> (Schedule?, Bool) {
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      return (
        Schedule(stationId: stationId, spins: spins, dateProvider: DependencyDateProvider()), true
      )
    } catch {
      return (nil, false)
    }
  }

  private func fetchListenerCountSafely() async -> (Int?, Bool) {
    guard let jwt = auth.jwt else { return (nil, false) }
    do {
      let response = try await api.getActiveListeningSessions(jwt, stationId, now, nil)
      return (response.summary.uniqueUsers, true)
    } catch {
      return (nil, false)
    }
  }

  private func durationLabel(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func timeString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm:ssa"
    return formatter.string(from: date)
  }
}
```

- [ ] **Step 4: Add the two `PlayolaAlert` factories used above**

In `PlayolaRadio/Views/Reusable Components/PlayolaAlert.swift`, add (mirror existing factory methods; single-button + retry uses the two-button init):

```swift
extension PlayolaAlert {
  static func liveShowEndFailed(retry: @escaping @MainActor () async -> Void) -> PlayolaAlert {
    PlayolaAlert(
      title: "Couldn\u{2019}t End the Show",
      message: "We couldn\u{2019}t end your show. Your outro is saved \u{2014} tap Retry to try again.",
      primaryButtonText: "Retry",
      primaryAction: retry,
      secondaryButtonText: "Cancel",
      secondaryAction: nil)
  }

  static var liveShowAlreadyEnded: PlayolaAlert {
    PlayolaAlert(
      title: "Your Show Already Wrapped",
      message: "This AMA already finished and your station is back to its regular schedule.",
      dismissButton: .default(Text("OK")))
  }
}
```

- [ ] **Step 5: Run the model tests to verify they pass**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingLivePageTests`
Expected: PASS (all four).

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageModel.swift "PlayolaRadio/Views/Reusable Components/PlayolaAlert.swift" PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageTests.swift
git commit -m "feature: add AMA live monitor model with phase, meter, and end flow"
```

> **Note (register file):** `AskMeAnythingLivePageModel.swift` and its test file must be added to `project.pbxproj` before the build compiles them — see Task 10. If executing inline and the build can't find the new file, do the pbxproj registration from Task 10 now.

---

### Task 7: Navigation — `askMeAnythingLivePage` Path case, targeted replace, guarded teardown

**Files:**
- Modify: `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift` (Path enum :80-100; `destinationView` switch :102-146; add replace helper; guard `cancelAbandonedAskMeAnythingSetups`)
- Test: `PlayolaRadioTests/MainContainerNavigationCoordinatorTests.swift` (add cases; create if absent)

**Interfaces:**
- Consumes: `AskMeAnythingLivePageModel` (Task 6); `AskMeAnythingSetupPageModel`; existing per-tab path key-paths, `setPath(_:at:)`, `cancelAbandonedAskMeAnythingSetups(from:to:)`.
- Produces:
  - `Path.askMeAnythingLivePage(AskMeAnythingLivePageModel)` + its `destinationView`.
  - `func replaceAskMeAnythingSetup(_ setupModel: AskMeAnythingSetupPageModel, with newPath: Path)` — finds the stack holding the setup model (any tab) and swaps that entry in place.

- [ ] **Step 1: Write the failing test**

Add to `MainContainerNavigationCoordinatorTests.swift`:

```swift
@Test func replaceAskMeAnythingSetupSwapsEntryInOriginatingStack() {
  @Shared(.activeTab) var activeTab = .artistDashboard
  let coordinator = MainContainerNavigationCoordinator()
  let setup = AskMeAnythingSetupPageModel(stationId: "station-1")
  coordinator.artistDashboardPath = [.askMeAnythingSetupPage(setup)]

  let live = AskMeAnythingLivePageModel(
    stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: Date())
  coordinator.replaceAskMeAnythingSetup(setup, with: .askMeAnythingLivePage(live))

  #expect(coordinator.artistDashboardPath.count == 1)
  guard case .askMeAnythingLivePage = coordinator.artistDashboardPath[0] else {
    Issue.record("expected live page on the stack")
    return
  }
}

@Test func replaceFindsSetupEvenWhenActiveTabChanged() {
  @Shared(.activeTab) var activeTab = .home  // active tab differs from the stack holding setup
  let coordinator = MainContainerNavigationCoordinator()
  let setup = AskMeAnythingSetupPageModel(stationId: "station-1")
  coordinator.artistDashboardPath = [.askMeAnythingSetupPage(setup)]

  let live = AskMeAnythingLivePageModel(
    stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: Date())
  coordinator.replaceAskMeAnythingSetup(setup, with: .askMeAnythingLivePage(live))

  guard case .askMeAnythingLivePage = coordinator.artistDashboardPath[0] else {
    Issue.record("expected live page on the artistDashboard stack")
    return
  }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/MainContainerNavigationCoordinatorTests/replaceAskMeAnythingSetupSwapsEntryInOriginatingStack`
Expected: FAIL — `askMeAnythingLivePage` / `replaceAskMeAnythingSetup` not defined.

- [ ] **Step 3: Add the Path case + destinationView**

In the `Path` enum, after `case recordWithMultiStepPromptPage(...)` (:100):

```swift
    case askMeAnythingLivePage(AskMeAnythingLivePageModel)
```

In `destinationView`, after the `recordWithMultiStepPromptPage` case (:144):

```swift
      case .askMeAnythingLivePage(let model):
        AskMeAnythingLivePageView(model: model)
```

- [ ] **Step 4: Add the targeted replace helper**

Add a method to `MainContainerNavigationCoordinator`:

```swift
  /// Replaces the `askMeAnythingSetupPage` entry for `setupModel` — in whichever tab stack holds
  /// it — with `newPath`, in place. Immune to the active tab changing during an await (spec §8):
  /// it targets the setup model's identity, not "whatever is on top now."
  func replaceAskMeAnythingSetup(
    _ setupModel: AskMeAnythingSetupPageModel, with newPath: Path
  ) {
    let stacks: [ReferenceWritableKeyPath<MainContainerNavigationCoordinator, [Path]>] = [
      \.homePath, \.stationsPath, \.yourLibraryPath, \.profilePath,
      \.artistStationPath, \.artistDashboardPath, \.settingsPath,
    ]
    for keyPath in stacks {
      guard
        let index = self[keyPath: keyPath].firstIndex(where: { path in
          guard case .askMeAnythingSetupPage(let model) = path else { return false }
          return model === setupModel
        })
      else { continue }
      var updated = self[keyPath: keyPath]
      updated[index] = newPath
      setPath(updated, at: keyPath)
      return
    }
  }
```

Note: `setPath` calls `cancelAbandonedAskMeAnythingSetups`, which calls `setupModel.setupAbandoned()`. The guard added in Task 8 (submission state `.scheduled`) makes that a no-op, so no uploads are cancelled.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/MainContainerNavigationCoordinatorTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift PlayolaRadioTests/MainContainerNavigationCoordinatorTests.swift
git commit -m "feature: add AMA live route and targeted setup-to-live replace"
```

---

### Task 8: Start Show flow in `AskMeAnythingSetupPageModel` (submission state, recovery, guard)

**Files:**
- Modify: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift` (implement `startShowButtonTapped()`; add `SubmissionState`; guard `setupAbandoned()`; add recovery + navigate helpers)
- Test: `PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift` (add cases)

**Interfaces:**
- Consumes: `readyAudioBlockIds`, `allOpeningItemsReady`, `hasRecordedIntro`, `isStartShowEnabled` (existing/Task 4); `api.startLiveShow`, `api.fetchSchedule`, `APIError.liveShowUnavailable` (Task 1/2); `@Shared(.activeLiveShow)` (Task 3); `navigationCoordinator.replaceAskMeAnythingSetup(_:with:)` (Task 7); `AskMeAnythingLivePageModel` init (Task 6); `DependencyDateProvider`.
- Produces: `enum SubmissionState`, `submissionState`, `func startShowButtonTapped() async`.

- [ ] **Step 1: Write the failing tests**

Add to `AskMeAnythingSetupPageTests.swift`:

```swift
@Test func startShowNavigatesToLiveOnSuccess() async {
  @Shared(.auth) var auth = Auth(jwt: "t")
  @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow? = nil
  @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
  @Shared(.activeTab) var activeTab = .artistDashboard

  let model = withDependencies {
    $0.api.startLiveShow = { _, _, _ in
      StartLiveShowResponse(
        liveShowId: "show-1", scheduledStartsAt: Date(), scheduledEndsAt: Date())
    }
  } operation: {
    AskMeAnythingSetupPageModel(stationId: "station-1")
  }
  model.openingItems = [
    AMAOpeningItem(id: UUID(0), content: .intro(.mockWith(id: "i", endOfMessageMS: 600_000)))
  ]
  coordinator.artistDashboardPath = [.askMeAnythingSetupPage(model)]

  await model.startShowButtonTapped()

  #expect(activeLiveShow?.liveShowId == "show-1")
  guard case .askMeAnythingLivePage = coordinator.artistDashboardPath[0] else {
    Issue.record("expected live page after start")
    return
  }
}

@Test func duplicateStartTapsRejected() async {
  @Shared(.auth) var auth = Auth(jwt: "t")
  @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow? = nil
  @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
  @Shared(.activeTab) var activeTab = .artistDashboard

  let callCount = LockIsolated(0)
  let model = withDependencies {
    $0.api.startLiveShow = { _, _, _ in
      callCount.withValue { $0 += 1 }
      return StartLiveShowResponse(
        liveShowId: "show-1", scheduledStartsAt: Date(), scheduledEndsAt: Date())
    }
  } operation: {
    AskMeAnythingSetupPageModel(stationId: "station-1")
  }
  model.openingItems = [
    AMAOpeningItem(id: UUID(0), content: .intro(.mockWith(id: "i", endOfMessageMS: 600_000)))
  ]
  coordinator.artistDashboardPath = [.askMeAnythingSetupPage(model)]

  await model.startShowButtonTapped()
  await model.startShowButtonTapped()  // no longer .editing → rejected

  #expect(callCount.value == 1)
}

@Test func startShowUnavailableShowsAlertAndReturnsToEditing() async {
  @Shared(.auth) var auth = Auth(jwt: "t")
  @Shared(.activeLiveShow) var activeLiveShow: ActiveLiveShow? = nil
  @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()

  let model = withDependencies {
    $0.api.startLiveShow = { _, _, _ in
      throw APIError.liveShowUnavailable(delayUntil: Date(timeIntervalSince1970: 2_000_000))
    }
  } operation: {
    AskMeAnythingSetupPageModel(stationId: "station-1")
  }
  model.openingItems = [
    AMAOpeningItem(id: UUID(0), content: .intro(.mockWith(id: "i", endOfMessageMS: 600_000)))
  ]

  await model.startShowButtonTapped()

  #expect(model.submissionState == .editing)
  #expect(model.presentedAlert != nil)
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests/startShowNavigatesToLiveOnSuccess`
Expected: FAIL — `startShowButtonTapped` is a no-op / `submissionState` not defined.

- [ ] **Step 3: Add the submission state and implement the flow**

In `AskMeAnythingSetupPageModel.swift`, add near Properties:

```swift
  enum SubmissionState: Equatable {
    case editing, preparing, submitting, scheduled, outcomeUnknown
  }
  private(set) var submissionState: SubmissionState = .editing
```

Replace `func startShowButtonTapped() {}` (:97) with:

```swift
  func startShowButtonTapped() async {
    guard submissionState == .editing else { return }
    guard isStartShowEnabled, hasRecordedIntro else { return }

    submissionState = .preparing
    await waitForPendingUploads()

    guard hasRecordedIntro, isStartShowEnabled, allOpeningItemsReady else {
      submissionState = .editing
      presentedAlert = .amaOpeningIncomplete
      return
    }

    guard let jwt = auth.jwt else {
      submissionState = .editing
      presentedAlert = .amaStartFailed("You need to be signed in to go live.")
      return
    }

    let audioBlockIds = readyAudioBlockIds
    submissionState = .submitting
    do {
      let response = try await api.startLiveShow(jwt, stationId, audioBlockIds)
      $activeLiveShow.withLock {
        $0 = ActiveLiveShow(liveShowId: response.liveShowId, stationId: stationId)
      }
      submissionState = .scheduled
      navigateToLive(liveShowId: response.liveShowId, scheduledStartsAt: response.scheduledStartsAt)
    } catch APIError.liveShowUnavailable(let delayUntil) {
      if let delayUntil {
        submissionState = .editing
        presentedAlert = .amaStartUnavailable(delayUntil: delayUntil)
      } else {
        await recoverStartedShow()
      }
    } catch {
      submissionState = .outcomeUnknown
      presentedAlert = .amaStartUnknown { [weak self] in await self?.recoverStartedShow() }
    }
  }
```

Guard `setupAbandoned()`:

```swift
  func setupAbandoned() {
    switch submissionState {
    case .editing, .preparing:
      cancelUploads()
    case .submitting, .scheduled, .outcomeUnknown:
      break  // A committed/in-flight show must not be torn down (spec §8).
    }
  }
```

Add the private helpers:

```swift
  private func navigateToLive(liveShowId: String, scheduledStartsAt: Date) {
    let liveModel = AskMeAnythingLivePageModel(
      stationId: stationId, liveShowId: liveShowId, scheduledStartsAt: scheduledStartsAt)
    navigationCoordinator.replaceAskMeAnythingSetup(
      self, with: .askMeAnythingLivePage(liveModel))
  }

  private func recoverStartedShow() async {
    guard let jwt = auth.jwt else {
      submissionState = .editing
      presentedAlert = .amaStartFailed("You need to be signed in to go live.")
      return
    }
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      guard let recoveredId = spins.compactMap({ $0.liveShowId }).first else {
        submissionState = .editing
        presentedAlert = .amaStartFailed("We couldn\u{2019}t confirm your show. Please try again.")
        return
      }
      let startsAt = spins.first(where: { $0.liveShowId == recoveredId })?.airtime ?? now
      $activeLiveShow.withLock {
        $0 = ActiveLiveShow(liveShowId: recoveredId, stationId: stationId)
      }
      submissionState = .scheduled
      navigateToLive(liveShowId: recoveredId, scheduledStartsAt: startsAt)
    } catch {
      submissionState = .editing
      presentedAlert = .amaStartFailed("We couldn\u{2019}t confirm your show. Please try again.")
    }
  }
```

Add the missing dependency to the model (schedule recovery uses `api`; the setup model currently has no `\.api`). Add to Dependencies:

```swift
  @ObservationIgnored @Dependency(\.api) var api
```

- [ ] **Step 4: Add the three `PlayolaAlert` factories**

In `PlayolaAlert.swift`:

```swift
extension PlayolaAlert {
  static var amaOpeningIncomplete: PlayolaAlert {
    PlayolaAlert(
      title: "Show Not Ready",
      message: "Some of your opening isn\u{2019}t ready yet. Make sure your intro and every item finished before going live.",
      dismissButton: .default(Text("OK")))
  }

  static func amaStartUnavailable(delayUntil: Date) -> PlayolaAlert {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    return PlayolaAlert(
      title: "Can\u{2019}t Go Live Yet",
      message: "Your station is busy right now. You can go live at \(formatter.string(from: delayUntil)).",
      dismissButton: .default(Text("OK")))
  }

  static func amaStartFailed(_ message: String) -> PlayolaAlert {
    PlayolaAlert(title: "Couldn\u{2019}t Start the Show", message: message,
      dismissButton: .default(Text("OK")))
  }

  static func amaStartUnknown(retry: @escaping @MainActor () async -> Void) -> PlayolaAlert {
    PlayolaAlert(
      title: "Did Your Show Start?",
      message: "We lost the connection before confirming. Tap Check to see if your show is live.",
      primaryButtonText: "Check",
      primaryAction: retry,
      secondaryButtonText: "Cancel",
      secondaryAction: nil)
  }
}
```

- [ ] **Step 5: Update the setup view's Start Show call to await**

In `AskMeAnythingSetupPageView.swift`, the Start Show button action must call the now-async method inside a `Task`:

```swift
Button {
  Task { await model.startShowButtonTapped() }
} label: { ... }
```

(No control flow added — this is an action closure, not conditional rendering.)

- [ ] **Step 6: Run the tests to verify they pass**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests`
Expected: PASS (Task 4 case + the three new cases).

- [ ] **Step 7: Run the full setup + navigation suites (touched-area regression rule)**

Run: `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingSetupPageTests -only-testing:PlayolaRadioTests/MainContainerNavigationCoordinatorTests`
Expected: PASS — the `setupAbandoned` guard change didn't regress existing abandonment behavior.

- [ ] **Step 8: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift "PlayolaRadio/Views/Reusable Components/PlayolaAlert.swift" PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageView.swift PlayolaRadio/Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageTests.swift
git commit -m "feature: wire Start Show to schedule the live show and navigate to the monitor"
```

---

### Task 9: `AskMeAnythingLivePageView` (visual-only; disabled Add to Show)

**Files:**
- Create: `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageView.swift`
- Test: none (view is visual-only; behavior is model-tested in Task 6). Optional: an `ImageRenderer` headless snapshot per the repo's throwaway-render pattern — not required for this PR.

**Interfaces:**
- Consumes: `AskMeAnythingLivePageModel` (Task 6) — `startMonitoring()`, `phase`, all view-helper strings/flags, `nowPlayingProgress`, `bufferedMeterFraction`, `upcomingSpins`, `endShowButtonTapped()`, `doneButtonTapped()`.

- [ ] **Step 1: Create the view**

Drive the refresh loop from `.task`, the presentation tick from `TimelineView(.periodic(by: 0.5))` (mirror `BroadcastPageView`), and keep ALL conditional rendering out of the view — use the model's precomputed opacity/enabled flags. Phase-specific sections (waiting banner vs running monitor) render via opacity flags the model supplies, not `switch`/`if`. Add the model helpers the view binds to as you build it (e.g. `waitingBannerOpacity`, `runningMonitorOpacity`, `endShowButtonOpacity`, `doneButtonOpacity`, `isEndShowEnabled`) — each a pure derivation from `phase`, colocated with the other view helpers in Task 6's model. Example skeleton:

```swift
import PlayolaPlayer
import SwiftUI

struct AskMeAnythingLivePageView: View {
  @Bindable var model: AskMeAnythingLivePageModel

  var body: some View {
    TimelineView(.periodic(from: .now, by: 0.5)) { _ in
      content
    }
    .task { await model.startMonitoring() }
    .playolaAlert(item: $model.presentedAlert)  // match the repo's alert modifier
  }

  private var content: some View {
    VStack(spacing: 0) {
      header
      waitingBanner.opacity(model.waitingBannerOpacity)
      nowPlayingCard
      queueList
      addToShowCard
      footer
    }
  }

  // header / waitingBanner / nowPlayingCard / queueList / addToShowCard / footer
  // each bind to model.* strings/flags. Add-to-Show buttons use .disabled(!model.isAddToShowEnabled).
}
```

Match the two approved frames (`K9H7f.png` running, `OFqgG.png` waiting): header title + listener count; now-playing card with `LIVE NOW` + progress; read-only queue rows (icon/title/subtitle/airtime — no drag handles, no lock control, static pin on intro row per D-B); Add to Show card rendered disabled; footer meter (`bufferedMeterLabel` + `bufferedPercentLabel` + green bar at `bufferedMeterFraction`) + End Show / Done button.

- [ ] **Step 2: Add the phase-driven opacity/enabled view helpers to the model**

In `AskMeAnythingLivePageModel` (View Helpers), add pure derivations (no new state):

```swift
  var waitingBannerOpacity: Double { phase == .waiting ? 1 : 0 }
  var runningMonitorOpacity: Double { (phase == .running || phase == .ending) ? 1 : 0 }
  var isEndShowEnabled: Bool { phase == .running }
  var endShowButtonOpacity: Double { (phase == .running || phase == .ending) ? 1 : 0 }
  var doneButtonOpacity: Double { (phase == .ended || phase == .unavailable) ? 1 : 0 }
```

Add a matching test to `AskMeAnythingLivePageTests.swift`:

```swift
@Test func endShowDisabledOnceEnding() async {
  let now = Date(timeIntervalSince1970: 1_000_000)
  @Shared(.auth) var auth = Auth(jwt: "t")
  let spins = [
    Spin.mockWith(
      id: "s1", airtime: now.addingTimeInterval(-5),
      audioBlock: .mockWith(endOfMessageMS: 120_000), liveShowId: "show-1")
  ]
  let model = withDependencies {
    $0.date = .constant(now)
    $0.api.fetchSchedule = { _, _ in spins }
    $0.api.getActiveListeningSessions = { _, _, _, _ in
      ActiveListeningSessionsResponse(
        summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
    }
    $0.api.endLiveShow = { _, _, _, _ in
      EndLiveShowResponse(endingSpinId: "end-1", effectiveEndsAt: now.addingTimeInterval(60))
    }
  } operation: {
    AskMeAnythingLivePageModel(stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)
  }
  await model.refreshNow()
  #expect(model.isEndShowEnabled == true)
  await model.submitEnd(outroAudioBlock: .mockWith(id: "outro"))
  #expect(model.phase == .ending)
  #expect(model.isEndShowEnabled == false)
}
```

- [ ] **Step 3: Build and run the model tests**

Run: `make lint` then `xcodebuild test -only-testing:PlayolaRadioTests/AskMeAnythingLivePageTests`
Expected: compiles; tests PASS.

- [ ] **Step 4: Commit**

```bash
git add PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageView.swift PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageModel.swift PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageTests.swift
git commit -m "feature: add AMA live monitor view"
```

---

### Task 10: Register new files in `project.pbxproj`; full lint + test gate

**Files:**
- Modify: `PlayolaRadio.xcodeproj/project.pbxproj` (register the new `.swift` files — explicit refs)
- Verify: both PlayolaPlayer SPM package refs at 0.21.1.

**Interfaces:**
- Consumes: all files created in Tasks 2, 3, 6, 9 (and any new test files from Tasks 4/5/7 if they didn't already exist).

- [ ] **Step 1: Enumerate the new files to register**

New product/source files: `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageModel.swift`, `.../AskMeAnythingLivePageView.swift`, `PlayolaRadio/Models/ActiveLiveShow.swift`.
New test files: `.../AskMeAnythingLivePage/AskMeAnythingLivePageTests.swift`, `PlayolaRadioTests/APIClientLiveShowTests.swift`, `PlayolaRadioTests/ActiveLiveShowKeyTests.swift`, and any of `AskMeAnythingSetupPageTests.swift` / `RecordWithMultiStepPromptTests.swift` / `MainContainerNavigationCoordinatorTests.swift` newly created in earlier tasks.

- [ ] **Step 2: Register each in `project.pbxproj`**

For each file add the four coordinated entries (PBXFileReference, PBXBuildFile, group `children` membership, and target `PBXSourcesBuildPhase` membership) — product files to the `PlayolaRadio` target, test files to the `PlayolaRadioTests` target. Mirror an existing sibling (e.g. how `AskMeAnythingSetupPageModel.swift` and its test are registered). Use unique 24-hex object IDs.

- [ ] **Step 3: Verify PlayolaPlayer 0.21.1 on both refs**

Run: `rg -n "playola-player|PlayolaPlayer|0.21" PlayolaRadio.xcodeproj/project.pbxproj | rg -i "version|branch|revision|0.21"`
Expected: both `XCRemoteSwiftPackageReference` / version pins resolve to 0.21.1. Fix if either lags.

- [ ] **Step 4: Full lint**

Run: `make lint`
Expected: clean (SwiftLint + swift-format).

- [ ] **Step 5: Full test run (touched-area regression + new suites)**

Run the full test action (repo standard: concrete sim id + `-skipPackagePluginValidation`, foreground, `timeout 600000`):
`xcodebuild test -scheme PlayolaRadio -skipPackagePluginValidation -destination '<repo sim id>'`
Expected: all suites green, including `APIClientLiveShowTests`, `ActiveLiveShowKeyTests`, `AskMeAnythingSetupPageTests`, `AskMeAnythingLivePageTests`, `MainContainerNavigationCoordinatorTests`, `RecordWithMultiStepPromptTests`.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "chore: register AMA live show files in the Xcode project"
```

---

## Self-Review

**1. Spec coverage:**

| Spec section | Task |
|---|---|
| §6 API types/closures/errors | Task 1 |
| §6 live impls + 409/400 parsing (start delayUntil vs end replaced vs end finished) | Task 2 |
| §7.1 model shape / Phase enum | Task 6 |
| §7.2 refresh model (10s poll, concurrent, immediate, last-good, 0.5s tick) | Task 6 (`startMonitoring`/`refreshNow`), Task 9 (TimelineView tick) |
| §7.3 phase derivation (never running→waiting) | Task 6 |
| §7.4 preparedness meter (contiguous run, filler/gap boundary, current-spin remainder, uncapped value/capped meter) | Task 6 |
| §7.5 view helpers / copy | Task 6 + Task 9 |
| §8 Start Show flow (submission state, revalidate no-silent-compactMap, persist, targeted replace, 409/unknown handling, guard) | Task 8 (+ Task 7 replace helper, Task 3 persist) |
| §9 End Show flow (recorder self-pop, model owns POST, ending phase, retry same block, 400-finished, Done→dashboard, natural exhaustion) | Task 6 (+ Task 5 outro factory) |
| §10 testing cases | Tasks 2/4/6/7/8/9 tests |
| §11 Add to Show disabled; queue read-only (D-B) | Task 9 (`isAddToShowEnabled == false`, no drag/lock) |
| D-D bounded recovery (persist + schedule-derived liveShowId) | Task 3 + Task 8 `recoverStartedShow` |
| D-E post-End destination | Task 6 `doneButtonTapped` |
| §12 pbxproj + SPM 0.21.1 + lint/test | Task 10 |

Availability endpoint (§11) intentionally NOT wired — no task, per spec.

**2. Placeholder scan:** No TBD/TODO. Task 9's view is described with a real skeleton + explicit binding list rather than full pixel layout — acceptable because the view is visual-only, control-flow-free, and every string/flag it binds is a concrete model member defined in Task 6. Task 10 pbxproj edits are mechanical (mirror a named sibling) rather than literal hex IDs, which cannot be predetermined.

**3. Type consistency:** `startLiveShow`/`endLiveShow` signatures, `StartLiveShowResponse`/`EndLiveShowResponse` fields, `APIError` cases, `ActiveLiveShow` fields, `Phase` cases, `SubmissionState` cases, `replaceAskMeAnythingSetup(_:with:)`, `Path.askMeAnythingLivePage`, and `AskMeAnythingLivePageModel(stationId:liveShowId:scheduledStartsAt:)` are used identically across Tasks 1/2/3/6/7/8/9. `bufferedMilliseconds`/`bufferedMeterLabel`/`bufferedMeterFraction`, `listenerCountLabel`, `isAddToShowEnabled`, `isEndShowEnabled` names match between model definition and test/view use.

**Open risks flagged for the executor:**
- `Spin.mockWith` / `AudioBlock.mockWith` exact arg labels: the plan uses `Spin.mockWith(id:airtime:audioBlock:liveShowId:isFiller:)` and `AudioBlock.mockWith(id:endOfMessageMS:)`. Confirm against the resolved 0.21.1 SDK; adjust labels/defaults if the signatures differ (all args are optional/defaulted).
- `PlayolaAlert` alert modifier name in the view (`playolaAlert(item:)` vs the repo's actual modifier) — mirror an existing page.
- `Auth(jwt:)` is the safe test initializer for a bare token (not `Auth(jwtToken:)`).
