# 001 — Series picker: API contract

Every endpoint this design calls. All are owned by the **`playola` server monorepo** (`server/src/api/…`) and are **unchanged by this design** — their recorded-shows behavior already shipped in playola #1141 (on `develop`; it must reach production before an App Store release that contains this design).

Words: UX **Show** = backend `Episode`; UX **Series** = backend `Show`. A standalone Show lives in a hidden one-time `Show` (`isOneTime: true`).

| Status | Method | Path | Used for |
|---|---|---|---|
| Unchanged | GET | `/v1/shows?stationIds=<stationId>` | The picker's list of Series |
| Unchanged | POST | `/v1/shows` | New Series |
| Unchanged | PUT | `/v1/episodes/:episodeId` | Join a Series, switch Series, remove from a Series |
| Unchanged | GET | `/v1/stations/:stationId` | Station time zone for the New Series time |
| Unchanged | GET | `/v1/episodes/:episodeId?includeSegments=true&includeAirings=true` | Builder refresh after a change or a refusal (already called by the builder) |

## Error envelope

Every refusal is `{ "error": { "message": "…" } }`; the app shows `message` as is. None of the endpoints below return a machine code this design branches on. Auth failures are the usual `401` (signed out) and `403` (not an editor of the station).

## GET /v1/shows

- **Auth:** authenticated.
- **Query:** `stationIds` — the builder's station.
- **Response `200`:** an array of Series. Fields this design relies on:
  ```json
  [{ "id": "2222…", "stationId": "1111…", "title": "This One's For You", "isOneTime": false, "rrule": "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0" }]
  ```
  - `isOneTime: true` rows are hidden wrappers and are never listed.
  - `rrule` is `null` (no schedule), the weekly form below, or — defensively — anything else, shown as "Custom schedule".
- **Errors:** 401.

## POST /v1/shows

- **Auth:** station editor (admin, or the station's owner/contributor).
- **Request:**
  ```json
  { "stationId": "1111…", "title": "Tuesday Evenings", "rrule": "FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0" }
  ```
  - `rrule` is omitted for "No schedule".
  - The only accepted form is `FREQ=WEEKLY;BYDAY=<days>;BYHOUR=<0-23>;BYMINUTE=<0-59>`, `<days>` one or more of `MO,TU,WE,TH,FR,SA,SU`, comma-separated, no repeats. Hour and minute are wall-clock in the station's time zone.
- **Response `201`:** the new Series (`id`, `stationId`, `title`, `isOneTime: false`, `rrule`, `episodes: []`).
- **Errors:**

  | Status | When |
  |---|---|
  | 400 | `rrule` longer than 255 characters or not the weekly form above |
  | 401 / 403 | signed out / not a station editor |

## PUT /v1/episodes/:episodeId

- **Auth:** station editor of the Show's station. Never edit-locked (works on Locked Shows).
- **Path:** `episodeId` — the Show.
- **Request — join or switch:**
  ```json
  { "showId": "2222…" }
  ```
- **Request — remove from its Series (make standalone):**
  ```json
  { "showId": null }
  ```
  A no-op if the Show is already standalone.
- **Behavior:** the Show's airings and air times are kept. A one-time wrapper left empty is deleted; an emptied real Series never is. Removing creates a new one-time wrapper titled like the Show.
- **Response `200`:** the Show with `show` (its Series or wrapper) and `airings`; `showId` is never null.
  ```json
  { "id": "5555…", "showId": "2222…", "title": "Tour Stories", "durationMS": 1115000,
    "show": { "id": "2222…", "title": "This One's For You", "isOneTime": false, "rrule": "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0" },
    "airings": [{ "id": "3333…", "airtime": "2026-11-23T01:00:00.000Z", "startTime": "2026-11-23T01:00:00.000Z", "endTime": "2026-11-23T01:18:35.000Z" }] }
  ```
- **Errors:**

  | Status | When |
  |---|---|
  | 400 | the target is a one-time wrapper, or a Series on another station |
  | 404 | the target Series doesn't exist |
  | 401 / 403 | signed out / not a station editor |

## GET /v1/stations/:stationId

- **Auth:** authenticated.
- **Response `200` — fields this design relies on:** `{ "timezone": "America/Chicago", "airingEditLockMS": 21600000 }` (server constants, the same for every station). `timezone` labels and interprets the New Series time.
- **Errors:** 401, 404.

## GET /v1/episodes/:episodeId

Already called by the builder; listed because every change in this design is followed by it. With `includeSegments=true&includeAirings=true` it returns the Show with `show`, `segments` and `airings` (with `startTime`/`endTime`). Errors: 401, 404.
