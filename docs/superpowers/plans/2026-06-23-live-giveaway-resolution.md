# Live Giveaway Win/Lose Resolution (M2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Before writing Swift, invoke the applicable `pfw-*` skills (pfw-observable-models, pfw-dependencies, pfw-sharing, pfw-modern-swiftui, pfw-testing, pfw-custom-dump, pfw-case-paths).

**Goal:** When a listener taps a live giveaway, reveal win/lose immediately from the tap response, let a winner submit mailing info, and recover the rare last-tapper-promotion via a bounded backstop + a targeted server push.

**Architecture:** The tap response (`isWinner`) drives an immediate outcome written to the durable `@Shared(.giveawayParticipations)` dict. The coordinator and push handler only *mutate* that dict; `MainContainerModel` is the sole presenter (winner sheet, loser-toast fallback). A foreground feed-reconcile backstop does one `my-result` check when a tapped contest closes, flipping loss→win if the server promoted the user.

**Tech Stack:** SwiftUI, `@Observable` MV models, swift-dependencies (`@DependencyClient`), swift-sharing (`@Shared`), swift-case-paths, swift-custom-dump, XCTest (`@MainActor`).

## Global Constraints

- All runtime behavior gated on `GiveawayFeature.isLiveDataEnabled` (`Config.shared.environment != .production`). `develop` stays deployable; prod stays dark.
- Participations keyed by the **per-airing event id** (`GiveawayEvent.id`), never `giveawayId`. Never cache a station→eventId map.
- Server-decoded status enums keep the `unknown` fallback; app-owned state enums (`GiveawayParticipationStatus`) stay strict.
- New `.swift` files must be hand-registered in `project.pbxproj` (explicit refs). Exclude `DEVELOPMENT_TEAM`/reordering churn from the PR.
- Every `@DependencyClient` property needs an explicit default/`testValue`.
- Page/overlay **views contain zero control flow** (no `if`/`switch`/ternary) — push conditionals into the model or a no-op subview via opacity/`allowsHitTesting`.
- Tests: `@MainActor`, colocated, camelCase names, no `Task.sleep`, `expectNoDifference`/`expectDifference` (not raw `#expect(a == b)`).
- Server "you won" push is a **named dependency** implemented in the server worktree, NOT here. iOS builds against the §7 contract in the spec.

**Spec:** `docs/superpowers/specs/2026-06-23-live-giveaway-resolution-design.md`

---

## Stage 1 — Foundations (models + API), no behavior change

### Task 1: CasePathable status + upgrade-win helper

**Files:**
- Modify: `PlayolaRadio/Models/GiveawayParticipation.swift`
- Test: `PlayolaRadio/Models/GiveawayParticipationTests.swift`

**Interfaces:**
- Produces: `GiveawayParticipationStatus` is `@CasePathable @dynamicMemberLookup`; `GiveawayParticipation.wasPromotedWin: Bool` (true when resolvedWon with `tapNumber != winningNumber` — the last-tapper surprise upgrade).

- [ ] **Step 1: Write the failing test**

```swift
import CasePaths
import CustomDump
import XCTest

@testable import PlayolaRadio

@MainActor
final class GiveawayParticipationTests: XCTestCase {
  func testWasPromotedWinTrueWhenWonBelowWinningNumber() {
    var p = GiveawayParticipation.mock
    p.winningNumber = 9
    p.tapNumber = 5
    p.status = .resolvedWon(submissionCompleted: false)
    XCTAssertTrue(p.wasPromotedWin)
  }

  func testWasPromotedWinFalseForNthTapperWin() {
    var p = GiveawayParticipation.mock
    p.winningNumber = 9
    p.tapNumber = 9
    p.status = .resolvedWon(submissionCompleted: false)
    XCTAssertFalse(p.wasPromotedWin)
  }

  func testWasPromotedWinFalseWhenLost() {
    var p = GiveawayParticipation.mock
    p.winningNumber = 9
    p.tapNumber = 5
    p.status = .resolvedLost(toastShown: false)
    XCTAssertFalse(p.wasPromotedWin)
  }
}
```

- [ ] **Step 2: Run, verify fail** (`wasPromotedWin` undefined). Use Xcode MCP / `xcodebuild test` (§ Running tests).

- [ ] **Step 3: Implement**

In `GiveawayParticipation.swift`, annotate the enum and add the helper:

```swift
import CasePaths
import Foundation

@CasePathable
@dynamicMemberLookup
enum GiveawayParticipationStatus: Codable, Equatable, Sendable {
  case tappedStandby
  case resolvedWon(submissionCompleted: Bool)
  case resolvedLost(toastShown: Bool)
  case canceled
}
```

Add to `GiveawayParticipation`:

```swift
var wasPromotedWin: Bool {
  status.is(\.resolvedWon) && tapNumber != winningNumber
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): case-pathable status + promoted-win helper"`

---

### Task 2: Winner-submission request + winner-push payload models

**Files:**
- Create: `PlayolaRadio/Models/GiveawayWinnerSubmissionRequest.swift`
- Create: `PlayolaRadio/Models/GiveawayWinnerPush.swift`
- Test: `PlayolaRadio/Models/GiveawayWinnerPushTests.swift`
- Register both new files in `project.pbxproj`.

**Interfaces:**
- Produces:
  - `GiveawayWinnerSubmissionRequest` — `Encodable, Equatable, Sendable` with `fullName, addressLine1, city, state, postalCode` (required) and `addressLine2: String?, country: String, comment: String?` (`country` defaults `"US"`). Provides `asParameters: [String: String]` (drops nil/empty optionals).
  - `GiveawayWinnerPush` — value parsed from an APNs `[String: any Sendable]` payload via `init?(userInfo:)`. Fields: `eventId, stationId, giveawayId?, prizeName, prizeDescription?, prizeImageUrl: URL?, winningNumber, tapNumber, winnerUserId?, reason: String?, submissionCompleted: Bool?, canSubmitMailingInfo: Bool?`. `init?` returns nil unless `type == "giveaway_winner"` and `eventId`/`prizeName`/`winningNumber`/`tapNumber` are present.

- [ ] **Step 1: Write the failing test**

```swift
import CustomDump
import XCTest

@testable import PlayolaRadio

@MainActor
final class GiveawayWinnerPushTests: XCTestCase {
  func testParsesValidWinnerPush() {
    let push = GiveawayWinnerPush(userInfo: [
      "type": "giveaway_winner", "eventId": "evt-1", "stationId": "stn-1",
      "prizeName": "Two tickets", "winningNumber": 9, "tapNumber": 5,
      "reason": "last_tapper_fallback", "canSubmitMailingInfo": true,
    ])
    expectNoDifference(push?.eventId, "evt-1")
    expectNoDifference(push?.tapNumber, 5)
    expectNoDifference(push?.reason, "last_tapper_fallback")
    expectNoDifference(push?.canSubmitMailingInfo, true)
  }

  func testRejectsWrongType() {
    XCTAssertNil(GiveawayWinnerPush(userInfo: ["type": "giveaway_closed", "eventId": "evt-1"]))
  }

  func testRejectsMissingRequiredFields() {
    XCTAssertNil(GiveawayWinnerPush(userInfo: ["type": "giveaway_winner", "eventId": "evt-1"]))
  }

  func testSubmissionRequestParametersDropEmptyOptionals() {
    let req = GiveawayWinnerSubmissionRequest(
      fullName: "Jo", addressLine1: "1 Main", city: "Austin", state: "TX",
      postalCode: "78701", addressLine2: nil, country: "US", comment: nil)
    expectNoDifference(req.asParameters, [
      "fullName": "Jo", "addressLine1": "1 Main", "city": "Austin",
      "state": "TX", "postalCode": "78701", "country": "US",
    ])
  }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** `GiveawayWinnerSubmissionRequest.swift`:

```swift
import Foundation

struct GiveawayWinnerSubmissionRequest: Encodable, Equatable, Sendable {
  var fullName: String
  var addressLine1: String
  var city: String
  var state: String
  var postalCode: String
  var addressLine2: String?
  var country: String = "US"
  var comment: String?

  var asParameters: [String: String] {
    var p: [String: String] = [
      "fullName": fullName, "addressLine1": addressLine1, "city": city,
      "state": state, "postalCode": postalCode, "country": country,
    ]
    if let addressLine2, !addressLine2.isEmpty { p["addressLine2"] = addressLine2 }
    if let comment, !comment.isEmpty { p["comment"] = comment }
    return p
  }
}
```

`GiveawayWinnerPush.swift`:

```swift
import Foundation

struct GiveawayWinnerPush: Equatable, Sendable {
  let eventId: String
  let stationId: String?
  let giveawayId: String?
  let prizeName: String
  let prizeDescription: String?
  let prizeImageUrl: URL?
  let winningNumber: Int
  let tapNumber: Int
  let winnerUserId: String?
  let reason: String?
  let submissionCompleted: Bool?
  let canSubmitMailingInfo: Bool?

  init?(userInfo: [String: any Sendable]) {
    guard userInfo["type"] as? String == "giveaway_winner",
      let eventId = userInfo["eventId"] as? String,
      let prizeName = userInfo["prizeName"] as? String,
      let winningNumber = userInfo["winningNumber"] as? Int,
      let tapNumber = userInfo["tapNumber"] as? Int
    else { return nil }
    self.eventId = eventId
    self.stationId = userInfo["stationId"] as? String
    self.giveawayId = userInfo["giveawayId"] as? String
    self.prizeName = prizeName
    self.prizeDescription = userInfo["prizeDescription"] as? String
    self.prizeImageUrl = (userInfo["prizeImageUrl"] as? String).flatMap(URL.init(string:))
    self.winningNumber = winningNumber
    self.tapNumber = tapNumber
    self.winnerUserId = userInfo["winnerUserId"] as? String
    self.reason = userInfo["reason"] as? String
    self.submissionCompleted = userInfo["submissionCompleted"] as? Bool
    self.canSubmitMailingInfo = userInfo["canSubmitMailingInfo"] as? Bool
  }
}
```

- [ ] **Step 4: Register both files in `project.pbxproj`; run, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): winner-submission request + winner-push payload models"`

---

### Task 3: APIClient — my-result + winner-submission

**Files:**
- Modify: `PlayolaRadio/Core/API/APIClient.swift` (after the giveaway block ~line 560)
- Modify: `PlayolaRadio/Core/API/APIClient+Live.swift` (after `tapGiveawayEvent` ~line 776)
- Test: `PlayolaRadio/Core/API/APIClientGiveawayResolutionTests.swift` (verify defaults; optional)

**Interfaces:**
- Produces on `APIClient`:
  - `giveawayEventMyResult: @Sendable (_ jwt: String, _ eventId: String) async throws -> GiveawayMyResult` (default `{ _,_ in .mock }`)
  - `submitGiveawayWinnerDetails: @Sendable (_ jwt: String, _ eventId: String, _ body: GiveawayWinnerSubmissionRequest) async throws -> Void` (default `{ _,_,_ in }`)

- [ ] **Step 1: Add the client properties** in `APIClient.swift` Giveaway section:

```swift
/// Authoritative final outcome for the current viewer. Reconciles a due close on demand.
var giveawayEventMyResult:
  @Sendable (_ jwtToken: String, _ eventId: String) async throws -> GiveawayMyResult = { _, _ in
    .mock
  }

/// Submits (upserts) the winner's mailing details. Winner-only on the server.
var submitGiveawayWinnerDetails:
  @Sendable (_ jwtToken: String, _ eventId: String, _ body: GiveawayWinnerSubmissionRequest)
    async throws -> Void = { _, _, _ in }
```

- [ ] **Step 2: Add live impls** in `APIClient+Live.swift`:

```swift
giveawayEventMyResult: { jwtToken, eventId in
  try await authenticatedGet(
    path: "/v1/giveaway-events/\(eventId)/my-result", token: jwtToken)
},
submitGiveawayWinnerDetails: { jwtToken, eventId, body in
  try await authenticatedPostVoid(
    path: "/v1/giveaway-events/\(eventId)/winner-submission",
    token: jwtToken, parameters: body.asParameters)
},
```

- [ ] **Step 3: Build.** No new test strictly required (covered via coordinator/sheet tests downstream). Confirm it compiles.

- [ ] **Step 4: Commit** — `git commit -m "feat(api): giveaway my-result + winner-submission endpoints"`

---

## Stage 2 — Task 0: tap() failure path

### Task 4: `onError` on overlay + throwing tap classification

**Files:**
- Modify: `PlayolaRadio/Views/Pages/PlayerPage/GiveawayOverlayModel.swift`
- Modify: `PlayolaRadio/Core/Giveaways/GiveawayCoordinator.swift`
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift` (`makePlayerModel`)
- Create: `PlayolaRadio/Core/Giveaways/GiveawayTapError.swift`
- Test: `PlayolaRadio/Views/Pages/PlayerPage/GiveawayOverlayModelTests.swift`, `PlayolaRadio/Core/Giveaways/GiveawayCoordinatorTests.swift`

**Interfaces:**
- Produces:
  - `enum GiveawayTapError: Error, Equatable { case unexpected }`
  - `GiveawayOverlayModel.onTap: (@MainActor (GiveawayEvent) async throws -> Void)?` (now throwing)
  - `GiveawayOverlayModel.onError: (@MainActor (any Error) async -> Void)?`
  - `GiveawayCoordinator.tap(event:)` throws `GiveawayTapError.unexpected` on network/5xx; silent on 400/success.

- [ ] **Step 1: Failing overlay test** — `onTap` throwing routes to `onError`:

```swift
func testTapButtonRoutesThrownErrorToOnError() async {
  @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying.mockWith(
    station: AnyStation.mockPlayola(id: "station-1"))
  @Shared(.activeGiveaway) var activeGiveaway = GiveawayEvent(
    id: "evt-1", stationId: "station-1", prizeName: "Prize", winningNumber: 9, status: .open)
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]

  let model = GiveawayOverlayModel()
  var capturedError: (any Error)?
  model.onTap = { _ in throw GiveawayTapError.unexpected }
  model.onError = { capturedError = $0 }

  await model.tapButtonTapped()

  XCTAssertEqual(capturedError as? GiveawayTapError, .unexpected)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement.** `GiveawayTapError.swift`:

```swift
enum GiveawayTapError: Error, Equatable {
  case unexpected
}
```

In `GiveawayOverlayModel.swift`:

```swift
var onTap: (@MainActor (GiveawayEvent) async throws -> Void)?
var onError: (@MainActor (any Error) async -> Void)?

func tapButtonTapped() async {
  guard let giveaway = visibleGiveaway else { return }
  do {
    try await onTap?(giveaway)
  } catch {
    await onError?(error)
  }
}
```

In `GiveawayCoordinator.tap`, classify (the project's `APIError` carries `statusCode`; 400 = expected race → silent; everything else genuine → throw):

```swift
func tap(event: GiveawayEvent) async throws {
  guard let jwt = auth.jwt else { return }
  guard participations[event.id] == nil, !inFlightTapIds.contains(event.id) else { return }
  inFlightTapIds.insert(event.id)
  defer { inFlightTapIds.remove(event.id) }
  do {
    let response = try await api.tapGiveawayEvent(jwt, event.id)
    persistOutcome(event: event, response: response)
  } catch let error as APIError where error.statusCode == 400 {
    log("tap: 400 not-open-yet for \(event.id) — silent")
  } catch {
    log("tap: unexpected failure for \(event.id) — \(error)")
    throw GiveawayTapError.unexpected
  }
}
```

> `persistOutcome` is implemented in Task 5; for this task keep the existing `persistStandby` call and only add the throwing classification, then swap to `persistOutcome` in Task 5. (Verify `APIError` exposes `statusCode`; if it is an enum, match the not-open case instead — read `APIClient+Live.swift:114`/`452`.)

Wire in `MainContainerModel.makePlayerModel()`:

```swift
model.giveawayOverlayModel.onTap = { [weak self] event in
  try await self?.giveawayCoordinator.tap(event: event)
}
model.giveawayOverlayModel.onError = { [weak self] _ in
  self?.giveawayCoordinator.presentTapErrorAlert()
}
```

Add to `GiveawayCoordinator` (or surface via a `@Shared` alert the player observes — choose the existing alert pattern; here we route through MainContainer's `presentedAlert`). Concretely, have `onError` set MainContainer state:

```swift
model.giveawayOverlayModel.onError = { [weak self] _ in
  self?.presentGiveawayTapErrorAlert()
}
```

and in `MainContainerModel`:

```swift
func presentGiveawayTapErrorAlert() {
  presentedAlert = PlayolaAlert(
    title: "Tap didn't go through",
    message: "Something went wrong. Please try again.",
    dismissButton: .default(Text("OK")))
}
```

(Match the actual `PlayolaAlert` initializer in `PlayolaRadio/Views/Reusable Components/PlayolaAlert.swift` and whatever alert surface `MainContainerModel` already presents.)

- [ ] **Step 4: Coordinator test** — 400 stays silent (no throw, no participation); 5xx throws:

```swift
func testTapSilentOn400NotOpen() async throws {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
  let coordinator = withDependencies {
    $0.api.tapGiveawayEvent = { _, _ in throw APIError.badRequest }  // 400 equivalent
  } operation: { GiveawayCoordinator() }

  try await coordinator.tap(event: .mock)  // does not throw

  expectNoDifference(participations, [:])
}

func testTapThrowsOnUnexpectedFailure() async {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
  let coordinator = withDependencies {
    $0.api.tapGiveawayEvent = { _, _ in throw APIError.serverError }  // 5xx equivalent
  } operation: { GiveawayCoordinator() }

  do { try await coordinator.tap(event: .mock); XCTFail("expected throw") }
  catch { XCTAssertEqual(error as? GiveawayTapError, .unexpected) }
}
```

(Use the real `APIError` cases/initializers — adjust `.badRequest`/`.serverError` to match the enum.)

- [ ] **Step 5: Run all, verify pass. Commit** — `git commit -m "feat(giveaway): surface unexpected tap failures via onError alert"`

---

## Stage 3 — Immediate reveal

### Task 5: tap persists resolved outcome from the tap response

**Files:**
- Modify: `PlayolaRadio/Core/Giveaways/GiveawayCoordinator.swift` (replace `persistStandby` with `persistOutcome`)
- Test: `PlayolaRadio/Core/Giveaways/GiveawayCoordinatorTests.swift`

**Interfaces:**
- Produces: `GiveawayCoordinator.persistOutcome(event:response:)` writes `.resolvedWon(submissionCompleted: false)` when `response.isWinner`, else `.resolvedLost(toastShown: false)`, carrying `tapNumber` from the response.

- [ ] **Step 1: Failing tests**

```swift
func testTapWinPersistsResolvedWon() async throws {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
  @Dependency(\.date.now) var now
  let event = GiveawayEvent(
    id: "evt-1", stationId: "stn-1", prizeName: "Tickets", winningNumber: 9, status: .open)
  let coordinator = withDependencies {
    $0.api.tapGiveawayEvent = { _, _ in GiveawayTapResponse(tapNumber: 9, isWinner: true, status: .open) }
  } operation: { GiveawayCoordinator() }

  try await coordinator.tap(event: event)

  expectNoDifference(participations["evt-1"]?.status, .resolvedWon(submissionCompleted: false))
  expectNoDifference(participations["evt-1"]?.tapNumber, 9)
}

func testTapLossPersistsResolvedLost() async throws {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
  let event = GiveawayEvent(
    id: "evt-1", stationId: "stn-1", prizeName: "Tickets", winningNumber: 9, status: .open)
  let coordinator = withDependencies {
    $0.api.tapGiveawayEvent = { _, _ in GiveawayTapResponse(tapNumber: 5, isWinner: false, status: .open) }
  } operation: { GiveawayCoordinator() }

  try await coordinator.tap(event: event)

  expectNoDifference(participations["evt-1"]?.status, .resolvedLost(toastShown: false))
  expectNoDifference(participations["evt-1"]?.tapNumber, 5)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — replace `persistStandby` with:

```swift
private func persistOutcome(event: GiveawayEvent, response: GiveawayTapResponse) {
  let status: GiveawayParticipationStatus =
    response.isWinner
    ? .resolvedWon(submissionCompleted: false)
    : .resolvedLost(toastShown: false)
  $participations.withLock {
    $0[event.id] = GiveawayParticipation(
      id: event.id, stationId: event.stationId, prizeName: event.prizeName,
      prizeDescription: event.prizeDescription, prizeImageUrl: event.prizeImageUrl,
      winningNumber: event.winningNumber, tapNumber: response.tapNumber,
      status: status, tappedAt: now)
  }
}
```

Update `tap` to call `persistOutcome(event: event, response: response)`.

- [ ] **Step 4: Update the M1 standby-persist test** (`hasTapped`/standby assertions) that now expect a resolved status. Run, verify pass.

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): resolve win/lose immediately from tap response"`

---

### Task 6: In-player loser reveal (overlay model + view)

**Files:**
- Modify: `PlayolaRadio/Views/Pages/PlayerPage/GiveawayOverlayModel.swift`
- Modify: `PlayolaRadio/Views/Pages/PlayerPage/GiveawayPlayerOverlayView.swift`
- Test: `PlayolaRadio/Views/Pages/PlayerPage/GiveawayOverlayModelTests.swift`

**Interfaces:**
- Consumes: `GiveawayParticipation.wasPromotedWin`, the participations dict, `activeGiveaway`.
- Produces on `GiveawayOverlayModel`: `showsLoserReveal: Bool`, `loserRevealHeadline: String` ("You were listener #N — good luck next time!"), `loserRevealOpacity`/interactive flags; min-display handled by a `revealedLossEventId` + `@Dependency(\.continuousClock)` hold so it survives `activeGiveaway` clearing for ≥10s.

**Design:** The loser reveal shows when the participation for the active (or just-active) event is `.resolvedLost`. Because `activeGiveaway` clears at close, the model latches the lost event id when it first sees the loss and keeps the reveal up for a minimum hold (10s), then clears on station change / player dismiss. Keep the view free of control flow (opacity + `allowsHitTesting`, like the existing prompt/standby split).

- [ ] **Step 1: Failing tests**

```swift
func testShowsLoserRevealForResolvedLostOnCurrentStation() {
  @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying.mockWith(
    station: AnyStation.mockPlayola(id: "stn-1"))
  @Shared(.activeGiveaway) var activeGiveaway = GiveawayEvent(
    id: "evt-1", stationId: "stn-1", prizeName: "P", winningNumber: 9, status: .open)
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "evt-1": GiveawayParticipation(
      id: "evt-1", stationId: "stn-1", prizeName: "P", winningNumber: 9, tapNumber: 5,
      status: .resolvedLost(toastShown: false), tappedAt: Date())
  ]
  let model = GiveawayOverlayModel()
  XCTAssertTrue(model.showsLoserReveal)
  expectNoDifference(model.loserRevealHeadline, "You were listener #5 — good luck next time!")
}

func testNoLoserRevealForWin() {
  @Shared(.nowPlaying) var nowPlaying: NowPlaying? = NowPlaying.mockWith(
    station: AnyStation.mockPlayola(id: "stn-1"))
  @Shared(.activeGiveaway) var activeGiveaway = GiveawayEvent(
    id: "evt-1", stationId: "stn-1", prizeName: "P", winningNumber: 9, status: .open)
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "evt-1": GiveawayParticipation(
      id: "evt-1", stationId: "stn-1", prizeName: "P", winningNumber: 9, tapNumber: 9,
      status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  ]
  let model = GiveawayOverlayModel()
  XCTAssertFalse(model.showsLoserReveal)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** the model helpers (derive the lost participation for the active event / now-playing station; compute headline from `tapNumber`). Add the min-hold latch (latch `revealedLossEventId` + a `clock.sleep(for: .seconds(10))` task that clears it; clear immediately on station change). Replace the standby subview with a `GiveawayOverlayLoserView` driven by `loserRevealOpacity` / `showsLoserReveal`. Keep all copy on the model.

- [ ] **Step 4: Update the `#Preview`s** to add a "Loser reveal" preview. Run, verify pass + visually check the preview.

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): in-player loser reveal with minimum display hold"`

---

## Stage 4 — Winner sheet

### Task 7: `GiveawayWinnerSheetModel`

**Files:**
- Create: `PlayolaRadio/Views/Pages/GiveawayWinnerSheet/GiveawayWinnerSheetModel.swift`
- Test: `PlayolaRadio/Views/Pages/GiveawayWinnerSheet/GiveawayWinnerSheetModelTests.swift`
- Register in `project.pbxproj`.

**Interfaces:**
- Consumes: `api.submitGiveawayWinnerDetails`, `api.giveawayEvent`, `@Shared(.auth)`, `@Shared(.giveawayParticipations)`.
- Produces: `@MainActor @Observable final class GiveawayWinnerSheetModel: ViewModel, Identifiable` with:
  - `init(participation: GiveawayParticipation, fromPush: Bool = false, onClose: @escaping () -> Void)`
  - form fields `fullName/addressLine1/city/state/postalCode/addressLine2/comment`
  - `headline: String` ("You won! You're Listener #N" or, when `participation.wasPromotedWin`, "Good news — you got bumped up to the winner!")
  - `prizeName/prizeDescription/prizeImageUrl`, `canSubmit: Bool`, `isSubmitting`, `submitErrorMessage: String?`, `showsClaimedConfirmation: Bool`
  - `task() async` (eligibility check when `fromPush`), `claimButtonTapped() async`, `closeButtonTapped()`

- [ ] **Step 1: Failing tests**

```swift
func testHeadlineForNthTapperWin() {
  let p = GiveawayParticipation(
    id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 9,
    status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  let model = GiveawayWinnerSheetModel(participation: p, onClose: {})
  expectNoDifference(model.headline, "You won! You're Listener #9")
}

func testHeadlineForPromotedWin() {
  let p = GiveawayParticipation(
    id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
    status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  let model = GiveawayWinnerSheetModel(participation: p, onClose: {})
  expectNoDifference(model.headline, "Good news — you got bumped up to the winner!")
}

func testCanSubmitRequiresRequiredFields() {
  let model = GiveawayWinnerSheetModel(participation: .mock, onClose: {})
  XCTAssertFalse(model.canSubmit)
  model.fullName = "Jo"; model.addressLine1 = "1 Main"; model.city = "Austin"
  model.state = "TX"; model.postalCode = "78701"
  XCTAssertTrue(model.canSubmit)
}

func testClaimSuccessMarksSubmissionCompletedAndCloses() async {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 9,
      status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  ]
  var closed = false
  let model = withDependencies {
    $0.api.submitGiveawayWinnerDetails = { _, _, _ in }
  } operation: {
    GiveawayWinnerSheetModel(participation: participations["e"]!, onClose: { closed = true })
  }
  model.fullName = "Jo"; model.addressLine1 = "1 Main"; model.city = "Austin"
  model.state = "TX"; model.postalCode = "78701"

  await model.claimButtonTapped()

  expectNoDifference(participations["e"]?.status, .resolvedWon(submissionCompleted: true))
  XCTAssertTrue(closed)
}

func testClaimFailureKeepsSheetOpenWithError() async {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 9,
      status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  ]
  var closed = false
  let model = withDependencies {
    $0.api.submitGiveawayWinnerDetails = { _, _, _ in throw APIError.serverError }
  } operation: {
    GiveawayWinnerSheetModel(participation: participations["e"]!, onClose: { closed = true })
  }
  model.fullName = "Jo"; model.addressLine1 = "1 Main"; model.city = "Austin"
  model.state = "TX"; model.postalCode = "78701"

  await model.claimButtonTapped()

  XCTAssertFalse(closed)
  XCTAssertNotNil(model.submitErrorMessage)
  expectNoDifference(participations["e"]?.status, .resolvedWon(submissionCompleted: false))
}

func testPushProvenanceAlreadyClaimedShowsConfirmation() async {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
  let p = GiveawayParticipation(
    id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
    status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
  let model = withDependencies {
    $0.api.giveawayEvent = { _, _ in
      GiveawayEvent(
        id: "e", stationId: "s", prizeName: "P", winningNumber: 9, status: .closed,
        viewer: GiveawayEventViewer(hasTapped: true, isWinner: true, canSubmitMailingInfo: false))
    }
  } operation: {
    GiveawayWinnerSheetModel(participation: p, fromPush: true, onClose: {})
  }

  await model.task()

  XCTAssertTrue(model.showsClaimedConfirmation)
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** following `pfw-observable-models` (no comments, `@ObservationIgnored @Dependency`/`@Shared`, action-named methods). `task()` GETs `api.giveawayEvent` when `fromPush`; if `viewer?.canSubmitMailingInfo == false` set `showsClaimedConfirmation = true` and mark `.resolvedWon(submissionCompleted: true)`. `claimButtonTapped()` builds `GiveawayWinnerSubmissionRequest`, calls `api.submitGiveawayWinnerDetails`; on success `$participations.withLock` set `.resolvedWon(submissionCompleted: true)` then `onClose()`; on failure set `submitErrorMessage`. Use `withErrorReporting`/`reportIssue` per `pfw-issue-reporting` for the unexpected failure log.

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): winner sheet model (claim, eligibility, upgrade copy)"`

---

### Task 8: Winner sheet view + `PlayolaSheet` case

**Files:**
- Create: `PlayolaRadio/Views/Pages/GiveawayWinnerSheet/GiveawayWinnerSheetView.swift`
- Modify: `PlayolaRadio/Views/Reusable Components/PlayolaSheet.swift` (add case)
- Modify: wherever `PlayolaSheet` is switched to a view (the sheet host) to render the new case.
- Register the new view in `project.pbxproj`.

**Interfaces:**
- Consumes: `GiveawayWinnerSheetModel`.
- Produces: `case giveawayWinner(GiveawayWinnerSheetModel)` on `PlayolaSheet`; `GiveawayWinnerSheetView(model:)`.

- [ ] **Step 1:** Add the enum case (since `GiveawayWinnerSheetModel` is an `@Observable` class, conform it `Equatable`/`Hashable` by object identity per `pfw-observable-models`, matching how other model-bearing cases hash):

```swift
case giveawayWinner(GiveawayWinnerSheetModel)
```

- [ ] **Step 2:** Build the view from the lovable `TapperWinnerScreen` (confetti, prize image via `WebImage` not `AsyncImage`, form fields, "Claim Prize", submitted/claimed states). **Zero control flow in the view** — drive the submitted/claimed/error states through opacity/disabled bindings off the model. Bindings via dynamic-member lookup, never `Binding(get:set:)`.

- [ ] **Step 3:** Render the case in the sheet host switch; add a `#Preview` for win and promoted-win.

- [ ] **Step 4:** Build, verify previews render. (No new unit test — model is covered in Task 7.)

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): winner sheet view + PlayolaSheet case"`

---

## Stage 5 — Presentation arbiter

### Task 9: MainContainer presents winner sheet + loser-toast fallback

**Files:**
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift`
- Test: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModelTests.swift` (or existing)

**Interfaces:**
- Consumes: `@Shared(.giveawayParticipations)`, `@Dependency(\.toast)`, the nav coordinator, `GiveawayWinnerSheetModel`.
- Produces: `MainContainerModel.processGiveawayResolutions()` — presents the oldest pending winner (resolvedWon, `winnerSheetPresentedAt == nil`) when no blocking sheet is up, marking `winnerSheetPresentedAt = now` in the same `withLock`; fires a one-time toast for the oldest pending loss (resolvedLost, `toastShown == false`) and flips `toastShown = true`. Observes the dict (Combine `$participations.publisher` or `Observations`) and on app foreground.

- [ ] **Step 1: Failing tests**

```swift
func testPresentsWinnerSheetOncePerWin() {
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 9,
      status: .resolvedWon(submissionCompleted: false), tappedAt: Date(), winnerSheetPresentedAt: nil)
  ]
  let model = MainContainerModel()

  model.processGiveawayResolutions()

  XCTAssertNotNil(participations["e"]?.winnerSheetPresentedAt)
  // sheet is the winner case
  guard case .giveawayWinner = model.mainContainerNavigationCoordinator.presentedSheet else {
    return XCTFail("expected winner sheet")
  }

  let presentedAt = participations["e"]?.winnerSheetPresentedAt
  model.processGiveawayResolutions()  // idempotent
  expectNoDifference(participations["e"]?.winnerSheetPresentedAt, presentedAt)
}

func testFiresLoserToastOnce() async {
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
      status: .resolvedLost(toastShown: false), tappedAt: Date())
  ]
  var shownToasts: [PlayolaToast] = []
  let model = withDependencies {
    $0.toast = ToastClient(show: { shownToasts.append($0) }, /* … */ )
  } operation: { MainContainerModel() }

  model.processGiveawayResolutions()

  expectNoDifference(participations["e"]?.status, .resolvedLost(toastShown: true))
  expectNoDifference(shownToasts.count, 1)
}
```

(Adjust `ToastClient` override to its real shape; assert `presentedSheet` via the nav coordinator the project uses.)

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** `processGiveawayResolutions()` — filter pending winners (sorted by `tappedAt`), guard `presentedSheet == nil` (or only the player is up), build `GiveawayWinnerSheetModel(participation:onClose:)`, set `winnerSheetPresentedAt = now` in the same `withLock`, present `.giveawayWinner(model)`. Then pending losses → `toast.show(...)`, flip `toastShown`. Subscribe in `start()`/the existing observation setup, and call from the foreground hook (next to `giveawayCoordinator.pollNow()`).

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): MainContainer arbiter presents winner sheet + loser toast"`

---

## Stage 6 — Correctness backstop + push

### Task 10: Poll-while-open backstop (flip loss→win on close)

**Files:**
- Modify: `PlayolaRadio/Core/Giveaways/GiveawayCoordinator.swift` (extend close-detection in `clearActiveIfNoLongerOpen` / reconcile)
- Test: `PlayolaRadio/Core/Giveaways/GiveawayCoordinatorTests.swift`

**Interfaces:**
- Consumes: `api.giveawayEventMyResult`.
- Produces: `GiveawayCoordinator.reconcileResolvedLoss(jwt:eventId:)` — when a tapped contest closes and the local participation is `.resolvedLost`, GET `my-result`; if `isWinner` and `status` resolved, flip to `.resolvedWon(submissionCompleted: false)` (carry `tapNumber` from the result). No-op on still-open / loser / throw.

- [ ] **Step 1: Failing tests**

```swift
func testBackstopFlipsLossToWinWhenPromoted() async {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
      status: .resolvedLost(toastShown: false), tappedAt: Date())
  ]
  let coordinator = withDependencies {
    $0.api.giveawayEventMyResult = { _, _ in
      GiveawayMyResult(tapNumber: 5, isWinner: true, status: .closed, winningNumber: 9)
    }
  } operation: { GiveawayCoordinator() }

  await coordinator.reconcileResolvedLoss(jwt: "jwt", eventId: "e")

  expectNoDifference(participations["e"]?.status, .resolvedWon(submissionCompleted: false))
}

func testBackstopLeavesLossWhenStillLost() async {
  @Shared(.auth) var auth = Auth.mockLoggedIn
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
      status: .resolvedLost(toastShown: false), tappedAt: Date())
  ]
  let coordinator = withDependencies {
    $0.api.giveawayEventMyResult = { _, _ in
      GiveawayMyResult(tapNumber: 5, isWinner: false, status: .closed, winningNumber: 9)
    }
  } operation: { GiveawayCoordinator() }

  await coordinator.reconcileResolvedLoss(jwt: "jwt", eventId: "e")

  expectNoDifference(participations["e"]?.status, .resolvedLost(toastShown: false))
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**

```swift
func reconcileResolvedLoss(jwt: String, eventId: String) async {
  guard participations[eventId]?.status.is(\.resolvedLost) == true else { return }
  guard let result = try? await api.giveawayEventMyResult(jwt, eventId) else { return }
  guard result.isResolved, result.isWinner else { return }
  $participations.withLock {
    $0[eventId]?.status = .resolvedWon(submissionCompleted: false)
    if let tap = result.tapNumber { $0[eventId]?.tapNumber = tap }
  }
  log("backstop: \(eventId) promoted loss→win")
}
```

Hook it where the feed reconcile detects an active tapped event closing (inside/after `clearActiveIfNoLongerOpen` when `fresh.status != .open`, for the local participation). Iterate any `.resolvedLost` participations whose event left the feed for the current station.

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): foreground backstop flips promoted loss to win"`

---

### Task 11: Winner push handler + delegate wiring

**Files:**
- Modify: `PlayolaRadio/Core/PushNotifications/PushNotifications.swift` (add `handleGiveawayWinnerPush`)
- Modify: `PlayolaRadio/PlayolaRadioApp.swift` (`didReceiveRemoteNotification`, `willPresent`, `didReceive`)
- Test: `PlayolaRadio/Core/PushNotifications/PushNotificationsTests.swift`

**Interfaces:**
- Consumes: `GiveawayWinnerPush`, `@Shared(.giveawayParticipations)`.
- Produces: `PushNotificationsClient.handleGiveawayWinnerPush: @Sendable (_ userInfo: [String: any Sendable]) async -> Void` — parse; find/create participation by `eventId`; idempotent flip to `.resolvedWon(submissionCompleted: false)` unless already won-and-presented or already submitted. Presentation is left to the MainContainer arbiter (which observes the dict).

- [ ] **Step 1: Failing tests**

```swift
func testWinnerPushFlipsLossToWon() async {
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
      status: .resolvedLost(toastShown: true), tappedAt: Date())
  ]
  let client = PushNotificationsClient.liveValue
  await client.handleGiveawayWinnerPush([
    "type": "giveaway_winner", "eventId": "e", "stationId": "s", "prizeName": "P",
    "winningNumber": 9, "tapNumber": 5, "reason": "last_tapper_fallback",
  ])
  expectNoDifference(participations["e"]?.status, .resolvedWon(submissionCompleted: false))
}

func testWinnerPushIdempotentWhenAlreadySubmitted() async {
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [
    "e": GiveawayParticipation(
      id: "e", stationId: "s", prizeName: "P", winningNumber: 9, tapNumber: 5,
      status: .resolvedWon(submissionCompleted: true), tappedAt: Date())
  ]
  let client = PushNotificationsClient.liveValue
  await client.handleGiveawayWinnerPush([
    "type": "giveaway_winner", "eventId": "e", "stationId": "s", "prizeName": "P",
    "winningNumber": 9, "tapNumber": 5,
  ])
  expectNoDifference(participations["e"]?.status, .resolvedWon(submissionCompleted: true))
}

func testWinnerPushCreatesParticipationOnReinstall() async {
  @Shared(.giveawayParticipations) var participations: [String: GiveawayParticipation] = [:]
  let client = PushNotificationsClient.liveValue
  await client.handleGiveawayWinnerPush([
    "type": "giveaway_winner", "eventId": "e", "stationId": "s", "prizeName": "P",
    "winningNumber": 9, "tapNumber": 5,
  ])
  expectNoDifference(participations["e"]?.status, .resolvedWon(submissionCompleted: false))
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** `handleGiveawayWinnerPush` in the live client:

```swift
handleGiveawayWinnerPush: { userInfo in
  guard let push = GiveawayWinnerPush(userInfo: userInfo) else { return }
  @Shared(.giveawayParticipations) var participations
  let participationsShared = $participations
  await MainActor.run {
    participationsShared.withLock { dict in
      if case .resolvedWon(submissionCompleted: true) = dict[push.eventId]?.status { return }
      if let existing = dict[push.eventId] {
        var updated = existing
        if case .resolvedWon = existing.status {} else {
          updated.status = .resolvedWon(submissionCompleted: false)
        }
        dict[push.eventId] = updated
      } else {
        dict[push.eventId] = GiveawayParticipation(
          id: push.eventId, stationId: push.stationId ?? "", prizeName: push.prizeName,
          prizeDescription: push.prizeDescription, prizeImageUrl: push.prizeImageUrl,
          winningNumber: push.winningNumber, tapNumber: push.tapNumber,
          status: .resolvedWon(submissionCompleted: false), tappedAt: Date())
      }
    }
  }
}
```

Add the property to the `@DependencyClient` struct (with the implicit default). Wire the three delegate entry points in `PlayolaRadioApp.swift` to call it for `type == "giveaway_winner"`:
- `didReceiveRemoteNotification` (background/silent): call, `completionHandler(.newData)`.
- `willPresent` (foreground): call; `completionHandler([])` for a silent data push (the arbiter presents the sheet) or `[.banner, .sound]` if product wants the banner too.
- `didReceive` (tap): call (the arbiter then presents).

> The `MainActor.run` + `withLock` + `Date()` here mirror the existing `handleSupportNotificationBadge` pattern. Replace `Date()` with the injected clock if this is refactored into a model later.

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** — `git commit -m "feat(giveaway): winner push handler flips state for arbiter to present"`

---

## Final verification

- [ ] Run the full giveaway test suite via `xcodebuild test` with `-skipPackagePluginValidation -skipMacroValidation` and a concrete simulator id (see memory `project_xcodebuild_test_cli_flags`). Not just build.
- [ ] Simulator smoke (staging / `isLiveDataEnabled`): tap → win sheet; tap → loser reveal; (with a stub/dev push) loss→win flip presents the sheet.
- [ ] Codex review (pass/fail gate) + Codex challenge (adversarial) on the final diff; fix findings.
- [ ] PR against `develop`. Body notes the server-push dependency (§7) and that the feature is gated dark in prod.
- [ ] Confirm `project.pbxproj` diff contains only the new file refs (no `DEVELOPMENT_TEAM`/reorder churn).

---

## Self-review notes (spec coverage)

- Immediate reveal → Task 5. Loser reveal + min hold → Task 6. Winner sheet (form, eligibility, upgrade copy, retry) → Tasks 7-8. Arbiter (sole presenter, dedupe, toast fallback) → Task 9. Backstop → Task 10. Push handler → Task 11. Task 0 onError → Task 4. APIClient additions → Task 3. Models (CasePathable, request/push) → Tasks 1-2.
- Server "you won" push = external dependency (spec §7); not a task here.
- Out of scope (spec §10): congrats recording / record-video toggle, cross-station banner, stale GC.
- Open implementation confirmations flagged inline: real `APIError` shape for the 400-vs-5xx classification (Task 4), the exact `ToastClient`/`PlayolaAlert`/nav-coordinator APIs (Tasks 4, 9), and the `PlayolaSheet` host switch site (Task 8).
