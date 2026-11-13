# Recorded shows (scheduled, in the app)

Status: **Scope, screens, data layer and implementation plan approved (2026-11-06); simplicity review (Phase 7) applied.** Ready for implementation via [implementation-plan.md](./implementation-plan.md).

## Base commits

- iOS (`playola-radio-ios`): `98a6d9835c832473da308a3546b11be0ec38969a` (= `origin/develop` at prerequisite check).
- Backend (`playola` monorepo): `origin/develop` `15e655d4c4f2fb261ca49f522022b8682d2a6e9f` (Phase 4; screens phase read `cc82f93a`). The local checkout at `/Users/brian/playola/playola` is stale; every backend read in this design is taken from `origin/develop`, not the working tree.
- Canvas: `design/playola-ios.pen`.

## Target surfaces

- **ios** — curator-side: create, build, schedule, edit, move and unschedule recorded shows; manage series.
- **backend** — whatever gaps the data-layer phase finds (see "Backend needs" below). The website already has a show builder for the same data (monorepo `design/features/one-time-shows-and-shows-list/`); iOS reuses its contracts wherever possible.

## Vocabulary

The user-facing names follow the planned rename. Code and API names are unchanged by this feature.

| UX word | Backend today | Notes |
| --- | --- | --- |
| **Show** | `Episode` (+ its `Airing`) | One recorded program; airs once in v1. |
| **Series** | `Show` with an `rrule` | Optional. A Show not in a series lives in a hidden one-time Series (`shows.isOneTime = true`) the curator never sees. |
| Airing | `Airing` | One scheduled broadcast. v1: at most one per Show (no reruns). |

**Screen names:** the curator destinations are **Curator Series list** and **Curator Series page**. Their user-facing navigation titles remain **Series** and the Series name, respectively. This keeps them distinct from the listener `seriesListPage` (Radio Shows).

## Scope

Let a station curator make a **recorded show** in the iOS app and schedule it, as a counterpart to the existing live-show runner (`ShowsPage` → AMA live runner).

### Agreed behavior

1. **Same building experience as a live show, minus the buffer.** The builder reuses the live runner's playlist rows and its add actions — **Audio** (voicetrack / intro / song intro), **Song** (the approved Search/Suggestions song picker), **Q&A** (pick a listener question from the inbox, record an answer, add the pair). No on-air timeline, buffer meter, fallback songs, or Start Show. Nothing is on air while building. The song picker offers **available songs only** — "request for next time" songs would produce no audio in a recorded show (Claude's call).
2. **Drafts.** A Show is a draft until it is scheduled. The curator can leave and come back at any time.
3. **Time is picked at the end.** A **Schedule** step replaces the live runner's Start Show.
4. **Creating a Show and creating a Series are separate actions; connecting them is obvious but never required.** (User, 2026-11-06: "I don't want curators to feel like they have to commit to a series when they just want to make a show.")
   - **Record a New Show** (on the Individual Shows list) goes straight to the builder and never asks about a series up front.
   - **Create a New Series** (on the Curator Series list) creates a Series directly. A Series can also be created from a Show's "Add to a series" control.
   - **From a Show:** an obviously-optional **"Add to a series"** control on the Show itself (empty by default), not buried in scheduling.
   - **From a Series:** **"Add a show"** → make a new Show in this series, or **add one of your existing standalone Shows**.
   - A Show can be **removed** from its series (back to standalone). (Claude's call; designed in the Series picker sheet.)
   - **Schedule step:** pick a date/time. If the Show is in a Series, that Series' **next open slots** are listed above the picker; tapping one fills the picker.
   - **Series have a repeating schedule** (user: "yes repeating schedule with slots"), e.g. "every Tuesday at 8pm". Slots are suggestions only; nothing is auto-scheduled and an empty slot simply plays regular programming. This deliberately diverges from the website, which removed weekly scheduling (see Existing contracts).
5. **Each Show in a Series is new content.** Series → many Shows; each Show airs once in v1.
6. **No show types for recorded shows.** A "pre-recorded AMA" is just a Show whose content is Q&A. Listener-facing per-type behavior (e.g. the live AMA "Ask a Question" prompt) does not apply. (Claude's recommendation; user agreed.)
7. **Listeners cannot tell a recorded show from a live one** (rerun labeling comes later). While a recorded Show airs:
   - the station gets the **LIVE badge** and floats to the top of the station list, exactly like a live show;
   - followers get the existing show-start push (playola #1120) when it starts, under #1120's rules: daytime starts only (8am–9pm Central), at most once a day per station, no per-airing guarantee;
   - the player looks the same, except the live-AMA "Ask a Question" prominence does not appear (no one is there to answer); the normal message button still works.
   - Existing "Radio Shows" listener page shows them; no new listener screens.
8. **After scheduling**, the curator can **edit content or move** a Show until it is **6 hours from air** (user, 2026-11-06). Inside those 6 hours, and while it airs, the Show is **locked**: no content edits and no moves. Renaming it and changing its Series still work (Phase 7, R4).
   - **Edit** reuses the builder; every change goes straight to the scheduled copy on the station schedule (see "Changes save automatically"). If a change makes the Show collide with something it can't overlap (another show, a live show, a giveaway), the change is refused with a clear message and the Show stays as it was.
   - **Unschedule** (was "cancel") removes the airing and returns the Show to **draft** (content kept), not delete. It stays available inside the 6-hour lock — it is how a curator changes a locked Show: **unschedule, edit, schedule again**. It is not available once the Show is on air (the server's existing last-minute cutoff still applies).
   - **Scheduling inside the 6 hours is allowed**; the Show is locked as soon as it is scheduled, and the Schedule step says so before the curator confirms. (Claude's call.)
   - The 6 hours is a **server rule**: the server enforces it and serializes its length; the client computes each airing's lock time from its air time and never hardcodes 6 hours.
9. **Series management** (reached from Upcoming → Series; a Show's series row opens the Series picker, per the approved screens): create a Series (title + optional repeating schedule); view its Shows and open slots; rename; change its repeating schedule. Changing the rule only affects which future slots are offered — Shows already scheduled keep their times.
   - **Curator Series page** (title = the Series name, **Edit** at top right): the amber repeating-schedule badge with a note that open slots are only suggestions; **NOT SCHEDULED YET** (the Series' drafts); **UPCOMING** (scheduled Shows and open slots in date order, each slot with an outlined **+ Add show**); an **Add a Show** button at the bottom. Aired Shows are not listed (no Past list in v1).
   - **Add a show** sheet (from a slot's **+ Add show**): titled with the Series and the slot's time. Offers **Record a New Show** (opens the builder for that slot) or **add one of your Shows**: drafts, plus already-scheduled Shows labeled "Moves here from <old time>" — adding one moves it into the slot. Locked Shows (inside 6 hours) are not offered. The bottom **Add a Show** button has no slot: a new Show's time is picked in the Schedule step, and an added existing Show keeps its time. Adding to a slot is two requests (schedule or move, then join the Series); if the second fails, an alert says so and the Show stays scheduled outside the Series (Phase 7, R2).
   - **Edit Series** sheet (Cancel / Save): Name; Repeats (Every week / No schedule — Phase 7, R1); Days (S M T W T F S chips); Time ("Starts at"); with the note that changing the schedule only changes open slots. **New Series** is the same sheet titled "New Series". **No Delete Series in v1** — the server has no way to delete a Series (`/v1/shows` has no DELETE route on `develop`).
10. **Entry points** (user, 2026-11-06 — round 1's combined Shows home was rejected as "too busy and confusing"): Going live and recorded shows are **separate screens**. The Station tab's links are two sections of nouns:
    - **SHOWS:** **Live** (today's curator Shows screen, renamed; confirmed by user 2026-11-06) and **Upcoming**. No Past link in v1 (Phase 7, R5).
    - **LIBRARY:** **Music** (today's Music Library), **Breakers** (today's Breakers Library).
    - **No schedule link.** The station schedule (today's Broadcast screen) is still opened by tapping the On Air Now card, as it is today.
    - **Every destination's title matches the link that opens it** (user, 2026-11-06). Today's "Shows", "Music Library" and "Breakers Library" screen titles are renamed to match.
    - **Upcoming** has two rows: **Series** and **Individual Shows**, each with a one-line count.
    - **Series** opens the Curator Series list, which reuses the listener's Radio Shows card (`SeriesCard`): one card per Series with its title, an amber repeating-schedule badge, an "UPCOMING SHOWS" heading with counts, and its next Shows as calendar-tile rows. **Open slots appear inside the card** as dashed rows with **+ Add show**. A **Create a New Series** button sits at the bottom. Tapping a card's title opens the Curator Series page (item 9).
    - **Individual Shows** lists **every** upcoming Show, each row led by the calendar tile (red month strip over the day) with the title, then day · time · length. A Show in a Series carries a grey badge with the Series name; a one-off has none. Drafts sit at the top with an amber pencil tile and "Not scheduled yet". A **Record a New Show** button sits at the bottom.

### Decisions from the builder check (user, 2026-11-06)

- **Changes save automatically** (user, 2026-11-06 — reverses "edits are held until Save"). There is no Save button and no leave-without-saving prompt. Every change to a Show — draft or scheduled — is saved as it is made, and a scheduled Show's place on the station schedule updates with it. If the 6-hour lock starts while the builder is open, the next content change is refused with the server's message and the builder switches to its locked state.
- **Q&A in a recorded Show — document, don't change.** Since `develop` `fd6b31201` (2026-09-23) answering a question only marks it answered; putting a Q&A on air is an explicit, separate step (`POST /v1/spins { listenerQuestionId, … }`) that also notifies the listener. Adding a Q&A to a recorded Show places the question audio and the answer audio as two ordinary segments of that Show. Consequences, accepted as-is: the same answered question may also be put on air separately ("it can get both"); a Q&A airing inside a recorded Show creates no `ListenerQuestionAiring` and does **not** notify the asking listener. No changes to Q&A broadcasting in this feature.
- **Start time and overlaps.** A Show starts at the first song break at or after the chosen time (existing scheduler behavior); the app shows it as "airs at about <time>". Scheduling or moving a Show so it overlaps another Show (or a live show / giveaway) is **blocked with a clear message** rather than silently pushed later — a series slot means what it says.

### Builder-check calls (Claude's calls, 2026-11-06 — user may override)

- **Existing web-made data:** iOS lists every Series and Show of the station, whoever made it. A Show whose airing is inside the lock window or on air is locked; aired Shows are not listed. Shows with more than one airing (web-made) are listed by their next airing and are read-only in iOS v1.
- **Repeating schedule richness:** every week only, on one or more days, at one time, in the **station's** time zone (not the device's; Central for every station in v1). The server accepts only this weekly form (the website editor already writes nothing else, and production holds no other rules as of 2026-11-11). If the app ever reads a rule it can't parse, it shows "Custom schedule" read-only and offers no slots. A slot is open when no Show on that station airs at that time. The Schedule step offers the next 8 open slots. Moving/unscheduling a Show reopens its slot.
- **Listener-facing title:** a standalone Show's title is its own (the hidden series mirrors it). Scheduled Shows appear on "Radio Shows" before they air, as web-made ones do today.
- **Show-start push:** already shipped by playola #1120 (`lib/showStartNotifications`); this feature adds nothing to it. It goes out when an airing's first spin airs, only for starts between 8am and 9pm Central, at most once per station per Central day, and is skipped if the station sent a manual or Ask Me Anything push in the prior 4 hours. So a recorded show is not guaranteed a push of its own.
- **What can be scheduled:** at least one piece of audio. No minimum or maximum length, and no "doesn't fit the slot" warning in v1.
- **Multiple editors:** all of a station's editors see and edit all its Shows and Series. Last write wins; no locking.
- **Saving a new Show:** nothing is saved until its first change (first piece of content or a rename), so an untouched "Record a New Show" leaves no empty draft.
- **Unschedule asks first** ("Unschedule <Show>?" / "Keep it scheduled").
- **Changing or removing a Show's Series keeps its air time.**
- **Add a show sheet** offers only drafts with at least one piece of audio.
- **A series slot less than 6 hours away**, picked in the Add a show sheet, opens the Schedule sheet set to that slot, so the "Locks right away" note shows before scheduling. (Inside the Schedule sheet, tapping a slot only fills the picker, so the note shows anyway.)
- **Overlaps are judged by the server:** the Schedule sheet shows the server's refusal and disables Schedule until the time changes; the app does no overlap check of its own.
- **"Airs at about"** before scheduling is the picked time; after scheduling the builder shows the server's air time.
- **Saving (Phase 5):** the builder (including the sheets it opens) sends one change at a time per Show, in order. A failed or uncertain save shows the server's message and refetches the Show; nothing is retried blindly. A new Show is created on its first change and keeps that id even if the content write after it fails, so no second draft appears. Leaving the builder doesn't cancel a save in flight.
- **A Q&A is added in one request** (question and answer audio together), so it never half-saves.
- **Which list a Show is in:** draft = no airings; upcoming = has an airing that hasn't ended; past = every airing ended (not shown in v1). Counts are of Shows, not airings. One airing per Show is an iOS rule, not a server rule.
- **Going live wins:** if the curator goes live while a recorded Show is due to start, the live show plays and the recorded Show doesn't air (existing server behavior).

## Non-goals

- Reruns / multiple airings per Show, and any rerun labeling for listeners.
- Show types for recorded shows.
- Deleting a Series (deferred — Claude's call; open question below).
- A Past list of aired Shows (Phase 7, R5; was a "Coming soon" placeholder).
- Every-other-week and other non-weekly repeating schedules in the app (Phase 7, R1).
- Per-station time zones (Phase 7, R3; every station is Central in v1).
- Any new listener-facing screen.
- The code/API rename of Episode→Show and Show→Series (separate effort).
- Warning curators when a series slot is approaching with no Show scheduled.
- Web changes (the website builder already exists).

## Open questions

- Delete a Series: deferred from v1. When revisited, decide what happens to its scheduled and draft Shows.
- Empty Curator Series list (no Series yet): not mocked; Claude's call is the page with only "Create a New Series". Mock it if the user wants.
- Delete a draft Show: not in the v1 screens (Claude's call, 2026-11-06). The backend supports deleting a never-aired episode; revisit if abandoned drafts pile up.

## Existing contracts

Backend facts below are from `origin/develop` `cc82f93a` and still hold at `15e655d4c`. Paths are under `server/src/` unless noted.

### Website builder already shipped (monorepo `design/features/one-time-shows-and-shows-list/`)

- A one-time Show = hidden `shows` row with `isOneTime = true` holding exactly one `episodes` row; title kept in sync on both. `episodes.showId` stays NOT NULL.
- `POST /v1/shows {stationId, title, isOneTime?, firstEpisodeTitle?}` (station editor) creates the series/wrapper and its first episode; returns 201 with `episodes[0]`.
- `GET /v1/episodes?stationIds=&showId=&includeSegments=&includeStation=&includeAirings=` — lists drafts too (`airings: []`); `createdAt DESC`, no pagination.
- `POST /v1/episodes` (409 on a one-time wrapper), `PUT /v1/episodes/:id` (rename), `DELETE /v1/episodes/:id` (never-aired only; removes future airings first; removes a one-time wrapper with it).
- `PUT /v1/shows/:id` (station editor) rename; renaming a one-time wrapper renames its episode.
- **Recurring/weekly scheduling was deliberately removed from the website** (spec non-goal: "Recurring or weekly scheduling of any kind"; `shows.rrule` kept in schema, unused). Evidence there: production 2026-11-02 had 36 shows, only 2 with an `rrule`; admin feedback said the weekly schedule wasn't used.

### Models (relevant columns)

| Table | Columns | Notes |
| --- | --- | --- |
| `shows` (UX: Series) | `id`, `stationId`, `title`, `isOneTime` (bool, default false), `rrule` (nullable, unused by web), `approximateDurationMS` | `episodes.showId` ON DELETE CASCADE |
| `episodes` (UX: Show) | `id`, `showId` NOT NULL, `title`; virtual `durationMS` = max(`offsetMS` + audioBlock duration) | No `stationId` (via show). `durationMS` is 0 unless segments are loaded **with** audioBlock (only `GET /v1/episodes/:id` does). |
| `episodeSegments` | `episodeId`, `audioBlockId` XOR `songRequestId`, `offsetMS`, `startingVolume`, `fades`, `position` | Server computes `offsetMS`/fades (`calculateShowSegmentTimings`) on every add/remove/reorder. Song-request-only segments produce **no spins**. A Q&A = two ordinary segments (question audio, then answer audio). |
| `airings` | `id`, `episodeId`, `stationId`, `airtime` | `spins.airingId` SET NULL. |

### Behaviors that matter to this feature

- **Scheduling (`POST /v1/airings`)**: station editor; 400 `LIVE_SHOW_AIRING_CONFLICT` on live-show overlap; 409 `MERCH_OUT_OF_STOCK` for giveaways. **No lead-time or past-time check on create**; overlapping airings are not rejected — a later one is pushed back to the end of the earlier spin group (`scheduler.ts:75-103`).
- **Move / cancel (`PUT` / `DELETE /v1/airings/:id`)**: 409 "This airing has started or starts within 2 minutes…" inside `SCHEDULE_EDIT_LEAD_MS` (2 min, `scheduler.ts:36`); move to a time < now+lead → 400 `AIRING_TIME_TOO_SOON`. DELETE keeps the episode (→ draft).
- **Lead time is not exposed** in any response. Errors are `{error:{message}}` with no machine code.
- **Content edits after scheduling go stale silently**: segment add/edit/remove never touch airings; `insertAirings` skips an airing that already has spins (`scheduler.ts:498-508`), and airings inside the playlist horizon get spins at creation.
- **Segment routes are `authenticate`-only** — no station-editor check (`api/episode/index.ts:60-74`).
- **LIVE badge already covers recorded shows**: iOS reads `GET /v1/stations/live` → `liveStatus: show_airing` for `airtime <= now <= airtime + segment durations` (`stations.lib.ts:2064+`).
- **No push when a scheduled airing starts.** The live-show go-live push (`liveShowGoLiveWorker`, 15s tick, dedup on `liveShows.liveNotificationSentAt`) only covers `spins.liveShowId`, and its copy is AMA-specific ("…is Answering Listener Questions Live Right Now").

### iOS today

- Curator `ShowsPage` ("Shows" → "Go live on your station" → one row, Ask Me Anything), pushed from `ArtistStationPage`. AMA live runner: `AskMeAnythingLivePage`.
- Listener `SeriesListPage` ("Radio Shows") groups `GET /v1/airings` by show; `RRuleFormatter` renders a show's rrule as plain English.
- iOS `Episode.showId` is a non-optional `String`.

### Backend needs

Designed in [endpoints.md](./endpoints.md) and [models.md](./models.md): content changes checked against the lock and overlaps in one transaction; a bounded schedule repair for Unschedule and move instead of today's rebuild; station-editor auth on segment routes; lead-time check on create; the 6-hour lock (length serialized on the station); moving a Show into and out of a Series; overlap rejection; LIVE status that follows a recorded Show's real playback; and the Series repeating schedule (weekly, Central time, slots computed on iOS).

## Acceptance criteria

Backend (each a server test):
- A content change or move is refused with `AIRING_EDIT_LOCKED` at exactly `airtime − 6h` and allowed 1 ms before; also refused once the Airing has spins, and after it has aired. Rename and Series change still work then. Unschedule still works inside the lock, and is refused inside the 2-minute cutoff.
- `GET /v1/episodes/:id` on a scheduled Show changes nothing in the database.
- Create, move and content change are refused with `AIRING_OVERLAP` when the interval touches another Airing, a live-show block, or a protected giveaway spin; end-to-start adjacency is allowed, including across midnight.
- Unschedule and move leave every other Airing's, listener-question airing's, live block's and giveaway spin's id and time unchanged.
- `POST …/segments { audioBlockIds: [q, a] }` adds both or neither.
- Two concurrent writes to one Show serialize.
- Writes to an Episode with Airings on two stations need edit rights on both.
- The show-start push is playola #1120's and is not changed by this feature: daytime starts only (8am–9pm Central), at most once a day per station, no per-airing guarantee.
- A recorded Show's station is LIVE from its first to its last spin, and not before.
- Creating or updating a Series with an `rrule` that isn't the weekly form (e.g. `INTERVAL=2`, `MONTHLY`) is refused with 400.

iOS (each a model test):
- Open slots: weekly on several days, across both DST transitions, skip taken times, stop at 8.
- A rule the app can't parse shows "Custom schedule" read-only, offers no slots, and a rename sends no `rrule`.
- New/Edit Series: Save stays disabled while Name is empty or while Every week has no day selected.
- Builder state follows `airtime − airingEditLockMS`; a refusal with `AIRING_EDIT_LOCKED` switches to Locked.
- Saves (builder and its sheets) are serialized; a failed save refetches.
- Add a show sheet: a failed Series step after a successful schedule shows an alert and leaves the Show scheduled.
- Show classification and counts match the rules above for drafts, upcoming and multi-airing Shows.

## Adversarial review (Phase 5, Codex `gpt-6-astra`, 2026-11-06)

Read-only review of spec, screens, models and endpoints against backend `15e655d4c`. Every finding was checked against code before its disposition.

| # | Finding | Disposition |
|---|---|---|
| 1 | GET episode writes song-request audio during the read, bypassing the lock | **Resolved** — GET skips that resolution for any Episode with an Airing (endpoints.md, GET detail) |
| 2 | Airings can be on a station other than the Episode's | **Resolved** — every Episode write authorizes and locks each such station (endpoints.md, Lock rule) |
| 3 | Move and Unschedule delete every later non-live spin | **Resolved** — one bounded repair for Unschedule, move and content (endpoints.md); DELETE becomes Changed (internals only) |
| 4 | Drift can exceed one song; a live block can stop a Show from airing | **Accepted** — chained drift is absorbed by the existing push-back; going live wins (Builder-check calls). The approval-13 wording was corrected, not reversed |
| 5 | "Giveaway announcement" had no persisted definition | **Resolved** — defined as spins the giveaway workflow persisted and linked; the backend plan names the relation, with a fallback (endpoints.md, Overlap rule) |
| 6 | Compound Series-plus-slot PUT lacked lock order and reservation handling | **Resolved**, then **superseded by R2** (Phase 7) — the compound PUT was dropped; Add a show makes two requests |
| 7 | Rebuilding partially played or materialized airings was undefined | **Resolved** — the lock (6 h) is longer than the playlist horizon (4 h, `scheduler.ts:162`), so editable Shows normally have no spins; the rare case uses the bounded repair |
| 8 | A Q&A was two POSTs and could half-save | **Resolved** — `audioBlockIds` adds both in one request |
| 9 | Short Shows or worker downtime can miss the push | **Accepted** — discovery is "started and not ended"; no late push for a Show that is over (models.md, Airing) |
| 10 | Detail GET has no `includeAirings` today | **Resolved** — documented as an added param |
| 11 | Autosave had no failure semantics | **Resolved** — Builder-check calls "Saving (Phase 5)"; screens.md conventions |
| 12 | Recurrence anchor, week start and DST undefined | **Resolved** — expansion rules (models.md, Show). The server still only length-checks, because the admin web editor writes other rule kinds |
| 13 | Multi-airing and mixed past/future classification undefined | **Resolved** — classification call; multi-airing Shows are read-only and excluded from pickers |
| 14 | Lists are unbounded; aired history uses current audio | **Accepted** — existing endpoints are already unpaginated, and stations are small (36 Series in production on 2026-11-02); implementation measures the largest station; no Past list in v1 (Phase 7) |
| 15 | Title authority on a Series change; the website can still delete a Series by deleting its last Show | **Resolved / accepted** — the Episode title is authoritative and a new wrapper copies it; the website's existing last-show delete is left as is (Delete Series deferred) |
| 16 | Missing loading/error/empty states; slot under 6 h from Add a show; builder → Series page | **Resolved** — conventions note and Add a show path (screens.md); item 9 now matches the approved screens. Empty Series list is not mocked (see Open questions) |
| 17 | Acceptance criteria not testable | **Resolved** — Acceptance criteria section |

No blocking findings remain.

## Simplicity review (Phase 7, Codex `gpt-6-astra` + Claude, 2026-11-06)

Every disposition was checked against `origin/develop` (backend `fd456a53`, iOS `1eaefdb0`).

| # | Finding | Disposition |
|---|---|---|
| S1 | Merge the two UI PRs | **Applied** — four PRs: B1, B2, I1 (data layer), I2 (builder, sheets, lists, Station tab) |
| S2 | Slot occupancy can use the existing `getAirings` | **Applied** — no new airings endpoint or field |
| S3 | Upcoming doesn't need Airings for slots | **Applied** — only Curator Series list, Curator Series page and Schedule sheet fetch them |
| S4 | `editableUntil` duplicates `airtime − lock length` | **Applied** — dropped; lock = not ended and (inside 6 h or has spins); the client computes it from `airingEditLockMS` |
| S5 | Error codes nobody branches on | **Applied** — only `AIRING_EDIT_LOCKED` and `AIRING_OVERLAP`; no `data.conflict`; other refusals are message-only |
| S6 | New airing-window and duration helpers duplicate existing ones | **Applied** — generalize `embedAiringTimes`; switch batched `episodeDurationsByEpisode` to `endOfMessageMS` |
| S7 | New calendar tile duplicates `CalendarDateBadge` / `ScheduleBadge` | **Applied** — reuse both (time-zone param, draft variant) |
| S8 | Separate saver object | **Applied** — a private task chain inside the builder model |
| S9 | Several builder-state types | **Applied** — one `CuratorEpisode.state(now:)` |
| S10 | One iOS write path via compound `PUT /v1/episodes` | **Superseded by R2** — the app keeps the existing airings calls |
| S11 | Defer the LIVE/voicetrack fix | **Rejected** — spec item 7; recorded Shows are mostly voicetracks, so without it the badge lights hours early |
| S12 | Drop the "can't remove the last audio of a scheduled Show" rule | **Rejected** — keeps "scheduled Shows have audio" true with the same check |
| R1 | Repeats: every week only | **Accepted by user** — no `DTSTART`, anchor or formatter change; web-made other rules are read-only |
| R2 | Add a show = two requests, not a compound PUT | **Accepted by user** — schedule/move first, then join the Series; failure alert |
| R3 | No per-station time zone | **Accepted by user** — constant `America/Chicago`; no column, migration or admin field |
| R4 | Rename and Series change aren't locked | **Accepted by user** — lock covers content and moves only |
| R5 | Merge screens | **Accepted by user** — no Past placeholder; one Locked builder state; Schedule and Pick a time are one Schedule sheet |

## Design deliverables

- Screens: [screens.md](./screens.md)
- Endpoints: [endpoints.md](./endpoints.md)
- Models: [models.md](./models.md)
- Implementation plan: [implementation-plan.md](./implementation-plan.md)

## Approval log

1. 2026-11-06 — Scope (this file's "Scope", "Non-goals", "Vocabulary") agreed in chat over the Phase 1 conversation: series hierarchy, UX naming, both entry points, time-at-end, no types, listeners see no difference, edit/move/cancel until the server lead time, cancel→draft, series management (view/rename/change schedule).
2. 2026-11-06 — Revision: Show and Series creation are separate actions with obvious optional linking (incl. adding an existing standalone Show to a Series); Series keep a repeating schedule with suggested slots (user, after being told the website dropped it). Supersedes the "series picked in the Schedule step / New series… inline" wording of revision 1.
3. 2026-11-06 — Builder-check answers: edits held until Save; Q&A behavior documented with no broadcasting changes; song-break start + block overlaps. Claude's calls listed under "Builder-check calls".
4. 2026-11-06 — Round 1 Shows home (three combined layouts) rejected as too busy. Approved instead: Station tab with SHOWS (Go Live / Record a Show / View Schedule) and LIBRARY (Music / Breakers) sections; Recorded Shows as a plain upcoming list with a Record a New Show button, plus its empty state; drafts at the top of that list; Series reached only through a Show (no series list, no New Series button). Back button uses the app's standard look (chevron only, centered title). Supersedes item 10's original "Shows screen grows" wording. Follow-up same day: each screen's title matches its Station link.
5. 2026-11-06 — User replaced the SHOWS links with nouns: **Live / Single Show / Series**. This brings back a Series list (with Create a New Series), supersedes entry 4's "Series reached only through a Show", and drops the schedule link (On Air Now card still opens it). Claude's calls: Single Show lists only Shows not in a Series; Series rows show the repeating schedule and upcoming count.
6. 2026-11-06 — Live / Single Show / Series rejected on sight. Replaced with SHOWS: **Past** (Coming soon) and **Upcoming** → Series (list → detail with shows and open slots) or Individual Shows (all shows, series-name badge). Supersedes entry 5's Single Show list (which hid series shows). Live link kept at the top pending user confirmation.
7. 2026-11-06 — User asked whether anything in the design file beat plain lists. Approved ("love it"): Series as Radio Shows-style cards with open slots inside, and Individual Shows with calendar tiles. The plain-list versions are superseded.
8. 2026-11-06 — Series page, Add a show sheet (slot moves an already-scheduled Show; no aired Shows on the page; bottom Add a Show picks its time in the Schedule step) and Edit Series sheet consolidated as the approved design, together with the Show builder (draft with unsaved changes; to be restyled), and the rejected round 1 home layouts and superseded plain lists removed from the design file. Still open: Delete Series, and whether the Live link stays.
9. 2026-11-06 — User reversed "edits are held until Save": changes save automatically and update the scheduled Show right away. New rule: a Show is locked (no edits, no moves) within 6 hours of air; to change it then, unschedule, edit, and schedule again. Supersedes item 8's server-lead-time cutoff and backend need 9 (save-as-one-step). Claude's calls: scheduling inside 6 hours is allowed and locks immediately, with a note in the Schedule step; unschedule stays available until the show is on air.
10. 2026-11-06 — No Delete Series in v1: the server has no Series delete route. (Server note: deleting a Series' last Show also deletes the Series — `deleteEpisode` on `develop`. This matters only if Show delete is added.)
11. 2026-11-06 — Live link confirmed: SHOWS is Live / Past / Upcoming.
12. 2026-11-06 — Remaining screens approved ("love it"): Show builder restyled (Draft, Scheduled, Airing soon, On air), Unschedule confirmation, Schedule sheet (series open slots), Pick a time (locks right away, overlap), Series picker (add / change, with remove), New Series. `screens.md` written; the old builder frame was replaced. Claude's calls listed under "Builder-check calls".
13. 2026-11-06 — Data layer approved ("all approved"): `models.md` and `endpoints.md` as drafted from the Codex architect consult against `15e655d4c`, trimmed by Claude. Calls approved with it: every station's time zone defaults to Central (admins change it); overlaps judged on the picked time (drift of up to one song is absorbed by the scheduler's existing push-back); a giveaway blocks its announcement and its show, not the contest window; one "on now" push per airing (rare duplicate on crash; no cooldown exists); every-other-week starts with the next occurrence after saving, and older apps show no schedule line for it; locked means read-only except Unschedule (rename and series changes included); website moves/renames inside 6 hours and overlapping schedules are now refused with a message.
14. 2026-11-06 — Implementation plan approved, then the Phase 7 simplicity review. User accepted all five reversals ("1. yes drop it 2. yes 3. yes 4. yes 5. yes"): R1 every week only; R2 Add a show makes two requests (schedule/move, then join the Series); R3 one fixed time zone (Central), no station column; R4 locked Shows can still be renamed and moved between Series; R5 no Past placeholder, Airing soon + On air merged into Locked, Schedule + Pick a time merged into one Schedule sheet. Claude's non-reversal simplifications (S1–S9) applied with them. Supersedes entry 13's "every station's time zone defaults to Central (admins change it)", "every-other-week…", and "locked means read-only except Unschedule (rename and series changes included)", and entries 11–12's Past link, Airing soon/On air states and Pick a time sheet.
15. 2026-11-10 — Mockups updated to match entry 14 (no new design decisions): Past link and frame removed; Every-other-week option removed from Edit Series and New Series; Airing soon became the single Locked state (Rename and Series "Change" kept, "Shows lock 6 hours before they air" banner); Series-slots, locks-right-away and overlap frames are now one Schedule sheet (Cancel / Schedule bar, open slots when in a Series, then the date/time picker). Final PNG, HTML, design-token and per-screen JSON exports regenerated.
16. 2026-11-11 — Second CodeRabbit review decisions: (1) a create whose response is lost may leave an extra draft — accepted, not handled in v1; (2) repeating schedules are weekly-only everywhere: the server refuses any other `rrule` on Series create/update, the website drops its non-weekly display text, and iOS shows an unparseable rule as "Custom schedule" read-only (supersedes the "legacy rule" handling in entries 13–14); (3) New/Edit Series Save is disabled while Every week has no day selected; (4) the read-only rule state on Edit Series has no separate mockup. Mockups: open-slot wording removed from the Series picker; button layers renamed; the sample "Kitchen Table Songs" series is now weekly ("Every Wednesday at 8pm", "1 show · 1 open") because every-other-week is no longer allowed.
17. 2026-11-11 — iOS ships one screen at a time into the integration branch `feature/recorded-shows` (off `develop`), merged to `develop` once all screens are in. This replaces the single I2 PR; the order follows the tap path (Station tab + Upcoming, Individual Shows, builder, Schedule sheet, Series sheets, Series list, Series page + Add a show). See implementation-plan.md.
18. 2026-11-12 — B2.2 dropped: playola #1120 already pushes followers when a show starts, and Brian accepted #1120's rules for recorded shows (daytime starts only, at most once a day per station, no per-airing guarantee). No `Airing` column is added. B2 shipped as the LIVE-status fix only (#1142). Supersedes entry 13's "one 'on now' push per airing".
