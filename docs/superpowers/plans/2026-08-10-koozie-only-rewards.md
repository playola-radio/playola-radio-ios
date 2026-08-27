# Koozie-Only Rewards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New ("koozie_only") users earn a single Koozie inline on the Home Listening Time tile — progress → claim (with a US shipping address) → congrats → quiet earned state — while the multi-tier Rewards page/button/route disappear for them; existing users are byte-for-byte unchanged.

**Architecture:** Server-owns / client-reads. Cohort + earned/congrats flags ride on the already-fetched `RewardsProfile` (no new durable `@Shared`). The reusable `ListeningTimeTileModel` stays thin and only selects `.legacy` vs a new `.koozie(KoozieTileModel)`; `KoozieTileModel` owns all koozie mode-derivation/copy/actions, and a nested `KoozieAddressFormModel` owns the form. New typed API closures handle redeem-with-address (409-as-success, 400-inline-error) and congrats-dismiss.

**Tech Stack:** SwiftUI, `@Observable` MV models, swift-dependencies (`@Dependency`/`@DependencyClient`), swift-sharing (`@Shared`), Alamofire, swift-testing (`@Test`/`@Suite`/`#expect`), swift-custom-dump.

## Global Constraints

- **Design source of truth:** `docs/superpowers/specs/2026-08-10-koozie-only-rewards-design.md`. Read it before starting.
- **Never gate on environment.** No `Config.shared.environment != .production` anywhere. Feature is gated solely on `rewardsExperience == .koozieOnly`.
- **Backward compatible:** every new server field is optional; absent ⇒ today's behavior. `develop` stays deployable at each commit.
- **Threshold + koozie identity come from the server.** Find the prize with `slug == "koozie"` in `/tiers`; use its `id` (redeem `prizeId`) and its tier's `requiredListeningHours`. **No hardcoded UUID or hour count.**
- **Server enums need a safe fallback:** unknown/absent `rewardsExperience` ⇒ `.fullTiers` (never koozie-only).
- **Congrats copy (verbatim):** `"You've earned a \(prizeName)! Thanks for listening!"` where `prizeName` is the koozie prize's `name`.
- **New `.swift` files MUST be hand-registered in `PlayolaRadio.xcodeproj/project.pbxproj`** (explicit `PBXBuildFile` + `PBXFileReference` + group membership + `PBXSourcesBuildPhase` entry for the correct target — app target for source files, `PlayolaRadioTests` for test files). The project uses explicit refs, NOT synced folders. Forgetting this = "file not found" or "symbol not in scope" at build. Register a new file in the SAME commit that creates it.
- **Tests:** swift-testing only (no XCTest). Every suite carries `@Suite(.freshSharedState)` and `@MainActor`. Mock dependencies with `withDependencies { $0.api.x = ... }` (there is NO `.dependencies` test trait / DependenciesTestSupport). Use `@Shared(.key) var x = value` locally inside each test. Prefer `expectNoDifference` (swift-custom-dump) over `#expect(a == b)` for value comparisons. Tests colocated with code. Never use `Task.sleep` in tests — inject `continuousClock` or assert synchronously.
- **Build/test locally to match CI:** `DEVELOPER_DIR` must point at the CI Xcode (26.5.0), not the local 27.0 beta. App + Staging targets have `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` (tests excluded) — no new warnings. Run `make lint` (SwiftLint) before pushing; the pre-commit hook only runs swift-format.
- **Run tests yourself** via `xcodebuild test` (foreground, `timeout 600000`; ~9 min) with `-skipPackagePluginValidation` and a concrete simulator id. `build-for-testing` alone does not run them.

---

## File Map

**Create:**
- `PlayolaRadio/Models/RewardsExperience.swift` — cohort enum + `[PrizeTier]` koozie lookup.
- `PlayolaRadio/Models/KoozieShippingAddress.swift` — `Encodable` address + redeem request body.
- `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModel.swift` (+ Tests) — form fields/validation.
- `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileModel.swift` (+ Tests) — koozie mode + actions.
- `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileSection.swift` — the koozie bottom-section view.
- `PlayolaRadio/Models/RewardsExperienceTests.swift`, `PlayolaRadio/Models/PrizeTests.swift` (if absent) — decode tests.

**Modify:**
- `PlayolaRadio/Models/RewardsProfile.swift` — add optional cohort/earned/congrats fields + computed enum.
- `PlayolaRadio/Models/Prize.swift` — add `slug: String?`.
- `PlayolaRadio/Core/API/APIClient.swift` — add `redeemKooziePrize`, `markKoozieCongratsSeen` closures.
- `PlayolaRadio/Core/API/APIClient+Live.swift` — live impls.
- `PlayolaRadio/Core/ListeningTracker/ListeningTracker.swift` — `replacingRewardsProfile(_:)`.
- `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift` — use `replacingRewardsProfile` in `loadListeningTracker`.
- `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/ListeningTimeTileModel.swift` + `ListeningTimeTile.swift` — legacy/koozie selection + render.
- `PlayolaRadio/Views/Pages/HomePage/HomePageModel.swift` — construct koozie-aware tile model.
- `PlayolaRadio/Views/Pages/ContactPage/ContactPageModel.swift` + `ContactPageView.swift` (+ `ContactPagePadView.swift`) — `showRewardsButton`, guarded `onRewardsTapped`.
- `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift` — route guard + path sanitize.

---

## Task 1: Model fields — cohort enum, profile flags, Prize.slug, koozie lookup

**Files:**
- Create: `PlayolaRadio/Models/RewardsExperience.swift`
- Modify: `PlayolaRadio/Models/RewardsProfile.swift`
- Modify: `PlayolaRadio/Models/Prize.swift:10-58`
- Test: `PlayolaRadio/Models/RewardsExperienceTests.swift` (create), `PlayolaRadio/Models/PrizeTests.swift` (create if absent)

**Interfaces:**
- Produces: `enum RewardsExperience { case fullTiers, koozieOnly }`; `RewardsProfile.rewardsExperience: String?`, `.koozieEarned: Bool?`, `.shouldShowKoozieCongrats: Bool?`, computed `.rewardsExperienceType: RewardsExperience`; `Prize.slug: String?`; `[PrizeTier].kooziePrizeInfo -> KooziePrizeInfo?` where `struct KooziePrizeInfo { let prizeId: String; let prizeName: String; let requiredHours: Int }`.

- [ ] **Step 1: Write failing decode tests**

Create `PlayolaRadio/Models/RewardsExperienceTests.swift`:

```swift
import Foundation
import Testing
import CustomDump

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct RewardsExperienceTests {
  private func decodeProfile(_ json: String) throws -> RewardsProfile {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(RewardsProfile.self, from: Data(json.utf8))
  }

  @Test func absentRewardsExperienceIsFullTiers() throws {
    let profile = try decodeProfile(#"""
    {"totalTimeListenedMS":1000,"totalMSAvailableForRewards":1000,"accurateAsOfTime":"2026-09-20T14:00:00Z"}
    """#)
    #expect(profile.rewardsExperienceType == .fullTiers)
    #expect(profile.koozieEarned == nil)
    #expect(profile.shouldShowKoozieCongrats == nil)
  }

  @Test func koozieOnlyStringIsKoozieOnly() throws {
    let profile = try decodeProfile(#"""
    {"totalTimeListenedMS":1000,"totalMSAvailableForRewards":1000,"accurateAsOfTime":"2026-09-20T14:00:00Z","rewardsExperience":"koozie_only","koozieEarned":true,"shouldShowKoozieCongrats":true}
    """#)
    #expect(profile.rewardsExperienceType == .koozieOnly)
    #expect(profile.koozieEarned == true)
    #expect(profile.shouldShowKoozieCongrats == true)
  }

  @Test func unknownRewardsExperienceFallsBackToFullTiers() throws {
    let profile = try decodeProfile(#"""
    {"totalTimeListenedMS":1000,"totalMSAvailableForRewards":1000,"accurateAsOfTime":"2026-09-20T14:00:00Z","rewardsExperience":"some_future_tier_v3"}
    """#)
    #expect(profile.rewardsExperienceType == .fullTiers)
  }

  @Test func kooziePrizeInfoLocatesBySlug() {
    let tiers = [
      PrizeTier(
        id: "tier-koozie", name: "Koozie", requiredListeningHours: 50, imageIconUrl: nil,
        prizes: [Prize(id: "prize-koozie", name: "Playola Koozie", prizeTierId: "tier-koozie", imageUrl: nil, slug: "koozie")]
      ),
      PrizeTier(
        id: "tier-tshirt", name: "T-Shirt", requiredListeningHours: 100, imageIconUrl: nil,
        prizes: [Prize(id: "prize-tshirt", name: "Tee", prizeTierId: "tier-tshirt", imageUrl: nil, slug: "tshirt")]
      ),
    ]
    let info = tiers.kooziePrizeInfo
    #expect(info?.prizeId == "prize-koozie")
    #expect(info?.requiredHours == 50)
    #expect(info?.prizeName == "Playola Koozie")
  }

  @Test func kooziePrizeInfoIsNilWhenNoKoozieSlug() {
    let tiers = [
      PrizeTier(
        id: "tier-tshirt", name: "T-Shirt", requiredListeningHours: 100, imageIconUrl: nil,
        prizes: [Prize(id: "prize-tshirt", name: "Tee", prizeTierId: "tier-tshirt", imageUrl: nil, slug: "tshirt")]
      )
    ]
    #expect(tiers.kooziePrizeInfo == nil)
  }
}
```

Register `RewardsExperienceTests.swift` in `project.pbxproj` under the `PlayolaRadioTests` target.

- [ ] **Step 2: Run tests — verify they fail to compile**

Run the suite (see Task 8 for the full command). Expected: FAIL — `RewardsExperience`, `rewardsExperienceType`, `Prize.slug`, `kooziePrizeInfo` undefined.

- [ ] **Step 3: Add `Prize.slug`**

In `PlayolaRadio/Models/Prize.swift`: add `let slug: String?` after `imageUrl`, a `case slug` to `CodingKeys`, `slug = try container.decodeIfPresent(String.self, forKey: .slug)` in `init(from:)`, and `slug: String? = nil` to the memberwise `init` (assign `self.slug = slug`). Update the `mocks` in `PrizeTier.swift` koozie prize to pass `slug: "koozie"` (leave others `nil` or their slug).

- [ ] **Step 4: Add profile fields + enum + lookup**

In `PlayolaRadio/Models/RewardsProfile.swift`, add after `shouldShowWelcomeMessage`:

```swift
  var rewardsExperience: String?
  var koozieEarned: Bool?
  var shouldShowKoozieCongrats: Bool?

  var rewardsExperienceType: RewardsExperience {
    RewardsExperience(rawServerValue: rewardsExperience)
  }
```

Create `PlayolaRadio/Models/RewardsExperience.swift`:

```swift
import Foundation

enum RewardsExperience: Equatable, Sendable {
  case fullTiers   // absent / null / any unrecognized value
  case koozieOnly

  init(rawServerValue: String?) {
    switch rawServerValue {
    case "koozie_only": self = .koozieOnly
    default: self = .fullTiers
    }
  }
}

struct KooziePrizeInfo: Equatable, Sendable {
  let prizeId: String
  let prizeName: String
  let requiredHours: Int
}

extension Array where Element == PrizeTier {
  /// Locates the koozie prize by `slug == "koozie"` and returns its id, name, and its
  /// tier's required hours. Nil when no koozie prize exists (older server / non-koozie data).
  var kooziePrizeInfo: KooziePrizeInfo? {
    for tier in self {
      if let prize = tier.prizes.first(where: { $0.slug == "koozie" }) {
        return KooziePrizeInfo(
          prizeId: prize.id, prizeName: prize.name, requiredHours: tier.requiredListeningHours)
      }
    }
    return nil
  }
}
```

Register `RewardsExperience.swift` in `project.pbxproj` (app target). Create `PrizeTests.swift` only if you added slug-specific tests beyond the above (optional — the koozie test already exercises slug decode via mocks; add a raw-JSON slug decode test if you want belt-and-suspenders).

- [ ] **Step 5: Run tests — verify pass**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Models/RewardsExperience.swift PlayolaRadio/Models/RewardsProfile.swift PlayolaRadio/Models/Prize.swift PlayolaRadio/Models/PrizeTier.swift PlayolaRadio/Models/RewardsExperienceTests.swift PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat(rewards): koozie cohort model fields, Prize.slug, tiers koozie lookup"
```

---

## Task 2: `ListeningTracker.replacingRewardsProfile` (preserve local sessions)

**Files:**
- Modify: `PlayolaRadio/Core/ListeningTracker/ListeningTracker.swift`
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift:248-268`
- Test: `PlayolaRadio/Core/ListeningTracker/ListeningTrackerTests.swift`

**Interfaces:**
- Produces: `ListeningTracker.replacingRewardsProfile(_ profile: RewardsProfile) -> ListeningTracker` (carries over `localListeningSessions`).

- [ ] **Step 1: Write failing test**

Add to `ListeningTrackerTests.swift`:

```swift
@Test func replacingRewardsProfilePreservesLocalSessions() {
  let original = ListeningTracker(
    rewardsProfile: RewardsProfile(
      totalTimeListenedMS: 1_000, totalMSAvailableForRewards: 1_000, accurateAsOfTime: Date()),
    localListeningSessions: [
      LocalListeningSession(startTime: Date(timeIntervalSince1970: 0),
                            endTime: Date(timeIntervalSince1970: 60))  // 60s = 60_000ms
    ])
  let newProfile = RewardsProfile(
    totalTimeListenedMS: 5_000, totalMSAvailableForRewards: 5_000, accurateAsOfTime: Date(),
    koozieEarned: true)

  let replaced = original.replacingRewardsProfile(newProfile)

  #expect(replaced.rewardsProfile.totalTimeListenedMS == 5_000)
  #expect(replaced.rewardsProfile.koozieEarned == true)
  // Local sessions carried over: 5_000 server + 60_000 local
  #expect(replaced.totalListenTimeMS == 65_000)
}
```

(Confirm `LocalListeningSession`'s initializer signature in `ListeningTracker.swift`; adjust the mock session to produce a known `totalTimeMS`.)

- [ ] **Step 2: Run — verify fail** (`replacingRewardsProfile` undefined).

- [ ] **Step 3: Implement**

In `ListeningTracker.swift`:

```swift
  /// Returns a new tracker with a refreshed `rewardsProfile` but the SAME
  /// `localListeningSessions`, so a mid-session profile refetch doesn't reset the
  /// live counter. Snapshot sessions at call time (after any network await).
  func replacingRewardsProfile(_ profile: RewardsProfile) -> ListeningTracker {
    ListeningTracker(rewardsProfile: profile, localListeningSessions: localListeningSessions)
  }
```

- [ ] **Step 4: Use it in `MainContainerModel.loadListeningTracker`**

Replace the write at `MainContainerModel.swift:255`:

```swift
      let rewards = try await api.getRewardsProfile(authJWT)
      self.$listeningTracker.withLock { tracker in
        if let existing = tracker {
          tracker = existing.replacingRewardsProfile(rewards)
        } else {
          tracker = ListeningTracker(rewardsProfile: rewards)
        }
      }
      self.$welcomeMessageEligible.withLock { $0 = rewards.shouldShowWelcomeMessage ?? false }
```

- [ ] **Step 5: Run — verify pass.** Also confirm existing `ListeningTrackerTests` + `MainContainerTests` still pass.

- [ ] **Step 6: Commit**

```bash
git add "PlayolaRadio/Core/ListeningTracker/ListeningTracker.swift" "PlayolaRadio/Core/ListeningTracker/ListeningTrackerTests.swift" "PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift"
git commit -m "feat(tracker): replacingRewardsProfile preserves local sessions on refresh"
```

---

## Task 3: API — `redeemKooziePrize` + `markKoozieCongratsSeen`

**Files:**
- Create: `PlayolaRadio/Models/KoozieShippingAddress.swift`
- Modify: `PlayolaRadio/Core/API/APIClient.swift:75-99` (add closures near `redeemPrize`)
- Modify: `PlayolaRadio/Core/API/APIClient+Live.swift:282-290` (add impls near `redeemPrize`)

**Interfaces:**
- Produces: `struct KoozieShippingAddress: Encodable, Equatable, Sendable { var fullName, addressLine1: String; var addressLine2: String?; var city, state, postalCode: String }`; `api.redeemKooziePrize(jwt, prizeId, KoozieShippingAddress) async throws -> Void` (409 → success, 400 → `APIError.validationError(message)`); `api.markKoozieCongratsSeen(jwt) async throws -> Void` (204/409 → success).

> **Testing note:** `APIClientTests` has no URL-mock harness (only URL-encoding tests), and adding one is out of scope for this PR. The live 201/409/400 branches are verified by the Codex adversarial pass + manual QA (Task 8). Model-level tests (Tasks 4–5) mock these closures, so their *contract* (called with the right args, success/failure propagation) is fully covered.

- [ ] **Step 1: Create the address model**

`PlayolaRadio/Models/KoozieShippingAddress.swift`:

```swift
import Foundation

/// US shipping address captured when a koozie is claimed. `country` is intentionally omitted
/// from the wire body — the server defaults it to "US".
struct KoozieShippingAddress: Encodable, Equatable, Sendable {
  var fullName: String
  var addressLine1: String
  var addressLine2: String?
  var city: String
  var state: String
  var postalCode: String
}

/// Redeem request body. `stationId` is omitted for the koozie.
struct RedeemKooziePrizeRequest: Encodable, Sendable {
  let shippingAddress: KoozieShippingAddress
}
```

Register in `project.pbxproj` (app target).

- [ ] **Step 2: Declare the `@DependencyClient` closures**

In `APIClient.swift`, after `redeemPrize` (~line 92), add:

```swift
  /// Claims the koozie prize with a US shipping address.
  /// 201 → claimed. 409 ("already redeemed") is treated as success (idempotent).
  /// 400 → throws `APIError.validationError(serverMessage)` for inline display.
  var redeemKooziePrize:
    @Sendable (_ jwtToken: String, _ prizeId: String, _ address: KoozieShippingAddress)
      async throws -> Void = { _, _, _ in }

  /// Marks the in-app koozie congrats dismissed (write-once). 204 → recorded;
  /// 409 (not earned) tolerated as success.
  var markKoozieCongratsSeen: @Sendable (_ jwtToken: String) async throws -> Void = { _ in }
```

- [ ] **Step 3: Implement in `APIClient+Live.swift`**

After the `redeemPrize` closure (~line 290), add (mirrors the `moveSpin`/`deleteSpin` manual `serializingData().response` pattern):

```swift
      redeemKooziePrize: { jwtToken, prizeId, address in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/rewards/users/me/prizes/\(prizeId)/redeem"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let body = RedeemKooziePrizeRequest(shippingAddress: address)

        let dataResponse = await apiSession.request(
          url, method: .post, parameters: body, encoder: JSONParameterEncoder.default,
          headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw transportFailure(dataResponse.error)
        }
        // 409 "already redeemed" is idempotent success (concurrent double-tap).
        if (200..<300).contains(statusCode) || statusCode == 409 { return }
        let message =
          dataResponse.value.flatMap { parsePlayolaErrorMessage(from: $0) }
          ?? "Could not claim your koozie. Please try again."
        throw APIError.validationError(message)
      },
      markKoozieCongratsSeen: { jwtToken in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/rewards/users/me/koozie-congrats-seen"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let dataResponse = await apiSession.request(url, method: .post, headers: headers)
          .serializingData()
          .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw transportFailure(dataResponse.error)
        }
        if (200..<300).contains(statusCode) || statusCode == 409 { return }
        let message =
          dataResponse.value.flatMap { parsePlayolaErrorMessage(from: $0) }
          ?? "Could not dismiss the koozie message."
        throw APIError.validationError(message)
      },
```

- [ ] **Step 4: Build** (no unit test here — see testing note). Confirm the app + test targets compile.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Models/KoozieShippingAddress.swift PlayolaRadio/Core/API/APIClient.swift PlayolaRadio/Core/API/APIClient+Live.swift PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat(api): redeemKooziePrize (409-idempotent, 400-inline) + markKoozieCongratsSeen"
```

---

## Task 4: `KoozieAddressFormModel`

**Files:**
- Create: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModel.swift`
- Test: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModelTests.swift`

**Interfaces:**
- Produces: `@Observable @MainActor final class KoozieAddressFormModel` with bindable `var fullName, addressLine1, addressLine2, city, state, postalCode: String`; `var serverError: String?`; `var isSubmitting: Bool`; computed `var canSubmit: Bool`; `func trimmedAddress() -> KoozieShippingAddress`; static copy (`title`, `subtitle`, field placeholders, `backButtonText`, `submitButtonText`).

- [ ] **Step 1: Write failing tests**

`KoozieAddressFormModelTests.swift`:

```swift
import Testing
@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct KoozieAddressFormModelTests {
  private func filledModel() -> KoozieAddressFormModel {
    let m = KoozieAddressFormModel()
    m.fullName = "Jane Doe"
    m.addressLine1 = "123 Main St"
    m.city = "Austin"
    m.state = "TX"
    m.postalCode = "78704"
    return m
  }

  @Test func canSubmitFalseWhenRequiredFieldsBlank() {
    let m = KoozieAddressFormModel()
    #expect(m.canSubmit == false)
    m.fullName = "Jane"; m.addressLine1 = "123 Main"; m.city = "Austin"; m.state = "TX"
    #expect(m.canSubmit == false)  // still missing ZIP
  }

  @Test func canSubmitTrueWhenRequiredFilledAndZipValid() {
    #expect(filledModel().canSubmit == true)
  }

  @Test func zipMustMatchFiveOrNinePattern() {
    let m = filledModel()
    m.postalCode = "7870"
    #expect(m.canSubmit == false)
    m.postalCode = "78704-1234"
    #expect(m.canSubmit == true)
    m.postalCode = "abcde"
    #expect(m.canSubmit == false)
  }

  @Test func whitespaceOnlyFieldsDoNotCount() {
    let m = filledModel()
    m.fullName = "   "
    #expect(m.canSubmit == false)
  }

  @Test func trimmedAddressTrimsAndOmitsEmptyLine2() {
    let m = filledModel()
    m.fullName = "  Jane Doe  "
    m.addressLine2 = "   "
    let addr = m.trimmedAddress()
    #expect(addr.fullName == "Jane Doe")
    #expect(addr.addressLine2 == nil)
    #expect(addr.postalCode == "78704")
  }

  @Test func trimmedAddressKeepsNonEmptyLine2() {
    let m = filledModel()
    m.addressLine2 = " Apt 4 "
    #expect(m.trimmedAddress().addressLine2 == "Apt 4")
  }
}
```

Register the test file in `project.pbxproj` (test target).

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement**

```swift
import Foundation
import Observation

@MainActor
@Observable
final class KoozieAddressFormModel {
  var fullName: String = ""
  var addressLine1: String = ""
  var addressLine2: String = ""
  var city: String = ""
  var state: String = ""
  var postalCode: String = ""

  var serverError: String?
  var isSubmitting: Bool = false

  // MARK: - Copy
  var title: String { "Where should we send it?" }
  var subtitle: String { "US addresses only. We'll only use this to ship your koozie." }
  var fullNamePlaceholder: String { "Full name" }
  var addressLine1Placeholder: String { "Street address" }
  var addressLine2Placeholder: String { "Apt, suite (optional)" }
  var cityPlaceholder: String { "City" }
  var statePlaceholder: String { "State" }
  var zipPlaceholder: String { "ZIP" }
  var backButtonText: String { "Back" }
  var submitButtonText: String { "Send my koozie" }

  // MARK: - Validation
  private func t(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  private var isZipValid: Bool {
    t(postalCode).range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
  }
  var canSubmit: Bool {
    guard !isSubmitting else { return false }
    return !t(fullName).isEmpty && !t(addressLine1).isEmpty && !t(city).isEmpty
      && !t(state).isEmpty && isZipValid
  }

  func trimmedAddress() -> KoozieShippingAddress {
    let line2 = t(addressLine2)
    return KoozieShippingAddress(
      fullName: t(fullName), addressLine1: t(addressLine1),
      addressLine2: line2.isEmpty ? nil : line2,
      city: t(city), state: t(state).uppercased(), postalCode: t(postalCode))
  }
}
```

Register `KoozieAddressFormModel.swift` in `project.pbxproj` (app target).

- [ ] **Step 4: Run — verify pass.**

- [ ] **Step 5: Commit**

```bash
git add "PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModel.swift" "PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieAddressFormModelTests.swift" PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat(koozie): KoozieAddressFormModel with trimming + ZIP validation"
```

---

## Task 5: `KoozieTileModel` — mode derivation + actions

**Files:**
- Create: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileModel.swift`
- Test: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileModelTests.swift`

**Interfaces:**
- Consumes: `api.getPrizeTiers`, `api.redeemKooziePrize`, `api.markKoozieCongratsSeen`, `api.getRewardsProfile`; `@Shared(.auth)`, `@Shared(.listeningTracker)`; `[PrizeTier].kooziePrizeInfo`; `ListeningTracker.replacingRewardsProfile`; `KoozieAddressFormModel`.
- Produces: `enum KoozieTileMode { case inProgress, claimable, addressForm, congrats, earned }`; `KoozieTileModel` with `var mode`, display strings, `var liveTotalMS`, `var addressForm`, and actions `viewAppeared()`, `redeemTapped()`, `backTapped()`, `sendMyKoozieTapped()`, `dismissCongratsTapped()`.

- [ ] **Step 1: Write failing tests**

`KoozieTileModelTests.swift`:

```swift
import Foundation
import Sharing
import Dependencies
import Testing
@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct KoozieTileModelTests {
  private func tracker(totalMS: Int, koozieEarned: Bool? = nil, congrats: Bool? = nil)
    -> ListeningTracker
  {
    ListeningTracker(rewardsProfile: RewardsProfile(
      totalTimeListenedMS: totalMS, totalMSAvailableForRewards: totalMS, accurateAsOfTime: Date(),
      rewardsExperience: "koozie_only", koozieEarned: koozieEarned,
      shouldShowKoozieCongrats: congrats))
  }
  private let info = KooziePrizeInfo(prizeId: "p1", prizeName: "Playola Koozie", requiredHours: 50)

  @Test func belowThresholdIsInProgress() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 10 * 3_600_000)  // 10h of 50h
    let m = KoozieTileModel()
    m.kooziePrizeInfo = info
    m.liveTotalMS = 10 * 3_600_000
    #expect(m.mode == .inProgress)
    #expect(m.progressPercentLabel == "20%")
    #expect(m.hoursToGoLabel == "40h 0m of listening to go")
  }

  @Test func atThresholdNotEarnedIsClaimable() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let m = KoozieTileModel(); m.kooziePrizeInfo = info; m.liveTotalMS = 50 * 3_600_000
    #expect(m.mode == .claimable)
  }

  @Test func redeemTappedShowsAddressForm() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let m = KoozieTileModel(); m.kooziePrizeInfo = info; m.liveTotalMS = 50 * 3_600_000
    m.redeemTapped()
    #expect(m.mode == .addressForm)
    m.backTapped()
    #expect(m.mode == .claimable)
  }

  @Test func earnedWithCongratsIsCongrats() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 60 * 3_600_000, koozieEarned: true, congrats: true)
    let m = KoozieTileModel(); m.kooziePrizeInfo = info; m.liveTotalMS = 60 * 3_600_000
    #expect(m.mode == .congrats)
    #expect(m.congratsMessage == "You've earned a Playola Koozie! Thanks for listening!")
  }

  @Test func earnedWithoutCongratsIsEarned() {
    @Shared(.listeningTracker) var lt = tracker(totalMS: 60 * 3_600_000, koozieEarned: true, congrats: false)
    let m = KoozieTileModel(); m.kooziePrizeInfo = info; m.liveTotalMS = 60 * 3_600_000
    #expect(m.mode == .earned)
  }

  @Test func sendMyKoozieSuccessRefreshesToCongrats() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let captured = LockIsolated<KoozieShippingAddress?>(nil)
    let m = withDependencies {
      $0.api.getPrizeTiers = { [] }
      $0.api.redeemKooziePrize = { _, _, addr in captured.setValue(addr) }
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(totalTimeListenedMS: 50 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only",
          koozieEarned: true, shouldShowKoozieCongrats: true)
      }
    } operation: { KoozieTileModel() }
    m.kooziePrizeInfo = info; m.liveTotalMS = 50 * 3_600_000
    m.redeemTapped()
    m.addressForm.fullName = "Jane Doe"; m.addressForm.addressLine1 = "123 Main St"
    m.addressForm.city = "Austin"; m.addressForm.state = "tx"; m.addressForm.postalCode = "78704"

    await m.sendMyKoozieTapped()

    #expect(captured.value?.state == "TX")  // uppercased
    #expect(m.mode == .congrats)
  }

  @Test func sendMyKoozieValidationErrorSurfacesInlineAndStaysOnForm() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(totalMS: 50 * 3_600_000)
    let m = withDependencies {
      $0.api.redeemKooziePrize = { _, _, _ in throw APIError.validationError("Invalid US shipping address") }
    } operation: { KoozieTileModel() }
    m.kooziePrizeInfo = info; m.liveTotalMS = 50 * 3_600_000
    m.redeemTapped()
    m.addressForm.fullName = "Jane"; m.addressForm.addressLine1 = "1 St"
    m.addressForm.city = "Austin"; m.addressForm.state = "TX"; m.addressForm.postalCode = "78704"

    await m.sendMyKoozieTapped()

    #expect(m.addressForm.serverError == "Invalid US shipping address")
    #expect(m.mode == .addressForm)
  }

  @Test func dismissCongratsOptimisticallyShowsEarned() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.listeningTracker) var lt = tracker(totalMS: 60 * 3_600_000, koozieEarned: true, congrats: true)
    let m = withDependencies {
      $0.api.markKoozieCongratsSeen = { _ in }
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(totalTimeListenedMS: 60 * 3_600_000, totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(), rewardsExperience: "koozie_only",
          koozieEarned: true, shouldShowKoozieCongrats: false)
      }
    } operation: { KoozieTileModel() }
    m.kooziePrizeInfo = info; m.liveTotalMS = 60 * 3_600_000

    await m.dismissCongratsTapped()

    #expect(m.mode == .earned)
  }
}
```

Register the test file in `project.pbxproj` (test target).

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement**

```swift
import Foundation
import Dependencies
import Observation
import Sharing

enum KoozieTileMode: Equatable {
  case inProgress
  case claimable
  case addressForm
  case congrats
  case earned
}

@MainActor
@Observable
final class KoozieTileModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

  var kooziePrizeInfo: KooziePrizeInfo?
  var liveTotalMS: Int = 0
  var addressForm = KoozieAddressFormModel()

  private var isShowingAddressForm = false
  private var congratsDismissedLocally = false

  // MARK: - Static copy
  var progressTitle: String { "Playola Koozie" }
  var claimableTitle: String { "You earned a koozie!" }
  var claimableSubtitle: String { "Claim it and we'll get one out to you." }
  var redeemButtonText: String { "Redeem your koozie" }
  var earnedText: String { "Koozie redeemed — check your email" }
  var congratsMessage: String {
    "You've earned a \(kooziePrizeInfo?.prizeName ?? "koozie")! Thanks for listening!"
  }

  // MARK: - Derived
  private var profile: RewardsProfile? { listeningTracker?.rewardsProfile }

  var mode: KoozieTileMode {
    if profile?.koozieEarned == true {
      if profile?.shouldShowKoozieCongrats == true && !congratsDismissedLocally {
        return .congrats
      }
      return .earned
    }
    if isShowingAddressForm { return .addressForm }
    if let info = kooziePrizeInfo, liveTotalMS >= info.requiredHours * 3_600_000 {
      return .claimable
    }
    return .inProgress
  }

  var progressFraction: Double {
    guard let info = kooziePrizeInfo, info.requiredHours > 0 else { return 0 }
    return min(1.0, Double(liveTotalMS) / Double(info.requiredHours * 3_600_000))
  }
  var progressPercentLabel: String { "\(Int(progressFraction * 100))%" }
  var hoursToGoLabel: String {
    guard let info = kooziePrizeInfo else { return "" }
    let remainingMS = max(0, info.requiredHours * 3_600_000 - liveTotalMS)
    let totalMinutes = remainingMS / 60_000
    return "\(totalMinutes / 60)h \(totalMinutes % 60)m of listening to go"
  }

  // MARK: - Actions
  func viewAppeared() async {
    guard kooziePrizeInfo == nil else { return }
    if let tiers = try? await api.getPrizeTiers() {
      kooziePrizeInfo = tiers.kooziePrizeInfo
    }
  }

  func redeemTapped() {
    addressForm.serverError = nil
    isShowingAddressForm = true
  }

  func backTapped() { isShowingAddressForm = false }

  func sendMyKoozieTapped() async {
    guard addressForm.canSubmit, let jwt = auth.jwt, let info = kooziePrizeInfo else { return }
    addressForm.serverError = nil
    addressForm.isSubmitting = true
    defer { addressForm.isSubmitting = false }
    do {
      try await api.redeemKooziePrize(jwt, info.prizeId, addressForm.trimmedAddress())
      isShowingAddressForm = false
      await refreshProfile()
    } catch {
      addressForm.serverError =
        (error as? APIError)?.errorDescription ?? "Could not claim your koozie. Please try again."
    }
  }

  func dismissCongratsTapped() async {
    congratsDismissedLocally = true  // optimistic → .earned
    guard let jwt = auth.jwt else { return }
    try? await api.markKoozieCongratsSeen(jwt)
    await refreshProfile()
  }

  private func refreshProfile() async {
    guard let jwt = auth.jwt else { return }
    guard let refreshed = try? await api.getRewardsProfile(jwt) else { return }
    $listeningTracker.withLock { tracker in
      tracker = tracker?.replacingRewardsProfile(refreshed) ?? ListeningTracker(rewardsProfile: refreshed)
    }
  }
}
```

Register `KoozieTileModel.swift` in `project.pbxproj` (app target).

- [ ] **Step 4: Run — verify pass.**

- [ ] **Step 5: Commit**

```bash
git add "PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileModel.swift" "PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileModelTests.swift" PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat(koozie): KoozieTileModel mode derivation + redeem/dismiss/refresh actions"
```

---

## Task 6: Wire the tile — `ListeningTimeTileModel` selection + views (legacy unchanged)

**Files:**
- Modify: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/ListeningTimeTileModel.swift`
- Modify: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/ListeningTimeTile.swift`
- Create: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/KoozieTileSection.swift`
- Modify: `PlayolaRadio/Views/Pages/HomePage/HomePageModel.swift:82-95`
- Test: `PlayolaRadio/Views/Reusable Components/ListeningTimeTile/ListeningTimeTileTests.swift`

**Interfaces:**
- Consumes: `KoozieTileModel`, `KoozieTileSection`.
- Produces: `ListeningTimeTileModel.koozieTileModel: KoozieTileModel?` (non-nil only for koozie cohort), driven by its existing 1s loop which now also feeds `koozieTileModel?.liveTotalMS`.

- [ ] **Step 1: Write failing tests** (legacy-unchanged guard + koozie activation)

Add to `ListeningTimeTileModelTests.swift`:

```swift
@Test func legacyUserHasNoKoozieModel() {
  @Shared(.listeningTracker) var lt = createMockListeningTracker(totalTimeMS: 1_000)  // no rewardsExperience
  let model = ListeningTimeTileModel(buttonText: "Redeem Your Rewards!", buttonAction: {})
  model.refreshFromTracker()
  #expect(model.koozieTileModel == nil)
  #expect(model.buttonText == "Redeem Your Rewards!")
}

@Test func koozieUserGetsKoozieModelAndSuppressesLegacyButton() {
  @Shared(.listeningTracker) var lt = ListeningTracker(rewardsProfile: RewardsProfile(
    totalTimeListenedMS: 1_000, totalMSAvailableForRewards: 1_000, accurateAsOfTime: Date(),
    rewardsExperience: "koozie_only"))
  let model = ListeningTimeTileModel(buttonText: "Redeem Your Rewards!", buttonAction: {})
  model.refreshFromTracker()
  #expect(model.koozieTileModel != nil)
  #expect(model.showsLegacyButton == false)
}
```

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement the selection in `ListeningTimeTileModel`**

Add:

```swift
  private(set) var koozieTileModel: KoozieTileModel?

  var showsLegacyButton: Bool { koozieTileModel == nil && buttonText != nil }

  /// Sets up koozie mode iff the cohort is koozie-only; called on appear and each tick.
  func refreshFromTracker() {
    let isKoozie = listeningTracker?.rewardsProfile.rewardsExperienceType == .koozieOnly
    if isKoozie, koozieTileModel == nil {
      koozieTileModel = KoozieTileModel()
    } else if !isKoozie, koozieTileModel != nil {
      koozieTileModel = nil
    }
  }
```

Update `viewAppeared()` so the loop keeps koozie state fresh and feeds the live counter:

```swift
  func viewAppeared() {
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      guard let self else { return }
      self.refreshFromTracker()
      await self.koozieTileModel?.viewAppeared()  // one-shot tiers fetch (guards internally)
      while !Task.isCancelled {
        let ms = self.listeningTracker?.totalListenTimeMS ?? 0
        self.totalListeningTime = ms
        self.refreshFromTracker()
        self.koozieTileModel?.liveTotalMS = ms
        try? await self.clock.sleep(for: .seconds(1))
      }
    }
  }
```

- [ ] **Step 4: Implement `KoozieTileSection.swift`** (dumb view; koozie-model bindings only)

```swift
import SwiftUI

struct KoozieTileSection: View {
  @Bindable var model: KoozieTileModel

  var body: some View {
    Group {
      switch model.mode {
      case .inProgress: progressView
      case .claimable: claimableView
      case .addressForm: KoozieAddressFormView(model: model)
      case .congrats: congratsView
      case .earned: earnedView
      }
    }
  }
  // progressView / claimableView / congratsView / earnedView: render model strings + koozie-icon,
  // progress bar (model.progressFraction), and buttons calling model.redeemTapped() /
  // model.dismissCongratsTapped(). See spec state table for layout.
  // ... (implement each subview per the mockup; no logic beyond reading model)
}
```

> Implementer: build the four inline subviews and a `KoozieAddressFormView` (fields bound to `model.addressForm.*`, `Back` → `model.backTapped()`, `Send my koozie` → `await model.sendMyKoozieTapped()`, disabled when `!model.addressForm.canSubmit`, inline `model.addressForm.serverError`). Use `Image("koozie-icon")`. Keep it control-flow-limited to the `switch` on `model.mode` (a reusable component, not a page view). Register `KoozieTileSection.swift` in `project.pbxproj`.

- [ ] **Step 5: Render the section in `ListeningTimeTile.swift`**

Replace the legacy `if let buttonText` block with:

```swift
      if let koozie = model.koozieTileModel {
        Divider().overlay(Color.white.opacity(0.15))
        KoozieTileSection(model: koozie)
      } else if let buttonText = model.buttonText {
        // ...existing legacy button, unchanged...
      }
```

- [ ] **Step 6: HomePage stays as-is** — `HomePageModel.listeningTimeTileModel` still constructs with the legacy `buttonText`/`buttonAction`; koozie users simply get `koozieTileModel` populated from the tracker, and `showsLegacyButton`/the view suppress the legacy button. No change needed unless a test requires it; confirm `HomePageTests` still pass.

- [ ] **Step 7: Run all tests — verify pass, and legacy tile behavior unchanged.**

- [ ] **Step 8: Commit**

```bash
git add "PlayolaRadio/Views/Reusable Components/ListeningTimeTile/" PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat(koozie): render koozie tile sections; legacy tile path unchanged"
```

---

## Task 7: Remove Rewards for koozie users — button + coordinator route guard

**Files:**
- Modify: `PlayolaRadio/Views/Pages/ContactPage/ContactPageModel.swift`
- Modify: `PlayolaRadio/Views/Pages/ContactPage/ContactPageView.swift:171-197` (+ `ContactPagePadView.swift`)
- Modify: `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift`
- Modify: `PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift` (sanitize on load)
- Test: `PlayolaRadio/Views/Pages/ContactPage/ContactPageTests.swift`, `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinatorTests.swift`

**Interfaces:**
- Produces: `ContactPageModel.showRewardsButton: Bool`; guarded `onRewardsTapped()`; `MainContainerNavigationCoordinator.pushRewards(_:)` (no-ops for koozie) + `sanitizeRewardsRouteForKoozie()`.

- [ ] **Step 1: Write failing tests**

`ContactPageTests.swift`:

```swift
@Test func showRewardsButtonFalseForKoozieUser() {
  @Shared(.listeningTracker) var lt = ListeningTracker(rewardsProfile: RewardsProfile(
    totalTimeListenedMS: 0, totalMSAvailableForRewards: 0, accurateAsOfTime: Date(),
    rewardsExperience: "koozie_only"))
  #expect(ContactPageModel().showRewardsButton == false)
}

@Test func showRewardsButtonTrueForFullTiersUser() {
  @Shared(.listeningTracker) var lt = ListeningTracker(rewardsProfile: RewardsProfile(
    totalTimeListenedMS: 0, totalMSAvailableForRewards: 0, accurateAsOfTime: Date()))
  #expect(ContactPageModel().showRewardsButton == true)
}

@Test func onRewardsTappedNoOpsForKoozieUser() {
  @Shared(.listeningTracker) var lt = ListeningTracker(rewardsProfile: RewardsProfile(
    totalTimeListenedMS: 0, totalMSAvailableForRewards: 0, accurateAsOfTime: Date(),
    rewardsExperience: "koozie_only"))
  @Shared(.mainContainerNavigationCoordinator) var coord = MainContainerNavigationCoordinator()
  let model = ContactPageModel()
  model.onRewardsTapped()
  #expect(coord.profilePath.isEmpty)
}
```

`MainContainerNavigationCoordinatorTests.swift`:

```swift
@Test func sanitizeStripsRewardsFromProfilePath() {
  @Shared(.activeTab) var tab = MainContainerModel.ActiveTab.profile
  let coord = MainContainerNavigationCoordinator()
  coord.profilePath = [.rewardsPage(RewardsPageModel()), .notificationsSettingsPage(NotificationsSettingsPageModel())]
  coord.sanitizeRewardsRouteForKoozie()
  #expect(coord.profilePath.count == 1)
  if case .rewardsPage = coord.profilePath.first { Issue.record("rewardsPage should be stripped") }
}
```

(Confirm the `activeTab` shared-key type / default so `profilePath` is the active tab's path in the test.)

- [ ] **Step 2: Run — verify fail.**

- [ ] **Step 3: Implement coordinator guard + sanitize**

In `MainContainerNavigationCoordinator.swift`:

```swift
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

  private var isKoozieOnly: Bool {
    listeningTracker?.rewardsProfile.rewardsExperienceType == .koozieOnly
  }

  /// Push the Rewards page unless the user is koozie-only (route is inert for them).
  func pushRewards(_ model: RewardsPageModel) {
    guard !isKoozieOnly else { return }
    push(.rewardsPage(model))
  }

  /// Drop any `.rewardsPage` entries from every tab path (call when a koozie profile loads,
  /// so restored nav state can't surface the legacy page).
  func sanitizeRewardsRouteForKoozie() {
    guard isKoozieOnly else { return }
    let strip: ([Path]) -> [Path] = { $0.filter { if case .rewardsPage = $0 { return false }; return true } }
    homePath = strip(homePath); stationsPath = strip(stationsPath)
    yourLibraryPath = strip(yourLibraryPath); profilePath = strip(profilePath)
    broadcastPath = strip(broadcastPath); libraryPath = strip(libraryPath)
    listenersPath = strip(listenersPath); settingsPath = strip(settingsPath)
  }
```

Add `@ObservationIgnored @Shared(.listeningTracker)` requires importing nothing new. Note `nonisolated init()` — `@Shared` property wrappers are fine here.

- [ ] **Step 4: Route callers through the guard**

- `ContactPageModel.onRewardsTapped()`:

```swift
  var showRewardsButton: Bool {
    listeningTracker?.rewardsProfile.rewardsExperienceType != .koozieOnly
  }

  @MainActor
  func onRewardsTapped() {
    mainContainerNavigationCoordinator.pushRewards(self.rewardsPageModel)
  }
```

Add `@ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?` to `ContactPageModel`.

- `HomePageModel.listeningTimeTileModel` legacy button action already checks `if case .rewardsPage`; change its push to `pushRewards(RewardsPageModel())`. (For koozie users the legacy button isn't shown anyway; this is defense in depth.)

- [ ] **Step 5: Hide the button in the views**

In `ContactPageView.swift`, wrap the Rewards button block (lines 171-197) in `if model.showRewardsButton { ... }` (matches the file's existing `if model.myStationButtonVisible` pattern). Do the same in `ContactPagePadView.swift` if it renders a Rewards button.

- [ ] **Step 6: Sanitize on profile load**

In `MainContainerModel.loadListeningTracker`, after writing the tracker, call:

```swift
      mainContainerNavigationCoordinator.sanitizeRewardsRouteForKoozie()
```

- [ ] **Step 7: Run all tests — verify pass.**

- [ ] **Step 8: Commit**

```bash
git add "PlayolaRadio/Views/Pages/ContactPage/" "PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift" "PlayolaRadio/Views/Pages/MainContainer/MainContainerModel.swift" "PlayolaRadio/Views/Pages/HomePage/HomePageModel.swift"
git commit -m "feat(koozie): hide Rewards button + guard/sanitize .rewardsPage route for koozie users"
```

---

## Task 8: Integration verification, lint, and QA

**Files:** none (verification + polish only).

- [ ] **Step 1: Full test run (foreground, ~9 min)**

Run (substitute a concrete booted simulator UDID from `xcrun simctl list devices booted`):

```bash
DEVELOPER_DIR="/Applications/Xcode-26.5.0.app/Contents/Developer" \
xcodebuild test \
  -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,id=<SIM_UDID>' \
  -skipPackagePluginValidation 2>&1 | tail -40
```

Expected: all suites pass, including the new koozie suites and the unchanged `ListeningTimeTileModelTests`, `MainContainerTests`, `HomePageTests`, `ContactPageTests`.

- [ ] **Step 2: Lint + format**

```bash
make format && make lint
```

Fix any SwiftLint violations (CI fails on them; the pre-commit hook only formats).

- [ ] **Step 3: Manual/simulator QA of the live path**

Verify the full flow against staging with a koozie-cohort account (or a mocked profile): in-progress bar → claimable → address form (Back works, validation gates Send) → Send my koozie → congrats → ✕ dismiss → quiet earned row. Confirm double-tapping Send (409) still lands on congrats (idempotent), and a bad ZIP shows the inline server/client message. Confirm a full-tiers account sees ZERO change (Rewards button present, tile button present).

- [ ] **Step 4: Codex adversarial review** (per Architect-with-Codex pipeline)

`/codex review` then `/codex challenge` on the branch diff (resume session `019fec5b-2ec9-7093-99d7-308cf83d9b36` for continuity). Fix everything surfaced; re-run if fixes are non-trivial.

- [ ] **Step 5: PR** — open against `develop` (not `main`), then run `/fix-review` once.

---

## Self-Review (author checklist — completed)

- **Spec coverage:** cohort decode (T1), profile refresh preserving sessions (T2), redeem/dismiss API incl. 409/400 (T3), address form + validation (T4), 5-state derivation + actions incl. congrats copy (T5), tile wiring + legacy-unchanged (T6), button hide + coordinator route guard + path sanitize (T7), backward-compat + QA (T8). All spec sections map to a task.
- **Placeholder scan:** the only intentionally-summarized code is the four `KoozieTileSection` subviews + `KoozieAddressFormView` (pure layout, no logic, driven entirely by already-defined model strings/actions) — flagged explicitly for the implementer, not left as vague logic.
- **Type consistency:** `KooziePrizeInfo(prizeId/prizeName/requiredHours)`, `KoozieShippingAddress`, `KoozieTileMode`, `rewardsExperienceType`, `replacingRewardsProfile`, `redeemKooziePrize`, `markKoozieCongratsSeen`, `koozieTileModel`, `showRewardsButton`, `pushRewards`, `sanitizeRewardsRouteForKoozie` used consistently across tasks.
- **Not tracked in `LONG_RUNNING.md`** (per spec: single-PR iOS change, no soak).
</content>
