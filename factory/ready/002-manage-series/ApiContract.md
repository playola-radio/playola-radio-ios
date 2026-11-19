# 002 — Manage series: API contract

Every endpoint this design calls. All are owned by the **`playola` server monorepo** (`server/src/api/…`) and are **unchanged by this design** — their recorded-shows behavior already shipped in playola #1141 (on `develop`; it must reach production before an App Store release that contains this design). Endpoints already described in design 001 (`GET /v1/shows`, `POST /v1/shows`, `PUT /v1/episodes/:episodeId`, `GET /v1/stations/:stationId`) behave as written there.

Words: UX **Show** = backend `Episode`; UX **Series** = backend `Show`; a standalone Show lives in a hidden one-time `Show` (`isOneTime: true`). An **Airing** is one scheduled play of a Show.

| Status | Method | Path | Used for |
|---|---|---|---|
| Unchanged | GET | `/v1/stations/:stationId` | Station time zone and lock length (see 001) |
| Unchanged | GET | `/v1/shows?stationIds=<stationId>` | Series list cards (see 001) |
| Unchanged | POST | `/v1/shows` | "Create a New Series" (see 001) |
| Unchanged | GET | `/v1/shows/:showId` | Series page header and Edit Series |
| Unchanged | PUT | `/v1/shows/:showId` | Edit Series |
| Unchanged | GET | `/v1/episodes?stationIds=<stationId>&includeAirings=true` | Shows on the cards; Add a show sheet's list |
| Unchanged | GET | `/v1/episodes?showId=<showId>&includeAirings=true` | Series page Shows |
| Unchanged | GET | `/v1/airings?stationId=<stationId>` | Which times are taken, for open slots |
| Unchanged | POST | `/v1/airings` | Add a draft to a slot (step 1) |
| Unchanged | PUT | `/v1/airings/:airingId` | Move a scheduled Show to a slot (step 1) |
| Unchanged | PUT | `/v1/episodes/:episodeId` | Put a Show in this Series (step 2; see 001) |
| Unchanged | POST | `/v1/episodes` | First change of a new Show recorded for this Series (made by the builder) |

## Error envelope

Every refusal is `{ "error": { "message": "…" } }`; the app shows `message` as is. Two refusals add a machine code in `error.data.code`:

| Code | Status | Meaning |
|---|---|---|
| `AIRING_EDIT_LOCKED` | 409 | The Show is locked: it airs within 6 hours, is on air, has aired, or already has spins |
| `AIRING_OVERLAP` | 409 | The time would overlap another Show, a live show or a giveaway; the message names it, in Central time |

```json
{ "error": { "message": "This overlaps Fall Favorites, which airs 7:00–7:38 PM. Pick a time after 7:38 PM.", "data": { "code": "AIRING_OVERLAP" } } }
```

Auth failures are the usual `401` (signed out) and `403` (not a station editor: admin, or the station's owner/contributor).

## GET /v1/shows/:showId

- **Auth:** authenticated.
- **Response `200`:** one Series: `{ "id", "stationId", "title", "isOneTime", "rrule" }` (same fields as the list in 001).
- **Errors:** 401, 404.

## PUT /v1/shows/:showId

- **Auth:** station editor.
- **Request:** any of `title`, `rrule`.
  ```json
  { "title": "This One's For You", "rrule": "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0" }
  ```
  - `"rrule": null` clears the schedule ("No schedule").
  - Omit `rrule` to keep the schedule as is (always the case for a "Custom schedule" rename).
  - Accepted form: `FREQ=WEEKLY;BYDAY=<days>;BYHOUR=<0-23>;BYMINUTE=<0-59>`, `<days>` one or more of `MO,TU,WE,TH,FR,SA,SU`, in the station's time zone.
- **Behavior:** allowed at any time. A schedule change only changes which slots are offered; scheduled Shows keep their times.
- **Response `200`:** the updated Series.
- **Errors:**

  | Status | When |
  |---|---|
  | 400 | `rrule` longer than 255 characters, not the weekly form, or sent on a one-time wrapper |
  | 401 / 403 / 404 | signed out / not a station editor / no such Series |

## GET /v1/episodes

- **Auth:** authenticated.
- **Query:** `stationIds` or `showId`, plus `includeAirings=true`.
- **Response `200`:** an array of Shows, no pagination. Fields this design relies on:
  ```json
  [{ "id": "5555…", "showId": "2222…", "title": "Fall Favorites", "durationMS": 2280000,
     "show": { "id": "2222…", "title": "This One's For You", "isOneTime": false, "rrule": "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0" },
     "airings": [{ "id": "3333…", "airtime": "2026-11-09T01:00:00.000Z", "startTime": "2026-11-09T01:00:00.000Z", "endTime": "2026-11-09T01:38:00.000Z" }] }]
  ```
  - `durationMS` is always filled (0 = no audio). It gives the lengths shown, and tells which drafts have audio.
  - No `airings` = draft. One airing that hasn't ended = upcoming. Every airing ended = aired (not shown). More than one airing = made on the website (never offered).
- **Errors:** 401.

## GET /v1/airings

- **Auth:** authenticated.
- **Query:** `stationId`.
- **Response `200`:** the station's Airings, each with `id`, `episodeId`, `stationId`, `airtime`, `startTime`, `endTime`. A suggested slot is open only if it falls outside every `[startTime, endTime)` here, whichever Show the Airing belongs to.
- **Errors:** 401.

## POST /v1/airings

- **Auth:** station editor.
- **Request:**
  ```json
  { "episodeId": "5555…", "stationId": "1111…", "airtime": "2026-11-23T01:00:00.000Z" }
  ```
- **Behavior:** allowed inside 6 hours; the Show locks at once.
- **Response `201`:** the Airing (`id`, `episodeId`, `stationId`, `airtime`, `startTime`, `endTime`).
- **Errors:**

  | Status | When |
  |---|---|
  | 400 | the time is in the past or less than 2 minutes away (`AIRING_TIME_TOO_SOON` message) |
  | 409 | the Show has no playable audio (message only) |
  | 409 | `AIRING_OVERLAP` |
  | 401 / 403 | signed out / not a station editor |

## PUT /v1/airings/:airingId

- **Auth:** station editor of every station the Show airs on.
- **Request:** `{ "airtime": "2026-11-23T01:00:00.000Z" }`
- **Behavior:** moving to a time inside 6 hours is allowed and locks the Show at once. Other Airings keep their times.
- **Response `200`:** the moved Airing.
- **Errors:**

  | Status | When |
  |---|---|
  | 400 | the new time is in the past or less than 2 minutes away |
  | 409 | `AIRING_EDIT_LOCKED` — the Show is already locked |
  | 409 | `AIRING_OVERLAP` |
  | 401 / 403 / 404 | signed out / not a station editor / no such Airing |

## Putting a Show into a slot: two requests

1. Schedule it (`POST /v1/airings`, for a draft) or move it (`PUT /v1/airings/:airingId`, for a scheduled Show) to the slot's time.
2. Only if step 1 succeeds: `PUT /v1/episodes/:episodeId { "showId": "<this Series>" }`.

If step 2 fails, the Show stays scheduled at the slot's time in its old Series (or standalone). The app shows an alert and does not undo step 1.

With no slot, only step 2 is sent.

## POST /v1/episodes

- **Auth:** station editor.
- **Request:** `{ "showId": "2222…", "title": "…" }` — sent by the builder on the first change of a new Show recorded for this Series. Nothing is sent if the curator backs out without a change.
- **Response `201`:** the new Show.
- **Errors:** 409 if `showId` is a one-time wrapper; 401 / 403.
