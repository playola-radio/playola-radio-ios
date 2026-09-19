# AMA Live Show — PR1 (Start Show → Live Monitor) Design Spec

**Date:** 2026-09-18
**Branch:** `briankeane/ama-show-start-button`
**Status:** Draft for user review
**Design frames:** `design/features/live-shows/exports/approved/K9H7f.png` (running), `OFqgG.png` (waiting-to-air)

---

## 1. Summary

Wire the currently-inert **Start Show** button on `AskMeAnythingSetupPage` so it:
1. Waits for pending voicetrack uploads, collects the ordered opening `audioBlockId`s.
2. POSTs to the server to schedule the live show.
3. Navigates (replacing the setup route) to a new **AMA Live** monitor page that shows the show waiting-to-air, then running, and lets the curator end it.

This is **PR1 of 3**:
- **PR1 (this spec):** Start Show → live monitor with waiting + running states, live listener count, schedule-derived now-playing, read-only upcoming queue, a client-computed preparedness meter, and End Show (record outro → server end). "Add to Show" is rendered **disabled**. Queue reorder/lock deferred.
- **PR2:** wire "Add to Show" (voicetrack / song / Q&A mid-show).
- **PR3:** queue reorder + lock editing.

**Sequencing (locked D1=B):** the server ships the liveShow endpoints to production first/concurrently, so this PR targets `develop` normally — no feature branch hold, no environment gate.

---

## 2. Server contracts (iOS is a pure consumer)

All require bearer auth + station edit permission. Source: `../playola` branch `briankeane/ama-show-start-endpoint`, `server/src/api/liveShow/ENDPOINTS.md`.

| Method | Path | Success | Notable failure |
|---|---|---|---|
| POST | `/v1/stations/:stationId/liveShow` | 201 `{ liveShowId, scheduledStartsAt, scheduledEndsAt }` | 409 `{ error: { message, data: { delayUntil } } }` when an unfinished show or a materialized Episode/Q&A airing blocks it |
| GET | `/v1/stations/:stationId/liveShow/availability` | 200 `{ available: true }` / `{ available: false, delayUntil }` | preflight only — **not wired in PR1** |
| POST | `/v1/stations/:stationId/liveShow/:liveShowId/end` | 200 `{ endingSpinId, effectiveEndsAt }` | 409 if the show was replaced; 400 if finished or unsafe placement |

- Go-live body: `{ type: "ask-me-anything", audioBlockIds: ["uuid", ...] }` (duplicates allowed, order preserved). Server schedules the ordered opening blocks + **three trailing fillers** at a safe song boundary **≥2 min ahead**.
- End body: `{ audioBlockId: "uuid" }` — removes replaceable fillers, appends the outro block. **Idempotent.**
- **Liveness is derived from spins, not a status column.** The `Spin` model (PlayolaPlayer SDK **v0.21.1**, shipped) carries optional `liveShowId: String?` and `isFiller: Bool?`. `api.fetchSchedule(stationId)` (unauth GET) returns spins carrying these fields.

---

## 3. Key facts that shaped this design (from Codex consult + code read)

1. **The monitor's now-playing is schedule-derived, not player-derived.** `BroadcastPageModel.nowPlaying` = `schedule?.nowPlaying()` (BroadcastPageModel.swift:203-204), computed from the station's own fetched `Schedule`, NOT `@Shared(.nowPlaying)` (which is the *listener's* playback). The AMA Live monitor must work with playback stopped or another station playing → derive everything from the fetched schedule.
2. **`.scheduleUpdated` cannot be relied on for correctness here.** It is a NotificationCenter hint fired for editing flows and its observer drops notifications lacking `editorName` (BroadcastPageModel.swift:144). The code does not establish it fires for a station you own but aren't playing. → PR1 uses an explicit poll; notifications may become an optional refresh hint later.
3. **"Not currently airing my show" ≠ "waiting."** It also describes ended, replaced, missing-schedule, and other-station states. The phase must be derived carefully.
4. **`endLiveShow` success means the outro was *scheduled*, not that the show has ended.** The show ends when the outro finishes airing.
5. **The recorder owns its own navigation pop.** `RecordWithMultiStepPromptModel` deletes the local recording and unconditionally pops after its (async, non-throwing) `onCompleted`. Navigating inside `onCompleted` double-pops.
6. **`authenticatedPost` takes `[String: String]`.** The start body needs `[String]` → use an `Encodable` request struct, mirroring the manual `createVoicetrack` request pattern.

---

## 4. Decisions (RESOLVED by user 2026-09-18)

**D-A. Preparedness meter — RESOLVED: keep exactly as the mockup.**
Display **"6:32 buffered · 65% of 10 min"** with the green meter (no rename). Compute it as *remaining scheduled airtime of the contiguous run of this show's non-filler spins, from now, incl. current-spin remainder* (see §7.4). The copy is the approved design; §7.4 makes the number correct.

**D-B. Read-only queue affordances — RESOLVED: omit non-functional controls.**
Render queue rows read-only; **omit the drag handles and lock control** (reorder/lock ships in a future PR). The static pin on the intro row stays as an indicator.

**D-C. "Listeners notified" footer — RESOLVED: drop that claim.**
Waiting-state footer shows only **"Show starts automatically"**. Do NOT show "Listeners notified" — the contract doesn't guarantee it.

**D-D. Start-recovery depth — RESOLVED: bounded recovery.**
Persist `{liveShowId, stationId}` in `@Shared` on success (survives relaunch → resume to the monitor). On a `409 unfinished-show` conflict, fetch the schedule, derive the active `liveShowId` from this station's live spins, and navigate to the monitor. No new UI. Full resume-from-dashboard deferred.

**D-E. Post-End destination — RESOLVED: stay then Done → dashboard.**
On `endLiveShow` success, stay on the monitor in an **"Ending"** state (disable repeat End). After the outro is confirmed finished, offer **Done → Artist Dashboard** (preserve broadcast mode).

---

## 5. Files & changes

### 5.1 New files
- `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageModel.swift`
- `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageView.swift`
- `PlayolaRadio/Views/Pages/AskMeAnythingLivePage/AskMeAnythingLivePageTests.swift`
- (register all three in `project.pbxproj` — explicit refs, per repo convention.)

### 5.2 Edited files
- `Core/API/APIClient.swift` — add `startLiveShow` / `endLiveShow` closures + response/request/error types.
- `Core/API/APIClient+Live.swift` — live impls with manual status-code + `delayUntil` envelope parsing.
- `Views/Pages/AskMeAnythingSetupPage/AskMeAnythingSetupPageModel.swift` — implement `startShowButtonTapped()`, submission-state, `readyAudioBlockIds`, guard `setupAbandoned()`.
- `Views/Pages/AskMeAnythingSetupPage/AMAOpeningItem.swift` — ensure `audioBlockId` accessor covers all ready cases.
- `Core/Navigation/MainContainerNavigationCoordinator.swift` — new `askMeAnythingLivePage(...)` Path case + `destinationView`; targeted route-replace helper; guard `cancelAbandonedAskMeAnythingSetups`.
- `Views/Pages/RecordWithMultiStepPromptPage/RecordWithMultiStepPromptModel.swift` — add `askMeAnythingOutro(stationId:)` factory (mirror `askMeAnythingIntro`).
- `State/…` — `@Shared` key persisting the active live show (`liveShowId`, `stationId`) for recovery (D-D).

---

## 6. API client additions

```swift
// Request (Encodable — authenticatedPost's [String:String] can't carry [String])
struct StartLiveShowRequest: Encodable {
  let type: String            // "ask-me-anything"
  let audioBlockIds: [String]
}
struct StartLiveShowResponse: Decodable, Equatable, Sendable {
  let liveShowId: String
  let scheduledStartsAt: Date
  let scheduledEndsAt: Date
}
struct EndLiveShowResponse: Decodable, Equatable, Sendable {
  let endingSpinId: String
  let effectiveEndsAt: Date
}

// APIError gains a case carrying the typed conflict:
// case liveShowUnavailable(delayUntil: Date?)   // start 409
// case liveShowReplaced                          // end 409
```

Closures on `@DependencyClient struct APIClient`:
```swift
var startLiveShow: @Sendable (_ token: String, _ stationId: String, _ audioBlockIds: [String]) async throws -> StartLiveShowResponse
var endLiveShow:   @Sendable (_ token: String, _ stationId: String, _ liveShowId: String, _ audioBlockId: String) async throws -> EndLiveShowResponse
```

Live impls follow the `createVoicetrack` template (APIClient+Live.swift:568-598): manual `URLRequest`, decode status codes explicitly, on 409 parse the `{error:{data:{delayUntil}}}` envelope via `parsePlayolaErrorMessage`-style handling into the typed error. **Start 409 and End 409 decode to different cases** (delayUntil vs replaced) — never collapse them.

---

## 7. AMA Live page model

### 7.1 Shape (one model, derived phase — D per Codex Q5)
```swift
@MainActor @Observable
final class AskMeAnythingLivePageModel: ViewModel {
  enum Phase: Equatable { case loading, waiting, running, ending, ended, unavailable }

  // Init inputs (from Start Show or recovery):
  let stationId: String
  let liveShowId: String
  let scheduledStartsAt: Date        // initial fallback; reconciled with real spins

  // Refreshed state:
  private var schedule: Schedule?
  private var listenerCount: Int?
  private var isStale = false          // last fetch failed; keep showing last-good
  private var endOutcome: EndLiveShowResponse?

  var phase: Phase { /* derived — see 7.3 */ }
}
```
Refresh errors/staleness are tracked separately so a transient failure never erases good content and never resets a confirmed-running show back to waiting (Codex Q5).

### 7.2 Refresh model (Codex Q1 → option B)
- View drives it with **`.task { await model.startMonitoring() }`** (structured; cancelled automatically on disappear). No unstructured `Task` stored in the model.
- `startMonitoring()`: fetch schedule + listener count **immediately**, then loop every **10s** (injected clock), each iteration fetching both **concurrently** with independent error handling. Check `Task.isCancelled` before applying results.
- Refresh **immediately** on foreground return and right after start/end mutations.
- Listener count: `api.getActiveListeningSessions(token, stationId, airtime: <now, recomputed each call>, endTime: nil).summary.uniqueUsers`. A failed listener fetch keeps the last value (never shows 0).
- A separate **0.5s presentation tick** (view `TimelineView(.periodic(by: 0.5))`, as BroadcastPageView does) advances the countdown/progress from cached schedule data — no network.

### 7.3 Phase derivation (Codex Q3/Q5)
Compute from the fetched schedule + current time, never from "is my player playing this":
- `loading`: no schedule yet.
- `running`: `schedule.nowPlaying()?.liveShowId == liveShowId`.
- `waiting`: not yet running AND the schedule contains upcoming spins with `liveShowId == liveShowId` (first such spin's `airtime` drives the countdown). `scheduledStartsAt` is the initial fallback before the first schedule arrives.
- `ending`: local — we have a successful `endOutcome` but the outro hasn't finished airing.
- `ended`: outro spin (`endingSpinId`) has finished / no live spins remain after a confirmed run.
- `unavailable`: schedule fetched but shows another station's/no live spins where we expected ours (replaced/expired) — surfaces a recovery message, not a silent "waiting".
- **Never** transition running → waiting because data momentarily disappeared.

### 7.4 Preparedness meter (Codex Q2; copy per D-A)
- Value = **remaining scheduled airtime of the contiguous run of this show's spins**, from now forward:
  - Start at `nowPlaying` if it belongs to the show (include its **unplayed remainder**), else at the first upcoming show spin.
  - Walk consecutive spins while `liveShowId == liveShowId`; **stop** at the first `isFiller == true`, other-show, or genuine schedule gap. Do **not** sum disconnected matching spins.
  - Use actual scheduling boundaries / playable durations (respect overlaps/transitions), not blind `AudioBlock.durationMS` summation.
- Duration is **uncapped**; only the meter fraction caps at 100% (`value / 600_000ms`).
- Display: `"6:32 buffered"` + `"65% of 10 min"` (see D-A). 0:00 means prepared material is exhausted — not that the station goes silent (fillers cover it).

### 7.5 View helpers (all copy in the model)
Header title `"Ask Me Anything"`; `"\(count) listening"`; now-playing title/artist/`LIVE NOW`/progress; waiting banner `"Your Show Starts in \(mm:ss)"` + `"After \(nowPlayingTitle) finishes · \(airtimeLabel)"`; read-only queue rows (icon, title, subtitle, airtime — per D-B); Add-to-Show card rendered **disabled**; meter label/fraction; primary button `"End Show"` (running) / disabled "Ending…" (ending) / "Done" (ended).

---

## 8. Start Show flow (Codex Q3)

In `AskMeAnythingSetupPageModel`, replace the empty `startShowButtonTapped()`:

Submission state (not a bare Bool):
```swift
enum SubmissionState: Equatable { case editing, preparing, submitting, scheduled, outcomeUnknown }
private(set) var submissionState: SubmissionState = .editing
```

Order:
1. **Synchronously** set `.preparing` before the first `await` (rejects duplicate taps; freezes opening edits).
2. `await waitForPendingUploads()`.
3. **Revalidate** the opening: intro present, ready duration ≥ target, and every intended item ready. **Do NOT silently `compactMap` unfinished items away** — upload failures already drop items, so 10 min of surviving songs could pass while omitting something the curator meant to include. If invalid → back to `.editing` with an alert.
4. Snapshot ordered `readyAudioBlockIds`; set `.submitting`.
5. `POST startLiveShow`.
6. On 201: persist `{liveShowId, stationId}` to `@Shared` (D-D), store response, set `.scheduled`.
7. **With no intervening `await`**, replace the originating setup route with `askMeAnythingLivePage(liveShowId, stationId, scheduledStartsAt)`.

Failure handling:
- **409 with `delayUntil`:** alert "You can go live at \(time)"; return to `.editing`.
- **409 unfinished-show (no delayUntil):** recovery (D-D) — fetch schedule, derive the active `liveShowId`, navigate to the monitor.
- **Ambiguous transport failure after the POST await:** `.outcomeUnknown` — do not claim failure; offer retry/recovery (the server may have committed).

Abandonment / teardown:
- The real race is **during the POST await** (user leaves/switches tabs), not between the synchronous success + navigation (no MainActor interleaving there).
- Put the guard **inside `setupAbandoned()`** (the back button calls it directly): if `submissionState` is `.submitting`/`.scheduled`/`.outcomeUnknown`, do **not** cancel uploads / tear down. Only `.editing`/`.preparing` may cancel.
- `cancelAbandonedAskMeAnythingSetups` must respect the same guard.

Navigation replace hazard: `MainContainerNavigationCoordinator` resolves `path` by the **currently-active tab**; a generic "replace top" after an await could hit an unrelated route. The replace must target the **originating stack / setup-model identity**, not "whatever is on top now."

---

## 9. End Show flow (Codex Q4)

1. **End Show** button (running phase) → push `RecordWithMultiStepPromptModel.askMeAnythingOutro(stationId:)`.
2. Recorder records → uploads (blocking) → produces a completed outro `AudioBlock` → calls its async non-throwing `onCompleted(block)` → **the recorder pops itself** (unchanged behavior).
3. `onCompleted` hands the completed block to the live model; the live model (NOT the recorder) `POST endLiveShow(..., audioBlockId:)`.
4. On 200: retain `endingSpinId` + `effectiveEndsAt`, refresh schedule, enter `ending` phase (disable repeat End), show the scheduled ending.
5. On failure: retry using **the same uploaded block** (no re-record). Never pop/replace navigation from inside `onCompleted`.
6. After the outro is confirmed finished (`ended`): show **Done → Artist Dashboard**, preserving broadcast mode.

**Natural exhaustion (confirmed by user):** if the curator never ends, the trailing fillers play out and the station **automatically returns to auto-schedule** — the station never goes silent. So the monitor must handle "my show spins have all aired and the schedule is back to normal auto content" as a graceful `ended`/`unavailable` phase (not an error, not a stuck "running"). Derive this from the schedule no longer containing this show's live spins after a confirmed run.

**Unconfirmed edge (handle defensively):** whether the show can finish *while* the curator is recording the outro is unknown. Do not assume `endLiveShow` succeeds — the server may return **400 (finished)** if the outro POST lands after the show already ended. On that response, treat the show as already `ended` (surface a friendly "your show already wrapped" state, discard the outro), rather than reporting a hard failure.

---

## 10. Testing (swift-testing, `@Suite(.freshSharedState)`, `@MainActor`)

Essential cases (Codex): duplicate Start taps rejected; abandonment *during* submission does not tear down a committed show; lost/ambiguous Start response → `outcomeUnknown` (no false failure); monitor works with playback stopped / another station playing; stale/missing schedule keeps last-good and never resets running→waiting; preparedness meter respects filler/other-show/gap boundaries and current-spin remainder; End retry reuses the same block with no duplicate upload and no extra pop; 409-start (delayUntil) vs 409-end (replaced) decode to distinct errors; recovery derives `liveShowId` from schedule on unfinished-show 409.

Use `expectNoDifference` for value comparisons; assert enum phases via case-paths.

---

## 11. Explicitly out of scope for PR1
- "Add to Show" wiring (PR2) — rendered **disabled**.
- Queue reorder / lock editing (PR3).
- Availability endpoint (redundant with go-live's 409 for the core loop; may improve preflight messaging later).
- Full resume-from-dashboard UI (D-D ships only the bounded recovery).

---

## 12. Pre-merge gates
- Verify the app resolves PlayolaPlayer **0.21.1** (both SPM refs bumped); confirm server fields/endpoints are live in the target environment before Start Show is exposed.
- `make lint` + `xcodebuild test` green.
- No environment gate anywhere (repo policy).
- If this becomes multi-PR soak-tracked, add to `LONG_RUNNING.md` in the PR that starts it.
