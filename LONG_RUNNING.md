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

_Last updated: 2026-08-08_

---

## Active

| Task | Status | Current step | Soak | Links |
|------|--------|--------------|------|-------|
| Host-owned audio → Sonos | 🟡 soaking | Phase 1 in prod (phased, from 2026-08-08); Phase 2+3 merged to develop, soaking on staging | Phase 1: prod phased rollout · Phase 2+3: staging soak from 2026-08-08 | PR #345 · #384 · plan |
| Clip share | 🔵 in progress | ⟨owner: current step⟩ | none (standard release) | PR #219 |
| Rewards → Your Library | 🔵 in progress | Rewards→Profile, Library tab, Presets move | none | PR #372 · `fix-library-requests-ui` |
| Siri "Play on Playola" (App Intents media schema) | 🟢 planning | Approach B decided (2026-06-14); not started | n/a | — |
| View/Model pattern cleanup | 🔵 in progress (opportunistic) | ongoing, fix-on-touch | none | `TODO_VIEW_MODEL_VIOLATIONS.md` |
| Prettify iPad screens | 🔵 in progress | Profile (screen 4 of N) | none (standard release) | specs in `docs/superpowers/specs/2026-08-0*-ipad-*-design.md` |

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
- [x] **Phase 1 — app owns session + interruptions** (PR #345) — released to production 2026-08-08 (🟡 phased-rollout soak)
- [x] **Phase 2 — single Now Playing writer** (low risk, PR #384) — 🟡 merged to develop, soaking on staging (removes URLStreamPlayer's MPNowPlayingInfoCenter writes; NowPlayingUpdater sole writer)
- [ ] **Verify URL stations → Sonos** (quick AirPlay-2 check; possible early win)
- [x] **Phase 3 — single state-derivation source** (PR #384) — 🟡 merged to develop, soaking on staging (StationPlayer is the sole `@Shared(.nowPlaying)` writer + single derivation authority; NowPlayingUpdater is now a pure renderer of `stationPlayer.$state`; structural + behavioral tests guard it)
- [ ] **Owned URLStreamBackend** (retire the vendored FRadioPlayer fork; optional)
- [ ] **Phase 5 — Sonos renderer** (AVSampleBuffer render path; big; own plan + server-flag rollout)

### Current step

Phase 1 **released to production 2026-08-08** (phased rollout under way). That lifted the
hold on PR #384 — the hold existed so the Phase 1 *staging* soak canary stayed attributable
to Phase 1 alone; Phase 1 is now off staging, so Phase 2+3 can soak there without
contaminating it (different metric stream from Phase 1's prod rollout).

**Phase 2 + Phase 3 merged to develop together (PR #384) and are now soaking on staging.**
Phase 2 (single MPNowPlayingInfoCenter writer): URLStreamPlayer no longer writes the lock
screen, NowPlayingUpdater is the sole writer. Phase 3 (single state-derivation source):
StationPlayer is the sole writer of `@Shared(.nowPlaying)` and the single derivation
authority — its backend processors publish `nowPlaying` as a projection of `state` (so the
two can't drift); NowPlayingUpdater is a pure renderer of `stationPlayer.$state`. Both
guarded by structural + behavioral tests.

**Next:** cut a staging TestFlight build (`fastlane release_staging` from develop), soak ~1
week (see "Soak — Phase 2+3"). **Do NOT cut the Phase 2+3 production release while Phase 1's
phased prod rollout is still in flight** — stacking two audio changes on real listeners
re-muddies prod attribution. Gate the prod cut on: staging soak clean AND Phase 1 prod
rollout completed cleanly.

Behavior change to note: URL stations now surface their ICY track artwork in the in-app
now-playing UI (SmallPlayer / PlayerPage), consistent with Playola stations. Phase 3 makes
`nowPlaying` a projection of `state`, and `processAlbumArtworkURLChanged` (the URL artwork
signal) now routes through the shared writer, so `state` and `nowPlaying` no longer drift
(previously the artwork lived only in `state` and surfaced only after an interruption). The
write is guarded to the URL backend so the stale `artworkDidChange(nil)` that every Playola
play triggers via `reset()` can't blank the active Playola spin's artwork. Lock-screen
artwork (station image) is unchanged.

### Soak — Phase 1

- **Environment:** staging TestFlight (cleared) → App Store phased rollout, **live from 2026-08-08**.
- **Now:** in production phased rollout. Watch the go/no-go metrics below across the
  rollout; hold Phase 2+3's *production* cut until this rollout completes cleanly.
- **Watch (go/no-go metrics):** Mixpanel `listeningSessionStarted` count + session
  length (the canary — a dip means audio broke in the field without a crash);
  Sentry for new `AVAudioSession` / `engine.start` error clusters.
- **Rollback lever:** known-good prior version is PlayolaPlayer **0.19.0**. Now that
  Phase 1 is live, roll back by shipping a build repinned to 0.19.0 (phased release
  again) — reverting source does *not* change binaries already installed.

### Soak — Phase 2+3

- **Environment:** staging TestFlight (from develop) → later a production phased rollout.
- **Soaking since:** 2026-08-08 (merged to develop). Cut the staging build with
  `fastlane release_staging` from develop; the "~1 week clean" clock runs from that build.
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
- **Advance when:** device matrix passes AND ~1 week clean staging dogfooding AND Mixpanel
  session metrics flat **AND Phase 1's production rollout has completed cleanly**. Then cut
  the Phase 2+3 production release.
- **Rollback lever:** revert the PR #384 merge on develop; nothing shipped to production
  until the gate above is met, so pre-prod rollback is just not cutting the release.

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

## View/Model pattern cleanup

Standing, **opportunistic** cleanup (fix-on-touch, not a scheduled task) —
tracked in `TODO_VIEW_MODEL_VIOLATIONS.md`. Listed here only for visibility; it
has no phases or soak. Don't spin up dedicated PRs for it; fix violations when
you're already in a file.

---

## Done

_(none yet — move tasks here with their completion date once their soak clears)_
