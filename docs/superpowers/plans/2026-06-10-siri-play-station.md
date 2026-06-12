# Siri "Play [Station]" Implementation Plan (Option B — custom App Intent)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans, task-by-task. Steps use checkbox (`- [ ]`). Before writing any Swift, invoke the relevant `pfw-*` skills (pfw-dependencies, pfw-sharing, pfw-observable-models, pfw-testing, pfw-custom-dump).

**Goal:** Let a user start a Playola station by voice through Siri ("Play Bordertown Radio on Playola").

**Architecture:** App Intents in the main app target. A testable `@MainActor` core (`StationVoiceCatalog` matching, `PlayStationAction` auth+play, `PlaybackBootstrap` audio session) does all real work. Thin custom App Intents shells — `RadioStationEntity` + `EntityQuery`, `PlayStationIntent`, `AppShortcutsProvider` — expose it to Siri/Shortcuts. **No `.audio` schema conformance** (not in the installed SDK; iOS-26-only `IntentValueQuery`). Schema upgrade is a deferred fast-follow; the core is unchanged by it.

**Tech Stack:** Swift, App Intents (iOS 18), swift-dependencies, swift-sharing, Swift Testing (`import Testing`).

**Spec:** `docs/superpowers/specs/2026-06-10-siri-play-station-design.md`
**SDK spike notes:** `docs/superpowers/specs/audio-schema-notes.md`

---

## Conventions for every task

- **Tests:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@MainActor struct XxxTests`), colocated. Prefer custom-dump `expectNoDifference` for value comparisons.
- **`@Shared` in tests:** declare locally per test (e.g. `@Shared(.auth) var auth = Auth(jwtToken: "jwt")`). Never class-level.
- **New files MUST be hand-registered in `PlayolaRadio.xcodeproj/project.pbxproj`** (explicit refs — no synced folders). Task 9 batches this; register sooner if a per-task Xcode build is needed.
- **New code lives in** `PlayolaRadio/Core/SiriIntents/` (new group). Tests colocated.
- **Run tests (CLI):**
  ```bash
  xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
    -destination 'platform=iOS Simulator,id=CC4A4FCF-D331-4CB2-BADC-523BD1728852' \
    -skipPackagePluginValidation \
    -only-testing:PlayolaRadioTests/<TestStructName> 2>&1 | xcbeautify
  ```
  (Booted sim above is `iPhone 15`; substitute any booted sim. `-skipPackagePluginValidation` is required or the SwiftLint build plugin fails the run.)

---

## Task 1: Spike — pin `.audio` schema API ✅ DONE

Found `.audio` is **not** in the installed Xcode 26.5 SDK and its `IntentValueQuery` is iOS-26-only. Decision: Option B (custom intent). Notes committed at `docs/superpowers/specs/audio-schema-notes.md`. No further action.

---

## Task 2: `StationMatch` value type + name normalization

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift`
- Test: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing

@testable import PlayolaRadio

@MainActor
struct StationVoiceCatalogTests {
  @Test
  func testNormalizeLowercasesStripsPunctuationAndPossessive() {
    #expect(StationVoiceCatalog.normalize("Radney Foster's Station") == "radney foster")
    #expect(StationVoiceCatalog.normalize("Bordertown Radio!") == "bordertown")
    #expect(StationVoiceCatalog.normalize("  KOKE  FM ") == "koke fm")
  }
}
```

- [ ] **Step 2: Run it, verify it fails** (`-only-testing:PlayolaRadioTests/StationVoiceCatalogTests`). Expected: FAIL (no `StationVoiceCatalog`).

- [ ] **Step 3: Implement `StationMatch` and `normalize`**

```swift
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing

/// A station resolved from a spoken/typed query, with the label the App Intents
/// layer shows. FM → station name; Artist → "[Artist]'s Station".
struct StationMatch: Equatable, Identifiable {
  let id: String      // AnyStation.id
  let label: String
}

@MainActor
struct StationVoiceCatalog {
  @Shared(.stationLists) var stationLists

  /// Lowercase, strip possessive "'s", strip punctuation, drop the filler words
  /// "radio"/"station", collapse whitespace. Applied to both station aliases and
  /// the incoming query so matching is symmetric.
  static func normalize(_ raw: String) -> String {
    var s = raw.lowercased()
    s = s.replacingOccurrences(of: "'s", with: "")
    s = s.replacingOccurrences(of: "\u{2019}s", with: "")  // curly apostrophe
    let allowed = CharacterSet.alphanumerics.union(.whitespaces)
    s = String(s.unicodeScalars.filter { allowed.contains($0) })
    let filler: Set<String> = ["radio", "station"]
    let words = s.split(separator: " ").map(String.init).filter { !filler.contains($0) }
    return words.joined(separator: " ")
  }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift
git commit -m "feat: add StationMatch and station name normalization"
```

---

## Task 3: `StationVoiceCatalog` aliases, suggestions, lookup

`AnyStation.name` → curatorName for artist stations, station name for FM; `AnyStation.stationName` → underlying station name for both. Aliases: FM → `name`; artist → `curatorName`, `"[curatorName]'s Station"`, `stationName`.

**Files:**
- Modify: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift`
- Test: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import IdentifiedCollections
import PlayolaPlayer
import Sharing

@Test
func testSuggestedStationsFMLabelIsStationName() {
  @Shared(.stationLists) var stationLists = StationList.mocks
  let koke = StationVoiceCatalog().suggestedStations().first { $0.id == "koke-fm-id" }
  #expect(koke?.label == "KOKE FM")
}

@Test
func testSuggestedStationsArtistLabelIsArtistPossessive() {
  let artistList = StationList.mockArtistList(items: [
    APIStationItem(sortOrder: 0, station: Station.mockWith(
      id: "rf-id", name: "Bordertown Radio", curatorName: "Radney Foster"), urlStation: nil)
  ])
  @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [artistList])
  let match = StationVoiceCatalog().suggestedStations().first { $0.id == "rf-id" }
  #expect(match?.label == "Radney Foster's Station")
}

@Test
func testMatchesResolvesByStationNameAndCuratorName() {
  let artistList = StationList.mockArtistList(items: [
    APIStationItem(sortOrder: 0, station: Station.mockWith(
      id: "rf-id", name: "Bordertown Radio", curatorName: "Radney Foster"), urlStation: nil)
  ])
  @Shared(.stationLists) var stationLists = IdentifiedArrayOf(uniqueElements: [artistList])
  let catalog = StationVoiceCatalog()
  #expect(catalog.matches(query: "Bordertown Radio").first?.id == "rf-id")
  #expect(catalog.matches(query: "Radney Foster").first?.id == "rf-id")
  #expect(catalog.matches(query: "Radney Foster's Station").first?.id == "rf-id")
}

@Test
func testMatchesFailsClosedOnNoConfidentMatch() {
  @Shared(.stationLists) var stationLists = StationList.mocks
  #expect(StationVoiceCatalog().matches(query: "totally unrelated zzzz").isEmpty)
}

@Test
func testMatchByIdReturnsLabel() {
  @Shared(.stationLists) var stationLists = StationList.mocks
  #expect(StationVoiceCatalog().match(id: "koke-fm-id")?.label == "KOKE FM")
  #expect(StationVoiceCatalog().match(id: "nope") == nil)
}

@Test
func testStationByIdReturnsAnyStation() {
  @Shared(.stationLists) var stationLists = StationList.mocks
  #expect(StationVoiceCatalog().station(id: "koke-fm-id")?.id == "koke-fm-id")
  #expect(StationVoiceCatalog().station(id: "nonexistent") == nil)
}
```

- [ ] **Step 2: Run, verify failure.**

- [ ] **Step 3: Implement**

Add to `StationVoiceCatalog`:

```swift
/// All playable (visible, non-coming-soon) stations as matches.
func suggestedStations() -> [StationMatch] {
  allStations().map(makeMatch(for:))
}

/// Best-effort fuzzy matches for a spoken/typed query, ordered best-first.
/// Fails closed: returns [] when nothing clears the confidence bar.
func matches(query: String) -> [StationMatch] {
  let needle = Self.normalize(query)
  guard !needle.isEmpty else { return [] }
  return allStations().compactMap { station -> (StationMatch, Int)? in
    guard let score = bestScore(for: station, needle: needle), score > 0 else { return nil }
    return (makeMatch(for: station), score)
  }
  .sorted { $0.1 > $1.1 }
  .map(\.0)
}

/// Match for a known id (used to rehydrate an entity by id).
func match(id: String) -> StationMatch? {
  allStations().first { $0.id == id }.map(makeMatch(for:))
}

/// Resolve a match id back to the real station for playback.
func station(id: String) -> AnyStation? {
  allStations().first { $0.id == id }
}

// MARK: - Private

private func allStations() -> [AnyStation] {
  stationLists.flatMap { list in
    list.stationItems(includeHidden: false, includeComingSoon: false).map(\.anyStation)
  }
}

private func aliases(for station: AnyStation) -> [String] {
  switch station {
  case .url(let s): return [s.name]
  case .playola(let s): return [s.curatorName, "\(s.curatorName)'s Station", s.name]
  }
}

private func label(for station: AnyStation) -> String {
  switch station {
  case .url(let s): return s.name
  case .playola(let s): return "\(s.curatorName)'s Station"
  }
}

private func makeMatch(for station: AnyStation) -> StationMatch {
  StationMatch(id: station.id, label: label(for: station))
}

/// Exact normalized alias match beats prefix beats contains; nil = no relation
/// (fail closed).
private func bestScore(for station: AnyStation, needle: String) -> Int? {
  var best: Int?
  for alias in aliases(for: station) {
    let hay = Self.normalize(alias)
    guard !hay.isEmpty else { continue }
    let score: Int?
    if hay == needle { score = 100 }
    else if hay.hasPrefix(needle) || needle.hasPrefix(hay) { score = 60 }
    else if hay.contains(needle) || needle.contains(hay) { score = 30 }
    else { score = nil }
    if let score, score > (best ?? 0) { best = score }
  }
  return best
}
```

- [ ] **Step 4: Run, verify all pass.**
- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift
git commit -m "feat: add station matching, suggestions, and lookup to StationVoiceCatalog"
```

---

## Task 4: `PlaybackBootstrap` — explicit audio session

**Files:** Create `PlayolaRadio/Core/SiriIntents/PlaybackBootstrap.swift`

- [ ] **Step 1: Implement**

```swift
import AVFoundation

/// Ensures the audio session is active before playback begins from a Siri
/// cold-launch, where the normal app-launch path may not have run yet.
@MainActor
struct PlaybackBootstrap {
  func prepareForPlayback() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }
}
```

- [ ] **Step 2: Commit** (compiles as part of Task 9's batch build if not registered yet)

```bash
git add PlayolaRadio/Core/SiriIntents/PlaybackBootstrap.swift
git commit -m "feat: add PlaybackBootstrap for explicit audio session setup"
```

---

## Task 5: `PlayStationAction` — auth gate + lookup + play

`StationPlayer.play(station:)` synchronously sets `state` to `.loading(station)` before any await, so `stationPlayer.currentStation` reflects the requested station immediately — assert on that without a mock. Use a URL station in the "plays" test to avoid the network path the playola branch takes.

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/PlayStationAction.swift`
- Test: `PlayolaRadio/Core/SiriIntents/PlayStationActionTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct PlayStationActionTests {
  private func makeStationLists() -> IdentifiedArrayOf<StationList> {
    let fm = StationList(
      id: "fm_list", name: "FM", slug: "fm_list", hidden: false, sortOrder: 0,
      createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0),
      items: [APIStationItem(sortOrder: 0, station: nil, urlStation: UrlStation(
        id: "koke-fm-id", name: "KOKE FM", streamUrl: "https://example.com/stream",
        imageUrl: "https://example.com/i.png", description: "desc", website: nil,
        location: "Austin, TX", active: true, createdAt: Date(), updatedAt: Date()))]
    )
    return IdentifiedArrayOf(uniqueElements: [fm])
  }

  @Test
  func testLoggedOutReturnsRequiresSignIn() async {
    @Shared(.auth) var auth = Auth()
    @Shared(.stationLists) var stationLists = makeStationLists()
    let outcome = await withDependencies {
      $0.stationPlayer = StationPlayer()
    } operation: {
      await PlayStationAction().run(stationID: "koke-fm-id")
    }
    #expect(outcome == .requiresSignIn)
  }

  @Test
  func testUnknownStationReturnsNotFound() async {
    @Shared(.auth) var auth = Auth(jwtToken: "jwt")
    @Shared(.stationLists) var stationLists = makeStationLists()
    let outcome = await withDependencies {
      $0.stationPlayer = StationPlayer()
    } operation: {
      await PlayStationAction().run(stationID: "does-not-exist")
    }
    #expect(outcome == .notFound)
  }

  @Test
  func testLoggedInValidStationPlaysAndReturnsPlaying() async {
    @Shared(.auth) var auth = Auth(jwtToken: "jwt")
    @Shared(.stationLists) var stationLists = makeStationLists()
    let player = StationPlayer()
    let outcome = await withDependencies {
      $0.stationPlayer = player
    } operation: {
      await PlayStationAction().run(stationID: "koke-fm-id")
    }
    #expect(outcome == .playing(stationName: "KOKE FM"))
    #expect(player.currentStation?.id == "koke-fm-id")
  }
}
```

- [ ] **Step 2: Run, verify failure.**

- [ ] **Step 3: Implement**

```swift
import Dependencies
import Sharing

enum PlayStationOutcome: Equatable {
  case requiresSignIn
  case notFound
  case playing(stationName: String)
}

@MainActor
struct PlayStationAction {
  @Shared(.auth) var auth
  @Dependency(\.stationPlayer) var stationPlayer

  func run(stationID: String) async -> PlayStationOutcome {
    guard auth.isLoggedIn else { return .requiresSignIn }
    guard let station = StationVoiceCatalog().station(id: stationID) else { return .notFound }
    PlaybackBootstrap().prepareForPlayback()
    await stationPlayer.play(station: station)
    return .playing(stationName: station.stationName)
  }
}
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/PlayStationAction.swift PlayolaRadio/Core/SiriIntents/PlayStationActionTests.swift
git commit -m "feat: add PlayStationAction with auth gate and playback"
```

---

## Task 6: `RadioStationEntity` + `EntityQuery`

One `AppEntity` covers both station kinds (id + display name). The query delegates entirely to `StationVoiceCatalog` so there is no second, untested matcher.

**Files:** Create `PlayolaRadio/Core/SiriIntents/RadioStationEntity.swift`

- [ ] **Step 1: Implement**

```swift
import AppIntents

struct RadioStationEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation { TypeDisplayRepresentation(name: "Station") }
  static var defaultQuery = RadioStationEntityQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct RadioStationEntityQuery: EntityQuery, EntityStringQuery {
  @MainActor
  func entities(for identifiers: [String]) async throws -> [RadioStationEntity] {
    let catalog = StationVoiceCatalog()
    return identifiers.compactMap { id in
      catalog.match(id: id).map { RadioStationEntity(id: $0.id, name: $0.label) }
    }
  }

  @MainActor
  func suggestedEntities() async throws -> [RadioStationEntity] {
    StationVoiceCatalog().suggestedStations().map { RadioStationEntity(id: $0.id, name: $0.label) }
  }

  @MainActor
  func entities(matching string: String) async throws -> [RadioStationEntity] {
    StationVoiceCatalog().matches(query: string).map { RadioStationEntity(id: $0.id, name: $0.label) }
  }
}
```

- [ ] **Step 2: Register in pbxproj (or defer to Task 9), build in Xcode.** Expected: compiles.
- [ ] **Step 3: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/RadioStationEntity.swift
git commit -m "feat: add RadioStationEntity and EntityQuery backed by StationVoiceCatalog"
```

---

## Task 7: `PlayStationIntent`

**Files:** Create `PlayolaRadio/Core/SiriIntents/PlayStationIntent.swift`

- [ ] **Step 1: Implement**

```swift
import AppIntents

struct PlayStationIntent: AppIntent {
  static var title: LocalizedStringResource = "Play Station"
  static var openAppWhenRun = true

  @Parameter(title: "Station")
  var station: RadioStationEntity

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let outcome = await PlayStationAction().run(stationID: station.id)
    switch outcome {
    case .requiresSignIn:
      return .result(dialog: "Open Playola to sign in first")
    case .notFound:
      return .result(dialog: "I couldn't find that station on Playola")
    case .playing(let name):
      return .result(dialog: "Playing \(name)")
    }
  }
}
```

- [ ] **Step 2: Build in Xcode.** Expected: compiles.
- [ ] **Step 3: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/PlayStationIntent.swift
git commit -m "feat: add PlayStationIntent delegating to PlayStationAction"
```

---

## Task 9: AppShortcuts + register all files + build

(Task 8 removed — Option B has no `IntentValueQuery`; the query lives in Task 6.)

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/PlayolaShortcuts.swift`
- Modify: `PlayolaRadio.xcodeproj/project.pbxproj`

- [ ] **Step 1: Implement the shortcuts provider**

```swift
import AppIntents

struct PlayolaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: PlayStationIntent(),
      phrases: [
        "Play \(\.$station) on \(.applicationName)",
        "Start \(\.$station) on \(.applicationName)",
      ],
      shortTitle: "Play Station",
      systemImageName: "radio"
    )
  }
}
```

- [ ] **Step 2: Register every new file in `project.pbxproj`**

Add explicit `PBXBuildFile` + `PBXFileReference` entries and a new `SiriIntents` group. In the **PlayolaRadio** target: `StationVoiceCatalog.swift`, `PlaybackBootstrap.swift`, `PlayStationAction.swift`, `RadioStationEntity.swift`, `PlayStationIntent.swift`, `PlayolaShortcuts.swift`. In the **PlayolaRadioTests** target: `StationVoiceCatalogTests.swift`, `PlayStationActionTests.swift`. Copy the four-line registration shape from an existing recently-added file (grep `project.pbxproj` for `ChooseStationToBroadcastPage.swift`).

- [ ] **Step 3: Build the whole app**

```bash
xcodebuild build -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,id=CC4A4FCF-D331-4CB2-BADC-523BD1728852' \
  -skipPackagePluginValidation 2>&1 | xcbeautify
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the new test suites**

```bash
xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,id=CC4A4FCF-D331-4CB2-BADC-523BD1728852' \
  -skipPackagePluginValidation \
  -only-testing:PlayolaRadioTests/StationVoiceCatalogTests \
  -only-testing:PlayolaRadioTests/PlayStationActionTests 2>&1 | xcbeautify
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/PlayolaShortcuts.swift PlayolaRadio.xcodeproj/project.pbxproj
git commit -m "feat: register Siri intents and add AppShortcuts phrases"
```

---

## Task 10: Device verification (manual) + adversarial review

- [ ] **Step 1:** On a device, sign in. Say "Play KOKE FM on Playola" and "Play Radney Foster's Station on Playola". Confirm the app foregrounds and the station plays.
- [ ] **Step 2:** In the Shortcuts app, confirm the "Play [Station] on Playola" shortcut appears and runs; per-station entries surface as suggestions in Spotlight/Siri Suggestions.
- [ ] **Step 3:** Sign out, invoke by voice, confirm "Open Playola to sign in first" and the app opens to sign-in.
- [ ] **Step 4:** Force-quit the app, invoke by voice, confirm audio starts (validates `PlaybackBootstrap`).
- [ ] **Step 5:** Run `/codex review` then `/codex challenge` on the branch diff. Fix anything surfaced; re-run if fixes were non-trivial.

---

## Self-review notes

- **Spec coverage:** login gate (Task 5), fuzzy match on name + curator + possessive (Task 3), fail-closed (Task 3), FM/artist labels (Task 3), custom entity/query/intent/shortcuts (Tasks 6-9), `PlaybackBootstrap` (Task 4), native no-match (Task 7 maps only the three outcomes; unmatched speech never reaches `perform()`). All covered.
- **Type consistency:** `PlayStationOutcome` (`.requiresSignIn`/`.notFound`/`.playing(stationName:)`), `StationMatch(id,label)`, and `StationVoiceCatalog.{normalize, suggestedStations, matches, match(id:), station(id:)}` are used identically across Tasks 3, 5, 6.
- **All code is concrete** — Option B uses the stable iOS 18 App Intents API, so there are no SDK-dependent skeletons. The deferred `.audio` upgrade is documented in the spec, not this plan.
