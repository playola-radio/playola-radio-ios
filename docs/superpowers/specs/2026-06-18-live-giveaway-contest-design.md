# Live Giveaway Contest — Design (iOS)

**Date:** 2026-06-18
**Branch:** `briankeane/live-giveaway-contest`
**Scope:** FULL feature — listener side **and** artist congrats recording. This **replaces** the
abandoned `briankeane/prizes-flow` work (listener-only, ~4800 lines, unit-tested but at runtime
**none of its UI ever appeared**). We are not basing on or merging that branch.

## Problem

A station runs a live giveaway during a broadcast. Mechanic: "be the Nth person to tap." The
target (`winningNumber`) is **public**. A listener taps once, gets their own tap number, and learns
win/lose only when the giveaway resolves (server closes it — either the artist's congrats voicetrack
airs, or a timeout). Winners fill a shipping form; losers get a quiet "try again." Separately, when a
winner is determined the **station owner (artist)** gets a push and can record an optional congrats
voicetrack; if it airs, that closes the contest.

## Why the prior attempt failed, and the prime directive of this rebuild

The prior implementation was fully unit-tested yet **invisible at runtime** — banner, overlay, and
winner sheet never appeared. Root-cause theory (Codex-reviewed):

1. The feature is **100% server-data-driven**. `GET …/giveaways/active` returns `null` until a
   giveaway is `open`, and pushes only fire during a live contest. With no live giveaway, every
   surface correctly renders nothing — and there was **no way to make it appear on demand**, so it
   was undebuggable.
2. Secondary: silent gate failures (the overlay's `isVisible` requires `status==open` AND
   `activeGiveaway.stationId == nowPlaying.currentStation.id` AND a `.playola` station — one wrong
   comparison and it stays height 0), and error paths that **normalize every fetch failure (401 /
   network) to "no giveaway"**, clearing the UI forever.

**Prime directive:** *Make every surface visible on demand, with diagnostics, before wiring live
data.* The first PR delivers debug fake-injection + a gate-diagnostics readout + `#Preview`s for
every state. Each subsequent PR ends with something you can **see in the simulator**. Unit tests did
not save the prior attempt; runtime verification per PR is mandatory.

`@ObservationIgnored @Shared(.key)` in an `@Observable` model is the correct, sanctioned pattern —
`@Shared` manages its own observation and drives SwiftUI updates. (This was *not* the bug.)

**Server-decoded status enums tolerate unknown values.** `GiveawayStatus` and `FulfillmentStatus`
are decoded straight from server JSON and use an `unknown` fallback (`init(from:)` → `rawValue ?? .unknown`)
so one unrecognized value can't make a whole `Giveaway`/`GiveawayMyResult`/`GiveawayTapResponse` decode
throw — which the poll loop would swallow, silently hiding the UI (the exact failure mode above).
Consumers (PR2+) must handle `.unknown` explicitly; treat it as non-open and non-terminal (the
`opensAt+10min` fallback timer backstops a giveaway stuck in `.unknown`). The *local* state enums
`GiveawayParticipationStatus` / `CongratsActionState` are ours to control and stay strict.

## Server contract

### Listener (all Bearer JWT; IDs are UUID strings; timestamps ISO-8601 UTC)

| Endpoint | Returns / Body | Notes |
|---|---|---|
| `GET /v1/stations/:stationId/giveaways/active` | open `Giveaway` (incl. `winningNumber`, **no** `tapCount`) or `null` | Source of truth for "is a giveaway live & open on this station." Cheap; designed to poll. Returns `null` for `scheduled` (pre-open). |
| `GET /v1/giveaways/:giveawayId` | full `Giveaway` — `status ∈ {scheduled, open, closed, canceled}`, `winnerUserId?`, `viewer:{ hasTapped, isWinner, canSubmitMailingInfo, tapNumber? }` | Authoritative detail/status. `viewer.tapNumber` is `null` until `closed`. 404 if missing/canceled. Used for overlay confirm + artist screen. |
| `POST /v1/giveaways/:giveawayId/tap` (no body) | `{ tapNumber, isWinner, status }` | Idempotent (repeat tap → same `tapNumber`). `400` if not open. **Ignore `isWinner`** (not final — last-tapper fallback). |
| `GET /v1/giveaways/:giveawayId/my-result` | `{ tapNumber?, isWinner, status, winningNumber }` | **AUTHORITATIVE** final outcome (incl. last-tapper fallback). `tapNumber` null if never tapped. **Resolve the reveal from this.** |
| `POST /v1/giveaways/:giveawayId/winner-submission` | body below → `201` | Idempotent. `403` if caller isn't the winner. |

Winner-submission body — **required:** `fullName`, `addressLine1`, `city`, `postalCode`.
**Optional:** `addressLine2`, `state`, `comment`, `country` (default `"US"`), `willingToRecord` (bool).

### Artist congrats (reuses the existing voicetrack pipeline + ONE new endpoint)

1. `POST /v1/stations/:stationId/voicetrack-presigned-url { originalFilename }` → `{ presignedUrl, s3Key }`
2. `PUT` recorded audio (M4A) to `presignedUrl` (S3)
3. poll `GET /v1/stations/:stationId/voicetrack-status/:s3Key` until `ready` (LUFS normalize)
4. `POST /v1/stations/:stationId/voicetracks { durationMS, s3Key }` → `AudioBlock` (⇒ `audioBlockId`)
5. **NEW:** `POST /v1/giveaways/:giveawayId/congrats { audioBlockId }`

Steps 1–4 already exist as `VoicetrackUploadService` (`AudioRecorderClient` → convert WAV→M4A →
presign → S3 PUT → poll → create). Only step 5 is new client-side. Recording is **optional**; if the
artist never records, the server closes on a timeout.

### Push types (envelope `{ aps, type, stationId, giveawayId }`; `aps.alert.title` = curator name)

| `type` | Audience | When | iOS action |
|---|---|---|---|
| `giveaway_show_started` | all | show starts | **v1: ignore** (no `/active` confirmation possible pre-open; see Decision 1). |
| `giveaway_opened` | all | button opens | Seed app-wide banner (unconfirmed announcement); next `/active` confirms still-open. |
| `giveaway_closed` | all | contest closes | Accelerate the pending-result poll for that giveaway. |
| `giveaway_winner_pending` | **owner only** | winner determined | Present the artist congrats entry; the screen fetches `GET /giveaways/:id` on open (no winner name in the payload — privacy). |

Pushes are **accelerants**; always confirm via a GET before changing UI.

## Decisions (locked)

1. **No pre-open banner in v1.** Banner appears only once `status==open` (confirmable via `/active`).
   `giveaway_show_started` is ignored for v1 (avoids stale-banner logic). Revisit a "coming up"
   teaser later.
2. **Incremental, runtime-verified PRs** (see plan) — listener first, artist last.
3. **Winner name is NOT in the push.** The artist screen fetches `GET /giveaways/:id` on open.
   *Open item (does not block PRs 1–5):* confirm that GET returns the **winner's name** for the
   owner (prize is already on the giveaway). If not, request an owner-facing winner-detail field.

## Architecture

### Ownership & lifecycle

A `GiveawayCoordinator` (`@MainActor @Observable`) is owned by `MainContainerModel` (the existing
app-lifetime owner of pollers, push handling, toasts, and global sheets). Started from
`MainContainer.viewAppeared()`; paused/resumed on scene-phase changes. The coordinator is **not** in
`@Shared`; it writes small value structs into `@Shared` that the UI reads. `APIClient` gets plain
endpoint methods only — no polling/UI state in the client. Inject `@Dependency(\.continuousClock)`
from day one (resolution timing is core behavior under test).

### Shape: Inputs → `apply()` → Effects (avoid a god reducer)

The coordinator funnels every **input** through one state-recompute path so `@Shared` outputs can't
get half-updated:

- **Inputs:** push event · active-poll result · result-poll result · tap response · now-playing
  station change · auth change · app phase change.
- **`apply()`** recomputes ALL outputs together: `.activeGiveaway`, `.giveawayBanner`, the relevant
  `.giveawayParticipations` row, and any sheet/toast *intent*.
- **Effects** (kept separate from the recompute): polling tasks, API calls, `StationPlayer.play`,
  sheet presentation, toast.

Lifecycle correctness (explicit, tested):

- `start()` idempotent; `stop()` cancels tasks deterministically.
- Foreground → immediate poll of `/active` (current station) + `my-result` (each unresolved
  participation). Now-playing station change → immediate `/active` poll for the new station (don't
  wait 15s).
- Broadcast push for a **non-current** station → banner/invite intent only; **never** overwrite the
  current overlay's `activeGiveaway`.
- Sign-out → clear in-memory giveaway/banner; participations are **user-scoped** so one account never
  sees another's winner state.
- **Never normalize a 401 / network error to "no giveaway."** Distinguish "authoritatively null"
  from "fetch failed" — on failure, keep last-known state and retry (after re-auth for 401). No task
  pileup if a call exceeds the interval.

### Two poll loops, one funnel

1. **Active-station poll** → `GET /stations/:id/giveaways/active` for the currently-playing
   `.playola` station only. ~15s while playing; immediate on foreground & station change. Open →
   `.activeGiveaway` set → overlay shows. Authoritative `null` → clear. Also catches a missed push.
2. **Pending-result poll** → `GET /giveaways/:id/my-result` for every persisted unresolved
   participation, **app-wide, keyed by `giveawayId`** (independent of current station). ~5s for the
   first minute after tap, then ~15s; immediate on launch/foreground; accelerated by
   `giveaway_closed`. Resolve → winner sheet / loser toast.

### Reveal logic (canonical = `my-result`)

After a successful tap, persist `tappedStandby`, then poll `my-result`:
`open|scheduled` → keep polling · `closed` → persist final `tapNumber/isWinner`, reveal once
(winner sheet **or** loser toast) · `canceled` → persist canceled, stop, neutral (suppress
win/lose). **Never** stop polling merely because `isWinner==false` while `status != closed`. Never
trust the tap response's `isWinner`. `GET /giveaways/:id viewer{}` is for overlay/cold-launch sync,
**not** the reveal authority.

### Shared state (new keys in `State/SharedUserDefaults.swift`)

| Key | Storage | Type | Drives |
|---|---|---|---|
| `.activeGiveaway` | in-memory | `Giveaway?` | Player overlay (open giveaway for current station). |
| `.giveawayBanner` | in-memory | `GiveawayBannerState?` | App-wide "Tap In" banner. |
| `.giveawayParticipations` | file storage (user-scoped) | `[String: GiveawayParticipation]` keyed by `giveawayId` | Durable "I tapped X"; survives restart. |
| `.dismissedGiveawayBannerIds` | file storage | `Set<String>` | Remember banner dismissals (per-giveaway, not per-station). |
| `.pendingCongratsAction` | file storage (user-scoped) | `CongratsAction?` | Durable artist congrats progress (survives kill; holds `audioBlockId` for retry). |

### Per-user participation phase (persisted per giveaway)

```swift
enum GiveawayParticipationStatus: Codable, Equatable, Sendable {
  case tappedStandby(tapNumber: Int)
  case resolvedWon(tapNumber: Int, submissionCompleted: Bool)
  case resolvedLost(tapNumber: Int, toastShown: Bool)
  case canceled
}
```

A row is written **only after the user taps**, **immediately after the tap POST returns** (before any
UI update) so a crash can't lose the reveal. A row is **pruned** once terminal & fully handled
(`resolvedWon` + submission complete, `resolvedLost` + toast shown, or `canceled`).

### The five surfaces

- **App-wide banner** — in `MainContainer`, above the toast / small-player region. Shown when
  `.giveawayBanner` is set and the id isn't dismissed. Tap → play that station + open player.
  Dismiss (X) → add id to `.dismissedGiveawayBannerIds`.
- **Player overlay** — `GiveawayPlayerOverlayView` injected into `PlayerPage`, reading
  `.activeGiveaway` for the current station. Untapped: "Be the **Nth** tapper to win" + prize + TAP.
  After tap: "You're in." `PlayerPageModel` does **not** poll — it calls
  `coordinator.tap(giveaway:)` and reads shared state.
- **Winner sheet** — new `PlayolaSheet.giveawayWinner(GiveawayWinnerSheetModel)`, app-wide. "You won!
  You're #N", prize, shipping form (required: fullName/addressLine1/city/postalCode; optional:
  state/addressLine2/comment/country default "US"/`willingToRecord`) → `POST /winner-submission` →
  confirmation. **Queued** behind the nav coordinator's single `presentedSheet` slot; if a sheet is
  up, store `pendingWinnerPresentation` and present when the slot frees. Persist
  `winnerSheetPresentedAt` only **after** actually presented (so relaunch can re-present).
- **Loser toast** — existing toast dependency, shown exactly once (guarded).
- **Artist congrats** — new `PlayolaSheet.congratsRecording(CongratsRecordingPageModel)` (mirrors
  `RecordIntroPageModel`: record → review → auto-upload via `VoicetrackUploadService` → `POST
  /congrats`). Entry from the `giveaway_winner_pending` push tap and an in-app foreground entry point
  for owners. The screen fetches `GET /giveaways/:id` on open for prize/winner.

### Artist congrats correctness

Persist a `CongratsAction { giveawayId, stationId, state, audioBlockId? }` so progress survives a
kill. Cold-launch push tap may arrive before auth/nav exist → persist intent, resolve after launch.
Confirm ownership via `fetchUserStations` (server also enforces). Store `audioBlockId` **before**
`POST /congrats`; on step-5 failure **retry only step 5** (don't re-record). If `/congrats` 4xx's
because the contest already closed (timeout beat the artist) → "Giveaway already closed," terminal,
no re-record. 401/403 → stop until auth changes; 5xx/network → keep retryable. (Assume `/congrats`
is idempotent per giveaway — confirm server-side.)

### Debug / verifiability (PR1 — the prime directive)

- `#Preview` for every surface and every state (banner, overlay untapped/standby, winner sheet
  form/confirmation, loser, artist record/review/uploading/done).
- Debug-only **force-inject**: set a fake open `Giveaway` into `.activeGiveaway`, push a fake banner,
  simulate each push type and each result transition — togglable from a debug menu.
- Debug-only **gate diagnostics** readout: last push, last `/active` status code, current station id,
  `activeGiveaway` id/station/status, and **the reason the overlay gate is closed**
  (e.g. "station mismatch: playing A, giveaway B").

## New files

- `Models/Giveaway.swift`, `Models/GiveawayTapResponse.swift`, `Models/GiveawayMyResult.swift`,
  `Models/GiveawayWinnerSubmission.swift`, `Models/GiveawayParticipation.swift`,
  `Models/GiveawayBannerState.swift`, `Models/CongratsAction.swift`
- `Core/Giveaways/GiveawayCoordinator.swift`
- `Core/Giveaways/GiveawayDebug.swift` (debug fake-injection + diagnostics; `#if DEBUG`)
- `Views/Reusable Components/GiveawayBannerView.swift`
- `Views/Pages/PlayerPage/GiveawayOverlayModel.swift` + `GiveawayPlayerOverlayView.swift`
- `Views/Pages/GiveawayWinnerSheet/GiveawayWinnerSheetModel.swift` + `…View.swift`
- `Views/Pages/CongratsRecording/CongratsRecordingPageModel.swift` + `…View.swift`
- `Core/Giveaways/CongratsUploadService.swift` (thin wrapper over `VoicetrackUploadService` + step 5)
- Colocated tests for each model/coordinator.

## Touched files

- `Core/API/APIClient.swift` + `APIClient+Live.swift` — `activeGiveaway`, `giveaway`, `tapGiveaway`,
  `giveawayMyResult`, `submitGiveawayWinner`, `postGiveawayCongrats`.
- `State/SharedUserDefaults.swift` — new keys.
- `Views/Reusable Components/PlayolaSheet.swift` — `.giveawayWinner`, `.congratsRecording`.
- `Core/Navigation/MainContainerNavigationCoordinator.swift` — `pendingWinnerPresentation` queue.
- `Views/Pages/MainContainer/MainContainerModel.swift` + `MainContainer.swift` — own/start
  coordinator, render banner, host sheets.
- `Views/Pages/PlayerPage/PlayerPageModel.swift` + `PlayerPage.swift` — inject overlay, wire `tap`.
- `Core/PushNotifications/PushNotifications.swift` — `giveaway_opened`, `giveaway_closed`,
  `giveaway_winner_pending`; ignore `giveaway_show_started` (v1).

## Conventions

Models hold ALL text/logic/state; views are visuals only with **zero control flow** (push
conditional rendering into the model or a no-op component). All models + tests `@MainActor`. New
`.swift` files must be hand-registered in `project.pbxproj` (explicit refs). Tests: XCTest,
`@Shared` declared locally per test, controlled `continuousClock`, mocked `APIClient`,
`expectNoDifference`/`expectDifference` (not raw `==`). pfw skills invoked before writing Swift.

## Testing focus

tap → standby → delayed `my-result` resolve → winner sheet queued/presented; tap → lost → loser
toast **once**; relaunch with persisted standby → re-poll → reveal; winner sheet **waits** while a
sheet occupies the slot; banner dismissal remembered (per giveaway, not station); `/active` null
clears overlay but a **401/network does NOT**; wrong-station / nil-station / not-`.playola` overlay
gate stays hidden (and diagnostics explain why); congrats: upload success then `/congrats` failure →
retry step 5 only; `/congrats` already-closed → terminal; sign-out clears state.

## Risks

Single `presentedSheet` slot (mitigated by queue) · persist-before-die on tap · key by `giveawayId`
not station · banner push is an announcement not durable truth · auth expiration must fail gracefully
and retry · duplicate presentation guarded by `winnerSheetPresentedAt`/`loserToastShownAt` · **the
invisibility trap** — every gate must be diagnosable and every surface force-renderable.
