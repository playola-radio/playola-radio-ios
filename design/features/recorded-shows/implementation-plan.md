# Recorded Shows Implementation Plan

> **For agentic workers:** this feature spans two repos: two backend PRs, and nine iOS PRs into the `feature/recorded-shows` integration branch. Drive it with the `orchestrate-feature` skill: one fresh implementation session and one PR per row in the PR graph table, each executed with `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Curators can make, schedule, edit, move and unschedule recorded shows and manage series in the iOS app, with server-enforced six-hour locks, overlap refusals, and a LIVE badge that follows real playback.

**Architecture:** The backend keeps its existing routes and models and adds the missing rules: the lock length and a fixed time zone on the station response, one lock check, one overlap validator, and one bounded schedule repair for Unschedule and move. It also adds a batched segment insert, a Series change on `PUT /v1/episodes`, and a LIVE-status fix. iOS adds its own curator data types decoded straight from these routes, rule parsing and slot expansion, then the builder, sheets, lists and Station tab in one PR.

**Tech Stack:** Backend: Node/TypeScript, Express, Sequelize (Postgres), mocha + supertest, BullMQ worker. iOS: Swift 6, SwiftUI, `@Observable` models, swift-dependencies, swift-sharing, swift-testing.

**Spec:** [spec.md](./spec.md). **Contracts to implement:** [endpoints.md](./endpoints.md), [models.md](./models.md), [screens.md](./screens.md) (mockups in `exports/`). Implement those files as written; this plan does not repeat them. Design folder: `playola-radio-ios/design/features/recorded-shows/`. A backend session must read it from there.

## Base commits

- Backend `playola` `origin/develop` `fd456a53924ccb0c30b360b027f3aae2096e4227`. The design was read at `15e655d4c`; the only change since in touched areas is `station.controller.ts` category routes, which is unrelated. The local checkout at `~/playola/playola` is stale: branch from `origin/develop`.
- iOS `playola-radio-ios` `origin/develop` `1eaefdb0bf2b0137f200a710b83d106639a50cf8`.

## PR graph

```
B1 backend: scheduling contract ──┬──> B2 backend: LIVE badge follows real playback
                                  └──> iOS integration branch feature/recorded-shows:
                                         I1 data layer ──> S1 ──> S2 ──> … ──> S7 ──> merge to develop
```

All iOS work goes into the integration branch `feature/recorded-shows` (cut from `develop` at `ef7a9495`), one PR per screen. Each PR targets `feature/recorded-shows`, **not** `develop`. Nothing reaches `develop` until the whole feature is done, so the screens can land in the order a curator taps through them, with links to screens that don't exist yet. Merge `develop` into the integration branch whenever it falls behind.

| PR | Repo | Base | Title (plain English) | Plan tasks |
|---|---|---|---|---|
| B1 | playola | `develop` | `feature: let shows be safely scheduled, edited and moved from the app` | B1.1–B1.5. Merged (playola #1141) |
| B2 | playola | `develop` (after B1) | `bugfix: show the LIVE badge only while a recorded show is actually playing` | B2.1 (B2.2 superseded by #1120). Merged (#1142) |
| I1 | ios | `feature/recorded-shows` | `chore: teach the app to read and save recorded shows` | I1.1–I1.3 |
| S1 | ios | `feature/recorded-shows` | `feature: split the Station tab into Shows and Library and add Upcoming` | I2.5, plus Upcoming from I2.4 (`upcomingFetchesNoAirings`, `upcomingCountsShowsNotAirings`). Its "Series" and "Individual Shows" rows do nothing until S2 and S6 |
| S2 | ios | `feature/recorded-shows` | `feature: list a station's individual shows` | Individual Shows from I2.4 (`individualShowsListsDraftsFirstThenByAirtime`, `showInSeriesCarriesSeriesBadge`, `airedShowsAreNotListed`, `failedLoadShowsToastAndKeepsList`) and the `CalendarDateBadge` / `DraftDateBadge` changes. Rows and "Record a New Show" do nothing until S3 |
| S3 | ios | `feature/recorded-shows` | `feature: build a recorded show` | I2.1, and wires Individual Shows' rows and "Record a New Show" to the builder (`multiAiringShowOpensReadOnly`) |
| S4 | ios | `feature/recorded-shows` | `feature: schedule, move and unschedule recorded shows` | I2.2 |
| S5 | ios | `feature/recorded-shows` | `feature: pick and edit series for recorded shows` | I2.3 |
| S6 | ios | `feature/recorded-shows` | `feature: list a station's series with open slots` | Curator Series list from I2.4 (`seriesCardShowsOpenSlotsBetweenScheduledShows`, `seriesWithoutScheduleShowsNoSlots`, `emptySeriesListShowsOnlyCreateButton`) |
| S7 | ios | `feature/recorded-shows` | `feature: fill a series' open slots` | Curator Series page and Add a show sheet from I2.4 (the remaining `addShow…`, `addingDraftToSlot…`, `addingScheduledShowToSlot…`, `seriesStep…`, `slotUnderLock…`, `recordNewShowFromSlot…`, `lockedAndMultiAiring…`, `scheduledShowLabeled…` tests) |
| Final | ios | `develop` | `feature: let curators record and schedule shows from the Station tab` | `feature/recorded-shows` → `develop`, after B1 is on `develop` |

- Each screen PR: tests and `make lint` green, its screen checked on a simulator against its mockup in `exports/`, and the adversarial Codex review before it opens.
- I1 and every screen PR need B1's routes. Until B1 is on staging, test against stubs; verify on staging before the final merge.
- **Release gate:** B1 and B2 must be deployed to production before any App Store release that contains the final merge. Each PR advances the recorded-shows row in `LONG_RUNNING.md` (edit it on the integration branch; it reaches `develop` with the final merge).
- Backend rule (playola `CLAUDE.md`): use the fewest PRs that each ship safely, so the backend is two PRs, not one per endpoint.

## Global Constraints

- Every error added by this feature keeps `{ error: { message } }`. Only `AIRING_EDIT_LOCKED` and `AIRING_OVERLAP` add `code` in `AppError.data`; every other refusal is message-only. Messages are plain English and use station time.
- `RECORDED_SHOW_EDIT_LOCK_MS = 21600000` and `STATION_TIMEZONE = 'America/Chicago'` exist once each on the server. iOS never hardcodes 6 hours or the zone; it reads `airingEditLockMS` and `timezone` from the station.
- The lock covers content changes and moves only. Rename and Series change are never locked. Unschedule ignores the lock and keeps the existing 2-minute cutoff and message.
- No runtime environment gating (iOS `CLAUDE.md`). Production gets everything staging gets.
- iOS: zero control flow in views. All copy comes from models. Every test suite carries `@Suite(.freshSharedState)`. No `Task.sleep` in tests. Activate the pfw-* skills before writing Swift (`pfw-dependencies`, `pfw-observable-models`, `pfw-testing`, `pfw-custom-dump`, `pfw-modern-swiftui`, `pfw-issue-reporting`).
- iOS: register every new `.swift` file in `project.pbxproj`, and keep unrelated pbxproj churn out of the PR.
- Server enums decoded on iOS get an `unknown` fallback.
- Backend: every changed endpoint updates its module's `ENDPOINTS.md` and `*.api.docs.yaml`. Every changed model updates its `MODEL.md`, then run `npm run docs:check`. Add a `changelog.d/<short-kebab-description>.md` file (both repos use `changelog.d/`, never edit `CHANGELOG.md` in a PR): `### Changes` for user-visible behavior, and `### Ops` `MIGRATION:` lines for each migration.
- Backend skills: `create-model` (migrations + model changes), `create-lib` (lib functions + tests), `create-endpoint` (route/controller/docs/API tests). iOS guides: `.claude/PAGE_CREATION.md`, `.claude/VIEWS.md`, `.claude/API_CLIENT.md`, `.claude/TESTING.md`, `.claude/NAVIGATION.md`.

## Review Focus

1. **A curator whose phone is in a different time zone from the station.** Slots, "airs at about" and schedule text must use station time, and the label says so. → I1.3 (`openSlotsUseStationTimeNotDeviceTime`) and I2.2 (`scheduleSheetLabelsUseStationTimeZone`).
2. **Quick double taps on a slow network** (Schedule twice, two songs added fast). They must not create two Airings, two drafts, or out-of-order content. → I2.1 (`twoQuickChangesSaveInOrderOnce`), I2.2 (`scheduleButtonDisabledWhileSaving`).
3. **Web-made data the app didn't write**: Shows with two Airings, request-only segments with no audio, and (defensively) a rule that isn't the weekly form. These must decode and list without crashing, and open read-only. → I1.1 (`decodesRequestOnlySegmentWithoutAudio`), I1.3 (`everyOtherWeekRuleIsNotEditable`), I2.3 (`editSeriesWithUnparseableRuleShowsCustomScheduleAndSendsNoRruleOnRename`), I2.4 (`multiAiringShowOpensReadOnly`).
4. **Removing the last piece of audio from a scheduled Show** must show the server's "unschedule first" message and keep the row. → B1.4 (`refusesRemovingLastAudioFromScheduledEpisode`), I2.1 (`removingLastAudioOfScheduledShowShowsServerMessage`).
5. **Add a show: the schedule step succeeds but joining the Series fails.** The curator must be told, and the Show must stay scheduled (not silently half-done). → I2.4 (`seriesStepFailureAfterScheduleShowsAlertAndKeepsAiring`).

---

# Backend (`playola`) — PR B1: scheduling contract

Run from `server/`. To run one suite: `npm test -- --grep "<describe title>"`. Run the full suite before the PR: `npm test`, `npm run lint`, `npm run docs:check`.

### Task B1.1: Station lock length and time zone on the response

**Files:**
- Create: `server/src/lib/airings/airingEditing.ts` (constants only in this task)
- Modify: `server/src/db/models/station.model/station.model.ts` (two virtuals), `station.model/MODEL.md`
- Modify: `server/src/api/station/ENDPOINTS.md`, `station.api.docs.yaml`
- Test: `server/src/api/station/station.api.test.js`

**Interfaces:**
- Produces: `RECORDED_SHOW_EDIT_LOCK_MS = 21600000` and `STATION_TIMEZONE = "America/Chicago"` exported from `lib/airings/airingEditing.ts`; virtuals `Station.timezone` and `Station.airingEditLockMS` (not stored, not writable).

- [ ] **Step 1: Write failing test:** `GET /v1/stations/:id returns timezone America/Chicago and airingEditLockMS 21600000`.
- [ ] **Step 2:** Run `npm test -- --grep "airingEditLockMS"`. Expect FAIL.
- [ ] **Step 3:** Add the two virtuals from the constants. No migration.
- [ ] **Step 4:** Run again. Expect PASS. Update `MODEL.md`, `ENDPOINTS.md`, `station.api.docs.yaml`, then `npm run docs:check`.
- [ ] **Step 5:** Commit `feat: tell the app how long before air a show locks`.

### Task B1.2: Read side — real lengths, airing times, no writes on read

**Files:**
- Modify: `server/src/lib/stations/stations.lib.ts` (`episodeDurationsByEpisode:696` → `endOfMessageMS`; export `embedAiringTimes:740` and generalize it to any Airing list)
- Modify: `server/src/lib/airings/airings.lib.ts` (`getAiringById`), `lib/episodes/episodes.lib.ts` (`getAllEpisodes:55`, `getEpisodeById:113`)
- Modify: `server/src/db/models/episode.model/episode.model.ts` (`durationMS` virtual) and `MODEL.md`
- Modify: `server/src/api/episode/episode.controller.ts:47` (`includeAirings`), `episode.api.docs.yaml`, `ENDPOINTS.md`
- Test: `lib/episodes/episodes.lib.test.ts`, `lib/stations/stations.lib.test.ts`, `api/episode/episode.api.test.ts`

**Interfaces:**
- Produces: `embedAiringTimes(airings, durationsByEpisodeId, transaction?)` exported from `stations.lib.ts`, filling `startTime` / `endTime` (MIN spin `airtime`, MAX spin `endOfMessageTime`; before spins, `airtime + durationMS`). `episodeDurationsByEpisode` returns `endOfMessageMS`-based lengths.

- [ ] **Step 1: Write failing tests:**
  - `durationMS uses endOfMessageMS of each segment's audio`: two segments at offsets 0 and 60000, audio `endOfMessageMS` 90000 and 120000 → 180000.
  - `episodeDurationsByEpisode uses endOfMessageMS` (same fixture → 180000).
  - `getAllEpisodes fills durationMS without includeSegments`.
  - `GET /v1/episodes/:id?includeAirings=true returns airings with startTime and endTime`.
  - `airing endTime before spins is airtime plus durationMS`.
  - `GET /v1/episodes/:id on a scheduled episode with a song-request segment writes nothing`: snapshot `episodeSegments` rows before and after; expect deep equal.
  - `GET /v1/episodes/:id on a draft still resolves song requests` (current behavior kept).
  - `GET /v1/episodes/:id racing an Airing create rechecks under the shared scheduling lock and writes no resolved segments`.
- [ ] **Step 2:** Run `npm test -- --grep "episodes|durations|embedAiringTimes"`. Expect the new tests to FAIL.
- [ ] **Step 3:** Implement per endpoints.md "GET /v1/episodes" and "GET /v1/episodes/:episodeId". Do not touch the giveaway worker's own copy of the window logic. In `getEpisodeById`, take the existing scheduling-lock boundary shared with Airing creation, recheck for Airings on every station, and resolve song-request segments only when none exist.
- [ ] **Step 4:** Run again, plus the full `lib/stations` suite (touched-area regression rule). Expect PASS. Update the docs files listed above.
- [ ] **Step 5:** Commit `feat: return real show lengths and airing times`.

### Task B1.3: Airing writes — lock, overlap, lead time, has-audio, bounded repair

**Files:**
- Modify: `server/src/lib/airings/airingEditing.ts`, `lib/airings/airings.lib.ts` (`createAiring:79`, `updateAiring:243`, `deleteAiring:334`, `assertCanEditAiring:320`)
- Modify: `server/src/lib/scheduler/scheduler.ts`: add the bounded repair next to `deleteListenerQuestionAiringFromSchedule:1912`, and stop calling `deleteAiringFromSchedule:950` from move/delete
- Modify: `server/src/utils/errors.ts` (messages + the two codes)
- Modify: `api/airing/ENDPOINTS.md`, `airing.api.docs.yaml`
- Test: `lib/airings/airings.lib.test.ts`, `lib/scheduler/scheduler.test.js`, `api/airing/airing.api.test.ts`

**Interfaces:**
- Produces, in `utils/errors.ts`: `export const ErrorCodes = { AIRING_EDIT_LOCKED: "AIRING_EDIT_LOCKED", AIRING_OVERLAP: "AIRING_OVERLAP" } as const`.
- Produces, in `airingEditing.ts` (each takes the caller's `transaction` and assumes the scheduling lock is held):
  - `assertEpisodeEditable({ episodeId, now, transaction }): Promise<void>`: throws `ConflictError(msg, { code: AIRING_EDIT_LOCKED })` when the Episode has an ended Airing, or a not-ended Airing with `now >= airtime − RECORDED_SHOW_EDIT_LOCK_MS` or any spin.
  - `assertNoAiringOverlap({ stationId, airtime, durationMS, excludeAiringId, transaction }): Promise<void>`: throws `ConflictError(msg, { code: AIRING_OVERLAP })`; the message names what it overlaps.
  - `assertEpisodeHasAudio({ episodeId, transaction }): Promise<void>`: throws a message-only `ConflictError`.
  - `withEpisodeStationLocks<T>(episodeId: string, fn: (transaction: Transaction) => Promise<T>): Promise<T>`: authorizes nothing. It takes `acquireSchedulingLock` for every station that has an Airing of the Episode, plus the Episode's own station, in ascending `stationId` order, and runs `fn` in one transaction.
- Produces, in `scheduler.ts`: `repairScheduleForAiring({ airingId, stationId, transaction }): Promise<void>`. It removes only spins with this `airingId` and calls `reflowAfterRemoval`. After a move, call `insertAirings({ stationId, assumeLocked: true, transaction })` with no `windowOverride` (same as create), so a move into the already-built playlist materializes immediately and a later one waits for ordinary processing.

- [ ] **Step 1: Write failing tests**, one assertion each where possible:
  - `create refuses a past airtime with the too-soon message`.
  - `create refuses an episode with no audio`.
  - `create refuses an overlap with another airing with AIRING_OVERLAP`.
  - `create allows end-to-start adjacency across midnight` (first Show ends 23:59:59.999 Chicago, second starts 00:00).
  - `create refuses overlapping a live-show block with AIRING_OVERLAP` (replaces the old 400 `LIVE_SHOW_AIRING_CONFLICT` test).
  - `create refuses overlapping a giveaway airing with AIRING_OVERLAP`.
  - `create inside six hours succeeds`.
  - `move is refused at exactly airtime minus six hours and allowed 1 ms before` (sinon fake timers).
  - `move is refused once the airing has spins`.
  - `move leaves other airings, listener-question airings, live blocks and giveaway spins unchanged`: snapshot `spins` (id, airtime) excluding the moved Airing; expect deep equal.
  - `delete ignores the six-hour lock`.
  - `delete inside two minutes keeps the existing message`.
  - `delete leaves every other spin unchanged`: same snapshot assertion.
  - `writes to an episode with airings on two stations need edit rights on both`.
- [ ] **Step 2:** Run `npm test -- --grep "airing"`. Expect FAIL.
- [ ] **Step 3:** Implement per endpoints.md "Shared contracts", "POST /v1/airings", "PUT /v1/airings/:airingId" and "DELETE /v1/airings/:airingId".
  - Run all checks after `acquireSchedulingLock`.
  - Remove the silent push-back at schedule time (`scheduler.ts:75-103`) only for the create path. Materialization keeps it.
  - Model `repairScheduleForAiring` on `deleteListenerQuestionAiringFromSchedule`.
  - Reuse the existing too-soon throw (`airings.lib.ts:264-265`) on create; no code.
- [ ] **Step 4:** Run `npm test -- --grep "airing|scheduler"`. Expect PASS. Also run the full `lib/scheduler` and `lib/giveaways` suites (touched-area regression rule).
- [ ] **Step 5:** Commit `feat: refuse overlapping or locked show times and repair only the moved show`.

### Task B1.4: Segment routes — editor auth, ownership, batch insert, lock and overlap

**Files:**
- Modify: `server/src/api/episode/index.ts:59-74` (add the station-editor check), `episode.controller.ts` remove/edit segment endpoints (~`:110-140`; pass the path `episodeId`, which they ignore today)
- Modify: `server/src/lib/episodes/episodes.lib.ts` (`addEpisodeSegment:212`, `removeEpisodeSegment:288`, `editEpisodeSegment:431`)
- Modify: `api/episode/ENDPOINTS.md`, `episode.api.docs.yaml`
- Test: `lib/episodes/episodes.lib.test.ts`, `api/episode/episode.api.test.ts`

**Interfaces:**
- Consumes: `withEpisodeStationLocks`, `assertEpisodeEditable`, `assertNoAiringOverlap`, `assertEpisodeHasAudio` (B1.3).
- Produces: `addEpisodeSegment({ episodeId, position, audioBlockId?, audioBlockIds?, songRequestId? })`. `audioBlockIds` inserts in order at `position`, all or nothing.

- [ ] **Step 1: Write failing tests:**
  - `POST segments by a non-editor is 403`.
  - `POST segments with audioBlockIds [q, a] adds both in order`.
  - `POST segments with audioBlockIds where the second id does not exist adds neither` (count segments before/after).
  - `POST segments with both audioBlockId and audioBlockIds is 400`.
  - `POST segments with empty audioBlockIds is 400`.
  - `POST segments on a locked episode is 409 AIRING_EDIT_LOCKED`.
  - `POST segments that make a scheduled episode overlap the next airing is 409 AIRING_OVERLAP and adds nothing`.
  - `PUT segment from another episode's path is 404`.
  - `DELETE segment from another episode's path is 404`.
  - `refusesRemovingLastAudioFromScheduledEpisode` (409, message only).
  - `a draft may become empty`.
  - `two concurrent POSTs to one episode both land with distinct positions` (`Promise.all`).
- [ ] **Step 2:** Run `npm test -- --grep "segment"`. Expect FAIL.
- [ ] **Step 3:** Implement per endpoints.md segment sections and "Content changes never touch spins". Wrap each change in `withEpisodeStationLocks`. Apply the change and `calculateShowSegmentTimings`, then run the checks; a throw rolls back. No spin changes.
- [ ] **Step 4:** Run `npm test -- --grep "segment|episode"`. Expect PASS.
- [ ] **Step 5:** Commit `feat: protect show content edits with the station editor check and the edit lock`.

### Task B1.5: Series changes and repeating schedules

**Files:**
- Modify: `server/src/lib/episodes/episodes.lib.ts` (`updateEpisode:334`), `lib/shows/shows.lib.ts` (`createShow:88`, `updateShow:129`)
- Modify: `api/episode/*`, `api/show/*` controllers, `ENDPOINTS.md`, `*.api.docs.yaml`
- Test: `lib/episodes/episodes.lib.test.ts`, `lib/shows/shows.lib.test.ts`, `api/episode/episode.api.test.ts`, `api/show/show.api.test.ts`

**Interfaces:**
- Produces: `updateEpisode({ episodeId, title?, showId?: string | null, userId })` returning the Episode with `show` and `airings`. No lock check.

- [ ] **Step 1: Write failing tests:**
  - `PUT episode showId moves a standalone episode into a series and deletes the emptied wrapper`.
  - `PUT episode showId null creates a wrapper titled like the episode and keeps the airtime`.
  - `PUT episode showId null on an already-standalone episode changes nothing`.
  - `PUT episode to a series on another station is 400`.
  - `PUT episode showId on a locked episode succeeds`.
  - `POST shows saves rrule`.
  - `POST shows with rrule and isOneTime is 400`.
  - `POST and PUT shows with a non-weekly rrule are 400` (`INTERVAL=2`, `FREQ=MONTHLY`, `FREQ=DAILY`, `COUNT=3`, no `BYDAY`).
  - `PUT shows rrule null clears it`.
  - `PUT shows rrule longer than 255 is 400`.
  - `PUT shows rename of a one-time wrapper whose episode is locked succeeds`.
- [ ] **Step 2:** Run `npm test -- --grep "episode|show"`. Expect FAIL.
- [ ] **Step 3:** Implement per endpoints.md "PUT /v1/episodes/:episodeId", "POST /v1/shows" and "PUT /v1/shows/:showId". Lock the source and target Shows by id (`lockShowForUpdate`), then re-read membership. The weekly-only `rrule` check may already exist from the standalone server PR (spec.md approval log entry 16); reuse it for create rather than adding a second validator.
- [ ] **Step 4:** Run the full `npm test`, then `npm run lint` and `npm run docs:check`. Expect all green. Add the `CHANGELOG.md` Changes entry (website moves inside 6 hours and overlapping times are refused with a message). No migration in B1.
- [ ] **Step 5:** Commit `feat: move shows between series and save series schedules`.

---

# Backend (`playola`) — PR B2: LIVE badge (merged, playola #1142)

### Task B2.1: LIVE status follows a recorded show's real playback

**Files:**
- Modify: `server/src/lib/stations/stations.lib.ts:2064-2200` (`getLiveStations`)
- Modify: `api/station/ENDPOINTS.md` (behavior note)
- Test: `server/src/api/station/station.live.api.test.ts`

**Interfaces:**
- Consumes: `embedAiringTimes` (B1.2).

- [ ] **Step 1: Write failing tests:**
  - `show_airing starts at the first spin of the airing, not airtime`.
  - `show_airing ends after the last spin's endOfMessage`.
  - `an airing with no spins is not show_airing`.
  - `a voicetrack inside a recorded show does not mark the station voicetracking hours earlier`: an earlier voicetrack 3 h before the Show plus the Show's own voicetrack → not live at Show −2 h.
  - `a voicetrack outside any airing still marks voicetracking`.
- [ ] **Step 2:** Run `npm test -- --grep "live"`. Expect FAIL.
- [ ] **Step 3:** Exclude spins with a non-null `airingId` from the voicetrack window query. Compute `show_airing` from the first and last actual spin; an Airing with no spins is not `show_airing` (its nominal `startTime`–`endTime` is not playback evidence).
- [ ] **Step 4:** Run again. Expect PASS.
- [ ] **Step 5:** Commit `fix: show the LIVE badge only while a recorded show is actually playing`.

### Task B2.2: "On now" follower push

Superseded by playola #1120, which already pushes followers when a scheduled show starts (8am–9pm Central starts, at most once per station per Central day, skipped after a manual or Ask Me Anything push in the prior 4 hours). Not implemented; there is no worker, no `airings.onNowNotificationSentAt` column and no migration.

---

# iOS (`playola-radio-ios`) — PR I1: data layer

The PlayolaPlayer SDK's `Episode`/`Show`/`Station` (`PlayolaCore`) lack segments, `isOneTime`, `airingEditLockMS` and `timezone`. The curator screens get **app-local** types decoded straight from the API, so no SDK release is needed. Slot occupancy uses the existing `api.getAirings` (SDK `Airing.airtime`). Listener code keeps using the SDK types.

Test command for every iOS task: `xcodebuild test -project PlayolaRadio.xcodeproj -scheme PlayolaRadio -destination 'platform=iOS Simulator,id=<booted sim id>' -skipPackagePluginValidation -only-testing:PlayolaRadioTests/<SuiteName>`. Allow ~10 minutes and use `/tmp` for `-derivedDataPath`, never `.context/`. Run the full suite and `make lint` before each PR.

### Task I1.1: Curator models and Show state

**Files:**
- Create: `PlayolaRadio/Models/CuratorEpisode.swift` (`CuratorEpisode`, `CuratorEpisodeSegment`, `CuratorAiring`, `CuratorSeries`, `StationSchedulingSettings`, `CuratorEpisodeState`)
- Test: `PlayolaRadio/Models/CuratorEpisodeTests.swift`

**Interfaces:**
- Produces:
  - `struct CuratorSeries: Codable, Equatable, Identifiable, Sendable { id, stationId, title: String; isOneTime: Bool; rrule: String? }`
  - `struct CuratorAiring: Codable, Equatable, Identifiable, Sendable { id, episodeId, stationId: String; airtime: Date; startTime: Date?; endTime: Date? }`
  - `struct CuratorEpisodeSegment: Codable, Equatable, Identifiable, Sendable { id: String; position: Int; offsetMS: Int; audioBlock: AudioBlock? }` (`AudioBlock` from `PlayolaCore`)
  - `struct CuratorEpisode: Codable, Equatable, Identifiable, Sendable { id, showId, title: String; durationMS: Int; show: CuratorSeries?; segments: [CuratorEpisodeSegment]; airings: [CuratorAiring] }`. Missing `segments`/`airings` decode as `[]`.
  - `struct StationSchedulingSettings: Codable, Equatable, Sendable { timezone: String; airingEditLockMS: Int; var timeZone: TimeZone }` (falls back to `America/Chicago`)
  - `enum CuratorEpisodeState: Equatable { case draft, scheduled(CuratorAiring), locked(CuratorAiring), aired }` and `CuratorEpisode.state(now: Date, lockMS: Int) -> CuratorEpisodeState`. `locked` = not ended and (`now >= airtime − lockMS` or started).
  - `CuratorEpisode.isMultiAiring: Bool` (more than one Airing → read-only, not offered in pickers)
  - `CuratorEpisode.hasAudio: Bool` (`durationMS > 0`)

- [ ] **Step 1: Write failing tests** (swift-testing, `@Suite(.freshSharedState)`, `expectNoDifference`):
  - `decodesEpisodeWithSegmentsAndAirings` (JSON from endpoints.md "GET /v1/episodes", plus a segment).
  - `decodesRequestOnlySegmentWithoutAudio` (`audioBlock` absent → nil).
  - `stateIsDraftWithNoAirings`.
  - `stateIsScheduledOneMillisecondBeforeLock`.
  - `stateIsLockedAtExactlyAirtimeMinusLock`.
  - `stateIsLockedWhileOnAir`.
  - `stateIsAiredWhenEveryAiringEnded`.
  - `multiAiringEpisodeIsMultiAiring`.
- [ ] **Step 2:** Run the suite. Expect FAIL (types missing).
- [ ] **Step 3:** Implement the types above. Register the files in `project.pbxproj`.
- [ ] **Step 4:** Run. Expect PASS.
- [ ] **Step 5:** Commit `chore: add curator show types and their states`.

### Task I1.2: API client calls and the lock error

**Files:**
- Modify: `PlayolaRadio/Core/API/APIClient.swift` (closures + `APIError` case), `APIClient+Live.swift` (live implementations + error-body parsing next to `LiveShowConflictErrorBody:111`), `APIClientTestStubs.swift`
- Test: `PlayolaRadio/Core/API/APIClientRecordedShowsTests.swift`

**Interfaces:**
- Produces `APIError.recordedShowLocked(String)` (from `data.code == "AIRING_EDIT_LOCKED"`), whose `errorDescription` is the message. Every other refusal, including `AIRING_OVERLAP`, maps to the existing `.serverError(message)`.
- Produces these `APIClient` closures (all `@Sendable … async throws`, first parameter `jwtToken: String`, unimplemented-by-default like the existing ones):
  - `getCuratorEpisodes(stationId: String?, showId: String?) -> [CuratorEpisode]` → `GET /v1/episodes?…&includeAirings=true`
  - `getCuratorEpisode(episodeId: String) -> CuratorEpisode` → `GET /v1/episodes/:id?includeSegments=true&includeAirings=true`
  - `createStandaloneEpisode(stationId: String, title: String) -> CuratorEpisode` → `POST /v1/shows { stationId, title, isOneTime: true, firstEpisodeTitle: title }`, returns `episodes[0]`
  - `createEpisodeInSeries(showId: String, title: String) -> CuratorEpisode` → `POST /v1/episodes`
  - `updateEpisode(episodeId: String, update: CuratorEpisodeUpdate) -> CuratorEpisode` → `PUT /v1/episodes/:id`, where `struct CuratorEpisodeUpdate: Encodable, Sendable { var title: String?; var series: SeriesChange? }` and `enum SeriesChange { case join(String), makeStandalone }` encodes `showId` as the id or as an explicit JSON `null`
  - `addEpisodeSegments(episodeId: String, audioBlockIds: [String], position: Int) -> CuratorEpisode` (always the `audioBlockIds` form)
  - `moveEpisodeSegment(episodeId: String, segmentId: String, position: Int) -> CuratorEpisode`
  - `removeEpisodeSegment(episodeId: String, segmentId: String) -> CuratorEpisode`
  - `getCuratorSeries(stationId: String) -> [CuratorSeries]` → `GET /v1/shows?stationIds=`
  - `createSeries(stationId: String, title: String, rrule: String?) -> CuratorSeries`
  - `updateSeries(showId: String, title: String, rrule: String??) -> CuratorSeries` (outer nil = don't send `rrule`; `.some(nil)` = clear it)
  - `scheduleEpisode(episodeId: String, stationId: String, airtime: Date) -> Void` → `POST /v1/airings`
  - `moveAiring(airingId: String, airtime: Date) -> Void` → `PUT /v1/airings/:id`
  - `unscheduleAiring(airingId: String) -> Void`
  - `getStationSchedulingSettings(stationId: String) -> StationSchedulingSettings` → `GET /v1/stations/:id`, decoding only those two fields
  - Slot occupancy: the existing `getAirings(jwtToken, stationId)` (`APIClient.swift:188`), unchanged.

- [ ] **Step 1: Write failing tests** with the existing live-client test pattern in `APIClientTests.swift`:
  - `lockedErrorMapsToRecordedShowLocked`.
  - `overlapErrorMapsToServerErrorWithMessage`.
  - `unknownErrorCodeKeepsServerMessage`.
  - `seriesChangeMakeStandaloneEncodesExplicitNullShowId`.
  - `updateSeriesOmitsRruleWhenNotChanging`.
  - `updateSeriesSendsNullToClearRrule`.
- [ ] **Step 2:** Run the suite. Expect FAIL.
- [ ] **Step 3:** Implement per `.claude/API_CLIENT.md`. Every closure gets a `testValue` (unimplemented).
- [ ] **Step 4:** Run. Expect PASS.
- [ ] **Step 5:** Commit `chore: add recorded show API calls`.

### Task I1.3: Weekly schedules — read, write, open slots

**Files:**
- Create: `PlayolaRadio/Core/Formatters/SeriesSchedule.swift`
- Test: `PlayolaRadio/Core/Formatters/SeriesScheduleTests.swift`

**Interfaces:**
- Produces `struct SeriesSchedule: Equatable, Sendable`:
  - fields `weekdays: Set<Locale.Weekday>`, `hour: Int`, `minute: Int`
  - `init?(rrule: String)`: nil for any rule other than plain weekly (`INTERVAL` other than 1, `DAILY`, `MONTHLY`, `COUNT`, `UNTIL`, `DTSTART`, several times)
  - `var rrule: String`: the exact form in models.md "What iOS writes"
  - `var text: String`: plain English from the rule's own days and `BYHOUR`/`BYMINUTE` ("Every Sunday at 7pm"), shown as station wall-clock time with no time-zone conversion. The curator screens use this, not `RRuleFormatter`, because `RRuleFormatter` takes its time from the next Airing (`formatToPlainEnglish(rrule:airtime:)`), which is stale after a schedule change and missing for a Series with no Shows. A rule `init?` rejects displays as "Custom schedule". The listener `RRuleFormatter` is unchanged.
  - `func openSlots(after now: Date, in timeZone: TimeZone, occupiedIntervals: [DateInterval], limit: Int = 8) -> [Date]`: follows models.md "Expansion rules (iOS)" (skip the spring-forward gap, use the earlier fall-back instant, exclude slots inside an Airing interval, stop at `limit` or 52 weeks).

- [ ] **Step 1: Write failing tests:**
  - `weeklyRuleRoundTrips` (`"FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0"`).
  - `everyOtherWeekRuleIsNotEditable` (`INTERVAL=2` → nil).
  - `dailyRuleIsNotEditable` (`FREQ=DAILY` → nil).
  - `openSlotsSkipOccupiedIntervals`, including a candidate slot inside an Airing whose nominal airtime differs.
  - `openSlotsStopAtEight`.
  - `openSlotsSkipSpringForwardGap` (2:30 AM on 2027-03-14 Chicago).
  - `openSlotsUseEarlierInstantOnFallBack` (1:30 AM on 2026-11-01 Chicago).
  - `openSlotsUseStationTimeNotDeviceTime` (device `Asia/Tokyo`, station `America/Chicago`).
  - `textUsesRuleTimeNotDeviceTime` (`BYHOUR=19` reads "7pm" on a device in `Asia/Tokyo`).
  - `textForSeveralDays` (`BYDAY=TU,TH;BYHOUR=20` → "Every Tuesday and Thursday at 8pm").
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement with a `Calendar(identifier: .gregorian)` whose `timeZone` is the station's. No rrule library.
- [ ] **Step 4:** Run. Expect PASS. Run the full suite and `make lint`. Open the I1 PR against `feature/recorded-shows`.
- [ ] **Step 5:** Commit `chore: read and write weekly series schedules and find open slots`.

---

# iOS — screen PRs S1–S7: builder, sheets, lists, Station tab

The tasks below are grouped by kind; the PR graph table says which PR ships which task or test. Each PR includes only its own tests.

### Task I2.1: Show builder page

**Files:**
- Create: `PlayolaRadio/Views/Pages/ShowBuilderPage/ShowBuilderPageModel.swift`, `ShowBuilderPageView.swift`, `ShowBuilderPageTests.swift`
- Modify: `PlayolaRadio/Core/Navigation/MainContainerNavigationCoordinator.swift` (add `case showBuilderPage(ShowBuilderPageModel)`)
- Reuse: the AMA runner's playlist row (`AMAOpeningRowView`), voicetrack recording and upload (`AskMeAnythingLivePageModel.voicetrackActionTapped` / `waitForPendingUploads`), `CuratorSongPickerPageModel` (available songs only), and `AMAQuestionPickerPageModel` + `AMAAnswerQuestionPageModel` for Q&A

**Interfaces:**
- Consumes: I1 types and calls.
- Produces: `ShowBuilderPageModel(stationId: String, episodeId: String?, seriesId: String?, slot: Date?)`. `slot` pre-selects that time in the Schedule sheet. Mockups: screens.md "Show builder" (Draft, Scheduled, Locked).
- Produces: `func save(_ change: @escaping @MainActor (_ episodeId: String) async throws -> Void) async`. A private task chain: changes run one at a time in call order (each awaits the previous `Task`'s value). The first change creates the Episode (`createStandaloneEpisode`, or `createEpisodeInSeries` when `seriesId` is set), keeps that id even if the change fails, and never creates twice. After each change it refetches the Episode. The sheets it opens call back through `save`. A save keeps running after the builder closes.

- [ ] **Step 1: Write failing tests** (all copy asserted from the model; dependencies overridden with `withDependencies`):
  - `firstChangeCreatesOnce`.
  - `twoQuickChangesSaveInOrderOnce`: two changes started without awaiting the first, with a controllable stub continuation → the call log is `[create, add(a), add(b)]`.
  - `failedChangeKeepsCreatedId`.
  - `untouchedBuilderCreatesNothing`.
  - `viewAppearedLoadsEpisodeAndSettings`.
  - `addingQAndASendsBothIdsInOneRequest`.
  - `songPickerOffersAvailableSongsOnly`.
  - `reorderSendsNewPosition`.
  - `lockedRefusalSwitchesToLockedAndRefetches`: the stub throws `.recordedShowLocked(msg)` → `presentedAlert` carries the message and the state becomes `.locked`.
  - `failedSaveShowsAlertAndRefetches`.
  - `removingLastAudioOfScheduledShowShowsServerMessage`.
  - `lockedShowHidesAddActionsButKeepsRenameSeriesAndUnschedule`.
  - `navigationTitleAndStatusLinesMatchScreens` ("Not scheduled yet", "Airs at about …", "On air now").
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement per `.claude/PAGE_CREATION.md` and screens.md. Use `PlayolaAlert` for failed actions. Report caught errors except cancellations.
- [ ] **Step 4:** Run. Expect PASS.
- [ ] **Step 5:** Commit `feature: add the recorded show builder`.

### Task I2.2: Schedule sheet and Unschedule confirmation

**Files:**
- Create: `PlayolaRadio/Views/Pages/ScheduleShowSheet/ScheduleShowSheetModel.swift`, `ScheduleShowSheetView.swift`, `ScheduleShowSheetTests.swift`
- Modify: `PlayolaRadio/Views/Reusable Components/PlayolaSheet.swift` (add `case scheduleShow(ScheduleShowSheetModel)`)
- Modify: `ShowBuilderPageModel.swift` (Schedule / Change / Unschedule actions; Unschedule uses a `PlayolaAlert` confirm "Unschedule <Show>?" / "Keep it scheduled")

**Interfaces:**
- Produces: `ScheduleShowSheetModel(episode: CuratorEpisode, series: CuratorSeries?, settings: StationSchedulingSettings, occupiedIntervals: [DateInterval], initialTime: Date?, schedule: @escaping (Date) async throws -> Void)`. `schedule` is supplied by the caller: the builder passes one that goes through its `save` chain and calls `scheduleEpisode` for a draft or `moveAiring` for a scheduled Show.

- [ ] **Step 1: Write failing tests:**
  - `listsNextEightOpenSlotsForWeeklySeries`.
  - `noSlotsForStandaloneShowOrUnparseableRule`.
  - `tappingSlotFillsPickerWithoutScheduling`.
  - `showsLocksRightAwayInsideLock`.
  - `refusalShowsMessageAndDisablesScheduleUntilTimeChanges`.
  - `scheduleButtonDisabledWhileSaving`.
  - `scheduleSheetLabelsUseStationTimeZone`.
  - `unscheduleAsksFirst`.
  - `unscheduleInsideCutoffShowsServerMessage`.
  - `unscheduleReturnsShowToDraft`.
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement per screens.md "Schedule sheet" and "Unschedule confirmation".
- [ ] **Step 4:** Run. Expect PASS.
- [ ] **Step 5:** Commit `feature: schedule, move and unschedule recorded shows`.

### Task I2.3: Series picker and Series details sheets

**Files:**
- Create: `PlayolaRadio/Views/Pages/SeriesPickerSheet/SeriesPickerSheetModel.swift`, `SeriesPickerSheetView.swift`, `SeriesPickerSheetTests.swift`
- Create: `PlayolaRadio/Views/Pages/SeriesDetailsSheet/SeriesDetailsSheetModel.swift`, `SeriesDetailsSheetView.swift`, `SeriesDetailsSheetTests.swift`
- Modify: `PlayolaSheet.swift` (two cases), `ShowBuilderPageModel.swift` (series row)

**Interfaces:**
- Produces: `SeriesPickerSheetModel(stationId: String, episode: CuratorEpisode, change: @escaping (SeriesChange) async throws -> Void)` (the builder passes one through its `save` chain). `SeriesDetailsSheetModel(stationId: String, series: CuratorSeries?, settings: StationSchedulingSettings, onSaved: (CuratorSeries) -> Void)`: nil `series` = "New Series".

- [ ] **Step 1: Write failing tests:**
  - `pickerHidesOneTimeWrappers`.
  - `pickingSeriesSendsJoin`.
  - `removeFromSeriesSendsMakeStandalone`.
  - `newSeriesFromPickerCreatesThenJoins`.
  - `editSeriesWithUnparseableRuleShowsCustomScheduleAndSendsNoRruleOnRename`.
  - `saveEveryWeekSendsWeeklyRule`.
  - `noScheduleClearsRrule`.
  - `saveDisabledWithoutName`.
  - `saveDisabledForEveryWeekWithNoDay`.
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement per screens.md "Series picker sheet" and "Series details sheet".
- [ ] **Step 4:** Run. Expect PASS.
- [ ] **Step 5:** Commit `feature: pick and edit series for recorded shows`.

### Task I2.4: Upcoming, Individual Shows, Curator Series list, Curator Series page, Add a show sheet

**Files:**
- Create: `PlayolaRadio/Views/Pages/UpcomingShowsPage/…` (Model, View, Tests), `IndividualShowsPage/…`, `CuratorSeriesListPage/…` (with `CuratorSeriesCard.swift`, styled like the listener `SeriesCard`, which is not modified), `CuratorSeriesPage/…`, `AddShowToSeriesSheet/…`
- Modify: `PlayolaRadio/Views/Pages/SeriesListPage/EpisodeRow/EpisodeRow.swift` (`CalendarDateBadge` gains `timeZone: TimeZone = .current`; add a sibling `DraftDateBadge` with the amber pencil) and reuse `ScheduleBadge` (`SeriesCard.swift:164`) for the amber repeating-schedule badge
- Modify: `PlayolaSheet.swift` (`case addShowToSeries(AddShowToSeriesSheetModel)`), `MainContainerNavigationCoordinator.swift` (four page cases)

**Interfaces:**
- Consumes: `getCuratorEpisodes`, `getCuratorSeries`, `getAirings` (Curator Series list and Curator Series page only), `getStationSchedulingSettings`, `SeriesSchedule.openSlots`, `CuratorEpisode.state(now:lockMS:)`, `scheduleEpisode`, `moveAiring`, `updateEpisode(series:)`.
- Produces: `UpcomingShowsPageModel(stationId:)`, `IndividualShowsPageModel(stationId:)`, `CuratorSeriesListPageModel(stationId:)`, `CuratorSeriesPageModel(stationId:seriesId:)`, `AddShowToSeriesSheetModel(stationId:series:slot:)`.

- [ ] **Step 1: Write failing tests:**
  - `upcomingFetchesNoAirings` (the `getAirings` stub is unimplemented).
  - `upcomingCountsShowsNotAirings`.
  - `individualShowsListsDraftsFirstThenByAirtime`.
  - `showInSeriesCarriesSeriesBadge`.
  - `airedShowsAreNotListed`.
  - `multiAiringShowOpensReadOnly`.
  - `failedLoadShowsToastAndKeepsList`.
  - `seriesCardShowsOpenSlotsBetweenScheduledShows`.
  - `seriesWithoutScheduleShowsNoSlots`.
  - `emptySeriesListShowsOnlyCreateButton`.
  - `addShowOffersDraftsWithAudioAndUnlockedScheduledShows`.
  - `scheduledShowLabeledMovesHereFromOldTime`.
  - `lockedAndMultiAiringShowsNotOffered`.
  - `addingDraftToSlotSchedulesThenJoins` (call log `[scheduleEpisode, updateEpisode(join)]`).
  - `addingScheduledShowToSlotMovesThenJoins`.
  - `seriesStepFailureAfterScheduleShowsAlertAndKeepsAiring`.
  - `slotUnderLockLengthOpensScheduleSheetAtThatSlot`.
  - `recordNewShowFromSlotOpensBuilderWithSlot`.
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement per screens.md "Upcoming", "Individual Shows", "Curator Series list", "Curator Series page", "Add a show sheet".
- [ ] **Step 4:** Run. Expect PASS.
- [ ] **Step 5:** Commit `feature: list recorded shows and series with open slots`.

### Task I2.5: Station tab entry points and title renames

**Files:**
- Modify: `PlayolaRadio/Views/Pages/ArtistStationPage/ArtistStationPageModel.swift:73-135`, `ArtistStationPageView.swift:140`, `ArtistStationPageTests.swift`
- Modify: `ShowsPageModel.swift:88` ("Live"), `MusicLibraryPageModel.swift:41` ("Music"), `BreakersLibraryPageModel.swift:40` ("Breakers"), and their tests
- Modify: `LONG_RUNNING.md` (advance the recorded-shows row)

- [ ] **Step 1: Write failing tests:**
  - `stationTabShowsSectionsShowsAndLibrary` (SHOWS = Live, Upcoming).
  - `liveRowPushesShowsPage`.
  - `upcomingRowPushesUpcomingShowsPage`.
  - `everyDestinationTitleMatchesItsLink`.
- [ ] **Step 2:** Run. Expect FAIL.
- [ ] **Step 3:** Implement per screens.md "Station tab".
- [ ] **Step 4:** Run the full suite and `make lint`. Expect PASS. Verify on a simulator against staging (B1/B2 deployed there): create a draft, schedule it into a series slot, see it locked inside 6 hours, unschedule it.
- [ ] **Step 5:** Commit `feature: open recorded shows from the Station tab`. Open the S1 PR against `feature/recorded-shows`.

## Unresolved questions

- Delete a Series and delete a draft Show: deferred (spec Open questions).
- The empty Curator Series list is built from the Claude's-call description (page with only "Create a New Series"). It has no mockup.
