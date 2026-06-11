# Siri "Play [Station]" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Before writing any Swift, invoke the relevant `pfw-*` skills (pfw-dependencies, pfw-sharing, pfw-observable-models, pfw-testing, pfw-custom-dump, pfw-case-paths).

**Goal:** Let a user start a Playola station by voice through Siri ("Play Bordertown Radio", "Play Radney Foster's Station").

**Architecture:** App Intents in the main app target. A testable `@MainActor` core (`StationVoiceCatalog` matching, `PlayStationAction` auth+play, `PlaybackBootstrap` audio session) does all real work. Thin App Intents shells conform to Apple's `.audio` schema (`playAudio` intent, `liveRadioStation` / `algorithmicRadioStation` entities, an `IntentValueQuery` for matching) so the new Siri plays stations with bare phrases, plus an `AppShortcutsProvider` registering "Play [Station] on Playola" as the universal fallback.

**Tech Stack:** Swift, App Intents (iOS 18+, `.audio` schema domain), swift-dependencies, swift-sharing, Swift Testing (`import Testing`).

**Spec:** `docs/superpowers/specs/2026-06-10-siri-play-station-design.md`

---

## Conventions for every task

- **Tests:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@MainActor struct XxxTests`), colocated next to the file under test. For value comparisons prefer custom-dump's `expectNoDifference` (pfw-custom-dump).
- **`@Shared` in tests:** declare locally per test, e.g. `@Shared(.auth) var auth = Auth(jwtToken: "test-jwt")`. Never class-level.
- **New files MUST be hand-registered in `PlayolaRadio.xcodeproj/project.pbxproj`** (explicit file refs — this project does not use synced folders). Task 9 does this in one batch; until then new files won't compile in Xcode. If a per-task build is needed sooner, register the file as you add it.
- **Run tests (CLI):**
  ```bash
  xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
    -destination 'platform=iOS Simulator,id=CC4A4FCF-D331-4CB2-BADC-523BD1728852' \
    -skipPackagePluginValidation \
    -only-testing:PlayolaRadioTests/<TestStructName> 2>&1 | xcbeautify
  ```
  (Booted sim id above is `iPhone 15`; substitute any booted simulator. `-skipPackagePluginValidation` is required or the SwiftLint build plugin fails the run. The user may also run in Xcode.)
- **New code lives in** `PlayolaRadio/Core/SiriIntents/` (create the group). Tests colocated in the same folder.

---

## Task 1: Spike — pin the `.audio` schema API against the installed SDK

The `.audio` App Intents schema shipped with WWDC 2026 and its exact Swift signatures are only knowable from the SDK in Xcode 26.5. This task produces a notes file that later tasks consume. **No production code ships from this task.**

**Files:**
- Create: `docs/superpowers/specs/audio-schema-notes.md` (scratch notes, not shipped to users)

- [ ] **Step 1: Generate the schema templates in Xcode**

In Xcode, create a throwaway Swift file and type each of these, accepting Xcode's autocomplete template expansion:
- `audio_playAudio` → expands the `playAudio` intent template
- `audio_liveRadioStation` → expands the live-radio-station entity template
- `audio_algorithmicRadioStation` → expands the algorithmic-radio-station entity template

- [ ] **Step 2: Record the exact API into the notes file**

Capture, verbatim from the generated templates:
1. The macro name actually used (`@AppIntent(schema:)` vs `@AssistantIntent(schema:)`) and the module to `import` (e.g. `AppIntents`, and whether `MediaIntents` / Media Intents framework must be imported).
2. The `playAudio` intent's required properties (parameter name(s) and types for the target audio item / search, e.g. an entity parameter or a `MediaSearch`-style value) and its `perform()` return type.
3. The required properties of the `liveRadioStation` and `algorithmicRadioStation` entity schemas (which properties are mandatory: id, title/name, etc.).
4. The query type the intent expects for resolving its audio parameter (the `IntentValueQuery` / Media Intents query protocol name and its associated `Value` / method signatures).
5. The `@available` annotation Xcode attaches (the iOS floor — e.g. `iOS 18.4` or `iOS 26`). Record it exactly.
6. Whether one intent/query can return BOTH entity kinds, or whether the schema forces a single entity type (decides Task 6/7 shape).

- [ ] **Step 3: Delete the throwaway file. Commit the notes.**

```bash
git add docs/superpowers/specs/audio-schema-notes.md
git commit -m "docs: pin .audio App Intents schema API from SDK"
```

**Gate:** Later tasks reference `audio-schema-notes.md` for every place this plan says "(per Task 1 notes)". If Step 1 reveals the `.audio` schema is unavailable in this SDK or its floor is unacceptable, STOP and revisit the spec (fallback: ship the custom-intent + AppShortcuts path only, dropping schema conformance — the testable core in Tasks 2-5 is unchanged).

---

## Task 2: `StationMatch` value type + name normalization

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift`
- Test: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift`

- [ ] **Step 1: Write the failing test for normalization**

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

- [ ] **Step 2: Run it, verify it fails**

Run the test command with `-only-testing:PlayolaRadioTests/StationVoiceCatalogTests`. Expected: FAIL (no `StationVoiceCatalog`).

- [ ] **Step 3: Implement `StationMatch` and `normalize`**

```swift
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing

/// The entity kind a station maps to in Apple's `.audio` schema domain.
enum StationEntityKind: Equatable {
  case liveRadioStation       // UrlStation / FM
  case algorithmicRadioStation  // PlayolaPlayer.Station / artist
}

/// A station resolved from a spoken/typed query, with the label and entity kind
/// the App Intents layer needs.
struct StationMatch: Equatable, Identifiable {
  let id: String          // AnyStation.id
  let label: String       // FM: station name; Artist: "[Artist]'s Station"
  let kind: StationEntityKind
}

@MainActor
struct StationVoiceCatalog {
  @Shared(.stationLists) var stationLists

  /// Lowercase, strip possessive "'s", strip punctuation, drop the filler words
  /// "radio"/"station", collapse whitespace. Used on both station aliases and the
  /// incoming query so matching is symmetric.
  static func normalize(_ raw: String) -> String {
    var s = raw.lowercased()
    s = s.replacingOccurrences(of: "'s", with: "")
    s = s.replacingOccurrences(of: "\u{2019}s", with: "")  // curly apostrophe
    let allowed = CharacterSet.alphanumerics.union(.whitespaces)
    s = String(s.unicodeScalars.filter { allowed.contains($0) })
    let filler: Set<String> = ["radio", "station"]
    let words = s.split(whereSeparator: { $0 == " " }).map(String.init).filter { !filler.contains($0) }
    return words.joined(separator: " ")
  }
}
```

- [ ] **Step 4: Run the test, verify it passes**

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift
git commit -m "feat: add StationMatch and station name normalization"
```

---

## Task 3: `StationVoiceCatalog` aliases, suggestions, and lookup

`AnyStation.name` returns the curator name for artist stations and the station name for FM stations; `AnyStation.stationName` returns the underlying station name for both. Aliases per station:
- FM (`.url`): `name` (= station name)
- Artist (`.playola`): `name` (= curatorName), `"[curatorName]'s Station"`, `stationName`

**Files:**
- Modify: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalog.swift`
- Test: `PlayolaRadio/Core/SiriIntents/StationVoiceCatalogTests.swift`

- [ ] **Step 1: Write failing tests for suggestions, labels, and matching**

```swift
@Test
func testSuggestedStationsLabelsAndKinds() {
  @Shared(.stationLists) var stationLists = StationList.mocks

  let catalog = StationVoiceCatalog()
  let suggestions = catalog.suggestedStations()

  // FM station label is the station name; kind is liveRadioStation.
  let koke = suggestions.first { $0.id == "koke-fm-id" }
  #expect(koke?.label == "KOKE FM")
  #expect(koke?.kind == .liveRadioStation)
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
  #expect(match?.kind == .algorithmicRadioStation)
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
func testStationByIdReturnsAnyStation() {
  @Shared(.stationLists) var stationLists = StationList.mocks
  #expect(StationVoiceCatalog().station(id: "koke-fm-id")?.id == "koke-fm-id")
  #expect(StationVoiceCatalog().station(id: "nonexistent") == nil)
}
```

- [ ] **Step 2: Run, verify failure** (missing `suggestedStations`, `matches`, `station(id:)`).

- [ ] **Step 3: Implement the methods**

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
    let score = bestScore(for: station, needle: needle)
    guard let score, score > 0 else { return nil }
    return (makeMatch(for: station), score)
  }
  .sorted { $0.1 > $1.1 }
  .map(\.0)
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
  case .url(let s):
    return [s.name]
  case .playola(let s):
    return [s.curatorName, "\(s.curatorName)'s Station", s.name]
  }
}

private func label(for station: AnyStation) -> String {
  switch station {
  case .url(let s): return s.name
  case .playola(let s): return "\(s.curatorName)'s Station"
  }
}

private func kind(for station: AnyStation) -> StationEntityKind {
  station.isPlayolaStation ? .algorithmicRadioStation : .liveRadioStation
}

private func makeMatch(for station: AnyStation) -> StationMatch {
  StationMatch(id: station.id, label: label(for: station), kind: kind(for: station))
}

/// Confidence score: exact normalized alias match beats prefix beats contains.
/// Returns nil when no alias relates to the needle (fail closed).
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

Makes the implicit audio-session setup explicit before a Siri cold-launch play. Kept thin; the system `AVAudioSession` is not unit-tested (verified manually on device in Task 10).

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/PlaybackBootstrap.swift`

- [ ] **Step 1: Implement**

```swift
import AVFoundation
import Dependencies

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

- [ ] **Step 2: Build to confirm it compiles** (register in pbxproj now or defer to Task 9; if deferring, this builds in Task 9's batch).

- [ ] **Step 3: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/PlaybackBootstrap.swift
git commit -m "feat: add PlaybackBootstrap for explicit audio session setup"
```

---

## Task 5: `PlayStationAction` — auth gate + lookup + play

`StationPlayer.play(station:)` synchronously sets `state` to `.loading(station)` before any await, so `stationPlayer.currentStation` reflects the requested station immediately — tests assert on that without a mock. Use a URL station in the "plays" test to avoid the network path the playola branch takes.

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
    @Shared(.auth) var auth = Auth()                     // jwt nil → logged out
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

Note: `station.stationName` yields the human station name for both kinds ("KOKE FM", "Bordertown Radio").

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/PlayStationAction.swift PlayolaRadio/Core/SiriIntents/PlayStationActionTests.swift
git commit -m "feat: add PlayStationAction with auth gate and playback"
```

---

## Task 6: Station audio entities (`.audio` schema conformance)

Uses the exact API pinned in Task 1's `audio-schema-notes.md`. The shape below is the expected structure; **substitute the precise macro name, required properties, and `@available` floor from the notes.** Entities store ids + display strings only.

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/StationAudioEntities.swift`

- [ ] **Step 1: Implement the two entities per Task 1 notes**

Skeleton (fill required members from the generated template):

```swift
import AppIntents
// import MediaIntents   // only if Task 1 notes require it

// Substitute @available floor from Task 1 notes (e.g. @available(iOS 18.4, *)).
@available(iOS 18.4, *)
@AppEntity(schema: .audio.liveRadioStation)   // macro name per Task 1 notes
struct LiveRadioStationEntity {
  let id: String
  // Required schema properties (name/title, etc.) per Task 1 notes:
  let title: String
}

@available(iOS 18.4, *)
@AppEntity(schema: .audio.algorithmicRadioStation)
struct AlgorithmicRadioStationEntity {
  let id: String
  let title: String
}
```

- [ ] **Step 2: Add a bridge from `StationMatch` to the entity types**

```swift
@available(iOS 18.4, *)
extension StationMatch {
  // Returns the schema-correct entity for this match's kind.
  // Exact entity initializer args follow Task 1 notes.
  func makeAudioEntity() -> any AppEntity {
    switch kind {
    case .liveRadioStation:
      return LiveRadioStationEntity(id: id, title: label)
    case .algorithmicRadioStation:
      return AlgorithmicRadioStationEntity(id: id, title: label)
    }
  }
}
```

- [ ] **Step 3: Build in Xcode.** Resolve any schema-conformance compiler errors by matching the generated template exactly. Expected: compiles. Commit.

```bash
git add PlayolaRadio/Core/SiriIntents/StationAudioEntities.swift
git commit -m "feat: add .audio schema station entities"
```

> If Task 1 found the schema forces a single entity type (not two), collapse to one entity that carries the kind internally, and update Tasks 7-8 accordingly. Note the deviation in the commit message.

---

## Task 7: `PlayStationIntent` (schema-conformed)

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/PlayStationIntent.swift`

- [ ] **Step 1: Implement the intent per Task 1 notes**

```swift
import AppIntents

@available(iOS 18.4, *)
@AppIntent(schema: .audio.playAudio)   // macro + schema per Task 1 notes
struct PlayStationIntent {
  static let openAppWhenRun = true

  // The parameter(s) the playAudio schema requires (the resolved audio target /
  // search) — names and types per Task 1 notes. Example placeholder:
  @Parameter(title: "Station")
  var target: LiveRadioStationEntity   // or the schema's required parameter type

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let outcome = await PlayStationAction().run(stationID: target.id)
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

> The exact parameter wiring (single entity vs `MediaSearch` resolved via the query in Task 8) comes from Task 1. The constant fact this plan guarantees: `perform()` delegates to `PlayStationAction().run(stationID:)` and maps the three outcomes to dialog. Keep `perform()` a thin shell.

- [ ] **Step 2: Build in Xcode.** Match the `playAudio` template's required members until it compiles. Commit.

```bash
git add PlayolaRadio/Core/SiriIntents/PlayStationIntent.swift
git commit -m "feat: add PlayStationIntent conforming to .audio.playAudio"
```

---

## Task 8: `StationIntentValueQuery` — resolve spoken request to entities

The `.audio` `playAudio` flow resolves its audio parameter through a Media Intents query (the `IntentValueQuery`-family protocol named in Task 1). It receives the spoken search and returns matching station entities by delegating to `StationVoiceCatalog`.

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/StationIntentValueQuery.swift`

- [ ] **Step 1: Implement per Task 1 notes**

```swift
import AppIntents

@available(iOS 18.4, *)
struct StationIntentValueQuery: /* IntentValueQuery / Media Intents query protocol per Task 1 */ {
  @MainActor
  func values(for input: /* MediaSearch-style type per Task 1 */) async throws -> [any AppEntity] {
    // Extract the spoken string from `input` (field name per Task 1 notes),
    // run it through the matcher, and map to schema entities.
    let query = /* input.<spoken term> */ ""
    return StationVoiceCatalog().matches(query: query).map { $0.makeAudioEntity() }
  }
}
```

- [ ] **Step 2: Wire the query to the intent's parameter** as the generated template specifies (e.g. `@Parameter(query:)` or the schema's resolution hook). Build until it compiles.

- [ ] **Step 3: Commit**

```bash
git add PlayolaRadio/Core/SiriIntents/StationIntentValueQuery.swift PlayolaRadio/Core/SiriIntents/PlayStationIntent.swift
git commit -m "feat: resolve spoken station via StationVoiceCatalog in IntentValueQuery"
```

> The matching logic is already tested in Task 3. This task is glue: confirm `matches(query:)` is the only matching path, so there is no second, untested matcher.

---

## Task 9: AppShortcuts fallback + register all files + build

**Files:**
- Create: `PlayolaRadio/Core/SiriIntents/PlayolaShortcuts.swift`
- Modify: `PlayolaRadio.xcodeproj/project.pbxproj`

- [ ] **Step 1: Implement the fallback shortcuts provider**

For the AppShortcuts phrase path, the parameter must be a station entity the user can pick. If Task 1 shows `PlayStationIntent`'s parameter is not a plain pickable entity (e.g. it's a `MediaSearch`), add a small companion `AppIntent` (`PlayStationByNameIntent`) that takes a single `StationEntity` parameter backed by an `EntityQuery` (delegating to `StationVoiceCatalog`) and calls the same `PlayStationAction`. Use that companion here. Otherwise point the shortcut at `PlayStationIntent` directly.

```swift
import AppIntents

struct PlayolaShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: PlayStationByNameIntent(),   // or PlayStationIntent(), per Task 1
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

If a companion intent + `StationEntity` (`@AppEntity` with an `EntityQuery` whose `entities(matching:)`/`suggestedEntities()` call `StationVoiceCatalog`) is needed, create it in this file. Its `perform()` also delegates to `PlayStationAction().run(stationID:)`.

- [ ] **Step 2: Register every new file in `project.pbxproj`**

Add explicit `PBXBuildFile` + `PBXFileReference` entries (and group membership under a new `SiriIntents` group) for, in the `PlayolaRadio` target:
- `StationVoiceCatalog.swift`, `PlaybackBootstrap.swift`, `PlayStationAction.swift`, `StationAudioEntities.swift`, `PlayStationIntent.swift`, `StationIntentValueQuery.swift`, `PlayolaShortcuts.swift`

And in the `PlayolaRadioTests` target:
- `StationVoiceCatalogTests.swift`, `PlayStationActionTests.swift`

Mirror the pattern of an existing recently-added file (grep `project.pbxproj` for `ChooseStationToBroadcastPage.swift` to copy the four-line registration shape).

- [ ] **Step 3: Build the whole app**

```bash
xcodebuild build -project PlayolaRadio.xcodeproj -scheme PlayolaRadio \
  -destination 'platform=iOS Simulator,id=CC4A4FCF-D331-4CB2-BADC-523BD1728852' \
  -skipPackagePluginValidation 2>&1 | xcbeautify
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the full new test suite**

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
git commit -m "feat: register Siri intents and add AppShortcuts fallback phrases"
```

---

## Task 10: Device verification (manual) + adversarial review

App Intents voice behavior cannot be verified in the simulator's unit tests; it needs a real device and Siri.

- [ ] **Step 1: Run on an Apple-Intelligence device** (iPhone 15 Pro+ / 16+). Sign in. Say "Play Bordertown Radio" (bare). Confirm the app foregrounds and the station plays. Say a station that doesn't exist; confirm graceful behavior.
- [ ] **Step 2: Test the fallback.** In the Shortcuts app (or a non-AI device), confirm "Play [Station] on Playola" appears and runs. Confirm per-station suggestions show in Spotlight/Siri Suggestions.
- [ ] **Step 3: Logged-out path.** Sign out, invoke by voice, confirm "Open Playola to sign in first" and the app opens to sign-in.
- [ ] **Step 4: Cold launch.** Force-quit the app, invoke by voice, confirm audio starts (validates `PlaybackBootstrap`).
- [ ] **Step 5: Adversarial review (Codex).** Run `/codex review` then `/codex challenge` on the branch diff. Fix anything surfaced; re-run if fixes were non-trivial.
- [ ] **Step 6:** Delete `docs/superpowers/specs/audio-schema-notes.md` if it was scratch-only, or fold any durable API facts into the spec. Commit.

---

## Self-review notes

- **Spec coverage:** login gate (Task 5), fuzzy match on name + curator (Task 3), fail-closed (Task 3), FM/artist labels + entity kinds (Task 3), `.audio` schema conformance (Tasks 6-8), AppShortcuts fallback (Task 9), `PlaybackBootstrap` (Task 4), availability gating (Tasks 6-8 `@available`), native no-match (Task 7 maps only the three outcomes; unmatched speech never reaches `perform()`). All covered.
- **Type consistency:** `PlayStationOutcome` (`.requiresSignIn` / `.notFound` / `.playing(stationName:)`), `StationMatch(id/label/kind)`, `StationEntityKind`, and `StationVoiceCatalog.{normalize, suggestedStations, matches, station(id:)}` are used identically across Tasks 3, 5, 6, 8.
- **Known SDK-dependent gaps (by design):** Tasks 6-8 carry skeletons because the `.audio` schema's exact Swift signatures ship in the SDK and are pinned by Task 1, not guessable beforehand. Every such spot says "per Task 1 notes." This is deliberate, not a placeholder for missing thinking — the testable core (Tasks 2-5) is fully specified.
