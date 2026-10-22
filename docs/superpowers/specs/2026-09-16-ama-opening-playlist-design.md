# AMA Opening-Playlist Assembly — Design

**Date:** 2026-09-16
**Status:** Approved scope, pending spec review
**Feature area:** Live Shows → "Ask Me Anything" (AMA)
**Page:** `AskMeAnythingSetupPage`
**Spec authority:** `design/features/live-shows/spec.md` §S39
**Approved design refs:**
- `design/features/live-shows/exports/approved/ama-song-search-sheet--dXnbm.png` (song search sheet, reuses `SongSearchPage`)

---

## 1. Summary

After a curator records their AMA intro, the page transitions to a "build your
opening" state. Today that state renders one hardcoded intro row plus three
inert circular add-buttons, and the model tracks a single scalar
`introDuration`. The "Start Show" button is permanently disabled.

This PR turns that state into a real, ordered **opening playlist**: the curator
can append **songs** (via the reused song-search sheet) and **voicetracks** (via
the reused multi-step recorder), the readiness meter reflects the total staged
*ready* audio, and **"Start Show" enables the moment ≥ 10:00 (600,000 ms) of
ready audio is staged**.

Per §S39 the opening playlist is assembled **client-side only**; it is POSTed at
go-live in a **future** effort. This PR builds the preview and unlocks the
button. **iOS is an API consumer only** — no backend work.

---

## 2. Locked scope (decided; not open for relitigation)

- **D1 — Wire Song + Voicetrack adds now.** Q&A remains a deferred inert stub
  this PR.
  - Voicetracks **reuse the generic recorder** `RecordWithMultiStepPromptModel`
    with AMA-specific copy — **not** Broadcast's `RecordPageModel`.
  - Song search **reuses** `SongSearchPageModel(searchMode: .all, stationId:)`
    to match the approved `dXnbm` design.
- **D2 — Append-only.** No reorder, no user-facing remove in this task. (The one
  exception is automatic rollback of a *failed* voicetrack add — see §7.)
- **D3 — Add a deferred-upload mode to the generic recorder now.** The recorder
  can pop immediately handing back the local file URL, so upload/processing runs
  in the background while the curator keeps editing.
- **D4 — "Start Show" is a no-op tap.** It only becomes *enabled* at ≥ 10:00
  ready. Wiring go-live is out of scope.

---

## 3. Architecture consult outcomes (adopted)

An architecture consult (Codex, staff-level iOS reviewer) reviewed the proposed
shape against the real code. The following corrections were verified against the
codebase and are folded into this design:

1. **Do not hold `any StagingItem` as the model's source of truth.** `StagingItem`
   is a *presentation* interface (title/subtitle/icon/isReady/isProcessing). It
   exposes **no duration** and is **not `Identifiable`**. Use a concrete model
   type (§4) and expose `StagingItem`-shaped fields to the view via computed row
   view-data.
2. **Count the returned `AudioBlock.durationMS`, not the recorder's estimate.**
   The recorder's `recordedDuration` is captured as `currentTime` *before* the
   stop-await and is an estimate. Readiness must be computed from authoritative
   durations only.
3. **Exclude processing voicetracks from the ready-sum** (spec: processing is not
   "secured"). Accept the bar jumping when a voicetrack completes; animate it. No
   contiguous-prefix rule.
4. **The two-optional-callback recorder is a smell** but a full acceptance-mode
   enum ripples into the shipped, tested intro path. We adopt a **narrower**
   change (§5) and document the divergence.
5. **The background upload Task must be owned by `AskMeAnythingSetupPageModel`**,
   not the popped recorder. Re-fetch the row by id across awaits; capture an
   immutable `stationId` + auth at accept-time; cancel on setup abandonment but
   **not** on ordinary view-disappear.
6. **`VoicetrackUploadService` deletes only the converted `.m4a`, only on
   success. The original `.wav` is never deleted by the service.** On the
   deferred path the recorder hands off the file **without deleting it**, so the
   **AMA model owns deleting the original** on *both* success and failure.
7. **Song *requests* are not stageable.** `SongSearchPageModel.songRequestResults`
   produce no `AudioBlock`; only `onSongSelected` (a library `AudioBlock`)
   contributes to the playlist and readiness.
8. **`SongSearchPageModel.onSelectSong` does not self-dismiss.** The AMA
   `onSongSelected` closure must clear the sheet (mirrors `BroadcastPageModel`).
   Immediate dismissal also prevents a double-append from one presentation.
9. **Remove the "past Q&As" copy** from `addSectionExplanation` while Q&A is
   inert.
10. **Fix duration formatting** so it can never read "10:00 ready" while the
    button is disabled (floor the ready value, ceil the remaining value — §6).

---

## 4. Model — ordered opening playlist

Replace the scalar `introDuration` with an ordered, identified collection.

```swift
struct AMAOpeningItem: Identifiable, Equatable {
  let id: UUID
  var content: Content

  @CasePathable
  enum Content: Equatable {
    case intro(AudioBlock)
    case song(AudioBlock)
    case voicetrack(LocalVoicetrack, completedDurationMS: Int?)
  }
}
```

Held as `IdentifiedArrayOf<AMAOpeningItem>` on the model.

**Why a per-occurrence `id` (not `audioBlock.id`):**
- The item carries its own lifecycle state (a voicetrack's processing status),
  distinct from its payload's identity.
- Keying on `audioBlock.id` would collide if the same song were staged twice.
  We allow intentional duplicates; per-occurrence UUIDs make that well-defined.
- `id` comes from `@Dependency(\.uuid)` for deterministic tests.

**Intro pinning.** The intro is always the first element (inserted at index 0 on
completion; songs/voicetracks append). Append-only (D2) preserves the invariant.

**Duration accounting (per item):**

| Content | Ready? | Duration counted |
|---|---|---|
| `.intro(block)` | always (uploaded via blocking path) | `block.durationMS` |
| `.song(block)` | always (library block) | `block.durationMS` |
| `.voicetrack(vt, completedDurationMS)` | `vt.isComplete && vt.audioBlockId != nil && completedDurationMS != nil` | `completedDurationMS!` (only when ready) |

`readyMilliseconds` = sum of `durationMS` over items where the row is ready.
`isStartShowEnabled` = `readyMilliseconds >= 600_000`.
`readyProgress` = `min(1, Double(readyMilliseconds) / 600_000)`.

**Why `completedDurationMS` on the voicetrack case (not the recorder estimate):**
the voicetrack has no authoritative duration until its background upload returns
an `AudioBlock`. On completion we set `completedDurationMS = block.durationMS`
and flip status to `.completed` with `audioBlockId = block.id`. Until then the
row shows a processing indicator and contributes **0** to `readyMilliseconds`.

---

## 5. Recorder — deferred-upload mode (the D3 change)

`RecordWithMultiStepPromptModel` keeps its existing **blocking** intro path
unchanged (`onUseRecording` → `.uploading`/`.processing` → `onCompleted` → pop).
We add a **deferred** path:

```swift
@ObservationIgnored
var onRecordingAccepted: (@MainActor (URL, TimeInterval) throws -> Void)?
```

In `useRecordingButtonTapped()`, when `onRecordingAccepted` is set, run the
**deferred branch** — which is fully synchronous on the main actor up to the pop,
so no interleaving/duplicate acceptance is possible:

```swift
guard recordingPhase == .review, let url = recordingURL else { return }
if let onRecordingAccepted {
  do {
    try onRecordingAccepted(url, recordedDuration)  // append row + launch upload; no await
    recordingURL = nil                              // hand off ownership; do NOT delete the file
    navigationCoordinator.pop()
  } catch {
    presentedAlert = .recordingSaveFailed(error.localizedDescription)
  }
  return
}
// existing blocking upload path (onUseRecording / onCompleted) unchanged
```

Key properties:
- **Synchronous + throwing.** The handler validates prerequisites (auth,
  station), appends the row, and launches the background upload, all before
  returning. If it throws (e.g. not authenticated), the recorder stays on the
  review screen and shows an alert — nothing is handed off, nothing is lost.
- **`recordingURL = nil` without deleting.** The AMA model now owns the file
  (see §6/§7 cleanup). Skipping the delete is deliberate and load-bearing.
- **No `.uploading`/`.processing` phases** on this path — the recorder pops
  immediately.

A new factory `RecordWithMultiStepPromptModel.askMeAnythingVoicetrack(...)`
configures `onRecordingAccepted` (and AMA copy) instead of `onUseRecording`.

**Divergence from the consult (documented).** The consult preferred replacing
the two optional callbacks with a single `acceptance` enum. We keep two
optionals because:
- The intro path sets `onCompleted` *after* the factory builds the model
  (`recorder.onCompleted = { ... }`); an enum forces building the whole strategy
  up front, rippling into the intro factory **and** its passing tests.
- The deferred branch is chosen explicitly and is atomic on `@MainActor`, so the
  ambiguous-precedence risk the consult flagged does not materialize at runtime.
- Keeping the shipped intro path byte-for-byte protects a tested, in-production
  flow — consistent with "`develop` stays shippable."

To make the invariant explicit rather than implicit, the deferred branch is
checked first and, if **both** `onRecordingAccepted` and `onUseRecording` are
somehow set, we `reportIssue` (dev-only) documenting "exactly one acceptance
path expected." The full enum refactor is a deliberate future cut, not a
requirement of this PR.

---

## 6. Voicetrack add — background upload owned by the AMA model

`voicetrackActionTapped()` pushes the `askMeAnythingVoicetrack` recorder. Its
`onRecordingAccepted` closure (running on `@MainActor`, synchronous):

1. Guards `auth.jwt` and `stationId`; **throws** if missing (recorder shows the
   alert, keeps the recording).
2. Builds `LocalVoicetrack(originalURL: url, title: <timestamped>)` using
   `@Dependency(\.uuid)` / `@Dependency(\.date.now)`.
3. Appends `AMAOpeningItem(id: uuid(), content: .voicetrack(vt, completedDurationMS: nil))`.
4. Launches a background upload **Task owned by the model**, keyed by the item
   `id`, stored under `@ObservationIgnored`.
5. Returns (recorder pops).

The upload Task:

```
capture immutable stationId + jwt at accept-time
call voicetrackUploadService.processVoicetrack(vt, stationId, jwt) { status in
  // re-fetch the row by id; if gone, bail
  update that row's LocalVoicetrack.status
}
on success:
  re-fetch by id; set status .completed, audioBlockId = block.id,
    completedDurationMS = block.durationMS  → row becomes ready, bar animates up
  delete the original .wav (audioRecorder.deleteRecording(url))   // AMA-owned cleanup
on failure:
  re-fetch by id; remove the row (rollback); present a specific alert
  delete the original .wav                                        // AMA-owned cleanup
```

Ownership / lifecycle rules:
- **Re-fetch the row by id across every await** (`items[id: entryID]`) — never
  hold an index or a stale copy. `IdentifiedArrayOf` is mutated only on
  `@MainActor`.
- **Capture `stationId` + `jwt` at accept-time** so a mid-flight station/auth
  change can't corrupt the upload.
- **Cancellation:** cancel outstanding upload Tasks when the *setup is
  abandoned* (model teardown / leaving the AMA flow), **not** on ordinary
  view-disappear. Store handles in an `[UUID: Task<Void, Never>]` under
  `@ObservationIgnored`; cancel + clear on teardown.
- **The Task weakly references the model** to avoid retain cycles.
- **Original-file cleanup is AMA-owned** on both success and failure, because the
  service never deletes the original `.wav` (only the derived `.m4a`, only on
  success).

This mirrors `BroadcastPageModel.handleAcceptedRecording` in spirit, but
**diverges** where Broadcast is not a complete precedent: Broadcast awaits
processing inline and stores no task handles; AMA must run upload in the
background and own the handles for cancellation.

---

## 7. Song add

`songActionTapped()` presents `SongSearchPageModel(searchMode: .all, stationId:)`
as `PlayolaSheet.songSearchPage`. Configure:
- `onSongSelected = { [weak self] block in self?.addSong(block); self?.dismissSheet() }`
  — appends `AMAOpeningItem(id: uuid(), content: .song(block))` (ready
  instantly) **and clears the sheet** (the search model does not self-dismiss).
- `onDismiss = { [weak self] in self?.dismissSheet() }`.

**Song requests do not count.** `onSongRequested` / library-add paths are not
wired to the playlist; only a selected library `AudioBlock` becomes an item.

Duplicates are allowed (per-occurrence id). Immediate dismissal on selection
prevents an accidental double-append from a single presentation.

---

## 8. Q&A — inert stub

`qaActionTapped()` stays an empty stub this PR. Remove the "past Q&As" wording
from `addSectionExplanation` so the copy doesn't promise a disabled capability.

---

## 9. View — data-driven, zero control flow

Make the "build your opening" layer (state 01b) render from the model:
- The pinned intro row + one row per `AMAOpeningItem`, driven by per-row
  view-data the model computes (title, subtitle, subtitle color, icon,
  `isProcessing`, `isReady`, artwork URL) — the `StagingItem`-shaped fields, but
  supplied by the model, not by holding `any StagingItem`.
- A processing indicator on in-flight voicetracks (from the row's `isProcessing`).
- The bottom bar: `preparedAudioLabel`, `readinessHint`, progress bar sized by
  `readyProgress`, and `startShowButton` `.disabled(!model.isStartShowEnabled)`.
- **Add the missing alert binding** (`presentedAlert`) — the page currently has
  none, and voicetrack failures/auth errors need to surface.

The view contains **no** `if`/`switch`/ternary. All display strings and the
row-list come from the model (per project MV rules).

**Formatting fix.** `durationLabel` / readiness copy must **floor** the ready
value and **ceil** the remaining value so the UI can never show "10:00 ready"
(or "Add 0:00 more") while `isStartShowEnabled` is still false. At exactly
600,000 ms it reads ready and the button enables together.

`startShowButtonTapped()` stays a no-op.

---

## 10. Error handling

- **Deferred accept throws** (no auth/station at accept-time): recorder stays on
  review, shows `.recordingSaveFailed` (or a not-authenticated alert), file kept.
- **Background upload fails:** remove the row (rollback), present a specific
  alert on the AMA page, delete the original `.wav`. This is the one automatic
  removal under append-only — it undoes an add that never succeeded, so the
  curator isn't stuck with a permanently-failed row they can't remove.
- **Auth missing on song add:** handled inside `SongSearchPageModel` (existing
  `.notAuthenticated` alert).

---

## 11. Testing plan (boundaries to cover)

Colocated swift-testing, `@Suite(.freshSharedState) @MainActor`,
`withDependencies { }` in the body (no `DependenciesTestSupport` trait in this
target), `expectDifference` for action/mutation, `expectNoDifference` for static
state. Override `\.uuid`, `\.date.now`, `\.voicetrackUploadService`,
`\.audioRecorder`, and `@Shared(.auth)`.

1. **Readiness threshold — 599,999 vs 600,000 ms.** Button disabled at
   599,999; enabled at exactly 600,000.
2. **Processing exclusion.** A voicetrack in-flight contributes 0; readiness and
   the bar exclude it until completion.
3. **Returned-duration accounting.** Ready-sum uses `AudioBlock.durationMS` from
   the completed upload, not the accept-time estimate.
4. **Out-of-order completions preserve order.** Two voicetracks accepted A→B; B
   completes first — row order stays A,B and both durations count.
5. **Duplicate acceptance / duplicate song.** Same song added twice → two rows,
   both counted; single presentation can't double-append (dismiss-on-select).
6. **File handoff without premature deletion.** Deferred accept sets
   `recordingURL = nil` and does **not** delete the file; the AMA upload path
   deletes the original exactly once, on completion.
7. **Failure rollback.** Upload throws → row removed, alert presented, original
   deleted.
8. **Abandonment cancels uploads.** Tearing down / leaving setup cancels
   outstanding upload Tasks; ordinary view-disappear does not.
9. **Blocking intro path unchanged.** Existing recorder intro tests still pass
   (`onCompleted` → intro item appended, duration counted). Update the one test
   that set `model.introDuration` directly to the new collection shape.
10. **Formatting invariant.** No label reads "10:00 ready" while disabled;
    floor/ceil boundaries verified.

---

## 12. Explicitly cut (YAGNI / out of scope)

- Persistence of the assembled playlist across launches.
- Retry UI for a failed voicetrack (auto-rollback instead).
- Reorder / user-remove infrastructure (append-only, D2).
- A global upload manager or cross-page upload queue.
- Backend serialization / go-live POST (§S39 future effort).
- The full recorder `acceptance` enum refactor (§5 divergence).
- Q&A add behavior (inert stub, D1).

---

## 13. Deployability

Single PR against `develop`, kept shippable: the intro blocking path is
untouched, the new adds are additive, and "Start Show" remains a no-op — so
nothing half-built is reachable at runtime. No feature is environment-gated.
