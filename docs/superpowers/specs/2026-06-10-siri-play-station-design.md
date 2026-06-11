# Siri Voice Control — "Play [Station]"

**Date:** 2026-06-10
**Status:** Design approved (Option B), executing
**Branch:** `briankeane/siri-play-station-intent`

## Goal

Let a user start playback by voice through Siri, e.g. *"Play Bordertown Radio on
Playola"* / *"Play Radney Foster's Station on Playola"*. Match the spoken name
against the user's station list and start it via the existing `StationPlayer`.

## Approach: custom App Intents now, `.audio` schema deferred

WWDC 2026 made App Intents the mandatory Siri surface (SiriKit deprecated) and
introduced a first-class `.audio` schema domain (`playAudio` intent;
`liveRadioStation` / `algorithmicRadioStation` entities) that would let the new
Siri play stations with bare phrases. **However, a Task 1 SDK spike found that
`.audio` is not yet in the installed Xcode 26.5 SDK, and its `IntentValueQuery`
mechanism is iOS 26.0-only — above the app's iOS 18 deployment target.** Apple's
docs are ahead of the shipping tooling. See `audio-schema-notes.md`.

**Decision: ship a custom (non-schema) App Intent now**, compatible with iOS 18
and the whole user base. Re-skin to the `.audio` schema as a fast-follow once it
ships in a release Xcode and iOS 26 adoption grows. The tested core
(`StationVoiceCatalog`, `PlayStationAction`, `PlaybackBootstrap`) is identical
between the two approaches, so the later upgrade is cheap.

### Phrase reality (custom approach)

Every App Shortcut phrase must contain `\(.applicationName)` or it silently never
triggers. So the reliable spoken phrase is **"Play [Station] on Playola"**. Bare
"Play [Station]" is not registered; it surfaces as a **suggestion** (Shortcuts
app, Spotlight, Siri Suggestions) the user can tap or self-assign a custom phrase
to. (The bare-phrase-without-setup experience needs the deferred `.audio` schema.)

## Decisions (locked with user)

1. **Custom App Intent (Option B).** A `PlayStationIntent` (`AppIntent`) with a
   single `RadioStationEntity` parameter backed by an `EntityQuery`, plus an
   `AppShortcutsProvider` registering "Play [Station] on Playola". No schema
   conformance, no `IntentValueQuery`.
2. **Login required.** If not authenticated, Siri says *"Open Playola to sign in
   first"* and foregrounds the app (`openAppWhenRun = true`). No silent failure.
3. **Best-effort fuzzy match, no disambiguation in v1.** Match on both station
   name and curator/artist name. No confident match → native no-match behavior.
4. **Entity / suggestion labels.** FM/URL stations → station name. Artist
   stations → "[Artist]'s Station".

## Architecture

App Intents (iOS 18) in the **main app target** — no extension. The intent runs in
the app process so it reaches the live `StationPlayer` and `@Shared` auth/station
state. Siri may cold-launch the app; `PlayolaRadioApp.init` runs, dependencies
init, and `@Shared(.auth)` / `@Shared(.stationLists)` load from `FileStorage`.

All real logic lives in plain, `@MainActor`, dependency-injected, unit-testable
types. The `AppEntity`, `EntityQuery`, and `AppIntent` are thin shells over them.

### Testable core (no App Intents dependency)

**`StationVoiceCatalog`** (`@MainActor` struct) — matching and lookup over
`@Shared(.stationLists)`:
- `suggestedStations() -> [StationMatch]` — current playable stations.
- `matches(query:) -> [StationMatch]` — normalized fuzzy match, used by the
  entity query.
- `match(id:) -> StationMatch?` — id → match (for `entities(for:)`).
- `station(id:) -> AnyStation?` — id → real station for playback.

`StationMatch` carries `id` and a display `label` (FM → station name; artist →
"[Artist]'s Station"). Match aliases: FM → `name`; artist → `curatorName`,
`"[curatorName]'s Station"`, `stationName`. Normalize: lowercase, strip
possessive, strip punctuation, drop "radio"/"station" filler, collapse
whitespace. **Fails closed.**

**`PlayStationAction`** (`@MainActor` struct) — auth gate + play. Holds
`@Shared(.auth)`, `@Dependency(\.stationPlayer)`.
`run(stationID:) async -> PlayStationOutcome` (`.requiresSignIn` / `.notFound` /
`.playing(stationName:)`): logged out → `.requiresSignIn`; unknown id →
`.notFound`; else `PlaybackBootstrap` then `await stationPlayer.play(station:)`.

**`PlaybackBootstrap`** (`@MainActor` struct) — explicit `AVAudioSession`
`.playback` activation before a Siri cold-launch play. Info.plist already declares
the `audio` background mode.

### App Intents layer (thin shells)

- **`RadioStationEntity`** — `AppEntity` with `id` + `name`, `defaultQuery =
  RadioStationEntityQuery()`. One entity covers both station kinds.
- **`RadioStationEntityQuery`** — `EntityQuery` + `EntityStringQuery`;
  `entities(for:)`, `suggestedEntities()`, `entities(matching:)` delegate to
  `StationVoiceCatalog`.
- **`PlayStationIntent`** — `AppIntent`, `openAppWhenRun = true`, one
  `@Parameter var station: RadioStationEntity`; `perform()` calls
  `PlayStationAction` and maps the outcome to a dialog.
- **`PlayolaShortcuts`** — `AppShortcutsProvider`; phrases
  `"Play \(\.$station) on \(.applicationName)"`,
  `"Start \(\.$station) on \(.applicationName)"`.

## Data flow

1. User: *"Play Bordertown Radio on Playola"*.
2. Siri resolves the spoken station via `RadioStationEntityQuery.entities(matching:)`
   → `StationVoiceCatalog().matches(query:)` → `RadioStationEntity`.
3. `PlayStationIntent.perform()` → `PlayStationAction.run(stationID:)`.
4. Auth → lookup → `PlaybackBootstrap` → `stationPlayer.play(station:)`.
5. App foregrounds; now-playing shows; Siri confirms *"Playing Bordertown Radio."*

## Error handling

- **Logged out** → `.requiresSignIn` → *"Open Playola to sign in first"*; foreground sign-in.
- **No matching station** (resolved id not in cache / empty cache) → `.notFound` →
  *"I couldn't find that station on Playola."*
- **Unresolvable speech** → system native no-match. Accepted for v1.

## Testing

Unit tests against the testable core (`withDependencies`, local `@Shared`):
logged-out → `.requiresSignIn` (no play); valid id → `.playing` + play called;
unknown id → `.notFound`; FM label == station name; artist label ==
"[Artist]'s Station"; fuzzy matches name + curator + possessive; low-confidence →
no match (fail closed); empty list → clear failure.

## Out of scope (v1)

- `.audio` schema conformance / bare-phrase-without-setup (deferred fast-follow).
- Multi-step disambiguation; custom dialog for unresolvable speech; in-intent
  `getStations` refresh; other audio intents (pause/stop/next handled by the
  existing lock-screen remote command center).
- Sentry device indexing / traces sample-rate bump (separate task).

## Risks

1. **Bare phrases need "on Playola"** (set expectations); bare-without-setup awaits
   the deferred `.audio` upgrade.
2. **Cold-launch empty cache** → fails cleanly in v1.
3. **`@MainActor` isolation** — all catalog/action/bootstrap/query code is
   `@MainActor`.
4. **Explicit audio session** before play on cold start (`PlaybackBootstrap`).
5. **Fuzzy threshold** — fail closed.
6. **`openAppWhenRun = true`** foregrounds every play; accepted for a radio app.

## New project files (hand-register in `project.pbxproj`)

- `StationVoiceCatalog.swift` (+ tests)
- `PlayStationAction.swift` (+ tests)
- `PlaybackBootstrap.swift`
- `RadioStationEntity.swift` (entity + query)
- `PlayStationIntent.swift`
- `PlayolaShortcuts.swift`

## Deferred: `.audio` schema upgrade (future)

When `.audio` ships in a release Xcode and iOS 26 adoption is meaningful: conform
`PlayStationIntent` → `.audio.playAudio`, model stations as `liveRadioStation` /
`algorithmicRadioStation`, replace the entity query with the Media Intents
`IntentValueQuery` (delegating to the same `StationVoiceCatalog`), gated by
`@available`. The tested core is unchanged. See `audio-schema-notes.md`.
