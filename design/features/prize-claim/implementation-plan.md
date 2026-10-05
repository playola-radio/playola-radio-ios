# Prize Claim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` (single PR) — or
> `superpowers:subagent-driven-development` to run it task-by-task with a reviewer per task. Steps use
> checkbox (`- [ ]`) syntax for tracking. **One PR** into `develop`; it is not a multi-PR effort, so it
> does not go in `LONG_RUNNING.md`.

**Goal:** When a listener wins a giveaway or earns a reward, collect the prize's server-defined
`infoFields` in-app via one reusable Claim sheet, with a Home prize tile as the durable re-entry —
replacing the email-only winner sheet, the koozie's inline address form, and the legacy Rewards redeem
sheet.

**Architecture:** A new `ClaimSheetModel` (one `PlayolaSheet.claim` case) renders a form generated from a
`FulfillmentRequest`'s `infoFields` and drives the three new `APIClient` calls. The last-known request
list lives in an in-memory `@Shared(.fulfillmentRequests)`; Home derives its prize tiles from it, and
every writer (Home appear, foreground, the Claim sheet after any PUT/POST outcome, the giveaway presenter)
refreshes it through one helper. Up-front presentation stays in `MainContainerModel` (giveaway) and
`HomePageModel` (koozie), both writing the single `presentedSheet` slot only after re-checking it.

**Tech Stack:** Swift / SwiftUI, `@Observable` MV models, swift-dependencies, swift-sharing,
swift-identified-collections, swift-testing + swift-custom-dump, Alamofire.

**Spec:** [spec.md](./spec.md) — contracts: [screens.md](./screens.md), [endpoints.md](./endpoints.md),
[models.md](./models.md). Those files are authoritative; this plan points at them and does not restate
them.

**Base commits:** playola-radio-ios `20417ae34c60762e5fec18f7603877dae9aac78b` (origin/develop) ·
playola `283fbe2be881f2d77d3d23101c0d62f6471297b9` (origin/develop; server already in production since
2026-10-04 — no backend work in this plan).

## Global Constraints

- **pfw skills are mandatory** before writing Swift: `pfw-dependencies` (APIClient), `pfw-observable-models`
  (every `*Model`), `pfw-sharing` (`@Shared` keys), `pfw-testing` + `pfw-custom-dump` (tests use
  `expectNoDifference` / `expectDifference` for value comparisons), `pfw-modern-swiftui` (views),
  `pfw-issue-reporting` (`reportIssue`), `pfw-identified-collections` where applicable.
- **Page views contain zero control flow** — no `if`, `if let`, `guard`, ternary, `switch`, or boolean
  expressions in a `*View.swift` page body. Branching lives in the model, or in a *reusable component*
  that owns its own variants (the `KoozieTileSection` pattern). Grep-gate every new page view.
- All copy lives in models. Copy below is verbatim from the approved frames; per-screen JSON in
  `exports/json/` is the source for fonts, sizes, spacing and colors.
- Every test suite carries `@Suite(.freshSharedState)` and `@MainActor`; declare `@Shared` locally inside
  each test. Never `Task.sleep` in tests. Tests are swift-testing, colocated with the code.
- Every new `.swift` file is hand-registered in `PlayolaRadio.xcodeproj/project.pbxproj` (explicit
  refs — this project does not use synchronized folders); deleted files are removed from it. Exclude
  Xcode's unrelated pbxproj churn (DEVELOPMENT_TEAM flips, re-sorting) from commits.
- Every new server-decoded enum has an `unknown` fallback. Every `DependencyKey`/`@DependencyClient`
  closure has a test-safe default.
- Never gate anything on `Config.shared.environment`.
- `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` everywhere — build with `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app`
  to match CI. Run `make lint` before every push (the pre-commit hook only formats).
- Never send `""` as an answer, never send `country`, never send `stationId`.

## Review Focus

1. **A required field the user filled with only spaces** — must count as empty: Send disabled, Incomplete
   hint names it (Task 3 test `testWhitespaceOnlyRequiredTextIsMissing`).
2. **A request with an optional ADDRESS left partly filled** — Send stays disabled until it is complete or
   wholly blank; wholly blank omits the key (Task 3 tests `testPartialOptionalAddressBlocksSend`,
   `testBlankOptionalAddressIsOmitted`).
3. **Pre-filled answers from another device** (incl. a ZIP+4 from the legacy koozie form) — the form opens
   pre-filled, Send is enabled, and the ZIP+4 is accepted (Task 3 test `testPrefilledZipPlusFourIsValid`).
4. **The reward POST response is lost and "Try again" gets a 409** — treated as claimed: the opener is
   told, the sheet dismisses, the list refetches (Task 4 test `testRewardConflictCountsAsClaimed`).
5. **The list fetch fails on Home appear after tiles were shown** — tiles stay; nothing is cleared (Task 2
   test `FulfillmentRequestsRefresherTests.testFailureKeepsLastKnownList`; Home only reads the shared list).

---

## File map

| Action | Path | Responsibility |
|---|---|---|
| Create | `PlayolaRadio/Models/FulfillmentRequest.swift` | `FulfillmentRequest`, `InfoField`, `InfoAnswer`, request bodies |
| Create | `PlayolaRadio/Models/FulfillmentRequestTests.swift` | Decoding / encoding tests |
| Rename | `Models/KoozieShippingAddress.swift` → `Models/ShippingAddress.swift` | `ShippingAddress: Codable`; `RedeemKooziePrizeRequest` deleted |
| Create | `PlayolaRadio/Core/API/ClaimAPIError.swift` (+ `ClaimAPIErrorTests.swift`) | Status → error mapping |
| Modify | `Core/API/APIClient.swift`, `Core/API/APIClient+Live.swift` | 3 new closures; 4 removed (`redeemPrize`, `redeemKooziePrize`, `markKoozieCongratsSeen`, `submitGiveawayWinnerDetails`) |
| Modify | `State/SharedUserDefaults.swift` | `.fulfillmentRequests` (in-memory), `.koozieClaimPromptShownUserIds` (fileStorage) |
| Create | `State/FulfillmentRequestsRefresher.swift` | The one list-refresh helper |
| Move/rename | `Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModel.swift` → `Views/Reusable Components/ClaimForm/AddressFieldModel.swift` (+ tests) | Generalized ADDRESS field |
| Create | `Views/Reusable Components/ClaimForm/ClaimFieldModel.swift` (+ `ClaimFieldModelTests.swift`) | One field: text / choice / address; validation; answer building |
| Create | `Views/Reusable Components/ClaimForm/ClaimFieldView.swift`, `AddressFieldView.swift`, `ChoiceFieldView.swift`, `ChoicePickerView.swift` | Reusable field components (may switch) |
| Create | `Views/Pages/ClaimSheet/ClaimSheetModel.swift`, `ClaimSheetView.swift`, `ClaimSheetTests.swift` | The sheet |
| Modify | `Views/Reusable Components/PlayolaSheet.swift`, `Views/Pages/MainContainer/MainContainer.swift` | `.claim` case replaces `.giveawayWinner` + `.redeemPrize` |
| Modify | `Views/Pages/HomePage/HomePageModel.swift`, `HomePageView.swift`, `HomePagePadView.swift`, `HomePageTests.swift` | Prize tiles, positional `ForEach` id, koozie up-front |
| Modify | `Views/Reusable Components/ListeningTimeTile/KoozieTileModel.swift`, `KoozieTileSection.swift`, tests | 3 modes; claim override |
| Delete | `Views/Pages/GiveawayWinnerSheet/*`, `Models/GiveawayWinnerSubmissionRequest.swift`, `Views/Pages/RewardsPage/RedeemPrizeSheet*.swift` | Replaced flows |
| Modify | `Views/Pages/MainContainer/MainContainerModel.swift`, `MainContainerTests.swift` | Giveaway up-front presentation |
| Modify | `Models/GiveawayParticipation.swift`, `GiveawayParticipationTests.swift` | Drop `wasPromotedWin` (only the deleted winner sheet read it) |
| Modify | `Views/Pages/RewardsPage/RewardsPageModel.swift`, `RewardsPageView.swift`, `RewardsPageTests.swift` | Redeem → Claim sheet |
| Modify | `Models/RewardsProfile.swift` | Drop `shouldShowKoozieCongrats` |
| Modify | `Core/Analytics/AnalyticsEvent.swift` | Claim analytics events |

---

### Task 1: Data models

**Files:**
- Create: `PlayolaRadio/Models/FulfillmentRequest.swift`, `PlayolaRadio/Models/FulfillmentRequestTests.swift`
- Rename: `PlayolaRadio/Models/KoozieShippingAddress.swift` → `PlayolaRadio/Models/ShippingAddress.swift`

**Interfaces:**
- Produces: `FulfillmentRequest` (`id`, `status`, `source`, `giveawayEventId`, `prizeTitle`, `prizeImageUrl`,
  `infoFields`, `infoAnswers`), `FulfillmentRequest.Status` (`.awaitingInfo/.readyToShip/.unknown` — the list endpoint returns only those two),
  `FulfillmentRequest.Source` (`.giveaway/.reward/.unknown`), `InfoField` (`key`, `label`, `type`, `options`,
  `required`), `InfoField.FieldType` (`.shortText/.multiLineText/.singleChoice/.address/.unknown`),
  `InfoAnswer` (`.text(String)`, `.address(ShippingAddress)`), `ShippingAddress: Codable`,
  `SubmitFulfillmentAnswersRequest { infoAnswers: [String: InfoAnswer] }`,
  `CreateRewardRedemptionRequest { prizeId: String }`, `FulfillmentRequest.mock(...)` test factory.

- [ ] **Step 1: Write the failing tests** (`FulfillmentRequestTests.swift`)

```swift
import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct FulfillmentRequestTests {
  private func decode(_ json: String) throws -> FulfillmentRequest {
    try JSONDecoderWithIsoFull().decode(FulfillmentRequest.self, from: Data(json.utf8))
  }

  @Test func testDecodesServerSummary() throws {
    let request = try decode(
      """
      {"id":"r1","status":"awaiting_info","source":"giveaway","giveawayEventId":"e1",
       "userPrizeId":null,"prize":{"title":"Tour Poster","number":12,"imageUrl":null},
       "infoFields":[
         {"key":"shirtSize","label":"Shirt size","type":"SINGLE_CHOICE","options":["S","M"],"required":true},
         {"key":"shippingAddress","label":"Shipping address","type":"ADDRESS","required":true}],
       "infoAnswers":{"shirtSize":"M","shippingAddress":{"fullName":"Jane","addressLine1":"1 Main",
         "addressLine2":null,"city":"Austin","state":"TX","postalCode":"78701","country":"US"}}}
      """)
    expectNoDifference(
      request,
      FulfillmentRequest(
        id: "r1", status: .awaitingInfo, source: .giveaway, giveawayEventId: "e1",
        prizeTitle: "Tour Poster", prizeImageUrl: nil,
        infoFields: [
          InfoField(key: "shirtSize", label: "Shirt size", type: .singleChoice, options: ["S", "M"], required: true),
          InfoField(key: "shippingAddress", label: "Shipping address", type: .address, options: [], required: true),
        ],
        infoAnswers: [
          "shirtSize": .text("M"),
          "shippingAddress": .address(
            ShippingAddress(
              fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin",
              state: "TX", postalCode: "78701")),
        ]))
  }

  @Test func testUnknownEnumsFallBack() throws {
    let request = try decode(
      """
      {"id":"r1","status":"on_hold","source":"raffle","giveawayEventId":null,"prize":{},
       "infoFields":[{"key":"dob","label":"Birthday","type":"DATE","required":false}],"infoAnswers":{}}
      """)
    #expect(request.status == .unknown)
    #expect(request.source == .unknown)
    #expect(request.infoFields.first?.type == .unknown)
  }

  @Test func testUndecodableAnswerIsDropped() throws {
    let request = try decode(
      """
      {"id":"r1","status":"awaiting_info","source":"reward","giveawayEventId":null,"prize":{},
       "infoFields":[],"infoAnswers":{"a":"ok","b":42,"c":{"weird":true}}}
      """)
    expectNoDifference(request.infoAnswers, ["a": .text("ok")])
  }

  @Test func testAnswersRequestEncodesTextAndAddressWithoutCountry() throws {
    let body = SubmitFulfillmentAnswersRequest(infoAnswers: [
      "size": .text("M"),
      "addr": .address(
        ShippingAddress(
          fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
          postalCode: "78701")),
    ])
    let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any]
    let answers = json?["infoAnswers"] as? [String: Any]
    #expect(answers?["size"] as? String == "M")
    let addr = answers?["addr"] as? [String: Any]
    #expect(addr?["postalCode"] as? String == "78701")
    #expect(addr?["country"] == nil)
  }
}
```

- [ ] **Step 2: Run to verify it fails** — `FulfillmentRequest` is undefined.

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer xcodebuild test \
  -project PlayolaRadio.xcodeproj -scheme PlayolaRadio -skipPackagePluginValidation \
  -destination 'platform=iOS Simulator,id=<sim-id>' \
  -only-testing:PlayolaRadioTests/FulfillmentRequestTests
```
(`xcrun simctl list devices available` for `<sim-id>`; a full run takes ~9 min — use a 600000 ms timeout.)

- [ ] **Step 3: Implement.** Rename `KoozieShippingAddress` → `ShippingAddress` (`Codable`; decoding ignores
  `country`) and delete `RedeemKooziePrizeRequest`; update its references (`KoozieAddressFormModel`,
  `APIClient`) — Task 2/3 removes them for good. Then `FulfillmentRequest.swift`:

```swift
import Foundation

struct FulfillmentRequest: Decodable, Equatable, Identifiable, Sendable {
  enum Status: String, Decodable, Sendable {
    case awaitingInfo = "awaiting_info", readyToShip = "ready_to_ship", unknown
    init(from decoder: Decoder) throws {
      self = Status(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
  }
  enum Source: String, Decodable, Sendable {
    case giveaway, reward, unknown
    init(from decoder: Decoder) throws {
      self = Source(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
  }

  let id: String
  let status: Status
  let source: Source
  let giveawayEventId: String?
  let prizeTitle: String?
  let prizeImageUrl: URL?
  let infoFields: [InfoField]
  let infoAnswers: [String: InfoAnswer]

}

// Decoding lives in an extension so Swift still synthesizes the memberwise init.
extension FulfillmentRequest {
  private enum CodingKeys: String, CodingKey {
    case id, status, source, giveawayEventId, prize, infoFields, infoAnswers
  }
  private enum PrizeKeys: String, CodingKey { case title, imageUrl }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    status = try c.decode(Status.self, forKey: .status)
    source = try c.decode(Source.self, forKey: .source)
    giveawayEventId = try c.decodeIfPresent(String.self, forKey: .giveawayEventId)
    let prize = try c.nestedContainer(keyedBy: PrizeKeys.self, forKey: .prize)
    prizeTitle = try prize.decodeIfPresent(String.self, forKey: .title)
    prizeImageUrl = (try? prize.decodeIfPresent(String.self, forKey: .imageUrl)).flatMap(URL.init(string:))
    infoFields = try c.decodeIfPresent([InfoField].self, forKey: .infoFields) ?? []
    let raw = try c.decodeIfPresent([String: LossyInfoAnswer].self, forKey: .infoAnswers) ?? [:]
    infoAnswers = raw.compactMapValues(\.value)
  }
}

struct InfoField: Decodable, Equatable, Sendable {
  enum FieldType: String, Decodable, Sendable {
    case shortText = "SHORT_TEXT", multiLineText = "MULTI_LINE_TEXT", singleChoice = "SINGLE_CHOICE"
    case address = "ADDRESS", unknown
    init(from decoder: Decoder) throws {
      self = FieldType(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
  }
  let key: String
  let label: String
  let type: FieldType
  let options: [String]
  let required: Bool
}

extension InfoField {
  private enum CodingKeys: String, CodingKey { case key, label, type, options, required }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    key = try c.decode(String.self, forKey: .key)
    label = try c.decode(String.self, forKey: .label)
    type = try c.decode(FieldType.self, forKey: .type)
    options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
    required = try c.decodeIfPresent(Bool.self, forKey: .required) ?? false
  }
}

enum InfoAnswer: Codable, Equatable, Sendable {
  case text(String)
  case address(ShippingAddress)

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let text = try? c.decode(String.self) {
      self = .text(text)
    } else {
      self = .address(try c.decode(ShippingAddress.self))
    }
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .text(let text): try c.encode(text)
    case .address(let address): try c.encode(address)
    }
  }
}

/// Decodes one stored answer without failing the whole request on a value the app can't read.
private struct LossyInfoAnswer: Decodable {
  let value: InfoAnswer?
  init(from decoder: Decoder) throws { value = try? InfoAnswer(from: decoder) }
}

struct SubmitFulfillmentAnswersRequest: Encodable, Equatable, Sendable {
  let infoAnswers: [String: InfoAnswer]
}

struct CreateRewardRedemptionRequest: Encodable, Equatable, Sendable {
  let prizeId: String
}

extension FulfillmentRequest {
  static func mock(
    id: String = "request-1", status: Status = .awaitingInfo, source: Source = .giveaway,
    giveawayEventId: String? = "event-1", prizeTitle: String? = "Signed Bri Bagwell tour shirt",
    prizeImageUrl: URL? = nil,
    infoFields: [InfoField] = [
      InfoField(key: "shippingAddress", label: "Shipping address", type: .address, options: [], required: true)
    ],
    infoAnswers: [String: InfoAnswer] = [:]
  ) -> FulfillmentRequest {
    FulfillmentRequest(
      id: id, status: status, source: source, giveawayEventId: giveawayEventId,
      prizeTitle: prizeTitle, prizeImageUrl: prizeImageUrl, infoFields: infoFields,
      infoAnswers: infoAnswers)
  }
}
```

  `ShippingAddress` must decode with `addressLine2` absent *or* null (synthesized `Codable` with
  `String?` does both) and ignore unknown keys like `country` (synthesized decoding does).

- [ ] **Step 4: Run the tests — PASS.** Register both new files + the renamed file in the pbxproj.
- [ ] **Step 5: Commit** — `git commit -m "feat: decode prize fulfillment requests"`

---

### Task 2: API client, error mapping, shared state

**Files:**
- Create: `PlayolaRadio/Core/API/ClaimAPIError.swift`, `PlayolaRadio/Core/API/ClaimAPIErrorTests.swift`,
  `PlayolaRadio/State/FulfillmentRequestsRefresher.swift`
- Modify: `PlayolaRadio/Core/API/APIClient.swift` (add after `getUserPrizes`, ~line 91),
  `PlayolaRadio/Core/API/APIClient+Live.swift` (add after `getUserPrizes`, ~line 326),
  `PlayolaRadio/State/SharedUserDefaults.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces:
  - `ClaimAPIError: Error, Equatable` — `.invalidAnswers`, `.notOpen`, `.conflict`, `.failed`;
    `init(status: Int?)`. The calls differ only on 409, so the caller interprets `.conflict`: answers →
    No longer open; redemption → already claimed.
  - `APIClient.getMyFulfillmentRequests: (_ jwt: String) async throws -> [FulfillmentRequest]`
  - `APIClient.submitFulfillmentAnswers: (_ jwt: String, _ requestId: String, _ body: SubmitFulfillmentAnswersRequest) async throws -> Void` (throws `ClaimAPIError`)
  - `APIClient.createRewardRedemption: (_ jwt: String, _ prizeId: String) async throws -> FulfillmentRequest` (throws `ClaimAPIError`)
  - `@Shared(.fulfillmentRequests)` — `InMemoryKey<[FulfillmentRequest]>`, default `[]`.
  - `@Shared(.koozieClaimPromptShownUserIds)` — `FileStorageKey<Set<String>>`, file
    `koozie-claim-prompt-shown.json`, default `[]`.
  - `@MainActor func refreshFulfillmentRequests() async -> Bool` — fetches with the current JWT and
    writes `@Shared(.fulfillmentRequests)` only on success; returns success. On failure it leaves the
    last-known list untouched and tracks `.apiError(endpoint: "getMyFulfillmentRequests", …)`.

- [ ] **Step 1: Write the failing tests** (`ClaimAPIErrorTests.swift`)

```swift
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ClaimAPIErrorTests {
  @Test(arguments: [
    (400, ClaimAPIError.invalidAnswers), (403, .notOpen), (404, .notOpen), (409, .conflict),
    (401, .failed), (500, .failed),
  ])
  func testStatusMapping(status: Int, expected: ClaimAPIError) {
    #expect(ClaimAPIError(status: status) == expected)
  }

  @Test func testTransportFailureIsFailed() {
    #expect(ClaimAPIError(status: nil) == .failed)
  }
}
```

  Add to the same file a refresher test:

```swift
@Suite(.freshSharedState)
@MainActor
struct FulfillmentRequestsRefresherTests {
  @Test func testFailureKeepsLastKnownList() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    let ok = await withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in throw URLError(.notConnectedToInternet) }
    } operation: {
      await refreshFulfillmentRequests()
    }
    #expect(!ok)
    expectNoDifference(requests, [FulfillmentRequest.mock()])
  }

  @Test func testSuccessReplacesList() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    let ok = await withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      await refreshFulfillmentRequests()
    }
    #expect(ok)
    expectNoDifference(requests, [])
  }
}
```

- [ ] **Step 2: Run — FAIL** (types undefined).
- [ ] **Step 3: Implement.**

`ClaimAPIError.swift`:

```swift
/// The server's error body carries only a message, so the claim calls branch on HTTP status alone.
enum ClaimAPIError: Error, Equatable {
  case invalidAnswers
  case notOpen
  case conflict
  case failed

  init(status: Int?) {
    switch status {
    case 400: self = .invalidAnswers
    case 403, 404: self = .notOpen
    case 409: self = .conflict
    default: self = .failed
    }
  }
}
```

`APIClient.swift` — add the three closures with test-safe defaults:

```swift
  /// Prize requests still in progress (`awaiting_info` + `ready_to_ship`), server-ordered.
  var getMyFulfillmentRequests: @Sendable (_ jwtToken: String) async throws -> [FulfillmentRequest] =
    { _ in [] }

  /// Saves answers. Any 2xx is success (the body is not decoded — admins get a different shape).
  /// Throws `ClaimAPIError` mapped from the status.
  var submitFulfillmentAnswers:
    @Sendable (_ jwtToken: String, _ requestId: String, _ body: SubmitFulfillmentAnswersRequest)
      async throws -> Void = { _, _, _ in }

  /// Claims a reward prize; returns its new fulfillment request. Throws `ClaimAPIError`.
  var createRewardRedemption:
    @Sendable (_ jwtToken: String, _ prizeId: String) async throws -> FulfillmentRequest = { _, _ in
      .mock(source: .reward, giveawayEventId: nil)
    }
```

`APIClient+Live.swift` — follow the existing `redeemKooziePrize` status-reading pattern
(`.serializingData().response`, `transportFailure`):

```swift
      getMyFulfillmentRequests: { jwtToken in
        try await authenticatedGet(path: "/v1/users/me/fulfillment-requests", token: jwtToken)
      },
      submitFulfillmentAnswers: { jwtToken, requestId, body in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/fulfillment-requests/\(requestId)/answers"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let response = await apiSession.request(
          url, method: .put, parameters: body, encoder: JSONParameterEncoder.default,
          headers: headers
        )
        .serializingData()
        .response
        let status = response.response?.statusCode
        if let status, (200..<300).contains(status) { return }
        throw ClaimAPIError(status: status)
      },
      createRewardRedemption: { jwtToken, prizeId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/reward-redemptions"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let response = await apiSession.request(
          url, method: .post, parameters: CreateRewardRedemptionRequest(prizeId: prizeId),
          encoder: JSONParameterEncoder.default, headers: headers
        )
        .serializingData()
        .response
        let status = response.response?.statusCode
        guard let status, (200..<300).contains(status), let data = response.data else {
          throw ClaimAPIError(status: status)
        }
        return try sharedIsoDecoder.decode(FulfillmentRequest.self, from: data)
      },
```

`SharedUserDefaults.swift`:

```swift
extension SharedKey where Self == InMemoryKey<[FulfillmentRequest]>.Default {
  /// Last successfully fetched prize requests. Kept when a refetch fails; never persisted.
  static var fulfillmentRequests: Self {
    Self[.inMemory("fulfillmentRequests"), default: []]
  }
}

extension SharedKey where Self == FileStorageKey<Set<String>>.Default {
  /// User ids that have already seen the up-front koozie Claim sheet on this device. Not cleared on
  /// sign-out, so each account is prompted once and re-signing-in doesn't re-prompt.
  static var koozieClaimPromptShownUserIds: Self {
    Self[
      .fileStorage(.documentsDirectory.appending(component: "koozie-claim-prompt-shown.json")),
      default: []
    ]
  }
}
```

`FulfillmentRequestsRefresher.swift`:

```swift
import Dependencies
import Sharing

/// The one place that refreshes `@Shared(.fulfillmentRequests)`. Keeps the last-known list on failure.
@MainActor
@discardableResult
func refreshFulfillmentRequests() async -> Bool {
  @Dependency(\.api) var api
  @Dependency(\.analytics) var analytics
  @Shared(.auth) var auth
  @Shared(.fulfillmentRequests) var requests
  guard let jwt = auth.jwt else { return false }
  do {
    let fetched = try await api.getMyFulfillmentRequests(jwt)
    $requests.withLock { $0 = fetched }
    return true
  } catch {
    await analytics.track(
      .apiError(endpoint: "getMyFulfillmentRequests", error: error.localizedDescription))
    return false
  }
}
```

  In `AuthService.signOut()` (`Models/LoggedInUser.swift:190`), declare
  `@Shared(.fulfillmentRequests) var fulfillmentRequests` beside `giveawayParticipations` and add
  `$fulfillmentRequests.withLock { $0 = [] }` beside its reset, so one account never sees another's tiles.

- [ ] **Step 4: Run tests — PASS.** Register new files.
- [ ] **Step 5: Commit** — `git commit -m "feat: add prize claim API calls"`

---

### Task 3: Claim form field models

**Files:**
- Move: `Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModel.swift` →
  `Views/Reusable Components/ClaimForm/AddressFieldModel.swift` (and its tests →
  `ClaimForm/AddressFieldModelTests.swift`); class renamed `AddressFieldModel`.
- Create: `Views/Reusable Components/ClaimForm/ClaimFieldModel.swift`, `ClaimFieldModelTests.swift`,
  `Views/Reusable Components/ClaimForm/USStateCodes.swift`

**Interfaces:**
- Consumes: `InfoField`, `InfoAnswer`, `ShippingAddress`.
- Produces:
  - `AddressFieldModel` (`fullName`, `addressLine1`, `addressLine2`, `city`, `state`, `postalCode`;
    `init(prefill: ShippingAddress?)`; `isBlank: Bool`; `isComplete: Bool`; `missingParts: [String]`
    (subset of `["name", "street address", "city", "state", "ZIP"]` — "ZIP" only when empty);
    `hasMalformedZip: Bool`; `answer() -> ShippingAddress`; copy from the frames: section label =
    field label, caption "United States only", placeholders "Full name", "Street address",
    "Apt, suite (optional)", "City", "State", "ZIP").
  - `USStateCodes.all: [String]` — the server's 59 codes: 50 states + `DC PR VI GU AS MP AA AE AP`.
  - `ChoicePresentation` — `.chips`, `.inlineList`, `.picker` with
    `static func forOptions(_ options: [String]) -> ChoicePresentation` (2–5 options and every label ≤ 4
    characters → chips; otherwise ≤ 6 → inline list; 7+ → picker).
  - `ClaimFieldModel` (`@Observable`, `Identifiable` by `field.key`): `field: InfoField`,
    `kind: Kind` (`.text(multiLine: Bool)`, `.choice(ChoicePresentation)`, `.address`),
    `text: String`, `selectedOption: String?`, `address: AddressFieldModel`,
    `init(field: InfoField, prefill: InfoAnswer?)`, `missingParts: [String]`, `hasMalformedZip: Bool`,
    `answer: InfoAnswer?` (nil = omit), `optionTapped(_:)` (deselects when optional and already selected),
    `text` clamps itself in `didSet` to its limit (255 short text and each address part, 5000
    multi-line; counted in UTF-16 units, cut on a character boundary),
    `pickerShowsSearch: Bool` (> 12 options), `pickerShowsNone: Bool` (`!required`).

- [ ] **Step 1: Write the failing tests** (`ClaimFieldModelTests.swift`; move the existing
  `KoozieAddressFormModelTests` cases into `AddressFieldModelTests.swift` and rename the type)

```swift
import CustomDump
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ClaimFieldModelTests {
  private let address = InfoField(key: "addr", label: "Shipping address", type: .address, options: [], required: true)
  private let optionalAddress = InfoField(key: "addr", label: "Shipping address", type: .address, options: [], required: false)
  private let size = InfoField(key: "size", label: "Shirt size", type: .singleChoice, options: ["S", "M", "L", "XL", "XXL"], required: true)
  private let note = InfoField(key: "note", label: "Name to sign it to", type: .shortText, options: [], required: false)
  private let fullAddress = ShippingAddress(
    fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX", postalCode: "78701")

  @Test func testWhitespaceOnlyRequiredTextIsMissing() {
    let field = ClaimFieldModel(
      field: InfoField(key: "n", label: "Guest list name", type: .shortText, options: [], required: true),
      prefill: nil)
    field.text = "   "
    expectNoDifference(field.missingParts, ["guest list name"])
    #expect(field.answer == nil)
  }

  @Test func testTextAnswerIsTrimmed() {
    let field = ClaimFieldModel(field: note, prefill: nil)
    field.text = "  Brian \n"
    #expect(field.answer == .text("Brian"))
  }

  @Test func testChoiceAnswerIsExactOption() {
    let field = ClaimFieldModel(field: size, prefill: nil)
    field.optionTapped("XL")
    #expect(field.answer == .text("XL"))
  }

  @Test func testOptionalChoiceDeselects() {
    let optionalSize = InfoField(key: "size", label: "Shirt size", type: .singleChoice, options: ["S", "M"], required: false)
    let field = ClaimFieldModel(field: optionalSize, prefill: .text("M"))
    field.optionTapped("M")
    #expect(field.selectedOption == nil)
    #expect(field.answer == nil)
  }

  @Test func testPrefillNotInOptionsIsIgnored() {
    let field = ClaimFieldModel(field: size, prefill: .text("Medium"))
    #expect(field.selectedOption == nil)
  }

  @Test func testPartialOptionalAddressBlocksSend() {
    let field = ClaimFieldModel(field: optionalAddress, prefill: nil)
    field.address.city = "Austin"
    expectNoDifference(field.missingParts, ["name", "street address", "state", "ZIP"])
  }

  @Test func testBlankOptionalAddressIsOmitted() {
    let field = ClaimFieldModel(field: optionalAddress, prefill: nil)
    #expect(field.missingParts.isEmpty)
    #expect(field.answer == nil)
  }

  @Test func testPrefilledZipPlusFourIsValid() {
    var legacy = fullAddress
    legacy.postalCode = "78701-1234"
    let field = ClaimFieldModel(field: address, prefill: .address(legacy))
    #expect(field.missingParts.isEmpty)
    #expect(!field.hasMalformedZip)
    #expect(field.answer == .address(legacy))
  }

  @Test func testStateMustBeServerCode() {
    var bad = fullAddress
    bad.state = "XX"
    let field = ClaimFieldModel(field: address, prefill: .address(bad))
    expectNoDifference(field.missingParts, ["state"])
  }

  @Test(arguments: [
    (["S", "M", "L", "XL", "XXL"], ChoicePresentation.chips),
    (["Small", "Medium"], .inlineList),
    (["A", "B", "C", "D", "E", "F"], .inlineList),
    (["1", "2", "3", "4", "5", "6", "7"], .picker),
    (["Only"], .inlineList),
  ])
  func testChoicePresentationRule(options: [String], expected: ChoicePresentation) {
    #expect(ChoicePresentation.forOptions(options) == expected)
  }

  @Test func testTextIsClampedToLimitInUTF16() {
    let field = ClaimFieldModel(field: note, prefill: nil)
    field.text = String(repeating: "😀", count: 200)  // 400 UTF-16 units
    #expect(field.text.utf16.count <= 255)
  }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement.**
  - `AddressFieldModel`: keep the existing trim + `^\d{5}(-\d{4})?$` ZIP check; replace the 2-letter
    state regex with `USStateCodes.all.contains(trimmed(state).uppercased())`; `isBlank` = every part
    empty after trim; `missingParts` returns `[]` when `!required && isBlank`, else the empty/invalid parts
    in the order name, street address, city, state, ZIP (ZIP listed only when empty — a non-empty bad
    ZIP sets `hasMalformedZip` instead). `answer()` is the old `trimmedAddress()` returning
    `ShippingAddress`. Drop the koozie copy (`title`, `subtitle`, `submitButtonText`, `serverError`,
    `isSubmitting`) — the sheet owns those now.
  - `ClaimFieldModel.kind`: `.shortText` and `.unknown` → `.text(multiLine: false)`; `.multiLineText` →
    `.text(multiLine: true)`; `.singleChoice` → `.choice(.forOptions(options))`; `.address` → `.address`.
    `missingParts`: text → `[label.lowercased()]` when required and trimmed empty; choice → same when
    required and `selectedOption == nil`; address → `address.missingParts`. `answer`: text → trimmed,
    nil when empty; choice → `.text(selectedOption)` or nil; address → nil when blank, else
    `.address(address.answer())`. Length: `didSet` clamps `text` (and each `AddressFieldModel` part) to its
    limit, so an over-long value never exists — no separate over-limit state. (The Incomplete hint is
    built from `missingParts` by the sheet model — Task 4.)

- [ ] **Step 4: Run — PASS.** Update pbxproj for the move/rename + new files.
- [ ] **Step 5: Commit** — `git commit -m "feat: generic prize claim form fields"`

---

### Task 4: ClaimSheetModel

**Files:**
- Create: `PlayolaRadio/Views/Pages/ClaimSheet/ClaimSheetModel.swift`, `ClaimSheetTests.swift`
- Modify: `PlayolaRadio/Core/Analytics/AnalyticsEvent.swift`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces:
  - `enum ClaimSheetEntry: Equatable { case request(FulfillmentRequest); case reward(RewardClaim) }`
  - `struct RewardClaim: Equatable, Sendable { let prizeId: String; let prizeTitle: String?; let prizeImageUrl: URL?; let requiredHours: Int }`
  - `enum ClaimSheetPhase: Equatable { case notYetClaimed, claiming, form, sending, sendFailed(SendFailure), noLongerOpen, nothingToFillIn, sent }`
    and `enum SendFailure: Equatable { case connection, invalidAnswers }`
  - `ClaimSheetModel(entry:, onClaimed: @escaping () -> Void = {}, onClose: @escaping () -> Void)`
    — actions `viewAppeared()`, `claimItTapped() async`, `sendTapped() async`, `tryAgainTapped() async`,
    `laterTapped()`, `doneTapped()`; view helpers listed in Step 3.
  - Analytics cases: `.claimSheetShown(source: String)`, `.claimSheetLater(source: String)`,
    `.claimSheetSubmitted(source: String)`, `.claimSheetSubmitFailed(source: String, reason: String)`,
    `.prizeTileShown(source: String)`, `.prizeTileTapped(source: String)` (source = `"giveaway"`,
    `"reward"`, `"koozie"`).

- [ ] **Step 1: Write the failing tests** (`ClaimSheetTests.swift`) — one behavior each:

```swift
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ClaimSheetTests {
  private let fullAddress: InfoAnswer = .address(
    ShippingAddress(
      fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
      postalCode: "78701"))
  private let koozie = RewardClaim(prizeId: "prize-koozie", prizeTitle: "Playola Koozie", prizeImageUrl: nil, requiredHours: 50)

  @Test func testRequestWithRequiredFieldsOpensForm() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(model.phase == .form)
  }

  @Test func testRequestWithNoRequiredFieldsShowsNothingToFillIn() {
    let model = ClaimSheetModel(entry: .request(.mock(infoFields: [])), onClose: {})
    #expect(model.phase == .nothingToFillIn)
  }

  @Test func testSendPutsOnlyAnsweredFields() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let sent = LockIsolated<SubmitFulfillmentAnswersRequest?>(nil)
    let request = FulfillmentRequest.mock(infoFields: [
      InfoField(key: "addr", label: "Shipping address", type: .address, options: [], required: true),
      InfoField(key: "note", label: "Name to sign it to", type: .shortText, options: [], required: false),
    ], infoAnswers: ["addr": fullAddress])
    let model = withDependencies {
      $0.api.submitFulfillmentAnswers = { _, _, body in sent.setValue(body) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .request(request), onClose: {})
    }
    await model.sendTapped()
    expectNoDifference(sent.value, SubmitFulfillmentAnswersRequest(infoAnswers: ["addr": fullAddress]))
    #expect(model.phase == .sent)
  }

  @Test func testSendRefetchesList() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    let model = withDependencies {
      $0.api.submitFulfillmentAnswers = { _, _, _ in }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    }
    await model.sendTapped()
    expectNoDifference(requests, [])
  }

  @Test(arguments: [
    (ClaimAPIError.invalidAnswers, ClaimSheetPhase.sendFailed(.invalidAnswers)),
    (.failed, .sendFailed(.connection)),
    (.notOpen, .noLongerOpen),
    (.conflict, .noLongerOpen),
  ])
  func testSendFailureMapsToPhase(error: ClaimAPIError, expected: ClaimSheetPhase) async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = withDependencies {
      $0.api.submitFulfillmentAnswers = { _, _, _ in throw error }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    }
    await model.sendTapped()
    #expect(model.phase == expected)
  }

  @Test func testSendFailedKeepsAnswers() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = withDependencies {
      $0.api.submitFulfillmentAnswers = { _, _, _ in throw ClaimAPIError.failed }
    } operation: {
      ClaimSheetModel(entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    }
    await model.sendTapped()
    #expect(model.fields.first?.answer == fullAddress)
  }

  @Test func testSendDisabledWhileIncomplete() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(!model.isSendEnabled)
    #expect(model.incompleteHintText == "Add your name, street address, city, state, and ZIP to send.")
  }

  @Test func testIncompleteHintNamesMissingParts() {
    var noZip = ShippingAddress(
      fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX", postalCode: "")
    noZip.postalCode = ""
    let model = ClaimSheetModel(
      entry: .request(.mock(infoFields: [
        InfoField(key: "addr", label: "Shipping address", type: .address, options: [], required: true),
        InfoField(key: "size", label: "Shirt size", type: .singleChoice, options: ["S", "M"], required: true),
      ], infoAnswers: ["addr": .address(noZip)])),
      onClose: {})
    #expect(model.incompleteHintText == "Add your ZIP and shirt size to send.")
  }

  @Test func testIncompleteHintForMalformedZip() {
    let badZip = InfoAnswer.address(
      ShippingAddress(
        fullName: "Jane", addressLine1: "1 Main", addressLine2: nil, city: "Austin", state: "TX",
        postalCode: "7870"))
    let model = ClaimSheetModel(
      entry: .request(.mock(infoAnswers: ["shippingAddress": badZip])), onClose: {})
    #expect(model.incompleteHintText == "Enter a 5-digit ZIP code.")
    #expect(!model.isSendEnabled)
  }

  @Test func testCompleteFormHasNoHint() {
    let model = ClaimSheetModel(
      entry: .request(.mock(infoAnswers: ["shippingAddress": fullAddress])), onClose: {})
    #expect(model.incompleteHintText == nil)
    #expect(model.isSendEnabled)
  }

  @Test func testRewardEntryStartsNotYetClaimed() {
    let model = ClaimSheetModel(entry: .reward(koozie), onClose: {})
    #expect(model.phase == .notYetClaimed)
    #expect(model.primaryButtonTitle == "Claim my koozie")
  }

  @Test func testClaimItMovesToReturnedFormAndReportsClaim() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let claimed = LockIsolated(false)
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in .mock(source: .reward, giveawayEventId: nil) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClaimed: { claimed.setValue(true) }, onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .form)
    #expect(claimed.value)
  }

  @Test func testClaimItReadyToShipShowsNothingToFillIn() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in .mock(status: .readyToShip, source: .reward, giveawayEventId: nil, infoFields: []) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .nothingToFillIn)
  }

  @Test func testRewardConflictCountsAsClaimed() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = []
    let claimed = LockIsolated(false)
    let closed = LockIsolated(false)
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in throw ClaimAPIError.conflict }
      $0.api.getMyFulfillmentRequests = { _ in [.mock(source: .reward, giveawayEventId: nil)] }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClaimed: { claimed.setValue(true) }, onClose: { closed.setValue(true) })
    }
    await model.claimItTapped()
    #expect(claimed.value)
    #expect(closed.value)
    #expect(requests.count == 1)
  }

  @Test func testRewardFailureShowsSendFailedAndRetries() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    let attempts = LockIsolated(0)
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in
        attempts.withValue { $0 += 1 }
        throw ClaimAPIError.failed
      }
    } operation: {
      ClaimSheetModel(entry: .reward(koozie), onClose: {})
    }
    await model.claimItTapped()
    #expect(model.phase == .sendFailed(.connection))
    await model.tryAgainTapped()
    #expect(attempts.value == 2)
  }

  @Test func testSwipeDismissDisabledOnlyWhileInFlight() {
    let model = ClaimSheetModel(entry: .request(.mock()), onClose: {})
    #expect(!model.isInteractiveDismissDisabled)
    model.phase = .sending
    #expect(model.isInteractiveDismissDisabled)
    model.phase = .claiming
    #expect(model.isInteractiveDismissDisabled)
  }

  @Test func testNilTitleFallsBack() {
    let model = ClaimSheetModel(entry: .request(.mock(prizeTitle: nil)), onClose: {})
    #expect(model.prizeTitle == "Your prize")
  }
}
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** `ClaimSheetModel` (MARK sections per CLAUDE.md; `@ObservationIgnored
  @Dependency(\.api)`, `\.analytics`; `@ObservationIgnored @Shared(.auth)`):
  - **Init:** `.request(r)` → `request = r`, `fields = r.infoFields.map { ClaimFieldModel(field: $0, prefill: r.infoAnswers[$0.key]) }`,
    `phase = r.status == .awaitingInfo && r.infoFields.contains(where: \.required) ? .form : .nothingToFillIn`
    (spec Scope §1: no required fields → congrats + Done). `.reward` → `phase = .notYetClaimed`.
  - **`claimItTapped`:** guard `phase == .notYetClaimed || phase == .sendFailed(_)` with no request;
    `phase = .claiming`; `createRewardRedemption(jwt, prizeId)`. On success: adopt the returned request
    exactly like init, call `onClaimed()`, `await refreshFulfillmentRequests()`. On
    `.conflict` (already claimed): `onClaimed()`, `await refreshFulfillmentRequests()`, `onClose()`. On
    `.notOpen`: `phase = .noLongerOpen`, `reportIssue(error)`. On `.invalidAnswers` (a malformed prize id —
    a bug; the POST carries no answers): `.sendFailed(.connection)` + `reportIssue(error)`. Else
    `.sendFailed(.connection)`.
  - **`sendTapped`:** guard `isSendEnabled`, `request != nil`; `phase = .sending`; body =
    `fields.compactMap` of `(key, answer)` pairs; on success `.sent` + `.claimSheetSubmitted`; on
    `.invalidAnswers` `.sendFailed(.invalidAnswers)` + `reportIssue`; `.notOpen` or `.conflict` → `.noLongerOpen`;
    else `.sendFailed(.connection)` + `.claimSheetSubmitFailed`. **Every outcome** then
    `await refreshFulfillmentRequests()`.
  - **`tryAgainTapped`:** `request == nil ? claimItTapped() : sendTapped()` (resolve in a computed
    property, not a view).
  - **`laterTapped`:** track `.claimSheetLater`, `onClose()`. **`doneTapped`:** `onClose()`.
  - **View helpers (copy verbatim from frames):**
    - `headerPill`: `"YOU WON"` (giveaway) / `"YOU EARNED"` (reward); `prizeTitle` (nil → `"Your prize"`).
    - `subtitle` by phase: form/sending/sendFailed/claiming → `"Tell us a few things so we can get it to you."`;
      notYetClaimed → `"You've listened \(requiredHours) hours on Playola. Claim your free koozie and we'll mail it to you."`
      for the koozie (`prizeId` is the koozie) and `"You've listened \(requiredHours) hours on Playola. Claim it and tell us where to send it."`
      for other tiers; noLongerOpen → `"This prize has already been shipped or closed, so there's nothing left to fill in."`;
      nothingToFillIn → `"Nothing else needed from you — we'll take it from here."`.
    - Sent: `sentTitle` `"You're all set"`, `sentSubtitle` `"We'll get your \(prizeTitle) out to you."`.
    - `primaryButtonTitle`: notYetClaimed → `"Claim my koozie"` (koozie) / `"Claim it"`; claiming →
      `"Getting your prize ready…"`; form → `"Send it to me"`; sending → `"Sending…"`; sendFailed →
      `"Try again"`; noLongerOpen/nothingToFillIn/sent → `"Done"`.
    - `laterButtonTitle` `"I'll finish this later"`; `isLaterAvailable` true in notYetClaimed/form/sendFailed
      (dimmed + disabled while claiming/sending). The terminal phases (noLongerOpen/nothingToFillIn/sent) use a
      footer variant with no Later button at all, chosen by `ClaimSheetContent`.
    - `errorText`: `.connection` → `"We couldn't send your answers. Check your connection and try again."`;
      `.invalidAnswers` → `"Some of your answers didn't go through. Check them and try again."`; else `""`.
    - `incompleteHintText: String?` — collect `missingParts` across `fields` in order; if none and any field
      `hasMalformedZip` → `"Enter a 5-digit ZIP code."`; if none → nil; else `"Add your \(list) to send."`
      where list joins two with `" and "`, three+ with `", "` and a final `", and "`.
      `isSendEnabled` = phase `.form` or `.sendFailed` and `incompleteHintText == nil`.
    - `isInteractiveDismissDisabled` = phase `.claiming` or `.sending`; `fieldsOpacity` 0.5 while sending.
    - No visibility helpers: `ClaimSheetContent` (a reusable component) switches on `phase` to pick the
      header/body/footer variant, the `KoozieTileSection` pattern.
  - Track `.claimSheetShown(source:)` from `viewAppeared()`.

- [ ] **Step 4: Run — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat: prize claim sheet logic"`

---

### Task 5: Claim sheet views + sheet wiring

**Files:**
- Create: `Views/Pages/ClaimSheet/ClaimSheetView.swift`, `Views/Reusable Components/ClaimForm/ClaimSheetContent.swift`,
  `ClaimFieldView.swift`, `AddressFieldView.swift`, `ChoiceFieldView.swift`, `ChoicePickerView.swift`
- Modify: `Views/Reusable Components/PlayolaSheet.swift` (add `case claim(ClaimSheetModel)`; mark the
  enum `@CasePathable` so tests can assert `presentedSheet?.is(\.claim)` per `pfw-case-paths`),
  `Views/Pages/MainContainer/MainContainer.swift` (sheet content switch)

**Interfaces:**
- Consumes: `ClaimSheetModel`, `ClaimFieldModel`, `ChoicePresentation`.
- Produces: `ClaimSheetView(model:)`; `PlayolaSheet.claim(ClaimSheetModel)`.

- [ ] **Step 1: Build each component from the frame JSON** (`exports/json/<node>.json`, resolved
  variables): header with image (`eiTMx`) / collapsed header (`kiqOK`), fields (`K4D70` chips, `tp5TU`
  inline list, `S28a1a` picker row, address block from `eiTMx`), footer states (`Py5xL`, `P0ErfC`,
  `u7f7m`, `Kv6L0`, `n2xDx4`, `yS1Dw`, `Upib6`, `vNp75`), picker `r3ZvbY`.
  - `ClaimSheetView` (page): `ScrollView { ClaimSheetContent(model: model) }`,
    `.interactiveDismissDisabled(model.isInteractiveDismissDisabled)`, `.task { model.viewAppeared() }`.
    **Zero control flow.** Swipe-down when allowed = Later: `.onDisappear` must not double-track — use
    `MainContainer`'s sheet `onDismiss` calling `model.laterTapped()` only through the existing
    dismissal path (match how `.giveawayWinner` dismissal is wired today).
  - `ClaimSheetContent` (reusable component) may `switch model.phase` to pick header/body/footer
    variants — same rule as `KoozieTileSection`.
  - `ClaimFieldView` switches on `field.kind`. Chips: one row, full width, equal widths, 8pt gap, 44pt
    tall. Inline list: native selection rows. Picker row opens `ChoicePickerView` via a sheet **local to
    `ClaimFieldView`** (`.sheet(isPresented:)` bound to a `ClaimFieldModel.isPickerPresented`), never a
    `PlayolaSheet` case. Picker: close ✕, search only when `pickerShowsSearch`, "None" row only when
    `pickerShowsNone`.
  - Address block: State is a picker row over `USStateCodes.all`; ZIP uses `.keyboardType(.numberPad)`;
    autofill `textContentType`s (`.name`, `.streetAddressLine1`, `.streetAddressLine2`,
    `.addressCity`, `.postalCode`). VoiceOver reads selected values.
  - Remote images use `WebImage` (SDWebImageSwiftUI), not `AsyncImage`, with a fixed-size frame so the
    thumbnail size is known before load.
- [ ] **Step 2: Wire** `.claim(let model)` → `ClaimSheetView(model: model)` in `MainContainer.swift`'s
  sheet switch.
- [ ] **Step 3: Verify visually.** Throwaway `ImageRenderer` test renders `ClaimSheetContent` for each
  phase to PNG and compare against `exports/claim-sheet--*.png` by eye (ScrollView content renders
  blank — render `ClaimSheetContent` directly). Delete the throwaway test before committing. Grep the
  page view: `grep -nE '\bif\b|\? |switch|guard' PlayolaRadio/Views/Pages/ClaimSheet/ClaimSheetView.swift`
  → no hits.
- [ ] **Step 4: Build + lint** (`make lint`). Register files.
- [ ] **Step 5: Commit** — `git commit -m "feat: prize claim sheet UI"`

---

### Task 6: Home prize tiles + up-front koozie

**Files:**
- Modify: `Views/Pages/HomePage/HomePageModel.swift` (tiles ~line 229; `viewAppeared` ~line 160),
  `HomePageView.swift:47`, `HomePagePadView.swift:71`, `HomePageTests.swift`

**Interfaces:**
- Consumes: `@Shared(.fulfillmentRequests)`, `refreshFulfillmentRequests()`, `ClaimSheetModel`,
  `KoozieTileModel.isClaimable`, `KoozieTileModel.rewardClaim: RewardClaim?`, `KoozieTileModel.markClaimed()` (Task 7), `ListeningTimeTileModel.refreshFromTracker()` (existing; test fixture).
- Produces: `HomePageModel.prizeTileModels: [NewFeatureTileModel]`, `HomePageModel.presentKoozieClaimIfNeeded()`;
  `visibleFeatureTileModels` now starts with the prize tiles.

- [ ] **Step 1: Write the failing tests** (in `HomePageTests.swift`):

```swift
  /// A koozie-only listener past the 50h threshold, so Home's koozie tile is claimable — driven through
  /// the real cohort path (`refreshFromTracker`), no test-only hook in app code.
  private func makeHomeWithClaimableKoozie() -> HomePageModel {
    // swiftlint:disable:next redundant_optional_initialization
    @Shared(.nowPlaying) var nowPlaying: NowPlaying? = nil
    @Shared(.listeningTracker) var lt = ListeningTracker(
      rewardsProfile: RewardsProfile(
        totalTimeListenedMS: 51 * 3_600_000, totalMSAvailableForRewards: 51 * 3_600_000,
        accurateAsOfTime: Date(), rewardsExperience: "koozie_only"))
    let model = HomePageModel()
    model.listeningTimeTileModel.refreshFromTracker()
    let koozie = model.listeningTimeTileModel.koozieTileModel
    koozie?.kooziePrizeInfo = KooziePrizeInfo(prizeId: "p1", prizeName: "Playola Koozie", requiredHours: 50)
    koozie?.liveTotalMS = 51 * 3_600_000
    return model
  }

  @Test func testPrizeTilesFollowServerOrderThenKoozie() async {
    @Shared(.fulfillmentRequests) var requests = [
      FulfillmentRequest.mock(id: "b", prizeTitle: "Poster"),
      FulfillmentRequest.mock(id: "a", source: .reward, giveawayEventId: nil, prizeTitle: "Show Tix"),
      FulfillmentRequest.mock(id: "c", status: .readyToShip, prizeTitle: "Shipped"),
    ]
    let model = makeHomeWithClaimableKoozie()
    expectNoDifference(
      model.prizeTileModels.map(\.content), ["Poster", "Show Tix", "Playola Koozie"])
    expectNoDifference(model.prizeTileModels.map(\.label), ["You won", "You earned", "You earned"])
  }

  @Test func testPrizeTileOpensClaimSheet() async {
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = HomePageModel()
    await model.prizeTileModels[0].onButtonTapped()
    #expect(coordinator.presentedSheet?.is(\.claim) == true)
  }

  @Test func testKooziePromptShownOncePerUser() {
    @Shared(.auth) var auth = Auth(
      currentUser: LoggedInUser(id: "user-1", firstName: "Me", email: "me@playola.fm"), jwt: "token")
    @Shared(.koozieClaimPromptShownUserIds) var shown = []
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = makeHomeWithClaimableKoozie()
    model.presentKoozieClaimIfNeeded()
    #expect(coordinator.presentedSheet != nil)
    coordinator.presentedSheet = nil
    model.presentKoozieClaimIfNeeded()
    #expect(coordinator.presentedSheet == nil)
    #expect(shown == ["user-1"])
  }

  @Test func testKooziePromptNeverTakesAnOccupiedSlot() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    coordinator.presentedSheet = .share(ShareSheetModel(items: ["x"]))
    let model = makeHomeWithClaimableKoozie()
    model.presentKoozieClaimIfNeeded()
    #expect(coordinator.presentedSheet == .share(ShareSheetModel(items: ["x"])))
  }
```

  (`PlayolaSheet` is `@CasePathable` from Task 5. Never build test auth with `Auth(jwtToken:)` on a bare
  string — it crashes; use `Auth(jwt:)` / `Auth(currentUser:jwt:)` as above.)

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement.**
  - `prizeTileModels` (computed): for each `requests` item with `status == .awaitingInfo`, a
    `NewFeatureTileModel(iconName: "gift.fill", isSystemImage: true, label: source == .reward ? "You earned" : "You won",
    content: prizeTitle ?? "Your prize", paragraph: "Tell us where to send it and we'll get it out to you.",
    buttonText: "Claim your prize", buttonAction: { open .claim(ClaimSheetModel(entry: .request(r), …)) })`;
    then, if `listeningTimeTileModel.koozieTileModel?.isClaimable == true`, the koozie tile
    (`label "You earned"`, `content` = koozie prize name, `paragraph "Your listening earned you a free koozie. Tell us where to mail it."`,
    `buttonText "Claim my koozie"`, action opens `.claim(ClaimSheetModel(entry: .reward(koozie.rewardClaim), onClaimed: { koozie.markClaimed() }, …))`).
    Icon/colors per `Xr7bh`/`UdaDn` JSON. Track `.prizeTileTapped`. Tiles are rebuilt from state on every
    read — no cache — so each tile's action always holds the latest request (and its latest answers).
  - `visibleFeatureTileModels` = `prizeTileModels + existing tiles`.
  - **Ids:** change both `ForEach(model.visibleFeatureTileModels, id: \.label)` (HomePageView:47,
    HomePagePadView:71) to `ForEach(Array(model.visibleFeatureTileModels.enumerated()), id: \.offset)`
    (render `\.element`). `NewFeatureTile` holds no view state, so positional identity is safe, and two
    "You won" tiles no longer collide on the label.
  - `viewAppeared()` calls `await refreshFulfillmentRequests()`, then `presentKoozieClaimIfNeeded()`. Track `.prizeTileShown` once per appear per visible prize tile.
  - `presentKoozieClaimIfNeeded()` (synchronous, so check-and-set can't interleave on the main actor):
    guard `presentedSheet == nil`, koozie `isClaimable`, `auth.currentUser?.id` not in
    `koozieClaimPromptShownUserIds`; insert the id, then present `.claim(…reward…)`.
  - Every `ClaimSheetModel` built here gets `onClose: { coordinator.presentedSheet = nil }` (guarded to
    `.claim`, like `dismissGiveawayWinnerSheet`).
- [ ] **Step 4: Run Home tests + full `HomePageTests` suite — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat: home prize tiles"`

---

### Task 7: Koozie tile simplification

**Files:**
- Modify: `Views/Reusable Components/ListeningTimeTile/KoozieTileModel.swift`, `KoozieTileSection.swift`,
  `KoozieTileModelTests.swift`, `Models/RewardsProfile.swift`,
  `Core/API/APIClient.swift` + `APIClient+Live.swift` (remove `redeemKooziePrize`, `markKoozieCongratsSeen`)
- (The koozie address-form UI lives inside `KoozieTileSection.swift` — its `.addressForm` branch and
  form subviews are deleted there; there is no separate view file.)

**Interfaces:**
- Produces: `KoozieTileMode` = `.inProgress`, `.claimable`, `.earned`; `KoozieTileModel.isClaimable: Bool`;
  `KoozieTileModel.rewardClaim: RewardClaim?` (from `kooziePrizeInfo`); `KoozieTileModel.markClaimed()`
  (sets `hasClaimedLocally`, then `refreshProfile()` adopting only `rewardsExperience` + `koozieEarned`).

- [ ] **Step 1: Write the failing tests** (`KoozieTileModelTests.swift`; delete the address-form and
  congrats tests):

```swift
  @Test func testClaimedLocallyShowsEarnedBeforeProfileCatchesUp() {
    let model = KoozieTileModel()
    model.kooziePrizeInfo = KooziePrizeInfo(prizeId: "p", prizeName: "Playola Koozie", requiredHours: 50)
    model.liveTotalMS = 51 * 3_600_000
    #expect(model.mode == .claimable)
    model.markClaimed()
    #expect(model.mode == .earned)
    #expect(!model.isClaimable)
  }

  @Test func testEarnedProfileIsNotClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 60 * 3_600_000, koozieEarned: true)
    let model = KoozieTileModel()
    model.kooziePrizeInfo = KooziePrizeInfo(prizeId: "p", prizeName: "Playola Koozie", requiredHours: 50)
    model.liveTotalMS = 60 * 3_600_000
    #expect(model.mode == .earned)
  }

  @Test func testCopy() {
    let model = KoozieTileModel()
    #expect(model.claimableSubtitle == "Claim it from your prize tile above.")
    #expect(model.earnedText == "Koozie claimed — thanks for listening!")
  }
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement.** `mode`: `koozieEarned == true || hasClaimedLocally` → `.earned`; threshold met
  → `.claimable`; else `.inProgress`. Remove `addressForm`, `isShowingAddressForm`,
  `congratsDismissedLocally`, `redeemTapped`, `backTapped`, `sendMyKoozieTapped`,
  `dismissCongratsTapped`, `redeemButtonText`, `congratsMessage`. `claimableTitle` stays
  `"You earned a koozie!"`. `KoozieTileSection`: drop the `.addressForm`/`.congrats` cases and the
  Redeem button; `claimableView` shows title + subtitle only (`GWKZh`); `earnedView` per `wtGs8`.
  `RewardsProfile`: delete `shouldShowKoozieCongrats`. Remove the two APIClient closures and their live
  impls. Drop the `congrats:` parameter from the suite's existing `tracker(totalMS:koozieEarned:congrats:)`
  helper (it seeds `@Shared(.nowPlaying)` first — keep using it, don't construct `ListeningTracker` inline).
- [ ] **Step 4: Run `KoozieTileModelTests`, `ListeningTimeTileTests`, `RewardsExperienceTests` — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat: koozie claims move to the claim sheet"`

---

### Task 8: Giveaway win → Claim sheet

**Files:**
- Modify: `Views/Pages/MainContainer/MainContainerModel.swift:190-209,395-454`, `MainContainerTests.swift`,
  `PlayolaSheet.swift` (remove `.giveawayWinner`), `MainContainer.swift`
- Modify: `Models/GiveawayParticipation.swift:39` (delete `wasPromotedWin` — its only reader is the deleted
  winner sheet), `GiveawayParticipationTests.swift:40-57` (delete its two tests)
- Delete: `Views/Pages/GiveawayWinnerSheet/` (model, view, tests), `Models/GiveawayWinnerSubmissionRequest.swift`,
  `APIClient.submitGiveawayWinnerDetails` (+ live impl), `PlayolaAlert.giveawaySubmissionFailed`

**Interfaces:**
- Consumes: `refreshFulfillmentRequests()`, `@Shared(.fulfillmentRequests)`, `ClaimSheetModel`,
  `HomePageModel.presentKoozieClaimIfNeeded()`.
- Produces: `MainContainerModel.presentPendingGiveawayClaimIfNeeded() async` (replaces
  `presentPendingGiveawayWinnerIfNeeded`).

- [ ] **Step 1: Write the failing tests** (`MainContainerTests.swift`; replace the winner-sheet tests):

```swift
  @Test func testWinPresentsMatchingRequestOnce() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.giveawayParticipations) var participations = [
      "event-1": GiveawayParticipation.mockWon(id: "event-1")
    ]
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in [.mock(giveawayEventId: "event-1")] }
      $0.date.now = Date(timeIntervalSince1970: 100)
    } operation: { MainContainerModel() }
    await model.processGiveawayResolutions()
    #expect(coordinator.presentedSheet?.is(\.claim) == true)
    #expect(participations["event-1"]?.winnerSheetPresentedAt == Date(timeIntervalSince1970: 100))
    coordinator.presentedSheet = nil
    await model.processGiveawayResolutions()
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func testWinAlreadyShownByOldBuildGetsTileOnly() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.giveawayParticipations) var participations = [
      "event-1": GiveawayParticipation.mockWon(id: "event-1", winnerSheetPresentedAt: Date())
    ]
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in [.mock(giveawayEventId: "event-1")] }
    } operation: { MainContainerModel() }
    await model.processGiveawayResolutions()
    #expect(coordinator.presentedSheet == nil)
  }

  @Test func testNoMatchingRequestPresentsNothingAndDoesNotStamp() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.giveawayParticipations) var participations = ["event-1": GiveawayParticipation.mockWon(id: "event-1")]
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: { MainContainerModel() }
    await model.processGiveawayResolutions()
    #expect(coordinator.presentedSheet == nil)
    #expect(participations["event-1"]?.winnerSheetPresentedAt == nil)
  }

  @Test func testReadyToShipMatchShowsNothingToFillIn() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.giveawayParticipations) var participations = ["event-1": GiveawayParticipation.mockWon(id: "event-1")]
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in [.mock(status: .readyToShip, giveawayEventId: "event-1", infoFields: [])] }
    } operation: { MainContainerModel() }
    await model.processGiveawayResolutions()
    guard case .claim(let sheet) = coordinator.presentedSheet else {
      Issue.record("expected claim sheet"); return
    }
    #expect(sheet.phase == .nothingToFillIn)
  }

  @Test func testSlotTakenDuringFetchDefersWin() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.giveawayParticipations) var participations = ["event-1": GiveawayParticipation.mockWon(id: "event-1")]
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in
        await MainActor.run { coordinator.presentedSheet = .share(ShareSheetModel(items: ["x"])) }
        return [.mock(giveawayEventId: "event-1")]
      }
    } operation: { MainContainerModel() }
    await model.processGiveawayResolutions()
    #expect(coordinator.presentedSheet == .share(ShareSheetModel(items: ["x"])))
    #expect(participations["event-1"]?.winnerSheetPresentedAt == nil)
  }

  @Test func testOverlappingTriggersFetchOnce() async {
    // push + foreground firing together must not double-fetch / double-present
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.giveawayParticipations) var participations = ["event-1": GiveawayParticipation.mockWon(id: "event-1")]
    let fetches = LockIsolated(0)
    let model = withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in
        fetches.withValue { $0 += 1 }
        return [.mock(giveawayEventId: "event-1")]
      }
    } operation: { MainContainerModel() }
    async let a: Void = model.processGiveawayResolutions()
    async let b: Void = model.processGiveawayResolutions()
    _ = await (a, b)
    #expect(fetches.value == 1)
  }
```

  Add `GiveawayParticipation.mockWon(id:winnerSheetPresentedAt:)` beside `.mock` in
  `GiveawayParticipation.swift` (status `.resolvedWon(submissionCompleted: false)`). Wrap
  timing-sensitive tests in `withMainSerialExecutor`.

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** `presentPendingGiveawayClaimIfNeeded()`:
  1. Single-flight: `guard !isPresentingGiveawayClaim` (`@ObservationIgnored private var`), set it,
     `defer` clear.
  2. Candidate = first (by `tappedAt`) participation with `.resolvedWon` and `winnerSheetPresentedAt == nil`.
     `submissionCompleted` is ignored. None → return (no fetch).
  3. Stage pre-check (today's rule): `.none` or `.player`, else return.
  4. `guard await refreshFulfillmentRequests()` else return.
  5. Match `fulfillmentRequests.first { $0.giveawayEventId == candidate.id }` (the list holds only
     `awaiting_info` / `ready_to_ship`);
     none → return without stamping.
  6. **Re-check the stage after the await** (`.none` or `.player`), else return without stamping.
  7. Stamp `winnerSheetPresentedAt = now`; present `.claim(ClaimSheetModel(entry: .request(match), onClose: dismissClaimSheet))`.
  - `processGiveawayResolutions()` order: giveaway claim → loss toast → artist congrats (unchanged).
  - `refreshOnForeground()`: after `processGiveawayResolutions()`, `await refreshFulfillmentRequests()`
    then `homePageModel.presentKoozieClaimIfNeeded()` (giveaway first, koozie only into an empty slot).
  - Delete the GiveawayWinnerSheet files, `submitGiveawayWinnerDetails`, the request model, the alert,
    and `wasPromotedWin` + its two tests;
    remove `.giveawayWinner` from `PlayolaSheet` and `MainContainer`. Leave `GiveawayParticipationStatus`
    and `isFullyHandled` as-is (push handling still writes them).
- [ ] **Step 4: Run `MainContainerTests`, `GiveawayCoordinatorTests`, `PushNotificationsTests`,
  `GiveawayModelsTests`, `GiveawayParticipationTests` — PASS** (touched-area regression rule).
- [ ] **Step 5: Commit** — `git commit -m "feat: giveaway wins open the claim sheet"`

---

### Task 9: Rewards page Redeem → Claim sheet

**Files:**
- Modify: `Views/Pages/RewardsPage/RewardsPageModel.swift:45-90`, `RewardsPageView.swift`, `RewardsPageTests.swift`,
  `PlayolaSheet.swift` (remove `.redeemPrize`), `MainContainer.swift`
- Delete: `RedeemPrizeSheetModel.swift`, `RedeemPrizeSheetView.swift`, `RedeemPrizeSheetTests.swift`,
  `APIClient.redeemPrize` (+ live impl), `PlayolaAlert.prizeRedeemed`

**Interfaces:**
- Consumes: `ClaimSheetModel`, `RewardClaim`.
- Produces: `RedemptionStatus.unavailable` (tier with no prize — Redeem hidden).

- [ ] **Step 1: Write the failing tests:**

```swift
  @Test func testRedeemOpensClaimSheetForTiersSinglePrize() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = RewardsPageModel()
    await model.redeemPrizeTapped(for: .mock)
    guard case .claim(let sheet) = coordinator.presentedSheet else {
      Issue.record("expected claim sheet"); return
    }
    #expect(sheet.phase == .notYetClaimed)
  }

  @Test func testClaimMarksTierRedeemed() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.mainContainerNavigationCoordinator) var coordinator = MainContainerNavigationCoordinator()
    let model = withDependencies {
      $0.api.createRewardRedemption = { _, _ in .mock(source: .reward, giveawayEventId: nil) }
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: { RewardsPageModel() }
    await model.redeemPrizeTapped(for: .mock)
    guard case .claim(let sheet) = coordinator.presentedSheet else { return }
    await sheet.claimItTapped()
    #expect(model.redemptionStatus(for: .mock) == .redeemed)
  }

  @Test func testTierWithoutPrizeIsUnavailable() {
    let model = RewardsPageModel()
    let empty = PrizeTier(
      id: "t", name: "Empty", requiredListeningHours: 0, imageIconUrl: nil, perStation: false,
      prizes: [], createdAt: Date(), updatedAt: Date())
    #expect(model.redemptionStatus(for: empty) == .unavailable)
  }
```

  (Make `RedemptionStatus: Equatable` if it isn't.)

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement.** `redeemPrizeTapped(for:)`: guard `let prize = prizeTier.prizes.first`;
  keep the `.tappedRedeemRewards` analytics; present `.claim(ClaimSheetModel(entry: .reward(RewardClaim(prizeId: prize.id, prizeTitle: prize.name, prizeImageUrl: prize.imageUrl, requiredHours: prizeTier.requiredListeningHours)), onClaimed: { [weak self] in self?.redeemedPrizeTierIds.insert(prizeTier.id) }, onClose: { coordinator.presentedSheet = nil }))`.
  `redemptionStatus`: `prizes.isEmpty` → `.unavailable` (checked after `.redeemed`). The tier row
  component renders `.unavailable` like `.moreTimeRequired` without the hours label and without Redeem
  (the row is a reusable component, so its `switch` is allowed). Delete the RedeemPrizeSheet files,
  `redeemPrize`, `.prizeRedeemed`, and `.redeemPrize`.
- [ ] **Step 4: Run `RewardsPageTests`, `ContactPageTests`, `MainContainerNavigationCoordinatorTests` — PASS.**
- [ ] **Step 5: Commit** — `git commit -m "feat: rewards redeem opens the claim sheet"`

---

### Task 10: Whole-branch verification

- [ ] `grep -rn "GiveawayWinnerSheet\|RedeemPrizeSheet\|KoozieAddressForm\|KoozieShippingAddress\|redeemKooziePrize\|markKoozieCongratsSeen\|submitGiveawayWinnerDetails\|shouldShowKoozieCongrats\|\.redeemPrize\b" PlayolaRadio`
  → no hits (Staging target and pbxproj included: `grep -n` the same names in `project.pbxproj`).
- [ ] `make format && make lint` — clean.
- [ ] Full test run (`xcodebuild test`, ~9 min, timeout 600000) — all green. Paste the summary line.
- [ ] Manual check on a simulator against staging (all three entry points): giveaway win (admin-assign a
  test win), koozie (staging user over 50h), Rewards tier — Later → Home tile → Send → tile disappears.
- [ ] Architect-pipeline phase 3: Codex review → challenge + Excess Audit in parallel, one combined fix wave.
- [ ] PR to `develop` via `codex exec` per CLAUDE.md, title e.g.
  `feature: ask prize winners for shipping details in the app`, then `/fix-review`.

## Acceptance scenarios (from the Phase-5 review — each maps to a test above or the manual pass)

| Scenario | Covered by |
|---|---|
| Legacy states: koozie already `ready_to_ship` with answers → no tile | Task 6 (`readyToShip` filtered) |
| Old build already stamped `winnerSheetPresentedAt` → tile only | Task 8 `testWinAlreadyShownByOldBuildGetsTileOnly` |
| Two devices answer the same request → last write wins, nothing cleared | Task 4 `testSendPutsOnlyAnsweredFields` |
| POST 201 then list refresh fails → sheet still shows the form; koozie shows claimed | Task 4 `testClaimItMovesToReturnedFormAndReportsClaim` + Task 7 `testClaimedLocallyShowsEarnedBeforeProfileCatchesUp` |
| Lost 201 then retry → 409 counts as claimed | Task 4 `testRewardConflictCountsAsClaimed` |
| Admin caller's PUT response shape | Task 2 (response never decoded) |
| Account switching → each account's own koozie prompt, no leaked tiles | Task 6 `testKooziePromptShownOncePerUser` + Task 2 sign-out clear |
| Push + foreground fire together | Task 8 `testOverlappingTriggersFetchOnce`, `testSlotTakenDuringFetchDefersWin` |
| Win with no request yet, discovered later | Task 8 `testNoMatchingRequestPresentsNothingAndDoesNotStamp` |
| Exact choice values | Task 3 `testChoiceAnswerIsExactOption`, `testPrefillNotInOptionsIsIgnored` |
| Optional partial address | Task 3 `testPartialOptionalAddressBlocksSend` |
| Home recovers after a list failure | Task 2 `FulfillmentRequestsRefresherTests.testFailureKeepsLastKnownList` |

## Release prerequisite (not code)

Before this app version is submitted: configure `infoFields` for **Show Tix** and **Meet & Greet** in
production (admin tool) — spec.md § Release prerequisite. Add it to the release PR's checklist.

## Unresolved questions

None blocking. The Show Tix / Meet & Greet field choices are Brian's data decision (above).
