# Siri Voice Control — "Play [Station] on Playola"

**Date:** 2026-06-10
**Status:** Design approved, ready for implementation plan
**Branch:** `briankeane/siri-play-station-intent`

## Goal

Let a user start playback by voice through Siri, e.g. *"Play Bordertown Radio on
Playola"* or *"Play Radney Foster's Station on Playola"*. Match the spoken name
against the user's station list and start the matching station via the existing
`StationPlayer`.

## Decisions (locked with user)

1. **Both phrasings (within iOS limits).** One parameterized intent gives the
   reliable spoken phrase *"Play [Station] on Playola"*, plus per-station entries
   that surface as **suggestions** in the Shortcuts app, Spotlight, and Siri
   Suggestions. Bare cold phrases ("Play Bordertown Radio" with no app name) are
   **not** registered — iOS requires `\(.applicationName)` in every App Shortcut
   phrase or the phrase silently never triggers. The supported bare-phrase path is
   the user self-assigning a custom phrase to a suggestion in the Shortcuts app,
   which the entity design enables for free.
2. **Login required.** If not authenticated, Siri says *"Open Playola to sign in
   first"* and foregrounds the app (`openAppWhenRun = true`). No silent failure.
3. **Best-effort fuzzy match, no disambiguation in v1.** Match on both the
   station name and the curator/artist name. On no confident match, accept iOS's
   native "no match" behavior (Siri's own UI). A custom spoken "couldn't find
   that station" reply is deferred — it would require a separate string-parameter
   intent path.
4. **Suggested-phrase labels.** FM/URL stations → station name. Artist stations →
   "[Artist]'s Station".

## Architecture

App Intents (iOS 18) in the **main app target** — no separate extension. The
intent runs in the app process so it can reach the live `StationPlayer` (audio
session, already-initialized singleton) and `@Shared` auth/station state. Siri may
cold-launch the app to run the intent; `PlayolaRadioApp.init` runs, dependencies
initialize, and `@Shared(.auth)` / `@Shared(.stationLists)` load from their
`FileStorage` caches on access.

All real logic lives in two plain, `@MainActor`, dependency-injected,
unit-testable types. The `AppIntent` itself is a thin shell that adapts an outcome
to spoken dialog.

### New types

**`StationVoiceCatalog`** (`@MainActor` struct) — the single home for matching and
lookup. Reads `@Shared(.stationLists)`. Methods:
- `suggestedEntities() -> [StationEntity]` — current playable stations as entities.
- `entities(ids:) -> [StationEntity]` — rehydrate entities by id.
- `matches(query:) -> [StationMatch]` — normalized fuzzy match for the Shortcuts
  search field.
- `station(id:) -> AnyStation?` — resolve an id back to a real station.

Per-station aliases used for matching:
- FM/URL: `name`, `stationName`
- Artist: `curatorName`, `"[curatorName]'s Station"`, `name`

Normalization: lowercase, strip punctuation, drop possessive suffix ("'s"),
collapse whitespace, careful handling of trailing "radio"/"station" words.
Matching **fails closed** — when no candidate clears the confidence threshold,
return nothing rather than play the wrong station.

**`PlayStationAction`** (`@MainActor` struct) — auth gate + play. Holds
`@Shared(.auth)`, `@Shared(.stationLists)`, `@Dependency(\.stationPlayer)`.
`run(stationID:) async -> PlayStationOutcome` where `PlayStationOutcome` is an enum
(`.requiresSignIn`, `.notFound`, `.playing(stationName:)`). Logic:
1. Not logged in → `.requiresSignIn`.
2. `StationVoiceCatalog().station(id:)` is nil → `.notFound`.
3. Else run `PlaybackBootstrap`, call `await stationPlayer.play(station:)`,
   return `.playing`.

**`PlaybackBootstrap`** (`@MainActor` struct) — makes the currently-implicit audio
setup explicit before a Siri-triggered cold play. Sets
`AVAudioSession.sharedInstance()` category `.playback` and active, and ensures the
remote command center / now-playing wiring is live. Info.plist already declares the
`audio` background mode, so playback survives backgrounding.

### App Intents types

**`StationEntity`** — `AppEntity, Identifiable, Hashable`. Stores **ids and display
strings only** (`id`, `displayTitle`, `suggestedPhraseLabel`), never an embedded
`AnyStation` (avoids serialization / `Sendable` issues). `displayRepresentation`
uses `suggestedPhraseLabel`. `defaultQuery = StationEntityQuery()`.

**`StationEntityQuery`** — `EntityStringQuery`, `@MainActor`. Delegates to
`StationVoiceCatalog`: `entities(for:)`, `suggestedEntities()`, and
`entities(matching:)` (string search for the Shortcuts UI).

**`PlayStationIntent`** — `AppIntent`. `openAppWhenRun = true`. One
`@Parameter var station: StationEntity`. `perform()` is `@MainActor`, calls
`PlayStationAction().run(stationID:)`, maps the outcome to a `ProvidesDialog`
result.

**`PlayolaShortcuts`** — `AppShortcutsProvider`. Phrases (all include the app
name): `"Play \(\.$station) on \(.applicationName)"`,
`"Start \(\.$station) on \(.applicationName)"`.

## Data flow

1. User: *"Play Bordertown Radio on Playola"*.
2. Siri resolves the spoken station against `StationEntityQuery.entities(matching:)`
   → `StationEntity`.
3. `PlayStationIntent.perform()` → `PlayStationAction.run(stationID:)`.
4. Auth check → station lookup → `PlaybackBootstrap` → `stationPlayer.play(station:)`.
5. App foregrounds (`openAppWhenRun`), now-playing UI shows; Siri speaks
   *"Playing Bordertown Radio on Playola"*.

## Error handling

- **Logged out** → `.requiresSignIn` → dialog *"Open Playola to sign in first"*;
  app foregrounds to sign-in.
- **No matching station** (after Siri resolves to an id we can't find, or empty
  cache) → `.notFound` → dialog *"I couldn't find that station on Playola."*
- **Unresolvable speech** (Siri can't match to any entity) → iOS native no-match
  UI. Accepted for v1.
- **Empty station cache on cold launch** → `.notFound` for v1. (Possible later:
  trigger a `getStations` refresh inside the intent before failing.)

## Testing

Unit tests against the testable seam (`withDependencies` overrides, `@Shared`
declared locally per test):
- Logged out → `.requiresSignIn`; `stationPlayer.play` not called.
- Logged in + valid id → `.playing`; `stationPlayer.play` called with the right
  station.
- Unknown id → `.notFound`.
- FM station suggested label == station name.
- Artist station suggested label == "[Artist]'s Station".
- Fuzzy query matches both `name` and `curatorName` ("radney foster",
  "radney foster's station", "bordertown radio").
- Low-confidence query → no entity (fail closed).
- Empty station list → clear failure outcome.

## Out of scope (v1)

- Bare cold spoken phrases without "on Playola".
- Multi-step spoken disambiguation for ambiguous names.
- Custom spoken "couldn't find that station" for unresolvable speech (needs a
  string-parameter intent).
- In-intent `getStations` network refresh on empty cache.
- Pause/stop/next/previous voice intents (already covered by the lock-screen
  remote command center; could be added as intents later).

## Risks

1. **Bare phrases are not registered.** Setting expectations: cold "Play X" without
   "on Playola" only works if the user self-assigns it in Shortcuts.
2. **Cold-launch empty cache.** If the user never opened the app post-install, the
   station list may be empty and any play fails. v1 fails cleanly.
3. **`@MainActor` isolation.** All query/action/bootstrap code is `@MainActor`;
   never read `@Shared` from arbitrary executor contexts.
4. **Audio session must be explicit** before `stationPlayer.play` on a Siri cold
   start — that's what `PlaybackBootstrap` is for.
5. **Fuzzy threshold tuning** — too loose plays the wrong station; default to fail
   closed.
6. **`openAppWhenRun = true`** foregrounds on every play (including sign-in
   failure). Accepted tradeoff for a radio app.

## New project files (must be hand-registered in `project.pbxproj`)

- `StationVoiceCatalog.swift` (+ tests)
- `PlayStationAction.swift` (+ tests)
- `PlaybackBootstrap.swift`
- `StationEntity.swift`
- `StationEntityQuery.swift`
- `PlayStationIntent.swift`
- `PlayolaShortcuts.swift`

Exact file grouping/placement to be decided in the implementation plan.
