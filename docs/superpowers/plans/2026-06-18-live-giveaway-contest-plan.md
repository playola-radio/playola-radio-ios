# Live Giveaway Contest — Implementation Plan

**Design:** `docs/superpowers/specs/2026-06-18-live-giveaway-contest-design.md`
**Branch:** `briankeane/live-giveaway-contest` · **PRs target:** `develop`

Rule for every PR: it ends with **something visible in the running simulator**, verified by hand
(not just green units). Each PR is independently shippable. TDD per the project workflow; invoke the
relevant `pfw-*` skills before writing Swift; register new files in `project.pbxproj`.

---

## PR 1: Models + debug surfaces + previews (the anti-invisibility foundation)
**Goal:** Every giveaway surface renders in the simulator on demand, with no live server data.
**Deliverables:**
- Codable models: `Giveaway`, `GiveawayTapResponse`, `GiveawayMyResult`, `GiveawayWinnerSubmission`,
  `GiveawayParticipation` (+ status enum), `GiveawayBannerState`, `CongratsAction`. Each with `.mock`.
- New `@Shared` keys (`State/SharedUserDefaults.swift`); participations + pendingCongrats user-scoped.
- Static (not-yet-wired) views: `GiveawayBannerView`, `GiveawayPlayerOverlayView` (+ `GiveawayOverlayModel`),
  `GiveawayWinnerSheetView` (+ model), `CongratsRecordingPageView` (+ model) — bound to model strings only.
- `GiveawayDebug` (`#if DEBUG`): force-inject a fake open giveaway / banner / each participation state;
  a gate-diagnostics readout. Reachable from a debug menu.
- `#Preview` for every surface and state.
**Success (see it):** From the debug menu, inject a fake giveaway → overlay shows on the player;
inject banner → banner shows; open winner/loser/artist screens in every state via previews + injection.
**Tests:** model decode/encode + mocks; winner-submission field mapping (required/optional, country
default "US"); participation status transitions.
**Status:** In Progress —
- ✅ Models (`Giveaway`, `GiveawayParticipation`, `GiveawayMyResult`, `GiveawayTapResponse`,
  `GiveawayWinnerSubmission`, `GiveawayBannerState`, `CongratsAction`) + 5 `@Shared` keys, registered
  in pbxproj, compiling; 9 tests green (`GiveawayModelsTests`, `GiveawayParticipationTests`,
  `CongratsActionTests`).
- ⬜ Static views (banner / overlay / winner sheet / congrats recording) bound to model strings.
- ⬜ `GiveawayDebug` force-injection + gate-diagnostics readout + debug-menu entry.
- ⬜ `#Preview` for every surface/state; **runtime-verify in simulator**.

## PR 2: Listener open overlay via `/active`
**Goal:** The real overlay appears when tuned to a station with a live open giveaway.
**Deliverables:** APIClient `activeGiveaway` + `giveaway`; `GiveawayCoordinator` skeleton (Inputs→`apply()`→Effects)
with the active-station poll only; owned/started by `MainContainerModel`; overlay reads `.activeGiveaway`
gated on `status==open` && station match && `.playola`. Gate diagnostics wired to real values.
**Success (see it):** With a mocked/staging open giveaway, overlay appears; switching stations clears it;
diagnostics explain a closed gate. **A 401/network error does NOT clear the overlay.**
**Tests:** poll sets/clears `.activeGiveaway`; wrong-station / nil-station / not-`.playola` → hidden;
fetch failure keeps last state; immediate poll on foreground + station change; `start()` idempotent.
**Status:** Not Started

## PR 3: Tap + participation persistence
**Goal:** Tapping enters the contest and survives an app kill.
**Deliverables:** APIClient `tapGiveaway`; `coordinator.tap(giveaway:)` with in-flight double-tap guard;
persist `GiveawayParticipation` (`tappedStandby`) **immediately after the POST returns, before UI**;
overlay flips to "You're in" (tapNumber hidden).
**Success (see it):** Tap → "You're in"; kill & relaunch → still "You're in" (not a fresh TAP button).
**Tests:** tap persists before UI; double-tap → one POST; 400-not-open handled; relaunch restores standby.
**Status:** Not Started

## PR 4: Result poll + reveal (winner sheet / loser toast)
**Goal:** The contest resolves and reveals correctly, once.
**Deliverables:** APIClient `giveawayMyResult` + `submitGiveawayWinner`; pending-result poll (5s→15s)
keyed by giveawayId, app-wide; resolve via `my-result` (closed/canceled rules); winner sheet queued
behind the single `presentedSheet` slot (`pendingWinnerPresentation`); loser toast once; winner sheet
form → `POST /winner-submission` → confirmation; prune terminal rows.
**Success (see it):** Force a closed-winner → sheet (even if another sheet was up, it waits then shows);
force closed-loser → toast once; canceled → neutral; submit form → confirmation; relaunch re-presents
an unshown winner sheet.
**Tests:** resolve→won queued/presented; resolve→lost toast exactly once; never stop polling on
`isWinner==false` while not closed; canceled suppresses reveal; submission idempotent; markers guard
duplicate presentation.
**Status:** Not Started

## PR 5: Push integration (listener)
**Goal:** Pushes accelerate the experience; GET still confirms.
**Deliverables:** `PushNotifications` handles `giveaway_opened` (seed banner, confirm via `/active`),
`giveaway_closed` (accelerate result poll); ignore `giveaway_show_started` (v1). Banner tap plays the
station + opens player; dismiss remembered per giveaway. Out-of-app push tap plays station (reuse).
**Success (see it):** Simulated `giveaway_opened` → banner; tap → plays station + overlay; dismiss
sticks; simulated `giveaway_closed` → faster reveal.
**Tests:** opened seeds banner then `/active` confirms/clears; closed accelerates poll; banner dismissal
per-giveaway (not per-station); non-current-station push doesn't overwrite current overlay.
**Status:** Not Started

## PR 6: Artist congrats — flow shell
**Goal:** An owner can get from the winner-pending push to a recording screen showing winner + prize.
**Deliverables:** ownership detection (`fetchUserStations`); `giveaway_winner_pending` push tap →
persist `CongratsAction` → present `CongratsRecordingPageModel`; screen fetches `GET /giveaways/:id`
on open for prize (+ winner name if available); `PlayolaSheet.congratsRecording`; record→review UI via
`AudioRecorderClient` (no upload yet). Cold-launch + warm paths; owner-while-listening doesn't collide
with listener overlay/sheet.
**Success (see it):** Simulated winner-pending push (as owner) → recording screen with prize/winner;
record + review playback works.
**Tests:** ownership gate; cold-launch intent persisted then resolved; sheet-slot arbitration vs winner
sheet; non-owner ignores the push.
**Status:** Not Started

## PR 7: Artist upload + `POST /congrats`
**Goal:** The recorded congrats uploads and is submitted, with correct retry.
**Deliverables:** APIClient `postGiveawayCongrats`; `CongratsUploadService` = `VoicetrackUploadService`
(steps 1–4) → store `audioBlockId` in `CongratsAction` → step 5 `POST /congrats`. Retry **only step 5**
on failure; already-closed 4xx → terminal "already closed," no re-record; 401/403 stop; 5xx/network
retryable; success terminal.
**Success (see it):** Record → upload progress → done; kill mid-flow and relaunch → resumes/retries
step 5 without re-recording; already-closed path shows the terminal message.
**Tests:** upload success then `/congrats` failure → retry step 5 only (audioBlockId preserved);
already-closed → terminal; auth error stops; pending action persists across relaunch.
**Status:** Not Started

---

## Cross-cutting
- After each PR: run the full XCTest suite via `xcodebuild test` (compile ≠ pass), `make format`,
  `make lint`; then **launch the app in the simulator and confirm the PR's surface by hand**.
- Adversarial Codex review (`/codex review` then `/codex challenge`) on each PR's diff before opening it.
- Keep pbxproj device-team/reorder churn out of feature PRs.

## Open item (non-blocking for PRs 1–5)
Confirm `GET /v1/giveaways/:id` returns the **winner's name** for the station owner (prize is already on
the giveaway). If not, request an owner-facing winner-detail field before PR 6.
