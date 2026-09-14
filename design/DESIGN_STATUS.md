# Design Status

See `design/README.md` for how to consume these designs (PNG exports + JSON specs).

Tracks every design in `design/playola-ios.pen` and whether it has been implemented
in the app. **Update this file in the same PR that implements (or drops) a design**,
and keep the canvas label notes in sync with it.

Node IDs refer to top-level frames in the `.pen` file (stable across edits; new IDs
are only generated if a frame is copy-pasted — prefer moving/renaming frames so IDs
survive).

## Canvas layout

The canvas is organized into labeled horizontal zones, top to bottom. Each zone is
enclosed in a color-coded background rectangle (the `Zone · …` nodes at the back of
the document), with a large color-matched zone title above it and its label note to the left:

| Zone color | Meaning |
|---|---|
| Gray | Components — shared library (`mykNr`) |
| Green | Current app — shipped (`iPLiG` listener, `g7bIip` broadcaster) |
| Amber | Proposal, exploring (`nz0Eu`, `Vnt0C`, `VOaSl`, `t011CZ`) |
| Blue | Proposal, proposed or implementing (`cJb6J` 3-Tab IA, `U8c7us` Home v2) |

When a proposal's status changes, recolor its zone rectangle to match, and
`git mv` its folder in `exports/` to the matching bucket (`future/` = exploring,
`in-progress/` = proposed/implementing, `current-app/` = shipped). When it ships,
move its frames into the green Current App zone.

**Statuses**

| Status | Meaning |
|---|---|
| Shipped | In the app; the frame documents current state |
| Proposed | Direction chosen on canvas, not yet implemented |
| Exploring | One of several candidates; no decision yet |
| Implementing | Actively being built (link the PR); zone stays blue |
| Dropped | Rejected; frame kept (or deleted) for reference |

---

## Current app

### Listener (label `lMHqy`)

| Frame | Node ID | Status |
|---|---|---|
| Welcome | `Ruxvx` | Shipped |
| Home | `M8XBj` | Shipped |
| Radio Stations | `L46hv` | Shipped |
| Player | `yZGmG` | Shipped |
| Your Library | `roZ5g` | Shipped |
| Your Profile | `lxBAm` | Shipped |

### Broadcaster (label `X3B4D`)

| Frame | Node ID | Status |
|---|---|---|
| Broadcast | `f3K4Q0` | Shipped |
| Library (Broadcast) | `FA8hb` | Shipped |
| Listeners (Broadcast) | `OQtHt` | Shipped |
| Profile (Broadcast) | `ZtByB` | Shipped |

---

## Proposals — Artist / DJ experience (current effort)

### Open decision: navigation IA

Two competing IAs — **3-tab** (Dashboard · Station · Profile) vs **2-tab
dashboard-style Home v2**. Implementation has started on the **3-tab IA**
(branch `briankeane/new-3-tab-navigation`, PR #416); mark Home v2 (`ccNgg`, `Q1nN0v`) Dropped
once that decision is confirmed.

### Proposal · Artist Home & Station Health (label `Pz47j`)

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Broadcast (Home · Station Pulse) | `gk4Zz` | Exploring | Home-screen concept A |
| Broadcast (Home · Health Meter) | `Rl8qR` | Exploring | Home-screen concept B |
| Station Health (Detail) | `KHugh` | Exploring | Drill-in from health meter |

### Proposal · Station Report (label `IzUOO`)

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Station Report (Tiny Station) | `fOdsK` | Exploring | Empty/small-station state |
| Station Report (Established · Down Week) | `gsgY5` | Exploring | |
| Station Report (Established · Up Week) | `CJSos` | Exploring | |

### Proposal · Live AMA (label `SJvyZ`)

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Broadcast (Live AMA) | `PKL5j` | Exploring | |
| Broadcast (Live AMA · Low Buffer) | `HvVZz` | Exploring | Low-buffer warning state |

### Proposal · Live Shows — formerly AMA Show Runner (zone `dGvzn`)

Initial alternatives, V2, and three V3 variations for the near-live curator runner. Spec and exports live in
[`features/live-shows/`](features/live-shows/spec.md), following the design-feature workflow.

**Data layer pivoted + renamed (S39, 2026-09-13):** the heavy `AmaSession`/worker design (S38) was rejected for a slim generic **live-shows** primitive — a `liveShows` identity row + `spins.liveShowId`/`isFiller`, two endpoints, live edits through the existing schedule editor, 3 filler spins for graceful fallback, and four small scheduler guards (~2 PRs). `ask-me-anything` is the first `type`. The visual-design frames below (labeled "AMA Runner/Setup/Q/A") are unaffected and still approved; only the backend contract changed. See `features/live-shows/spec.md` §S39 and `implementation-plan.md`.
H including its buffer readout and all five numbered setup states are visually approved (S31). D–G are archived drafts; earlier alternatives remain reference explorations. The overall feature is not implementation-ready. The earlier Live AMA
frames above remain reference material. The new zone is below Home v2.

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| AMA Runner · A · Questions First | `f9reh` | Exploring | Incoming question inbox with inline answer action; full queue on demand |
| AMA Runner · B · Schedule First | `k06CM4` | Exploring | Rundown, locked items, reorder handles; question selection tray |
| AMA Runner · C · One Answer at a Time | `n7lNyi` | Exploring | Large current transcript and recording action; compact rundown |
| AMA Runner · V2 · Familiar Broadcast | `TPitr` | Exploring | Reuses Broadcast actions, staging and grouped queue; question answering opens separately; follows feedback that A was cluttered |
| AMA Runner · D · Coverage in the Queue | `h4ZY4a` | Dropped | Archived draft; retained in Drafts area for comparison |
| AMA Runner · E · Queue Timeline | `UtE2s` | Dropped | Archived draft; retained in Drafts area for comparison |
| AMA Runner · F · Simplified | `o23lK` | Dropped | Archived draft; retained in Drafts area for comparison |
| AMA Runner · G · Add Audio in Playlist | `rIca5` | Dropped | Archived draft; retained in Drafts area for comparison |
| AMA Runner · H · Three Playlist Actions | `K9H7f` | Proposed | Approved 2026-09-13 (S31), including 6:32 buffered and 65% of 10 min above End Show; follows 04 in the approved design row |

PNG and resolved JSON exports: `features/live-shows/exports/exploration/`.

Drafts zone `G0JLmd` at y=17162 contains D–G, below the approved design area. Dropped here means an archived alternative; the frames are preserved.

Approved design zone `eoeNV` at y=15578 contains 01 → 01b → 02 → 03 → 04 → H. All six shown screens were approved 2026-09-13 (S31).

| State | Node ID | Status | Notes |
|---|---|---|---|
| AMA Setup · 01 · Record an Intro | `u1jha` | Proposed | Approved 2026-09-13; intro-first state with user-provided guidance |
| AMA Setup · 01b · Build Your Opening | `cDCux` | Proposed | Approved 2026-09-13 (S31); intro recorded; guide building ten minutes with songs, past Q&As and song intros |
| AMA Setup · 02 · Almost Ready | `M6FLxv` | Proposed | Approved 2026-09-13; 8:35 ready; Start Show disabled |
| AMA Setup · 03 · Ready to Start | `F4XUs4` | Proposed | Approved 2026-09-13 (S31); 10:35 ready; Start Show enabled |
| AMA Setup · 04 · Waiting to Air | `OFqgG` | Proposed | Approved 2026-09-13 (S31); countdown while last regular-programming spin finishes |

Approved PNG, JSON and HTML exports: `features/live-shows/exports/approved/`. Machine-readable manifest: `features/live-shows/pen-nodes.json`.

### Proposal · AMA Buffer Protection (zone `Tx61O`)

Two states immediately right of H, at y=15578, visually approved 2026-09-13 (S33). Their zone and labels now use the approved blue styling.

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| AMA Runner · H1 · Song About to Be Added | `GLrlG` | Proposed | Approved S33; Amber 3:30 / 35% buffer; Adding Hummingbird in 0:30; shown insertion at 3:00 |
| AMA Runner · H2 · Song Automatically Added | `VPjJg` | Proposed | Approved S33; Hummingbird appended; green 6:05 / 61% buffer and brief confirmation |

PNG and resolved JSON: `features/live-shows/exports/approved/`.

### Proposal · AMA Q/A Flow (zone `Kc5c1`)

Approved Q/A flow below Drafts at y=18746 (S36). Based on existing question cards and answer recording/review screens; Q4 includes the optional song-after-Q/A action. Song and Voicetrack reuse the existing Broadcast interfaces.

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| AMA Q/A · Q1 · Question Picker | `NeOtx` | Proposed | Approved S36; S35: All / Unanswered / Answered; status badges and New this show marker; expandable transcripts and audio sampling |
| AMA Q/A · Q2 · Read and Record | `E4LFx` | Proposed | Approved S36; Full transcript, question scrubber, familiar recorder and buffer |
| AMA Q/A · Q3 · Recording Answer | `HadXP` | Proposed | Approved S36; Transcript visible while recording; persistent buffer |
| AMA Q/A · Q4 · Review and Add | `Q52Pi9` | Proposed | Approved S36; Preview, Re-record and Add to Show; optional song immediately after the Q/A pair |

PNG and resolved JSON: `features/live-shows/exports/approved/`.

### Proposal · Station Dashboard (label `dF5d1`)

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Station Dashboard (Tab Root) | `wXZ1h` | Exploring | Predecessor of 3-tab Dashboard? |

### Proposal · Station in Development

Sequential artist experience while a station is being assembled. Exports under
`exports/in-progress/station-in-development/`.

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Dashboard · Station Setup (Artist · In Development) | `XjSto` | Implementing | Dashboard tab routes to a station-setup screen when the artist's own station has `active == false` (thin `ArtistDashboardTabRootModel` router + `StationSetupPage`); `/setup-progress` + `/station-categories?version=draft` endpoints. **Intentional deviation from the mock:** progress uses amber-while-building / green-when-complete only — the mock's coral (`#EF6962`) low-progress state was dropped because "in development" is a positive building stage, not an error; coral is kept only for the "IN DEVELOPMENT" badge label |

### Proposal · 3-Tab IA (label `QkDeh`)

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Dashboard (Artist · Tab Root) | `NLnb0` | Implementing (PR #416) | Placeholder page shipped on `briankeane/new-3-tab-navigation` (hardcoded model values); v2 (health + listeners + 6-week chart + improve checklist) implemented |
| Station (Artist · Tab Root) | `tscZI` | Implementing (PR #416) | Renamed from "Home"; placeholder implemented from canvas spec — export `station-tab-root--tscZI.png` is stale (shows the old Home design) |
| Profile (Artist · Tab Root) | `LeACy` | Implementing (PR #416) | Tab renamed "Profile"; still renders the old ContactPage for now |

### Proposal · Home v2 · 2-Tab (label `OMoHs`)

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Home (Artist · Tab Root v2 · Dashboard Style) | `ccNgg` | Proposed | Alternative to 3-tab IA |

### Proposal · Breakers Library (Artist · Station tab)

Replaces the Station page "Schedule" row. Category list → per-category detail with
per-clip audio preview. Exports under `exports/in-progress/breakers-library/`.

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Breakers Library · Categories | `Ycl19` | Implementing (PR #417) | Non-song categories (zero-clip filtered out), name + clip count, drill-down |
| Breakers · Fan Spotlights | `zPsR6` | Implementing (PR #417) | Detail page; per-clip play/stop + scrubber |
| Breakers · Intros | `y6LWT3` | Implementing (PR #417) | Detail page |
| Breakers · Pre Commercial | `P2kA4P` | Implementing | Detail page |
| Breakers · Promotions | `vaOkW` | Implementing | Detail page |
| Breakers · Post Commercial | `e9gP0d` | Implementing | Detail page |

### Proposal · Music Library (Artist · Station tab)

Song-category browser reached from the Station tab. Category list → per-category (or
"All Songs" aggregate) detail with sort (Title/Artist), A–Z section index, and per-song
full-track audio preview + scrubber. Exports under `exports/in-progress/music-library/`.

| Frame | Node ID | Status | Notes |
|---|---|---|---|
| Music Library · Categories | `z2PgEC` | Implementing (#418) | Song categories + "All Songs" row, deduped counts, drill-down |
| Music Library · All Songs / Category Detail | `SeRvJ` | Implementing (#418) | Detail page; sort control, A–Z index, per-song play/pause + scrubber |

### Supporting components (artist/DJ)

| Component | Node ID | Status |
|---|---|---|
| Tab Bar (Broadcast · Glass) | `k7Cd7m` | Exploring |
| Tab Bar (Artist · 3-tab Glass) | `R0hsG` | Implementing (3-tab IA; native TabView; PR #416) |
| Tab Bar (Artist · 2-tab Glass) | `Q1nN0v` | Proposed (Home v2) |
| Broadcast Action Button | `EqHkj` | Exploring |
| Schedule Row | `th8Fu` | Exploring (superseded by Breakers Library on Station tab) |
| Breaker Audio Row | `BPD1R` | Implementing (Breakers Library detail rows) |
| Staging Row | `GpwDu` | Exploring |
| Library Song Row | `dugqD` | Exploring |
| Library Request Row | `trUfU` | Exploring |
| Listener Question Card | `hIdNG` | Exploring |

---

## Shipped components (baseline)

Filter Pill `ENpFP` · Preset Tile `wcaR9` · Station Row `mDSiF` · Tab Item `HXMdX` ·
Tab Bar (Legacy · pre-26.1) `Uj69k` · Small Player (Legacy · pre-26.1) `EoP1x` ·
Suggest Station Row `QFygA` · Tab Bar (Glass · 26.1+) `wc8zL` ·
Small Player (Glass · 26.1+) `GMXbb` · Liked Song Row `Ybl28` · Feature Tile `hwShQ` ·
Station Card `bjDHT` · Profile Action Button `X1ijB`

---

## Workflow

- **New proposal**: add a new labeled row on the canvas (`PROPOSAL · <name> — <status>`
  note + frames below it, 1584px below the last row) and a section here.
- **Decision made**: winner → Proposed, losers → Dropped (delete their frames or
  note them Dropped in the label).
- **Implementation starts**: row → Implementing, link the PR.
- **Shipped**: move the frame into the "CURRENT APP" zone on canvas (replacing the
  baseline frame it supersedes), move its row to the Current App section here, and
  update this file in the shipping PR.
