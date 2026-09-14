# Live Shows — Backend Implementation Plan

Architected through Codex (`gpt-6-astra`, read-only) against the real backend `/Users/brian/playola/playola/server`. This is the backend needs list; iOS is an API consumer only.

**What this is.** A generic **live show** primitive: a curator goes live on their station with a short pre-assembled opening (~10 spins), the server drops it into the live schedule at the next safe boundary plus 3 trailing "filler" spins, and the curator edits the queue **through the existing schedule editor** while it airs. If the curator disappears, the fillers air and the station returns to its normal rotation on its own. "End show" appends a closing spin and drops the leftover fillers. The first show `type` is `ask-me-anything` (answering listener questions on-air); later types (e.g. `song-requests`) reuse the same primitive without the Q&A layer.

**Status (2026-09-13):** this plan replaces the original "AMA Show Runner" design after the product owner rejected that as over-engineered. The heavy design (dedicated `AmaSession` table, a 15s continuous-autofill worker, a stateless fallback deck, measured-duration readiness gating, revision-based optimistic concurrency, a bespoke `withStationScheduleMutation` boundary) is **gone**. See §Design history for exactly what was dropped and why it was safe. The core insight: a live show follows the *same* scheduling rules as the normal broadcast schedule, so it reuses the existing editor; the only genuinely-new work is four small scheduler guards, a slim identity table, filler maintenance, a go-live push, and a deferred Q&A-answer mode.

## Headline architecture calls

1. **Reuse the existing schedule editor unchanged for live edits — do NOT build a parallel API or a live worker.** Add/reorder/delete during a live show are the existing `insertSpin`/`moveSpin`/`deleteSpin` + airing ops. The curator's client passes a `liveShowId` it received on go-live; the spins carry that FK. There is no continuous auto-fill loop and no live-repair worker: the 3 fillers are the entire abandonment safety net, and the station's own rotation resumes behind them.

2. **Live content is plain, individually-editable spins tagged by `liveShowId` — never an Airing and never one show-wide `spinGroupId`.** Airing-delete restrictions and whole-group move semantics (`scheduler.ts:885`, `:1044`, `:834`) would defeat item-level editing. The only `spinGroupId` in a live show is a Q&A question→answer pair (two spins that move/delete together).

3. **The 2-minute commitment horizon is inherited, not added.** `deleteSpin` (`scheduler.ts:889`, `SPIN_TOO_SOON_TO_DELETE`), `moveSpin` (`:1059`, `SPIN_TOO_SOON_TO_MOVE`), and insert/move targets (`:1125`, `SPIN_TARGET_TOO_SOON`) already reject edits to any spin airing within 2 minutes. Live edits call these exact functions, so mid-air editing is safe by construction with **no new horizon constant**. (Codex flagged that this check is *leaky* in the general editor — insert validates the un-overlapped airtime before overlap subtraction (`:1291`, `audioBlockScheduling.ts:136`), rewrites the anchor's fades even if it already started (`:1359`), and airing update/delete bypass the horizon entirely (`:742`, `airings.lib.ts:162`). Those are pre-existing conditions affecting all edits equally; hardening them is **out of scope** for this feature unless we decide otherwise.)

4. **Takeover is insertion, not replacement — so rotation is preserved, not regenerated.** `insertSpin` shifts subsequent content later (`scheduler.ts:1332`); the station already keeps ~4h of rotation scheduled ahead (`createSchedule` continues from the last spin +4h — `:129`, `:298`; the 15-min worker maintains it — `worker.js:54`). Dropping the live content + fillers in pushes that rotation back; when the fillers finish, it plays immediately. **No seam gap and no dependence on the 15-min worker.** (This is why the heavy plan's "≥20-min continuation" safety net is unnecessary: we never delete the rotation that's already there.)

## Schema (PR1)

| Table / column | Definition |
|---|---|
| `liveShows` | `id` (uuid), `stationId` (FK), `curatorId` (FK — the user who started it), `type` (ENUM, first value `ask-me-anything`), `endingSpinId` (uuid FK → spins, nullable), `createdAt`/`updatedAt`. **No status/wrap/revision/count columns** — liveness and start/end times are derived from member spins. |
| `spins.liveShowId` | uuid FK → `liveShows`, nullable, default null. Membership tag; everything live keys on it. `ON DELETE RESTRICT` (never silently drop aired live history). |
| `spins.isFiller` | boolean, default false. Marks the just-in-time filler spins so they can be identified for tail-maintenance and removed at `end`. |

- `endingSpinId` makes `end` **idempotent** (retry sees it set, returns the existing ending time) and distinguishes "ending queued" (set, may still be airing) from a show that simply expired. "Ended normally" = has `endingSpinId`; "abandoned" = no `endingSpinId` and the last member spin is in the past. Both derivable, so no `canceledAt`/`endedAt`.
- **One live show at a time per station** is enforced in application logic inside the station lock (reject start if the station already has a live show whose member spins extend into the future), not a DB index — there's no status column to build a partial index on, and the invariant is cheap to check under the lock.
- No backfill; existing spins get `liveShowId = null`, `isFiller = false`.

## PR breakdown (dependency-ordered; `develop` deployable after each)

| PR | Goal / files | Completion criterion |
|---|---|---|
| **1 — Schema + scheduler guards + liveness reads (dark)** | Migrations (above). Make the scheduler **live-show-aware without any creation path**: (a) protect `liveShowId` spins wherever the scheduler currently treats a spin as disposable by checking `airingId` — episode insertion (`scheduler.ts:446`), LQ insertion (`:627`), airing removal suffix-delete (`:742`); (b) reuse the existing station Redis lock (`schedulingLock.ts`, today only `createSchedule` takes it and reads *before* acquiring — `:103`,`:121`,`:240`) around the participating writers, moving the state read **inside** the lock and wrapping each edit in one transaction; (c) batched liveness annotation on station/list reads. | Existing scheduler tests green; a seeded `liveShowId` spin survives episode/LQ/airing preemption; concurrent generic writers serialize on the lock (no partial-write interleave — `:1401`,`:1430`); station-list adds exactly one batched liveness query; **no way to create a live show yet.** |
| **2 — Endpoints + filler + Q&A defer + push** | `src/api/liveShow/*` (2 endpoints, below) mounted under `api/station`; filler-tail maintenance in the edit path; deferred Q&A-answer mode in `listenerQuestions.lib.ts`; one durable go-live notification job on the existing BullMQ (`queue/index.ts`). | Start/edit/end acceptance + the failure drills (below) pass. Deploy, then **allowlist stations** and expand. |

Migrations deploy fully before PR1's runtime rolls out (Sequelize selects the new columns as soon as they're declared). Readers/protection before writers.

## Endpoints (PR2)

Two new write endpoints; everything else reuses existing routes.

- **`POST /stations/:stationId/liveShow` `{ type, audioBlockIds: [~10] }`** — under the station lock, in one transaction: find the next **safe** boundary (a song boundary ≥ the 2-min horizon that doesn't collide with an already-scheduled Episode/LQ airing — reuse the scheduler's existing hard-boundary handling), batch-insert the explicit spins + **3 trailing fillers** (one operation, not N committed edits — `audioBlockScheduling.ts:113`), create the `liveShows` row, and enqueue the go-live push job. Returns `liveShowId` + derived `scheduledStartsAt`/`scheduledEndsAt`.
- **`POST /stations/:stationId/liveShow/:liveShowId/end` `{ audioBlockId }`** — under the lock, in one transaction: append the ending spin after the last live/filler spin, set `endingSpinId`, and remove the still-removable (future, outside the horizon) fillers. Idempotent via `endingSpinId`. Passing `:liveShowId` prevents a delayed request from ending a later show. Returns the effective ending time.

Live editing (add/reorder/delete items, answer Q&A) uses the **existing** spin/airing endpoints with the spins already tagged `liveShowId`; those endpoints gain filler-tail maintenance and (for the `ask-me-anything` type) the deferred-answer behavior.

## Filler tail

- Maintain **3 replaceable *future* fillers after the live content**, re-ensured after each edit (remove the future ones, re-append 3 fresh at the live-show tail — defined as the show's tail *before ordinary rotation*, not the station playlist's tail). "Exactly 3" holds only outside the 2-min window: once a filler crosses into the commitment window it can't be moved/removed, so a fresh edit tops the *future* fillers back to 3 behind it.
- Curator keeps adding real content faster than it airs → the show continues indefinitely (fillers are just the rolling buffer). Curator falls behind / disappears → up to 3 fillers air, then the shifted rotation resumes and the show is over (no `endingSpinId`, last member spin now in the past → not live). A curator returning after that starts a *new* show.
- `end` removes only the still-removable fillers; any filler already committed inside the window airs before the ending spin.

## Concurrency (write-by-write)

One curator editing sequentially from one client eliminates curator-vs-curator races, and the natural passage of airtime is not a competing writer (the scheduler derives unfinished spins via `endOfMessageTime > now` — `scheduler.ts:339`, a deadline concern, not a mutation). The remaining real writers on the same station schedule are: the 15-min rotation top-up (`:298`,`:157`), scheduled Episode/LQ insertion (`:444`,`:626`), giveaway congrats `insertSpin` (`giveawayEvents.lib.ts:794`), and airing edit/delete (`:742`). **Mitigation is minimal and reuses existing machinery:** take the existing (non-reentrant — `schedulingLock.ts:43`) station lock around those writers with the state read moved inside it, and put each edit + its filler repair in one transaction. No new command subsystem, no bespoke boundary. A transaction alone is insufficient (it doesn't serialize competing stale reads); the lock is what serializes.

## Q&A layer (`ask-me-anything` type only)

Today's answer flow is **not** "just insertSpin": it links the answer, picks a random future airtime, creates an LQAiring, and immediately notifies the listener (`listenerQuestions.lib.ts:191`,`:220`,`:514`); `insertAirings` later materializes the pair and *deletes* overlapping content (`scheduler.ts:588`,`:626`). For a live show:

- Add a **deferred-answer mode**: record + link the answer, mark the question answered, **skip** the random-airtime LQAiring creation and its listener notification (preserve today's default for existing clients — the auto-airing path stays, just bypassed during a live show; it's slated for removal later anyway).
- Insert the question→answer **pair** into the live queue through the normal editor as a pair-sized `spinGroupId` group (never a whole-show group). LQAiring identity is retained where the listening timeline needs it.
- The generic primitive itself only needs ordered audio + `liveShowId` membership; question status, answer recording, and listener messaging stay type-specific.

## Liveness, badge, listener-list promotion

- **Liveness is derived, not stored.** A station is "on air now" iff it has a member spin (any of live content, filler, or ending) with `airtime <= now AND endOfMessageTime > now`. This means *scheduled on-air content*, not proof the curator is still connected — which is the correct, cheap definition (a committed-but-future takeover doesn't show live early, and an abandoned show stops showing live the moment its last filler ends).
- **Batched into the station-list assembly:** collect distinct station ids in the list/controller path (`stationList.controller.ts:18`, `stationLists.lib.ts:81`,`:131`), issue **one** additional query for current live membership joined to `liveShows`, annotate the returned stations (`liveShowId`, `type`), and stable-sort live items first (lists are otherwise ordered by `sortOrder`). Apply the same helper to the id/slug reads and to the separate all-stations path (`stations.lib.ts:524`, currently ordered by curator name). URL stations get nothing.

## Go-live push (PR2)

No generic scheduled-push exists — `publishToTopic` fires immediately (`pushNotificationService.ts:265`). The pattern to follow is the giveaway worker, which detects real show start via spin airtimes and creates a deduplicated pending notification (`giveawayWorker.ts:291`). **Add one durable go-live job per `liveShowId`** on the existing BullMQ (`queue/index.ts`) — a notification handler, not a show runner. At fire time, re-read member-spin timing and: rescheduled later → defer; canceled/absent/past → suppress; currently live → send + dedup. Cancel/reschedule the pending job on relevant edits but keep the execution-time validation as the source of truth (edits recalculate downstream airtimes — `scheduler.ts:1340`).

## Design history — what the original plan dropped and why it was safe

The prior "AMA Show Runner" plan was audited by a two-provider simplicity gate (Codex + Claude Opus) and then rejected wholesale by the product owner in favor of this design. What was removed:

| Heavy-plan feature | Disposition |
|---|---|
| Dedicated `AmaSession` subsystem | **Dropped** — a slim `liveShows` identity row suffices; live content is ordinary editable spins, not a reconstructed Airing/group. |
| 15s continuous-autofill worker + fallback deck + presence counter | **Dropped** — 3 fillers + the station's own rotation cover abandonment. Indefinite show continuation and continuous live-repair are *genuinely lost*, and that matches the intended product (a show expires after its content). |
| Shared `withStationScheduleMutation` boundary (the pass-2 reversal) | **Shrunk to its real minimum** — reuse the *existing* station Redis lock for the handful of concurrent writers + one txn per edit. The reversal's concern was real (lock-free writers) but the fix is far smaller once there's no live worker adding a second writer. |
| Measured-duration readiness gating (`measuredDurationMS`) | **Dropped** — the existing editor accepts client duration (`audioBlocks.lib.ts:1049`) and checks AudioBlock existence (`scheduler.ts:1271`); fillers/rotation absorb a wrong duration. Real residual risk only for freshly-recorded Q&A answers inside the live sequence; accepted for v1. |
| Revision-based optimistic concurrency, status enum, wrap-reason, receipts | **Dropped** — single sequential writer under the lock; liveness/end derived from spins + `endingSpinId`. |

The four things this design *does* add over "reuse the editor untouched" — `liveShowId` preemption protection, lock reuse for concurrent writers, filler-tail maintenance, and the deferred Q&A mode — are the specific places the "same rules as the regular scheduler" claim is false in the real code, each verified file:line above.

## Migration, regression, release

- **Migration rules:** no backfill; `spins.liveShowId` / `liveShows.endingSpinId` FKs `ON DELETE RESTRICT` (no silent removal of aired history); down migration drops columns/constraints before the `type` enum, never while live-show-aware binaries or retained live rows remain. Rollback after enabling writers: keep the protective reader version, disable the create endpoint, let active shows drain, then roll back.
- **Touched-area regression (run in full — this edits shared scheduler code):** all `scheduler.test.js` groups (show boundaries, insertion, LQA insertion, airing deletion/reposition, all spin ops, grouping, 3-hr top-ups, preview, rotation persistence); `audioBlockScheduling.test.ts`, `SchedulerModels.test.js`, `schedulingLock.test.ts`; Spin/Airing/Episode lib+API; ListenerQuestion + LQAiring (deferred-answer mode); station schedule/live, station-list, listening-timeline, tapes; giveaway scheduling/events + the congrats `insertSpin` path (now serialized on the lock).
- **Release-gate failure drills** — expected behavior in all: committed playback drains into rotation. Curator abandons mid-show (fillers air → rotation). Edit attempted inside the 2-min window (rejected by the existing horizon). Episode/LQ scheduled over an active show (blocked by the `liveShowId` protection / hard-boundary at start). Giveaway congrats insertion during a show (serialized on the lock). `end` request retried after a lost response (idempotent via `endingSpinId`). Delayed `end` for an already-replaced show (rejected via `:liveShowId`). Go-live push fires after the show was edited/canceled (re-validated at fire time).

## Open items
- **Horizon leak (headline call 3):** the general-editor 2-min check is incomplete. Left out of scope; flag if you want it hardened as part of this work.
- The API path/verb shape (`POST …/liveShow` / `…/end`) follows Codex's proposal; confirm against the repo's existing station-route conventions at implementation time.
