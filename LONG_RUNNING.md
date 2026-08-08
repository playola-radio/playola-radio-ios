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

_Last updated: 2026-08-06_

---

## Active

| Task | Status | Current step | Soak | Links |
|------|--------|--------------|------|-------|
| Host-owned audio → Sonos | 🟡 soaking | Phase 1 merged; staging soak + device matrix | Not started (pending first staging build) | PR #345 · plan |
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
- [x] **Phase 1 — app owns session + interruptions** (PR #345, merged to develop) — 🟡 soaking
- [ ] **Phase 2 — single Now Playing writer** (low risk, ~1 PR)
- [ ] **Verify URL stations → Sonos** (quick AirPlay-2 check; possible early win)
- [ ] **Phase 3 — single state-derivation source** (low–med risk, ~1 PR)
- [ ] **Owned URLStreamBackend** (retire the vendored FRadioPlayer fork; optional)
- [ ] **Phase 5 — Sonos renderer** (AVSampleBuffer render path; big; own plan + server-flag rollout)

### Current step

Phase 1 merged. Now: run the device-verification matrix on real hardware and
soak on staging before an App Store release. Phase 2 can proceed on develop in
parallel — it does not block the Phase 1 release soak.

### Soak — Phase 1

- **Environment:** staging TestFlight → then App Store 7-day phased rollout.
- **Soaking since:** not started yet — pending the first staging TestFlight build.
  Fill the date when it ships (the "~1 week clean" advance criterion is measured
  from here).
- **Device matrix (must pass before App Store):** phone-call/Siri interruption
  resumes · interruption-without-shouldResume stays paused · headphone unplug
  pauses (not stops) · Bluetooth A2DP + car HFP route · CarPlay connect/play/
  interrupt/resume · AirPlay long-form (watch for a `-50` on `.longFormAudio`) ·
  record voicetrack → stop → play → output not speaker-stuck · URL station
  interruption pauses/resumes via the coordinator.
- **Watch (go/no-go metrics):** Mixpanel `listeningSessionStarted` count + session
  length (the canary — a dip means audio broke in the field without a crash);
  Sentry for new `AVAudioSession` / `engine.start` error clusters.
- **Advance when:** device matrix passes AND ~1 week of clean staging dogfooding
  AND Mixpanel session metrics flat. Then cut the release; don't over-soak on
  develop (it just entangles with later changes).
- **Rollback lever:** known-good prior version is PlayolaPlayer **0.19.0**. Rolling
  back = revert the SPM pin (0.20.2 → 0.19.0) + revert the app PR, then **build and
  ship a new release** — reverting source does *not* change binaries already
  installed via TestFlight/App Store. Because Phase 1 hasn't reached production
  yet, the cheapest rollback right now is simply **not cutting the release**; once
  it's live, roll back by shipping a build repinned to 0.19.0 (phased release again).

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
