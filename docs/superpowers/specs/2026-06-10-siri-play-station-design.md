# Siri Voice Control — "Play [Station]"

**Date:** 2026-06-10
**Status:** Design approved, ready for implementation plan
**Branch:** `briankeane/siri-play-station-intent`

## Goal

Let a user start playback by voice through Siri, e.g. *"Play Bordertown Radio"* or
*"Play Radney Foster's Station"*. Match the spoken name against the user's station
list and start it via the existing `StationPlayer`.

## Approach: adopt Apple's `.audio` App Intents domain

WWDC 2026 made App Intents the mandatory Siri integration surface (SiriKit
formally deprecated) and the new conversational Siri routes natural language to
apps through **assistant schemas** with no fixed phrases to define. Apple ships a
first-class **`.audio`** schema domain whose entity types map onto Playola almost
exactly:

| Playola concept | `.audio` schema |
|---|---|
| Play action | **`playAudio`** intent schema (example phrase: "Play music") |
| FM / `UrlStation` (e.g. KOKE FM) | **`liveRadioStation`** entity schema |
| Artist / `PlayolaPlayer.Station` (e.g. Radney Foster) | **`algorithmicRadioStation`** entity schema |

Conforming to `playAudio` lets the new Siri play a Playola station with the **same
bare phrases** users say for any audio app ("Play Bordertown Radio" — no "on
Playola"), on Apple-Intelligence-capable devices. We **also** register classic
AppShortcuts phrases ("Play [Station] on Playola") so every other
device/context (non-AI iPhones, the Shortcuts app, CarPlay) keeps working. One
schema-conformed intent serves both paths.

### Device-capability reality

- Bare-phrase voice requires Apple Intelligence: iPhone 15 Pro / 15 Pro Max (A17
  Pro) and **all** iPhone 16 and newer. Base iPhone 15 / 15 Plus and older do not
  qualify and fall back to the "on Playola" AppShortcuts phrases.
- Install-base capability % is not reliably available from Sentry (model field is
  not indexed on the error dataset; only a ~7-user perf sample carries it). The
  authoritative source is App Store Connect → Analytics → Devices. The decision
  does not depend on the exact %: capable devices get the bonus, everyone else
  gets the fallback, and the capable share grows over time.

## Decisions (locked with user)

1. **Adopt the `.audio` schema now (Option A).** Conform the play intent to
   `playAudio`, model stations as `liveRadioStation` / `algorithmicRadioStation`
   entities, implement an `IntentValueQuery` for matching, and keep AppShortcuts
   "Play [Station] on Playola" phrases as the universal fallback.
2. **Login required.** If not authenticated, Siri says *"Open Playola to sign in
   first"* and foregrounds the app (`openAppWhenRun = true`). No silent failure.
3. **Best-effort fuzzy match, no disambiguation in v1.** Match on both station
   name and curator/artist name. On no confident match, accept the system's native
   "no match" behavior. Custom "couldn't find that station" spoken reply deferred.
4. **Suggested-phrase / entity labels.** FM/URL stations → station name. Artist
   stations → "[Artist]'s Station".

## Architecture

App Intents (iOS 18+) in the **main app target** — no separate extension. The
intent runs in the app process so it can reach the live `StationPlayer` (audio
session, already-initialized singleton) and `@Shared` auth/station state. Siri may
cold-launch the app to run the intent; `PlayolaRadioApp.init` runs, dependencies
initialize, and `@Shared(.auth)` / `@Shared(.stationLists)` load from their
`FileStorage` caches on access.

All real logic lives in plain, `@MainActor`, dependency-injected, unit-testable
types. The schema-conformed `AppIntent` and the `IntentValueQuery` are thin shells
over them.

### Testable core (no App Intents dependency — unit-testable directly)

**`StationVoiceCatalog`** (`@MainActor` struct) — single home for matching and
lookup. Reads `@Shared(.stationLists)`. Methods:
- `suggestedStations() -> [StationMatch]` — current playable stations.
- `matches(query:) -> [StationMatch]` — normalized fuzzy match for a spoken/typed
  query, used by the `IntentValueQuery` and the AppShortcuts entity search.
- `station(id:) -> AnyStation?` — resolve an id back to a real station.

Per-station match aliases:
- FM/URL: `name`, `stationName`
- Artist: `curatorName`, `"[curatorName]'s Station"`, `name`

Normalization: lowercase, strip punctuation, drop possessive "'s", collapse
whitespace, careful handling of trailing "radio"/"station". **Fails closed** — no
candidate over threshold returns nothing rather than playing the wrong station.

`StationMatch` carries the station id, the chosen display label (FM → station
name; artist → "[Artist]'s Station"), and which audio-entity kind it maps to
(`liveRadioStation` vs `algorithmicRadioStation`).

**`PlayStationAction`** (`@MainActor` struct) — auth gate + play. Holds
`@Shared(.auth)`, `@Shared(.stationLists)`, `@Dependency(\.stationPlayer)`.
`run(stationID:) async -> PlayStationOutcome` where `PlayStationOutcome` is
`.requiresSignIn`, `.notFound`, or `.playing(stationName:)`:
1. Not logged in → `.requiresSignIn`.
2. `StationVoiceCatalog().station(id:)` nil → `.notFound`.
3. Else run `PlaybackBootstrap`, `await stationPlayer.play(station:)`, `.playing`.

**`PlaybackBootstrap`** (`@MainActor` struct) — makes the currently-implicit audio
setup explicit before a Siri cold-launch play. Sets
`AVAudioSession.sharedInstance()` category `.playback` and active, ensures the
remote command / now-playing wiring is live. Info.plist already declares the
`audio` background mode, so playback survives backgrounding.

### App Intents layer (thin shells; schema shape verified against the SDK)

**Station entities** — conform to the audio entity schemas:
`@AppEntity(schema: .audio.liveRadioStation)` for FM stations and
`@AppEntity(schema: .audio.algorithmicRadioStation)` for artist stations. Store
**ids and display strings only**, never an embedded `AnyStation` (avoids
serialization / `Sendable` issues). The exact required properties of each schema
are generated by Xcode (`audio_` template) and pinned in Task 1.

**`PlayStationIntent`** — conforms to `@AppIntent(schema: .audio.playAudio)`.
`openAppWhenRun = true`. `perform()` is `@MainActor`, resolves the target
station's id, calls `PlayStationAction().run(stationID:)`, maps the outcome to a
dialog result. The `playAudio` schema's exact parameter and result contract is
pinned in Task 1.

**`StationIntentValueQuery`** — the `IntentValueQuery` (Media Intents framework)
that receives the spoken audio search/playback request and returns matching
station entities by delegating to `StationVoiceCatalog().matches(query:)`.

**`PlayolaShortcuts`** — `AppShortcutsProvider`. Fallback phrases (all include the
app name): `"Play \(\.$station) on \(.applicationName)"`,
`"Start \(\.$station) on \(.applicationName)"`.

### Availability gating

The `.audio` schema may require a higher iOS floor than the app's 18.0/18.1
deployment target (Apple shipped these domains in waves). Gate the
schema-conformed types with `@available` as needed (exact floor pinned in Task 1);
the AppShortcuts fallback covers anything below the floor.

## Data flow

1. User: *"Play Bordertown Radio"* (AI device) or *"…on Playola"* (any device).
2. Siri routes via the `playAudio` schema (AI) or the AppShortcuts phrase (classic)
   → resolves the station through `StationIntentValueQuery` →
   `StationVoiceCatalog().matches(query:)`.
3. `PlayStationIntent.perform()` → `PlayStationAction.run(stationID:)`.
4. Auth check → station lookup → `PlaybackBootstrap` → `stationPlayer.play(station:)`.
5. App foregrounds; now-playing UI shows; Siri confirms *"Playing Bordertown Radio."*

## Error handling

- **Logged out** → `.requiresSignIn` → dialog *"Open Playola to sign in first"*;
  app foregrounds to sign-in.
- **No matching station** (resolved id not in cache, or empty cache) → `.notFound`
  → dialog *"I couldn't find that station on Playola."*
- **Unresolvable speech** → system native no-match. Accepted for v1.
- **Empty station cache on cold launch** → `.notFound` for v1.

## Testing

Unit tests against the testable core (`withDependencies` overrides, `@Shared`
declared locally per test):
- Logged out → `.requiresSignIn`; `stationPlayer.play` not called.
- Logged in + valid id → `.playing`; `stationPlayer.play` called with the right
  station.
- Unknown id → `.notFound`.
- FM station label == station name; entity kind == `liveRadioStation`.
- Artist station label == "[Artist]'s Station"; entity kind ==
  `algorithmicRadioStation`.
- Fuzzy query matches both `name` and `curatorName` ("radney foster", "radney
  foster's station", "bordertown radio").
- Low-confidence query → no match (fail closed).
- Empty station list → clear failure outcome.

Where practical, also validate the intent end-to-end with the **App Intents
Testing framework** (WWDC 2026) rather than UI automation.

## Out of scope (v1)

- Multi-step spoken disambiguation for ambiguous names.
- Custom spoken "couldn't find that station" for unresolvable speech.
- In-intent `getStations` network refresh on empty cache.
- Other `.audio` schemas (`addToLibrary`, `createStation`, `recognizeAudio`,
  affinity/like) and pause/stop/next/previous voice intents (lock-screen remote
  command center already covers transport).
- Raising Sentry device indexing / traces sample rate (separate task).

## Risks / verification items

1. **Exact `playAudio` schema contract** (parameters, result type, how it hands us
   the search request) and the **macro name** (`@AppIntent(schema:)` vs the older
   `@AssistantIntent(schema:)`) must be pinned against the installed SDK in Task 1
   via Xcode's `audio_` template generation.
2. **Two entity kinds vs one** — confirm whether `playAudio` accepts both
   `liveRadioStation` and `algorithmicRadioStation` from one query/result, or needs
   separate handling.
3. **iOS availability floor** of the `.audio` schema vs the 18.0 deployment target;
   gate with `@available`, fallback covers the rest.
4. **Cold-launch empty cache** — fails cleanly in v1.
5. **`@MainActor` isolation** — all catalog/action/bootstrap/query code is
   `@MainActor`; never read `@Shared` from arbitrary executor contexts.
6. **Audio session must be explicit** before `stationPlayer.play` on a Siri cold
   start — that is `PlaybackBootstrap`.
7. **Fuzzy threshold** — too loose plays the wrong station; default fail-closed.
8. **`openAppWhenRun = true`** foregrounds on every play; accepted for a radio app.

## New project files (must be hand-registered in `project.pbxproj`)

- `StationVoiceCatalog.swift` (+ tests)
- `PlayStationAction.swift` (+ tests)
- `PlaybackBootstrap.swift`
- `StationAudioEntities.swift` (the `liveRadioStation` / `algorithmicRadioStation`
  entities)
- `StationIntentValueQuery.swift`
- `PlayStationIntent.swift`
- `PlayolaShortcuts.swift`

Exact file grouping/placement decided in the implementation plan.
