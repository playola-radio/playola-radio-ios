# Resume Last Station (Lock Screen + Car) — Design

**Date:** 2026-08-27
**Branch:** `briankeane/lock-screen-resume-last-station`
**Status:** Approved, ready for implementation

## Problem

Two linked issues, one root cause and one shared foundation.

1. **Bug — lock-screen play button dies after Stop.** When the user hits Stop,
   `StationPlayer.stop()` sets state to `.stopped` and drops `currentStation` to
   `nil`. That triggers `NowPlayingUpdater.clearNowPlayingInfo()`, which nils
   `MPNowPlayingInfoCenter.nowPlayingInfo`. iOS then greys out / disables the
   lock-screen play button because there is no current item behind it. Separately,
   a 15-minute inactivity timer calls `releaseRemoteControlCenter()`, which removes
   all command targets and calls `endReceivingRemoteControlEvents()`. The play
   command already has a fallback to restart `lastPlayedStation`, but that value is
   held only in memory (lost on relaunch) and the button looks dead because the info
   was cleared.

2. **Feature — resume last station in the car, like Apple Music.** Apple Music is
   not doing proprietary car detection. It stays the system's Now Playing app (valid
   `nowPlayingInfo` + live play command) while stopped/paused; when the car connects
   it emits a play command over CarPlay / Bluetooth AVRCP, and Apple Music resumes
   via `MPRemoteCommandCenter`. The correct third-party approach is the same: keep a
   valid Now Playing entry + live play command + a durably persisted last station, so
   the car's play command restarts it. No route-sniffing, no CarPlay auto-play.

## Scope

- Targets the **Playola / AirPlay-2 (`playolaStationPlayer`) path only.** The legacy
  `urlStreamPlayer` backend is being abandoned and is not touched. We persist and
  resume **only `.playola` stations**.

## Accepted limitation

If iOS has fully terminated the app (user force-quit, or memory jettison), the car
cannot relaunch a third-party app, so resume will not fire. Suspended / backgrounded
/ alive / foreground-launched cases all work. This is the same boundary every
non-system audio app hits; Apple Music beats it only because it is a system app.

## Research finding that shapes the fix (iOS behavior)

`MPNowPlayingInfoCenter.playbackState` is effectively **macOS-only**. On iOS the
system infers the lock-screen play-vs-pause button from **`AVAudioSession`
active/inactive** state plus **`MPNowPlayingInfoPropertyPlaybackRate`**, not from the
`playbackState` enum. Therefore the button renders as a functional **Play** (resume)
after Stop only when all three hold:

1. `nowPlayingInfo` stays populated (non-nil).
2. `AVAudioSession` is inactive (already true — we release the session on Stop).
3. `MPNowPlayingInfoPropertyPlaybackRate = 0.0`.

Consequence: setting the playback rate to **0.0 on stop is mandatory**, not cosmetic.
The current code sets rate `1.0` for `.stopped`, which can make iOS show the wrong
(pause) button even with info populated. We still set `playbackState = .paused`
because CarPlay's `CPNowPlayingTemplate` and macOS do honor it (belt-and-suspenders),
but the enum choice is low-risk either way.

Sources:
- https://developer.apple.com/documentation/mediaplayer/mpnowplayingplaybackstate
- https://developer.apple.com/forums/thread/773870
- https://developer.apple.com/forums/thread/779533
- https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter

**Device-verify:** after a cold-but-alive launch (app alive, never played this
session), confirm on the truck that the car/lock-screen button shows Play and tapping
it resumes. One unresolved Apple thread reports a stale Pause icon on fresh restore
until the app backgrounds once; if we hit that, add a background-transition refresh.

## Design

### 1. Durable last-played station (new)

```swift
struct LastPlayedStation: Codable, Equatable, Sendable {
  var station: AnyStation
  var persistedAt: Date
}
```

- Persisted via **`.fileStorage`** (JSON file in the documents directory), NOT
  `.appStorage`. `appStorage` is for scalar prefs; structured Codable models belong
  in file storage, matching existing repo patterns.
- Store the **full station snapshot**, not just an id. When the car's play command
  arrives at launch, `@Shared(.stationLists)` may not be fetched yet; the snapshot
  lets us resume with zero network.
- On resume: prefer re-resolving the snapshot's id against `@Shared(.stationLists)`
  if it is loaded (fresher metadata / active check); fall back to the snapshot if the
  list is not available. Only refuse resume when lists are loaded AND the station is
  provably inactive/removed.

New shared key in `SharedUserDefaults.swift`:

```swift
extension SharedKey where Self == FileStorageKey<LastPlayedStation?>.Default {
  static var lastPlayedStation: Self {
    Self[.fileStorage(.documentsDirectory.appending(component: "last-played-station.json")), default: nil]
  }
}
```

### 2. When to persist

- Written on **accepted user intent** inside `StationPlayer.play(station:)`, before it
  stops the previous station — NOT on `.playing`. Writing on `.playing` is too late:
  a user could select a station, buffering starts, then they hit a dead zone, and the
  snapshot would be lost.
- **Only for `.playola` stations.** URL/legacy stations never overwrite the snapshot.

### 3. Keep the Now Playing entry alive after Stop

- Stop nilling `nowPlayingInfo` on stop. After Stop, keep the entry populated from
  the last station's title / artist / artwork, presented as **`.paused`** with
  **`MPNowPlayingInfoPropertyPlaybackRate = 0.0`**.
- The app's own `StationPlayer` state stays honestly `.stopped`. Resumability lives in
  the separate durable snapshot, NOT by forcing `currentStation` to stay non-nil
  (that would poison UI, analytics, CarPlay transitions, and seek logic).
- `setPlaybackRate`: use `0.0` for both `.paused` and `.stopped`.
- **Drop the 15-minute inactivity teardown** for ordinary stop. It is the thing that
  kills resumability and is not load-bearing for correctness (the expensive resource
  is the audio session, which we already release on Stop; keeping metadata + command
  handlers registered costs nothing meaningful). Reserve `releaseRemoteControlCenter()`
  for a real teardown event only — **sign-out**.

### 4. Play command is the single resume path

- Extract `handlePlayCommand() -> MPRemoteCommandHandlerStatus` for testability; the
  registered `playCommand` target just calls it.
- Logic: if `.paused` → resume; else restart the durably persisted Playola station
  (resolved via list, fallback to snapshot). Return `.commandFailed` only when there
  is genuinely no persisted station.
- On `NowPlayingUpdater` init (app launch), repopulate the Now Playing entry from the
  persisted snapshot so a cold-but-alive app is car-resumable before the user touches
  anything.
- Resume MUST go through `StationPlayer.play(station:)`, because that path activates
  `AVAudioSession` first and selects `.longFormAudio`. Do NOT activate the audio
  session merely to remain resumable while stopped.
- **No** CarPlay `didConnect` auto-play and **no** positive route-change detection.
  The car's own play command is the trigger.

### 5. Sign-out clears the snapshot

Clear `@Shared(.lastPlayedStation)` on sign-out (station content is account-scoped).
Also run `releaseRemoteControlCenter()` at sign-out as the real teardown event.

## Background execution requirements (reality check)

- `UIBackgroundModes` includes `audio` — already present in `Info.plist`.
- Registered `MPRemoteCommandCenter` handlers — kept alive after Stop by this design.
- Populated `MPNowPlayingInfoCenter.nowPlayingInfo` — kept alive by this design.
- `playCommand.isEnabled = true`.
- App still alive/suspended (not force-quit/jettisoned).

Returning `.success` from the command handler before async playback completes is
normal; failures must surface through `.error` and update Now Playing metadata.

## File-by-file plan (dependency order)

1. **`PlayolaRadio/State/SharedUserDefaults.swift`** — add `LastPlayedStation` model
   and the `.lastPlayedStation` `FileStorageKey` shared key.
2. **`PlayolaRadio/Core/AudioPlayback/StationPlayer.swift`** — add
   `@Shared(.lastPlayedStation)`; in `play(station:)`, persist the snapshot before
   stopping the previous station, only when `case .playola`. Leave `.stopped`
   stationless. Clear the snapshot on sign-out.
3. **`PlayolaRadio/Core/AudioPlayback/NowPlayingUpdater/NowPlayingUpdater.swift`** —
   back the resume source with `@Shared(.lastPlayedStation)` (memory var becomes a
   cache at most); on init, if stopped and a snapshot exists, populate
   `currentNowPlayingInfo`; in `updateNowPlaying(with:)`, when
   `currentStation == nil && state == .stopped`, render the persisted station instead
   of clearing; `setPlaybackRate` → `0.0` for `.stopped` too; stop calling
   `startInactivityTimer()` for `.stopped`; reserve `releaseRemoteControlCenter()` for
   sign-out; extract `handlePlayCommand()`.
4. **`PlayolaRadio/PlayolaRadioApp.swift`** — likely no change if `NowPlayingUpdater`
   init repopulates metadata; avoid double-registration churn.
5. **`PlayolaRadio/CarPlay/CarPlaySceneDelegate.swift`** — no auto-play; no
   route/connect resume logic. (Metadata refresh on connect is already handled.)

## Tests (swift-testing, `@Suite(.freshSharedState)`, `expectNoDifference`, `withDependencies`)

`StationPlayerTests.swift`:
- `playolaPlayPersistsLastPlayedStationBeforeBackendStarts`
- `urlPlayDoesNotOverwriteLastPlayedPlayolaStation`
- `stopDoesNotClearPersistedLastPlayedStation`
- `signOutClearsPersistedLastPlayedStation`

`NowPlayingUpdaterTests.swift`:
- stopped state with a persisted last station builds non-empty `currentNowPlayingInfo`
- stopped state sets playback rate `0.0`
- inactivity timer is not started / release is not called for ordinary `.stopped`
- `handlePlayCommand()` resumes the persisted station when current station is nil
- `handlePlayCommand()` returns `.commandFailed` when no persisted station exists
- paused state resumes via `handlePlayCommand()`

## swift-sharing / Codable footguns

- `@Shared(.key) var x = value` is a default, not a write — tests seed with `= value`
  under `.freshSharedState`, and use `$shared.withLock` only to drive mid-test changes.
- Persisting raw `AnyStation` couples the file format to the SDK's `Station` Codable
  shape; acceptable as the pragmatic first implementation since `play(station:)`
  already requires `AnyStation`. If the shape ever changes, decode must fail soft to
  `nil` (no crash, just no resume).
- File-storage writes can fail quietly; never make resume depend on station lists when
  the durable snapshot exists.
