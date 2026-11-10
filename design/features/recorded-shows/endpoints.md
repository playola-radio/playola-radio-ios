# Recorded shows — Endpoint changes

Backend: `playola` monorepo `origin/develop` `15e655d4c4f2fb261ca49f522022b8682d2a6e9f` (re-checked at `fd456a53` for the plan). Paths are under `server/src/`.
UX "Show" = `Episode`; UX "Series" = `Show`. No new routes, no PATCH.

| Change | Method | Path | Auth | Purpose |
|---|---|---|---|---|
| Changed | GET | `/v1/stations/:stationId` | authenticated | Return `timezone` (constant) and `airingEditLockMS` |
| Changed | GET | `/v1/stations/live` | authenticated | LIVE status follows a recorded show's actual playback |
| Changed | POST | `/v1/shows` | station editor | Accept a repeating schedule when creating a Series |
| Changed | PUT | `/v1/shows/:showId` | station editor | Validate the schedule |
| Changed | GET | `/v1/episodes` | authenticated | Correct lengths; Airings carry start and end times |
| Changed | GET | `/v1/episodes/:episodeId` | authenticated | Optional Airings; no writes during the read |
| Changed | PUT | `/v1/episodes/:episodeId` | station editor | Move a Show into or out of a Series |
| Changed | POST | `/v1/episodes/:episodeId/segments` | station editor | Add content (one or several pieces); lock and overlap checks |
| Changed | PUT | `/v1/episodes/:episodeId/segments/:segmentId` | station editor | Reorder; lock and overlap checks |
| Changed | DELETE | `/v1/episodes/:episodeId/segments/:segmentId` | station editor | Remove content; lock check |
| Changed | POST | `/v1/airings` | station editor | Lead-time, has-audio and overlap checks |
| Changed | PUT | `/v1/airings/:airingId` | station editor | Six-hour move lock and overlap check |
| Changed | DELETE | `/v1/airings/:airingId` | station editor | Same API; removes only this Show's spins |

## Shared contracts

**Errors** keep `{ "error": { "message" } }`. Two refusals add a machine code in the already-serialized `error.data` (`api/apiError.js:148`); iOS shows `message` and branches only on these codes. Every other refusal is message-only.

| Code | Status | Meaning |
|---|---|---|
| `AIRING_EDIT_LOCKED` | 409 | The Show is locked: it airs within 6 hours, is on air, or has aired |
| `AIRING_OVERLAP` | 409 | The Show's time would overlap another Show, a live show, or a giveaway |

```json
{
  "error": {
    "message": "This overlaps Fall Favorites, which airs 7:00–7:38 PM. Pick a time after 7:38 PM.",
    "data": { "code": "AIRING_OVERLAP" }
  }
}
```

The message names what it overlaps, is formatted in `Station.timezone`, and includes the date when the conflict is on another day.

**Lock rule** (one check in `lib/airings`, shared by the content and move routes below): an Episode is locked when it has an Airing that has ended, or an Airing that hasn't ended and either `now >= airtime − RECORDED_SHOW_EDIT_LOCK_MS` (6 h) or already has spins. Locked means no content change and no move. Rename and Series changes are not locked — they change neither content nor air time. Unschedule ignores the lock (it keeps its existing 2-minute cutoff). Moving an unlocked Airing inside 6 hours is allowed and locks it at once. Checks run after taking the scheduling lock. An Episode can have Airings on more than one station (web-made; `deleteEpisode` already handles this at `lib/episodes/episodes.lib.ts:388`): every locked-route write authorizes **each** station that has one of its Airings, and takes their scheduling locks in `stationId` order.

**Overlap rule** (one validator shared by create, move, and scheduled content changes): the candidate interval is `[airtime, airtime + episode.durationMS)`, checked against other Airings on the station (with or without spins), live-show blocks, and giveaway announcement spins; the Airing being moved or checked is excluded. Adjacent intervals are allowed. This is a nominal check at save time: the existing "start at the next song break" rule can still shift a Show by about a song when it materializes (chained back-to-back Shows add up), and the existing push-back at materialization handles any resulting touch. A live show that is running when a recorded Show would start takes precedence and the recorded Show does not air (existing `liveShowBlocksAiringStart`, `scheduler.ts:432`). A giveaway announcement is a segment of the giveaway's Episode and each run is tied to one Airing (`giveawayEvents.airingId`, NOT NULL), so the Airing check already covers it. Replaces today's silent push-back at scheduling time (`scheduler.ts:75`) and today's 400 `LIVE_SHOW_AIRING_CONFLICT`.

**Content changes never touch spins.** An Airing with spins is locked, so an editable Show has none. Segment add / reorder / remove apply the change, recompute offsets/fades, and run the lock and overlap checks in one transaction under the scheduling lock(s) — commit both or neither. The Airing picks up the new content when it materializes (about 4 hours ahead, `scheduler.ts:162`).

**Bounded repair** (one helper in `lib/scheduler`, used by Unschedule and move): remove only this Airing's spins, close the gap with ordinary rotation (existing `reflowAfterRemoval`, `scheduler.ts:1835`), and, for a move, re-materialize this Airing at its new time (`insertAirings` with `windowOverride`). Other Airings, listener-question airings, live blocks and giveaway spins keep their ids and times. Replaces today's suffix delete in move and DELETE (`deleteAiringFromSchedule`, `scheduler.ts:950`, which removes every later non-live spin). Pattern: `deleteListenerQuestionAiringFromSchedule`, `scheduler.ts:1912`.

**Airing times:** wherever an Airing is returned, the existing `embedAiringTimes` (`lib/stations/stations.lib.ts:740`, generalized) fills `startTime` / `endTime`.

**Station editor** = admin, or the station's owner/contributor, via the existing permission helper (`lib/stations/stations.lib.ts:1481`).

## GET /v1/stations/:stationId
- **Change:** Changed
- **Auth:** authenticated (unchanged)
- **Path params:** `stationId` (UUID)
- **Query params:** unchanged
- **Request body:** none
- **Response `200` — added fields** (both server constants, the same for every station):
  ```json
  { "id": "1111…", "timezone": "America/Chicago", "airingEditLockMS": 21600000 }
  ```
- **Errors:** unchanged (401, 404)
- **Compatibility:** additive.
- **Consumers:** Series details sheet (time label); Schedule sheet and Series cards (slot expansion); Show builder and Schedule sheet (lock time, "Locks right away").

## GET /v1/stations/live
- **Change:** Changed — behavior only; response shape unchanged
- **Auth:** authenticated
- **Path params / Query params / Request body:** none
- **Response `200`:** unchanged (`[{ "stationId": "…", "liveStatus": "show_airing", "station": { … } }]`)
- **Behavior:** a recorded Show is `show_airing` from its first to its last actual spin (Airing `startTime`–`endTime`). Its voicetrack spins no longer count toward the `voicetracking` window (`lib/stations/stations.lib.ts:2071`), which today can mark a station LIVE from an earlier voicetrack through a Show hours later and starts 5 minutes early.
- **Errors:** unchanged (401)
- **Compatibility:** no new `liveStatus` value; old apps render the same badge.
- **Consumers:** listener station list LIVE badge (spec item 7).

## POST /v1/shows
- **Change:** Changed
- **Auth:** station editor (unchanged)
- **Path params / Query params:** none
- **Request body — `rrule` now honored on create** (today it is dropped, `lib/shows/shows.lib.ts:88`):
  ```json
  { "stationId": "1111…", "title": "Tuesday Evenings", "rrule": "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0" }
  ```
- **Response `201`:** existing shape, now with the saved `rrule`; `episodes: []` when no `firstEpisodeTitle`/`isOneTime`.
- **Errors — added:**

  | Status | When |
  |---|---|
  | 400 | `rrule` longer than 255, or `rrule` with `isOneTime: true` |

- **Compatibility:** additive; existing callers send no `rrule`.
- **Consumers:** Series details sheet — New Series (also from Series picker → New Series). Standalone Show creation (`isOneTime: true`) is unchanged.

## PUT /v1/shows/:showId
- **Change:** Changed
- **Auth:** station editor (unchanged)
- **Path params:** `showId` (UUID)
- **Query params:** none
- **Request body:** unchanged (`{ "title"?, "rrule"? }`); `"rrule": null` clears the schedule
- **Response `200`:** unchanged
- **Errors — added:**

  | Status | When |
  |---|---|
  | 400 | `rrule` longer than 255, or `rrule` on a one-time wrapper |

- **Behavior:** renames and schedule changes are allowed at any time; a schedule change only changes which slots are offered.
- **Compatibility:** additive.
- **Consumers:** Series details sheet — Edit Series; Show builder rename of a standalone Show.

## GET /v1/episodes
- **Change:** Changed
- **Auth:** authenticated (unchanged)
- **Path params:** none
- **Query params:** unchanged (`stationIds`, `showId`, `includeSegments`, `includeStation`, `includeAirings`)
- **Request body:** none
- **Response `200` — changed fields:**
  ```json
  [{
    "id": "5555…", "showId": "2222…", "title": "Fall Favorites", "durationMS": 2280000,
    "show": { "id": "2222…", "title": "Tuesday Evenings", "isOneTime": false, "rrule": "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0" },
    "airings": [{ "id": "3333…", "airtime": "2026-11-11T02:00:00.000Z", "startTime": "2026-11-11T02:02:00.000Z", "endTime": "2026-11-11T02:40:00.000Z" }]
  }]
  ```
- **Behavior:** `durationMS` is always filled, from the existing batched `episodeDurationsByEpisode` (`lib/stations/stations.lib.ts:696`, switched to `endOfMessageMS`), so lists don't need `includeSegments`. Airing start/end from `embedAiringTimes`.
- **Errors:** unchanged
- **Compatibility:** additive; same array, order, no pagination.
- **Consumers:** Upcoming (counts), Series list, Series page, Individual Shows, Add a show sheet.

## GET /v1/episodes/:episodeId
- **Change:** Changed
- **Auth:** authenticated (unchanged)
- **Path params:** `episodeId` (UUID)
- **Query params — added:** `includeAirings` (boolean, default false; the list route has it, detail doesn't today — `api/episode/episode.controller.ts:47`)
- **Request body:** none
- **Response `200`:** `airings` populated as in the list above
- **Behavior:** GET no longer resolves song-request segments into audio for an Episode that has any Airing (today it writes during the read, `lib/episodes/episodes.lib.ts:160`); drafts still resolve on read as today. A scheduled web-made Show with an unresolved request airs without that song, as it does today.
- **Errors:** unchanged
- **Compatibility:** additive; the website's scheduled request-only segments stop filling in on read.
- **Consumers:** Show builder (load, and refresh after a refusal or a failed save).

## PUT /v1/episodes/:episodeId
- **Change:** Changed (today: rename only)
- **Auth:** station editor of the Episode's station; a target Series must be on the same station
- **Path params:** `episodeId` (UUID)
- **Query params:** none
- **Request body — any of `title`, `showId`:**
  ```json
  { "showId": "2222…" }
  ```
  ```json
  { "showId": null }
  ```
  - `showId`: a real Series id joins it; `null` makes the Show standalone (creates a one-time wrapper with the Episode's title; a no-op if it is already standalone). An emptied one-time wrapper is deleted; an emptied real Series never is. Air time is kept. No lock check.
- **Response `200`:** the Episode with `show` and `airings` (as in `GET /v1/episodes`); `showId` is never null.
- **Errors — added:**

  | Status | When |
  |---|---|
  | 400 | target is a wrapper or on another station |
  | 404 | target Series not found |

- **Compatibility:** title-only callers unchanged.
- **Consumers:** Series picker sheet (add / change / remove); Add a show sheet (second step, after scheduling); Show builder rename of a Show in a Series.

## POST /v1/episodes/:episodeId/segments
- **Change:** Changed
- **Auth:** station editor (today: any authenticated user, `api/episode/index.ts:59`)
- **Path params:** `episodeId` (UUID)
- **Query params:** none
- **Request body:** unchanged (`{ "audioBlockId": "7777…", "position": 0 }`; web's `songRequestId` still accepted), or — added — several AudioBlocks inserted in order at `position`, all or nothing:
  ```json
  { "audioBlockIds": ["8888…", "9999…"], "position": 3 }
  ```
  Exactly one of `audioBlockId`, `audioBlockIds`, `songRequestId`. A Q&A is one request (question audio, then answer audio), so it can never half-save.
- **Response `201`:** unchanged — the Episode with segments; adds `airings`
- **Errors — added:**

  | Status | When |
  |---|---|
  | 400 | more than one of `audioBlockId` / `audioBlockIds` / `songRequestId`, or an empty `audioBlockIds` |
  | 403 | caller isn't a station editor |
  | 409 | `AIRING_EDIT_LOCKED`; `AIRING_OVERLAP` (the longer Show now collides) |

- **Behavior:** see "Content changes never touch spins".
- **Compatibility:** non-editor callers now get 403.
- **Consumers:** Show builder — Audio, Song, Q&A.

## PUT /v1/episodes/:episodeId/segments/:segmentId
- **Change:** Changed
- **Auth:** station editor
- **Path params:** `episodeId`, `segmentId` (UUIDs); the segment must belong to the Episode (today the path `episodeId` is ignored, `api/episode/episode.controller.ts` ~`:110-140`)
- **Query params:** none
- **Request body:** unchanged (`{ "position": 1 }`)
- **Response `200`:** unchanged; adds `airings`
- **Errors — added:** 403 non-editor; 404 segment not in this Episode; 409 `AIRING_EDIT_LOCKED`, `AIRING_OVERLAP`
- **Behavior:** see "Content changes never touch spins".
- **Compatibility:** same request; non-editors now 403.
- **Consumers:** Show builder — reorder.

## DELETE /v1/episodes/:episodeId/segments/:segmentId
- **Change:** Changed
- **Auth:** station editor
- **Path params:** `episodeId`, `segmentId` (UUIDs); ownership verified (today derived from the segment alone, `lib/episodes/episodes.lib.ts:288`)
- **Query params:** none
- **Request body:** none
- **Response `200`:** unchanged (the Episode); adds `airings`
- **Errors — added:** 403; 404 ownership mismatch; 409 `AIRING_EDIT_LOCKED`; 409 (message only) when removing a scheduled Show's last audio — unschedule first. A draft may become empty.
- **Behavior:** see "Content changes never touch spins".
- **Consumers:** Show builder — remove row.

## POST /v1/airings
- **Change:** Changed
- **Auth:** station editor (unchanged)
- **Path params / Query params:** none
- **Request body:** unchanged
  ```json
  { "episodeId": "5555…", "stationId": "1111…", "airtime": "2026-11-11T02:00:00.000Z" }
  ```
- **Response `201`:** unchanged
- **Errors — added:**

  | Status | When |
  |---|---|
  | 400 | time is in the past or inside the 2-minute lead (the existing move message, `AIRING_TIME_TOO_SOON`; today create has no lead check, `lib/airings/airings.lib.ts:79`) |
  | 409 | the Show has no playable audio (message only) |
  | 409 | `AIRING_OVERLAP` (replaces silent push-back and 400 `LIVE_SHOW_AIRING_CONFLICT`) |

- **Behavior:** checks run inside the scheduling transaction. Scheduling inside 6 hours is allowed; the Show is locked at once.
- **Compatibility:** same request; formerly-accepted past or overlapping times now fail with a message the website already displays.
- **Consumers:** Schedule sheet; Add a show sheet (first step, for a draft).

## PUT /v1/airings/:airingId
- **Change:** Changed
- **Auth:** station editor (unchanged)
- **Path params:** `airingId` (UUID)
- **Query params:** none
- **Request body:** unchanged (`{ "airtime": "2026-11-12T02:00:00.000Z" }`)
- **Response `200`:** unchanged
- **Errors — added:** 409 `AIRING_EDIT_LOCKED` (the Airing is locked now); 409 `AIRING_OVERLAP` (replaces 400 `LIVE_SHOW_AIRING_CONFLICT`); existing 400 too-soon message unchanged
- **Behavior:** moves through the bounded repair (above) instead of the suffix delete.
- **Compatibility:** same request; web moves inside 6 hours now fail with a message.
- **Consumers:** Schedule sheet (Change); Add a show sheet (first step, for an already-scheduled Show).

## DELETE /v1/airings/:airingId
- **Change:** Changed — internals only
- **Auth:** station editor (unchanged)
- **Path params:** `airingId` (UUID)
- **Query params:** none
- **Request body:** none
- **Response `204`:** unchanged
- **Behavior:** ignores the six-hour lock (this is how a locked Show is changed). Keeps its two-minute cutoff and message (`lib/airings/airings.lib.ts:225`) — iOS shows that message if Unschedule is tapped inside it or once the Show has started. Removes only this Airing's spins via the bounded repair; the Episode, its segments and Series membership stay (it becomes a draft).
- **Errors:** unchanged
- **Compatibility:** same contract for the website; later Shows and questions on the schedule are no longer regenerated.
- **Consumers:** Unschedule confirmation.

## Open slots (computed on iOS — no endpoint)

From a weekly `show.rrule` and `Station.timezone`, expand occurrences forward and keep the first 8 that are in the future and not equal to the nominal `airtime` of any Airing on the station (existing `GET /v1/airings?stationId=`, iOS `api.getAirings`). Slots are suggestions; the server's overlap rule is the only judge. Moving or unscheduling a Show reopens its slot.

## Add a show sheet: two requests

Placing an existing Show into a slot is two existing calls, in order: schedule or move it (`POST /v1/airings` for a draft, `PUT /v1/airings/:id` for a scheduled Show), then — only if that succeeds — `PUT /v1/episodes/:id { showId }`. If the second call fails, the app shows an alert; the Show stays scheduled at the slot's time outside the Series, and the curator can fix it from the builder's Series row.

## Screen fetch plan

| Screen | Calls |
|---|---|
| Upcoming | `GET /v1/shows?stationIds=`, `GET /v1/episodes?stationIds=&includeAirings=true` |
| Series list | `GET /v1/shows?stationIds=`, `GET /v1/episodes?stationIds=&includeAirings=true`, `GET /v1/airings?stationId=` (slots) |
| Series page | `GET /v1/shows/:showId`, `GET /v1/episodes?showId=&includeAirings=true`, `GET /v1/airings?stationId=` (slots) |
| Individual Shows, Add a show sheet | `GET /v1/episodes?stationIds=&includeAirings=true` |
| Show builder | `GET /v1/episodes/:episodeId?includeSegments=true&includeAirings=true`; Q&A via one `POST …/segments { audioBlockIds }` |
| Schedule sheet | `GET /v1/airings?stationId=` when the Show is in a Series (slots) |
| Series picker sheet | `GET /v1/shows?stationIds=` (wrappers hidden) |
| New standalone Show (first change) | `POST /v1/shows { isOneTime: true }` (existing) |
| New Show in a Series (first change) | `POST /v1/episodes { showId, title }` (existing) |
| Unschedule confirmation | `DELETE /v1/airings/:airingId` |
