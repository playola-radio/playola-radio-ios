# Live Giveaway — Milestone 2: Win/Lose Resolution (listener side)

**Date:** 2026-06-23
**Branch:** `briankeane/richmond-v1` → PRs target `develop`
**Status:** Design — awaiting approval
**Gate:** all runtime behavior behind `GiveawayFeature.isLiveDataEnabled` (dark in prod, live in staging). `develop` stays deployable.

Builds on Milestone 1 (PR #336: reveal engine + tap). See memory `project_giveaway_milestones`,
`project_giveaway_event_contract`, `project_server_enums_unknown_fallback`.

---

## 1. Goal

When a listener taps into a giveaway, show them whether they won or lost, and let a winner submit
mailing info to claim the prize.

The headline decision (made during design): **reveal the outcome immediately from the tap response**,
not after a wait. This collapses most of the resolution machinery — there is no standby-then-reveal
poll loop. A small bounded backstop + a server push handle the one edge case where an immediate
"you lost" can later become a win.

---

## 2. Server contract (confirmed from source, branch `briankeane/giveaway-event-runtime`)

Do not guess field names (we got burned in M1 by id-vs-eventId). These are read from the server source.

### Two ways the server picks a winner
1. **At tap time** (`giveawayEvents.lib.ts`): `isWinner = !event.winnerUserId && tapNumber === winningNumber`.
   If you hit the winning number and no winner exists yet, the server crowns you **on that tap** and
   sets `winnerUserId`. The tap response carries this authoritative `isWinner`.
2. **At close** (`reconcileGiveawayClose`): *"keep an Nth-tap winner; else promote the last (highest)
   tapper; zero taps → no winner."* The last-tapper promotion is the only outcome a tapper cannot know
   at tap time.

### Endpoints
- `POST /v1/giveaway-events/:eventId/tap` → `{ tapNumber: Int, isWinner: Bool, status }`
  (already wired as `api.tapGiveawayEvent`; response type `GiveawayTapResponse` already exists).
- `GET /v1/giveaway-events/:eventId/my-result` → `{ tapNumber: Int?, isWinner: Bool, status, winningNumber: Int }`
  — exactly the existing `GiveawayMyResult`. Reconciles a due close on demand. 404 if event missing.
  **Not yet in `APIClient` — we add it.**
- `POST /v1/giveaway-events/:eventId/winner-submission` — **email-only (revised 2026-06-24):** iOS
  sends `{ "preferredEmail": "<confirmed>" }`. 201. Winner-only (403 otherwise). Upserts on `(eventId)`.
  **Server dependency:** the endpoint currently *requires* `fullName/addressLine1/city/postalCode` —
  it must be relaxed to accept email-only + store `preferredEmail` (it may still accept the legacy
  address fields from other clients). Delivery is arranged manually over email for v1. The original
  address-form contract is retained below for history.
  - *(legacy)* required `fullName, addressLine1, city, postalCode`; optional `addressLine2, state,
    country (default "US"), comment`.
- `GET /v1/giveaway-events/:eventId` → full event + `viewer { hasTapped, isWinner, canSubmitMailingInfo,
  tapNumber }` (`viewer.tapNumber` only set once closed). Reconciles on demand. Already wired as
  `api.giveawayEvent`. Used by the winner sheet to check claim eligibility for push/reinstall cases.

### Notifications today (and the gap)
- `giveaway_opened` / `giveaway_closed` → broadcast to ALL users. `giveaway_closed` is "see if you won"
  (not personalized).
- `winner_pending_owner` → **owner only** (the "record a congrats" nudge).
- **There is no targeted per-listener "you won" push.** This milestone defines one as a dependency
  (§7) for the server worktree that owns giveaway code to implement.

---

## 3. Reveal model — immediate

`tap()` POSTs and inspects the response:

- **`isWinner == true`** → persist `.resolvedWon(submissionCompleted: false)`; the arbiter presents the
  app-wide winner sheet immediately. Correct and final (server set `winnerUserId` on this tap).
- **`isWinner == false`** → persist `.resolvedLost(toastShown: false)`; the player shows the in-player
  loser reveal immediately. Because the tap button only lives in the player, a losing tapper is always
  looking at the player, so the reveal is the primary loser surface; the one-time toast is the **durable
  fallback** (app died before the reveal was seen → toast on next foreground).
- **400 (not open yet)** → silent (expected race at the open moment; user can tap again).
- **network / 5xx** → surface via the new `onError` callback → `PlayolaAlert` (Task 0, §6).

`.tappedStandby` is no longer a persisted "waiting" state. It survives only as a transient in-flight /
loading marker on the button while the POST is in flight. The "STAND BY… we'll reveal when the song
ends" copy is removed.

`resolvedLost` means **currently lost, not mathematically final** until the contest closes (last-tapper
promotion can still flip it). The backstop (§5) and push (§7) upgrade it if that happens.

---

## 4. Components & responsibilities

Single source of truth = `@Shared(.giveawayParticipations)` (durable file-backed `[String:
GiveawayParticipation]`, keyed by per-airing event id). Coordinator/push **mutate** it; MainContainer
**presents** from it. The overlay never presents app-wide UI.

### 4.1 `GiveawayCoordinator`
- `tap(event:)` (modified): POST, classify errors, on success persist `.resolvedWon`/`.resolvedLost`
  immediately (replacing the M1 `.tappedStandby` persist). Surface genuine failures to `onError`.
- **Poll-while-open backstop** (modified reconcile): the feed reconcile already runs every 30s while
  foregrounded and already detects when an active event closes (`handleNoFeedEvent` →
  `clearActiveIfNoLongerOpen` does a detail GET). Extend that close-detection: when a contest the user
  holds a `.resolvedLost` participation for has closed, do **one** `my-result` call and flip
  `.resolvedLost → .resolvedWon(submissionCompleted:false)` if the server promoted them. Bounded to
  contest length; no new loop or cadence.
- Coordinator only mutates durable state. No sheet/toast decisions.

### 4.2 `MainContainerModel` — presentation arbiter (sole presenter)
- Observes the participations dict. Derives pending effects:
  - **Winner pending**: `status == .resolvedWon(submissionCompleted: false)` && `winnerSheetPresentedAt
    == nil`. If no blocking sheet is up, mark `winnerSheetPresentedAt = now` **synchronously** with
    installing the sheet (same MainActor transaction), present the winner sheet. Serialize multiple,
    oldest-first by `tappedAt`. Durable dict ⇒ survives app kill ⇒ presents on next launch if not yet
    presented.
  - **Loser toast fallback**: `status == .resolvedLost(toastShown: false)` and the in-player reveal did
    not show it → fire one-time toast, set `toastShown = true`.
- eventId is the idempotency key; `winnerSheetPresentedAt` dedupes re-entry.

### 4.3 In-player loser reveal (player overlay)
- New reveal view replacing the standby view. Driven by the just-resolved participation for the
  now-playing station.
- **Minimum display duration (~8–12s)** then clears on navigation / station change / player dismissal —
  not tied solely to `activeGiveaway` lifetime (which clears at song-end and would otherwise yank the
  reveal mid-look).
- Copy from the lovable design (`briankeane/tapper-giveaway` `TapperLoserScreen`): dimmed gift,
  "You were listener #N — good luck next time!". All strings live on the model.

### 4.4 Push handler (new — iOS has zero giveaway push handling today)
- On the targeted winner push: find/create participation by `eventId`.
  - If already `.resolvedWon(submissionCompleted: true)` → ignore.
  - If `.resolvedWon(submissionCompleted: false)` && `winnerSheetPresentedAt != nil` → do not re-present.
  - Else flip to `.resolvedWon(submissionCompleted: false)` and let the **arbiter** present (handler does
    NOT present directly — it only mutates durable state).
- Push fires for **all** winners (covers reinstall / second device); eventId-deduped. Prefer a
  data/silent push so a common winner who already saw the sheet does not get a redundant banner.

### 4.5 Winner sheet (`GiveawayWinnerSheetModel` + view; new `PlayolaSheet` case)
- **Email-only (revised 2026-06-24).** A full mailing-address form is too much friction at the "you
  won" moment, and the server already knows the winner (`winnerUserId` → `User`). So the sheet collects
  just a **confirmed email**: prize image + headline + a single email field (pre-filled from
  `auth.currentUser.verifiedEmail ?? .email`, editable) + Claim. The team arranges delivery over email.
  No address fields, no "record a video" toggle.
- Submit → `POST winner-submission` with `{ "preferredEmail": "<confirmed>" }`. Success →
  `submissionCompleted = true`, dismiss. Failure → keep the sheet open, show a `PlayolaAlert` (matches
  `RedeemPrizeSheet`), let the user retry (server upserts). Do not loop-re-present.
- **Provenance check**: if the participation was created from a push or has unknown provenance, GET the
  event detail first; if `viewer.canSubmitMailingInfo == false` (already claimed on another device),
  mark `.resolvedWon(submissionCompleted: true)` and show a "claimed" confirmation instead of the form.
- Visuals from `TapperWinnerScreen` (confetti, prize image, "You won! You're Listener #N", prize
  name/desc, email field, "Claim Prize", then "You're all set — check your email").
- **Surprise-upgrade copy**: when the sheet is reached by flipping a `.resolvedLost` participation to
  won (the promoted last-tapper — local provenance was a loss, or push `reason == "last_tapper_fallback"`),
  the headline acknowledges the upgrade (e.g. "Good news — you got bumped up to the winner!") instead of
  the plain "You won!". The model exposes the right headline; the view just renders it.

### 4.6 `APIClient` additions
- `giveawayEventMyResult: (jwt, eventId) async throws -> GiveawayMyResult`
  → `authenticatedGet("/v1/giveaway-events/\(eventId)/my-result")`.
- `submitGiveawayWinnerDetails: (jwt, eventId, GiveawayWinnerSubmissionRequest) async throws -> …`
  → POST `/v1/giveaway-events/\(eventId)/winner-submission`. Body fields are all strings, so this fits
  the existing `authenticatedPost(parameters: [String: String])` (or add a typed `Encodable` body —
  decide in implementation). Provide an explicit `testValue`/default (memory
  `project_swift_dependencies_testvalue`).

---

## 5. Correctness backstop (layered)

A promoted last-tapper winner must never be permanently stranded as "lost". Three layers, fast → safe:

1. **Immediate** — tap response (winner path; instant).
2. **Poll-while-open** (§4.1) — the foreground feed reconcile, on detecting a tapped contest closed,
   does one `my-result` check and flips if promoted. Covers the user who stays in-app through close.
3. **Targeted push** (§4.4, §7) — covers backgrounded / reinstall / second-device. Lossy by nature
   (APNs), which is exactly why layer 2 exists: push is the accelerant, not the correctness guarantee.

---

## 6. Task 0 — tap() failure path (carried over from M1 P1 review)

- Add `onError: (@MainActor (Error) async -> Void)?` to `GiveawayOverlayModel`, parallel to `onTap`.
- `tapButtonTapped()` routes a thrown error from the tap path to `onError`.
- `coordinator.tap` throws a typed error on genuine failure (network / 5xx); stays silent on 400
  (not-open-yet) and on success.
- `MainContainerModel.makePlayerModel()` wires `onError` to present a `PlayolaAlert`.
- Alert **only** on genuinely-unexpected failures; never on the expected 400 race.

---

## 7. Dependency: server "you won" push (contract for the server team)

Implemented in the server worktree that owns giveaway code (NOT in this iOS effort — avoids colliding
with the active `giveaways-event-contract-migration` / `giveaway-dashboard-events` / `giveaway-contract`
worktrees). iOS ships gated and goes fully live once this lands.

Fire a targeted push to the resolved winner's device ARNs at close, for **every** winner.

**Payload contract:**
```json
{
  "type": "giveaway_winner",
  "eventId": "evt_…",          // REQUIRED — idempotency key
  "stationId": "stn_…",
  "giveawayId": "gw_…",
  "prizeName": "…",
  "winningNumber": 9,
  "tapNumber": 5,
  "winnerUserId": "usr_…",
  "status": "closed",
  "occurredAt": "2026-06-23T18:30:00Z",
  "reason": "tap_win | last_tapper_fallback",
  "schemaVersion": 1,
  // recommended (lets the sheet skip the eligibility GET):
  "prizeDescription": "…",
  "prizeImageUrl": "https://…",
  "submissionCompleted": false,
  "canSubmitMailingInfo": true
}
```
If `submissionCompleted` / `canSubmitMailingInfo` are omitted, iOS GETs the detail before showing the
form for push-created participations. Prefer a data/silent push when feasible.

---

## 8. State model (mostly exists — confirm, don't reinvent)

- `GiveawayParticipationStatus`: `.tappedStandby` (now transient-only), `.resolvedWon(submissionCompleted:
  Bool)`, `.resolvedLost(toastShown: Bool)`, `.canceled`. **No new cases needed.**
- `GiveawayParticipation`: `id, stationId, prize…, winningNumber, tapNumber, status, tappedAt,
  winnerSheetPresentedAt`. Sufficient. (No `resolvedAt`/stale fields — no long-lived poll loop to bound.)
- `GiveawayMyResult`: matches `my-result`. Reused as the backstop decode type.
- New `GiveawayWinnerSubmissionRequest` (Encodable) for the POST body.
- New `GiveawayWinnerPush` payload decode type for the push handler.

---

## 9. Testing (XCTest, `@MainActor`, colocated; see CLAUDE.md + pfw-testing)

- **Coordinator.tap**: win → persists `.resolvedWon`; loss → persists `.resolvedLost`; 400 → no
  participation + no error; network/5xx → `onError` fired, no participation. (`expectNoDifference`.)
- **Backstop**: reconcile detects a `.resolvedLost` event closed → my-result winner → flips to
  `.resolvedWon`; my-result still loser → stays lost; my-result throws → unchanged.
- **Arbiter**: resolvedWon pending → presents once, sets `winnerSheetPresentedAt`; second observation →
  no re-present; multiple wins → oldest-first; resolvedLost → toast once, sets `toastShown`; blocking
  sheet up → defers.
- **Push handler**: flips loss→won + lets arbiter present; duplicate push → idempotent; already-submitted
  → no form; no local participation → constructs from payload.
- **Winner sheet**: valid form enables submit; submit success → `submissionCompleted=true` + dismiss;
  submit failure → sheet stays open + error; push-provenance with `canSubmitMailingInfo=false` → claimed
  state, no form.
- **Overlay**: `onError` invoked when `onTap` throws; loser reveal min-duration; strings present.
- No `Task.sleep` in tests (use the `continuousClock` dependency / synchronous doubles).

---

## 10. Out of scope (named, not silently dropped)

- Server push implementation (dependency §7).
- Artist congrats recording flow + the "willing to record a video" opt-in.
- Cross-station invite banner.
- Stale-participation GC / 24h TTL (no long-lived poll loop exists to require it).
```
