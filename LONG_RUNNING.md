# Long-Running Work

Tracks efforts that span **more than one PR** or that carry a **production soak** —
the things a single PR description can't hold. If a piece of work is one PR and
merges without a staged rollout, it does **not** belong here; a normal PR covers it.

**When to update:** the moment a task advances a step, changes soak state, or a
soak gate passes/fails — in the *same PR* that caused the change. Keeping this
current is the point; a stale tracker is worse than none. (See the "Long-Running
Work Tracking" rule in `CLAUDE.md`.)

**Status legend:** 🟢 planning · 🔵 in progress · 🟡 soaking (merged; watching staging → phased prod) · ✅ done · ⏸️ paused

**Soak is a first-class state here on purpose.** "Merged" ≠ "shipped safely."
Risky changes (especially audio) merge to `develop`, then **soak** on staging /
phased production while we watch metrics before they reach everyone. A task is
not ✅ done until its soak clears.

> Entries marked `⟨owner: …⟩` are placeholders the task owner should fill in —
> I scaffolded them from open PRs/branches but don't know the internal plan.

_Last updated: 2026-09-19_

---

## Active

**"Next check"** is the ISO date by which someone should look at the task again
(advance it, verify a soak gate, or ping the owner) — not a delivery deadline.
An item is **due** when today ≥ that date. Update it whenever you touch the
task. `—` = opportunistic, no scheduled check. Ask "What long-running tasks do
we need to tackle?" (or run the `whats-due` skill) to see what's due.

| Task | Status | Current step | Soak | Next check | Links |
|------|--------|--------------|------|------------|-------|
| Host-owned audio → Sonos | 🟡 soaking | Phase 1 done (7.4.2 at 100% since ~2026-08-09, canary clean); Phase 2+3 shipping to prod in 7.5.1 | Phase 2+3: prod phased rollout via 7.5.1 (submission held on device matrix) | 2026-09-03 | PR #345 · #384 · #402 · plan |
| AirPlay-2 sample-buffer renderer (Phase 5) | 🟡 soaking | App on SDK **0.21.0 (stable)**; **shipping to 100% of users in 7.6.0** (PR #408) — the server flag is now a **rollback lever**, not a rollout gate | prod at **100%**: the sample-buffer renderer is served to everyone via the server flag. Kill lever (rollback): flip `SAMPLE_BUFFER_RENDERER_ALLOWED=false` (or clear the enabled env) to revert the whole population to the legacy renderer at each user's next app launch (backend locks per process). Watch Mixpanel `render_backend` on Listening Session Started + Sentry `render_backend` tag; hold ✅ until metrics clean across a full release cycle | 2026-09-10 | PR #404 · #408 |
| Clip share | 🔵 in progress | ⟨owner: current step⟩ | none (standard release) | 2026-09-10 | PR #219 |
| Rewards → Your Library | 🔵 in progress | Rewards→Profile, Library tab, Presets move | none | 2026-09-10 | PR #372 · `fix-library-requests-ui` |
| Siri "Play on Playola" (App Intents media schema) | 🟢 planning | Approach B decided (2026-06-14); not started | n/a | 2026-10-01 | — |
| View/Model pattern cleanup | 🔵 in progress (opportunistic) | ongoing, fix-on-touch | none | — | `TODO_VIEW_MODEL_VIOLATIONS.md` |
| Prettify iPad screens | 🔵 in progress | Profile (screen 4 of N) | none (standard release) | 2026-09-10 | specs in `docs/superpowers/specs/2026-08-0*-ipad-*-design.md` |
| Artist 3-tab IA (broadcast redesign) | 🔵 in progress | Step 2: Dashboard health + Listeners cards + 8-week chart wired; Station tab's third link row now pushes a new Breakers Library category list (categories fetch, non-song + zero-clip filter) with a per-category detail page (per-clip audio preview, play/stop toggle + scrubber) landed in PR #417; re-homing next — **must not merge until Step 3 re-homes Broadcast/Library/Listeners** | none (standard release) | 2026-09-10 | designs `design/exports/in-progress/3-tab-ia` · `design/exports/breakers-library` · `design/DESIGN_STATUS.md` |
| Artist Dashboard API Repair | 🔵 in progress | iOS PR (this repo) repointed to the new/renamed endpoints and is ready for staging verification; server PR (playola repo) is owned by a separate human implementer, not tracked here in detail | **prod gate**: server must ship `programming-health` + the station-filtered `listener-counts`/`active` work to production before any App Store release containing the dashboard | 2026-09-19 | see "Artist Dashboard API Repair" section below |
| Ask Me Anything live show | 🔵 in progress | PR1 (Start Show → schedule → live monitor) implemented, ready for review; PR2 (Add to Show while live) and PR3 (queue reorder/lock) not started | none (standard release); don't cut an App Store release while server AMA endpoints are unshipped to prod | 2026-09-26 | see "Ask Me Anything live show" section below |

---

## Prettify iPad screens

**Goal:** the app is iPhone-first; on iPad several screens render as a single narrow
column with large dead space and misplaced controls. Make them "not embarrassing" on
iPad, **one screen at a time**, without taxing the maintained iPhone path.

**Guiding constraint (load-bearing):** iPad is **not** a maintained priority. Each
screen's iPad layout must be **quarantined** — the iPhone/compact path stays byte-for-byte
unchanged and no shared abstraction may couple iPhone changes to iPad. iPad code lives in
its own `*PadView` file, branched once on `horizontalSizeClass == .regular`, reusing only
already-shared leaf components + the page model. Design drift (iPad styling lagging
iPhone) is acceptable. Any iPad file may be deleted wholesale without touching iPhone.

### Screens

- [ ] **Radio Stations** — 2-col grid, top search, right-aligned suggest button.
      Spec: `docs/superpowers/specs/2026-08-05-ipad-radio-stations-design.md`. 🔵 in progress.
- [ ] **Home** — logo+welcome header, 2-col compact reward/listening tiles, 2-col station
      card grid (reuses the shared `StationCardView`). `HomePagePadView.swift`.
      Spec: `docs/superpowers/specs/2026-08-06-ipad-home-design.md`. 🔵 in progress.
- [ ] **Sign In** — centered, width-constrained auth card on the gradient (logo, wordmark,
      welcome text, Google + Apple buttons, terms footer). `SignInPadView.swift`.
      Spec: `docs/superpowers/specs/2026-08-06-ipad-sign-in-design.md`. 🔵 in progress.
- [ ] **Profile** ("Your Profile" tab = `ContactPageView`) — centered profile card + 2-col
      action-button grid, outlined Log out below. `ContactPagePadView.swift`.
      Spec: `docs/superpowers/specs/2026-08-06-ipad-profile-design.md`. 🔵 in progress.
- [ ] (further screens added as they're tackled)

### Current step

Profile: `ContactPagePadView` implemented (branched on `horizontalSizeClass` in
`ContactPageView`); no model change (all text/flags already existed). iPhone path untouched.
Verified via `ImageRenderer` throwaway render.

---

## Host-owned audio → Sonos

**Goal:** make the app the single owner of the AVAudioSession / interruptions /
Now Playing, then swap the Playola render path so stations can cast to Sonos
(AirPlay 2 long-form). Fixes existing bugs (won't-resume-after-interruption,
CarPlay teardown, speaker-stuck-after-recording) along the way.

**Plan doc:** `~/playola/shared/PLAYOLA_AUDIO_OWNERSHIP_PLAN.md` (authoritative).

### Phases

- [x] **Phase 0 — SDK host-only** (shipped as PlayolaPlayer 0.20.0 → 0.20.2)
- [x] **Phase 1 — app owns session + interruptions** (PR #345) — ✅ done. Shipped in 7.4.2 (build 103); went to **100% immediately** (no phased rollout, despite the plan). Field adoption from ~2026-08-09. Canary verified clean 2026-08-19: listening minutes/session *up* post-rollout, zero new audio clusters in Sentry, and the one real CoreAudio issue (APPLE-IOS-1P "player did not see an IO cycle") has zero events on 7.4.2.
- [x] **Phase 2 — single Now Playing writer** (low risk, PR #384) — 🟡 shipping to prod in **7.5.1** (PR #402); staging-soaked since 2026-08-08 (removes URLStreamPlayer's MPNowPlayingInfoCenter writes; NowPlayingUpdater sole writer)
- [ ] **Verify URL stations → Sonos** (quick AirPlay-2 check; possible early win)
- [x] **Phase 3 — single state-derivation source** (PR #384) — 🟡 shipping to prod in **7.5.1** (PR #402); staging-soaked since 2026-08-08 (StationPlayer is the sole `@Shared(.nowPlaying)` writer + single derivation authority; NowPlayingUpdater is now a pure renderer of `stationPlayer.$state`; structural + behavioral tests guard it)
- [ ] **Owned URLStreamBackend** (retire the vendored FRadioPlayer fork; optional)
- [ ] **Phase 5 — Sonos renderer** (AVSampleBuffer render path; big; own plan + server-flag rollout)

### Current step

**Shipping Phase 2+3 to production via 7.5.1 (PR #402, this PR).** What happened between
the last update and now, discovered 2026-08-19:

- 7.4.2 (Phase 1) shipped to **100% immediately** — it was never a phased rollout. It's been
  in the field at scale since ~2026-08-09 with clean metrics (see Phase 1 checklist entry).
- **7.5.0 was tagged (`v7.5.0-b103`) and its build uploaded to TestFlight (build 104) but
  never submitted to the App Store** — no 7.5.0 version record exists in ASC. The release
  process ends at TestFlight; the ASC submission step is manual and silently didn't happen.
  Its payload (Phase 2+3 + iPad layouts) therefore ships in 7.5.1 instead.
- Phase 2+3's gates were re-verified 2026-08-19: staging soak 11 days (> the ~1-week bar),
  Mixpanel canary flat-to-up, Sentry clean. **Remaining gate: the device matrix below —
  the 7.5.1 ASC submission is held until it passes.**

**Phase 2 + Phase 3 (merged to develop 2026-08-08, PR #384).**
Phase 2 (single MPNowPlayingInfoCenter writer): URLStreamPlayer no longer writes the lock
screen, NowPlayingUpdater is the sole writer. Phase 3 (single state-derivation source):
StationPlayer is the sole writer of `@Shared(.nowPlaying)` and the single derivation
authority — its backend processors publish `nowPlaying` as a projection of `state` (so the
two can't drift); NowPlayingUpdater is a pure renderer of `stationPlayer.$state`. Both
guarded by structural + behavioral tests.

**Next:** device matrix on the 7.5.1 build → create ASC version 7.5.1, attach the build,
**phased release ON** (7.4.2 skipped it; for an audio change we want the pause lever), submit.
Watch the canary across the 7-day rollout. Koozie/develop content waits for the next release
(7.6.x) so this rollout's audio attribution stays clean.

Behavior change to note: URL stations now surface their ICY track artwork in the in-app
now-playing UI (SmallPlayer / PlayerPage), consistent with Playola stations. Phase 3 makes
`nowPlaying` a projection of `state`, and `processAlbumArtworkURLChanged` (the URL artwork
signal) now routes through the shared writer, so `state` and `nowPlaying` no longer drift
(previously the artwork lived only in `state` and surfaced only after an interruption). The
write is guarded to the URL backend so the stale `artworkDidChange(nil)` that every Playola
play triggers via `reset()` can't blank the active Playola spin's artwork. Lock-screen
artwork (station image) is unchanged.

### Soak — Phase 1 (✅ cleared 2026-08-19)

- Shipped in 7.4.2 (build 103), live at **100% from ~2026-08-09** (released all-at-once,
  not phased). ~11 days of field exposure at 87% adoption of the active listening base.
- **Canary results (verified 2026-08-19):** weekly `listeningSessionStarted` flat through
  the rollout (the 7.4.2-crossover week was the highest of the four-week window); per-user
  session counts on 7.4.2 ≥ same-window 7.3.1; server-side listening minutes hit the
  window's high the week 7.4.2 owned the base, with avg session length up 28.5 → 32.7 min.
  Sentry: zero new audio clusters; APPLE-IOS-1P (CoreAudio IO-cycle) has no 7.4.2 events.
- **Rollback lever (unchanged, now historical):** repin PlayolaPlayer 0.19.0 and ship.

### Soak — Phase 2+3

- **Environment:** staging TestFlight (from develop) → production phased rollout via 7.5.1.
- **Staging soak:** 2026-08-08 → 2026-08-19 (11 days, clean) — the ~1-week bar is met.
- **Device matrix (must pass before the production cut) — focused on the now-playing
  surface these phases change:** lock screen shows the correct track/title/artist ·
  **CarPlay Now Playing is NOT dismissed when a Playola station starts** (the `.urlNotSet`
  ownership guard) · interruption pause keeps artwork + metadata and the play button
  resumes · station switch updates the lock screen · **URL station shows ICY track artwork
  in-app** (new in Phase 3 — confirm it reads as an improvement). Re-run the Phase 1
  interruption/route/Bluetooth/CarPlay matrix too, since these phases sit on that path.
- **Watch (go/no-go metrics):** same canary — Mixpanel `listeningSessionStarted` count +
  session length; Sentry for `AVAudioSession` / `engine.start` clusters and any new
  MediaPlayer/now-playing errors.
- **Advance when:** device matrix passes (**the only gate still open** — staging soak,
  Mixpanel, Sentry, and Phase 1 all verified clean 2026-08-19). Then submit 7.5.1 in ASC
  with phased release ON.
- **Rollback lever:** before ASC submission — just don't submit. During the phased rollout —
  pause it in ASC; if a fix is needed, revert PR #384 on a hotfix branch from main and ship.

### Notes

- FRadioPlayer is now a maintained local package (`LocalPackages/FRadioPlayer`),
  isolated from the app's strict build settings.
- Phase 5 (the actual Sonos-enabling renderer) is the highest-risk item and gets
  its own Codex-architected plan + server-flag (not env-gate) staged rollout.

---

## Clip share

**Goal:** let listeners download and share audio clips of their Q&A airings
(spin-based clip identity for natural de-duplication). Includes MyAiringsPage,
push-notification handling, and homepage integration.

- **Status:** 🔵 in progress — PR #219 (open since 2026-03-19).
- **Steps:** `⟨owner: break into steps / what's left⟩`
- **Soak:** none expected (feature behind normal release; no process-global risk).
- **Links:** PR #219.

---

## Rewards → Your Library

**Goal:** replace the Rewards tab with a **Your Library** tab (heart icon); Rewards
moves to a button on Profile; the Presets carousel moves from Radio Stations to
the top of Your Library.

- **Status:** 🔵 in progress — PR #372.
- **Steps:** `⟨owner: is this one PR or a Library-area cluster? (a fix-library-requests-ui branch exists)⟩`
- **Soak:** none (UI reorg).
- **Links:** PR #372, branch `fix-library-requests-ui`.

---

## Siri "Play on Playola" (App Intents media schema)

**Goal:** make "Play {station} on Playola" route to Playola instead of Apple Music,
by adopting the App Intents media Assistant Schema (approach B, decided 2026-06-14).

- **Status:** 🟢 planning — decided, not started.
- **Steps:** `⟨owner: scope into a plan when prioritized⟩`
- **Soak:** n/a until built.
- **Notes:** SSU voice model is processed server-side by Apple; voice lags the
  install, the action works immediately.

---

## Artist 3-tab IA (broadcast redesign)

**Goal:** replace the broadcast-mode experience with the 3-tab IA from
`design/exports/in-progress/3-tab-ia` (Dashboard · Station · Profile). No existing
screens are eliminated — they move a level below the new tab roots (e.g. the
broadcast schedule screen will hang off the new Station tab).

- **Status:** 🔵 in progress.
- **Steps:**
  1. New tabs + placeholder pages — broadcast-mode tabs are now
     Dashboard (`ArtistDashboardPage`) / Station (`ArtistStationPage`) / Profile
     (old ContactPage), with hardcoded model values to lock the visuals. Old
     Broadcast/Library/Listeners tabs removed from the tab bar (pages kept).
     Revised per design v2 (2026-08-28): Home renamed to Station, Dashboard
     moved first and absorbed the improve-your-station checklist.
  2. Wire real data into Station + Dashboard models — **in progress.** Dashboard's
     Station Health ring + improve-your-station list are live against
     `GET /v1/stations/:id/programming-health`; the Listeners cards (NOW / THIS WEEK /
     THIS MONTH) are live against `GET /v1/listening-sessions/active` (global path,
     `stationId` query param) and the "Last 8 Weeks" chart against
     `GET /v1/stations/:id/listener-counts` (station-scoped path, `granularity=week`
     + explicit `startDate`/`endDate` query params) —
     (`ListenerAnalytics` DTOs + `api.getActiveListeningSessions` /
     `api.getListenerCounts`; see the "Artist Dashboard API Repair" entry below for
     why these paths changed from the original station-scoped ones). Remaining: the
     weekly-report header trend ("↑ 12%", awaiting the percent-change deltas
     fast-follow) and the Station tab.
  3. `⟨re-home the old screens (schedule, library, listeners) a level below⟩`
- **Merge gate:** this work must **not** merge to `develop` on its own until Step 3
  re-homes Broadcast, Library, and Listeners. Steps 1–2 remove those tabs from the
  tab bar while their destinations are still unreachable, so merging before Step 3
  would strand live screens and leave `develop` non-deployable. Keep the whole
  effort on the feature branch until Step 3 lands (or lands in the same PR).
- **Soak:** none (standard release), but don't cut an App Store release while
  broadcast mode is mid-transition in a way that strands a screen.
- **Notes:** design status per frame lives in `design/DESIGN_STATUS.md`
  (3-Tab IA rows `tscZI` / `NLnb0` / `LeACy` → Implementing). Home v2 2-tab
  alternative (`ccNgg`) pending an explicit Dropped decision.

---

## Artist Dashboard API Repair

**Goal:** the Artist Dashboard (Step 2 of the 3-tab IA above) called three
station-scoped server endpoints that a server tree-reset deleted before the
dashboard ever shipped. Repoint the client to the endpoints that actually
exist post-reset, matching a contract the two repos agreed on.

**Why this is cross-repo (2 PRs):** the client-facing contract required real
server changes (a new `programming-health` response shape, a `stationId`
filter + authz on the previously-global `listener-counts`/`active` endpoints),
so this can't land as a single-repo PR.

- **PR 1 (server, playola repo, base `develop`):** provide the station-scoped
  analytics the client consumes — a `stationId`-filtered active-listeners count
  on `GET /v1/listening-sessions/active` (query param) and a station-scoped
  `GET /v1/stations/:id/listener-counts`, both with participant authz (admin or
  owner/contributor/viewer of that station). **Owned by a separate human
  implementer as of 2026-09-12 — not built or tracked in detail from this
  repo.**
- **PR 2 (iOS, this repo):** repoint `APIClient+Live.swift` to the
  agreed-on contract — `getActiveListeningSessions` now hits the global
  `/v1/listening-sessions/active` path with a `stationId` query param;
  `getListenerCounts` hits the station-scoped
  `/v1/stations/:id/listener-counts` path with explicit `startDate`/`endDate`
  (America/Chicago week range, computed client-side) and `granularity=week`;
  `getStationHealthScore` is renamed to
  `getProgrammingHealth` and returns the new `ProgrammingHealth` model
  (`freshPct`-driven health ring, server-owned `status`, per-check progress).
  Old `StationHealth` model deleted. Status: implemented, tests green, ready
  for an authenticated staging smoke pass against the server's `develop`
  branch once PR 1 lands.

**Production gate (load-bearing):** the server must ship `programming-health`
+ the station-filtered `listener-counts`/`active` work to **production**
before any App Store release that contains the Artist Dashboard. Verified
2026-09-12: the dashboard has never shipped (not in `origin/main`, not in any
release tag through v7.6.0-b105) — no production user has a broken dashboard
today, so there's no compat shim to maintain; the gate only sequences the
*future* release. No environment gating in the client (hard project rule):
the dashboard points at the same endpoints in every environment, and the
server release date is what gates the App Store release, not a runtime check.

**Advance when:** PR 1 merges to the server's `develop` and deploys to
staging → run the authenticated iOS smoke pass against staging → once clean,
this task's remaining gate is the server's production deploy, tracked here
until it ships and an App Store release containing the dashboard is cut.

**Links:** iOS PR 2 branch `briankeane/artist-dashboard-api-repair` (this
repo). Server PR 1 tracked in the playola repo by its own implementer.

---

## Ask Me Anything live show

**Goal:** let a station host run a live "Ask Me Anything" show — record an opening,
go live, and monitor the show (listener count, now-playing, upcoming queue,
preparedness meter) with an End Show flow. Multi-PR because the full feature (live
editing, queue management) is too large for one deployable PR.

**Spec:** `docs/superpowers/specs/2026-09-18-ama-live-show-design.md`
**Plan:** `docs/superpowers/plans/2026-09-18-ama-live-show.md`

- **PR 1 (this repo, base `develop`) — implemented, in review.** Wire "Start Show":
  wait for pending voicetrack uploads, collect the ordered opening audioBlockIds,
  POST to schedule the show, persist `ActiveLiveShow`, and navigate (replacing the
  setup route) to the AMA Live monitor — waiting→running phases, live listener
  count, schedule-derived now-playing, read-only upcoming queue, a client-computed
  "buffered" preparedness meter, and the End Show flow. "Add to Show" is rendered
  **disabled**; queue reorder/lock deferred; the availability endpoint is
  intentionally **not** wired.
- **PR 2 — not started.** Enable "Add to Show" (append material to a running show).
- **PR 3 — not started.** Queue reorder / lock.

- **Soak:** none (standard release).
- **Release gate:** the server's AMA endpoints (`startLiveShow`, `endLiveShow`,
  schedule/live-show fields) must be live in **production** before an App Store
  release containing this feature is cut. No environment gating in the client
  (hard project rule) — the server ship date sequences the release, not a runtime
  check.

---

## View/Model pattern cleanup

Standing, **opportunistic** cleanup (fix-on-touch, not a scheduled task) —
tracked in `TODO_VIEW_MODEL_VIOLATIONS.md`. Listed here only for visibility; it
has no phases or soak. Don't spin up dedicated PRs for it; fix violations when
you're already in a file.

---

## Done

_(none yet — move tasks here with their completion date once their soak clears)_
