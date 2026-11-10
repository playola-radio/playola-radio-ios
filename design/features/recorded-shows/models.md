# Recorded shows — Model changes

Backend: `playola` monorepo `origin/develop` `15e655d4c4f2fb261ca49f522022b8682d2a6e9f` (re-checked at `fd456a53` for the plan). Paths are under `server/src/`.
UX "Show" = `Episode`; UX "Series" = `Show` (see spec Vocabulary).

| Change | Model | Table | Summary |
|---|---|---|---|
| Changed | `Station` | `stations` | Serializes the time zone (a server constant) and the edit-lock length |
| Changed | `Show` | `shows` | Defines what iOS writes into the existing `rrule` column |
| Changed | `Episode` | `episodes` | `durationMS` matches what the scheduler actually plays |
| Changed | `Airing` | `airings` | Adds the "on now" push dedup marker |

## Station (`stations`) — Changed

| Column | Type | Null | Default | Change | Notes |
|---|---|---|---|---|---|
| `timezone` | VIRTUAL(STRING) | — | `'America/Chicago'` | Added | Server constant, the same for every station. Read by Series slot expansion (iOS), the Series details sheet's time label, and the overlap error message. Not stored, not writable. |
| `airingEditLockMS` | VIRTUAL(INTEGER) | — | `21600000` | Added | Server constant `RECORDED_SHOW_EDIT_LOCK_MS` (6 h), serialized so the app can compute each Airing's lock time (`airtime − airingEditLockMS`) and the Schedule sheet can say "Locks right away" before an Airing exists. Not stored, not writable. |

- **Indexes / constraints:** none. **Associations:** unchanged. **Enums:** none.
- **Migration:** none.
- **Deploy compatibility:** additive — old clients ignore both fields. If stations ever need their own time zone, a real column replaces the constant behind the same field.
- **Requirement:** "times are in the station's time zone"; "the client does not hardcode 6 hours".

## Show (`shows`) — Changed

| Column | Type | Null | Default | Change | Notes |
|---|---|---|---|---|---|
| `rrule` | STRING(255) | NULL | `null` | Changed — contract only (was: stored, unused by web) | Repeating schedule of a Series. `null` = no schedule. Read by Curator Series cards, Curator Series page, Series details sheet, Schedule sheet, and the listener `RRuleFormatter`. |

**What iOS writes** (wall-clock values are in `Station.timezone`): every week only, one line, the form the shipped listener formatter already reads:
`FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0` — one or more days, exactly one time; no `INTERVAL`, `COUNT`, `UNTIL`, or exclusions.

- **Server role:** stores and length-checks the string; it never expands it. Slots are computed on iOS (see endpoints.md, "Open slots").
- **Legacy rules:** existing web-written rules (including `INTERVAL=2`, `DAILY`, `MONTHLY`) are left untouched. iOS shows a rule it can't edit as its formatted text, read-only, and offers slots only for plain weekly rules; saving a rename sends no `rrule`.
- **Indexes / constraints:** none. **Associations:** unchanged. **Enums:** none.
- **Migration:** none.
- **Deploy compatibility:** every rule iOS writes reads correctly in every shipped iOS version and in the admin web editor (`rrule.js`).
- **Expansion rules (iOS):** a wall time that doesn't exist (spring forward) is skipped; a repeated one (fall back) is used once, at the earlier instant. The client excludes a candidate slot that falls in any returned Airing interval `[startTime, endTime)` on the station, not merely one with the same nominal `airtime`. Expansion stops after 8 open slots or 52 weeks. The server remains the overlap authority when scheduling.
- **Requirement:** spec item 4 (repeating schedule with slots).

## Episode (`episodes`) — Changed

| Column | Type | Null | Default | Change | Notes |
|---|---|---|---|---|---|
| `durationMS` | VIRTUAL(number) | — | `0` | Changed — calculation (was: max(`offsetMS` + file `durationMS`)) | Now max(`offsetMS` + `audioBlock.endOfMessageMS`), skipping segments with no audio. Matches scheduler placement (`lib/scheduler/scheduler.ts:513`). Read by Individual Shows length, the Schedule sheet's "ends about", and the server overlap check. |

- **Indexes / constraints:** none. **Associations:** unchanged. **Enums:** none.
- **Source of truth:** segments + AudioBlocks. No stored duration, draft flag, or status: a draft is an Episode with no Airings.
- **List reads:** the existing batched `episodeDurationsByEpisode` (`lib/stations/stations.lib.ts:696`) switches to `endOfMessageMS` too, so lists get the same number without loading every segment.
- **Migration:** none.
- **Deploy compatibility:** same type; values can shrink where a file has audio after `endOfMessageMS`.

## Airing (`airings`) — Changed

| Column | Type | Null | Default | Change | Notes |
|---|---|---|---|---|---|
| `onNowNotificationSentAt` | DATE | NULL | `null` | Added | Set by the "on now" worker after the follower push publishes. Mirrors `liveShows.liveNotificationSentAt`. Never client-writable. |

Existing `startTime` / `endTime` virtuals are populated wherever an Airing is returned, by the existing `embedAiringTimes` (`lib/stations/stations.lib.ts:740`, generalized): MIN spin `airtime` and MAX spin `endOfMessageTime` once spins exist; before that, `airtime` + episode `durationMS`.

- **Lock (no stored field):** an Airing is locked when it hasn't ended and either `now >= airtime − RECORDED_SHOW_EDIT_LOCK_MS` or it already has spins. iOS computes the same time from `airtime` and `Station.airingEditLockMS`.
- **Indexes / constraints:** none. The worker finds due Airings from currently-playing airing spins, not by scanning `airings`.
- **Associations:** unchanged. **Enums:** none (no status column).
- **Migration:** add nullable column; no backfill. An Airing already on air at deploy may push once.
- **Deploy compatibility:** deploy the column before the worker; old workers ignore it; keep it on rollback.
- **"On now" worker:** a job on the existing 15-second tick (`worker.js:387`) finds Airings whose first spin has started and whose last spin hasn't ended, with `onNowNotificationSentAt IS NULL`; it re-reads the Airing and its spins under a row lock and re-checks that it is still playing, publishes to the station's existing follower topic (title: station name; body: "<Show title> is on now."; existing `stationId` payload), then sets the marker. Moves keep the Airing id; unscheduling deletes it, so nothing is pushed. A crash between publish and commit can repeat one push (same boundary as the live-show worker). A Show that starts and ends between two ticks, or plays while the worker is down, gets no push — no late "on now" for a Show that is over.
- **Requirement:** six-hour lock; "on now" push that follows moves and cancels.
