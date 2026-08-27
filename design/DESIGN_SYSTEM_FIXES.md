# Design System Reconciliation — Playola Radio iOS

**Task brief for a coding agent working in this repo.**

Revised after a Codex architecture review that overturned the first draft, then
re-derived against `main` @ `c32ef490` and cross-checked against a pen.dev
reconstruction of all ten shipping screens — the six listener screens and the four
broadcast tabs — built directly from this source.

Read `.claude/VIEWS.md`, `PlayolaRadio/Extensions/Color+Hex.swift`,
`PlayolaRadio/Extensions/Color+Palette.swift`,
`PlayolaRadio/Extensions/FontNames.swift` before starting.

Per repo `CLAUDE.md`: invoke `pfw-modern-swiftui` before touching SwiftUI views,
`pfw-testing` + `pfw-custom-dump` before touching tests.

---

## Context

### System A — the live system

`Color+Hex.swift` plus the neutral hex ramp sanctioned by `.claude/VIEWS.md`:

| token | value | uses |
|---|---|---|
| `.playolaRed` | `#EF6962` | 122 |
| `.playolaGray` | `#868686` | 63 |
| `.playolaLightPurple` | `#6962EF` | **0 — delete** |
| `Color.black` page bg | `#000000` | 91 |
| `Color(hex: "#333333")` row bg | literal | 31 |
| `Color(hex: "#666666")` placeholder | literal | 20 |
| `Color(hex: "#1A1A1A")` section bg | literal | 10 |
| all `Color(hex:)` call sites | literal | **189** |

### System B — `Color+Palette.swift`, effectively dead

Added 2026-01-23. **Counts are `Color.`-qualified.** An earlier draft of this brief
reported 10–20x higher numbers because it grepped `\.background\b`, which matches
every SwiftUI `.background(...)` modifier. Those figures were wrong.

| token | value | real uses |
|---|---|---|
| `.cardSurface` | `#3A1212` | 4 (+3 via `WelcomePalette`) |
| `.elevatedSurface` | `#471818` | 4 |
| `.background` | `#130000` | 7 |
| `.info` | `#6EC6FF` | 4 |
| `.error` / `.success` / `.textPrimary` | — | 1 each |
| `.textSecondary` | `#D7BFBF` | 2 |
| `.disabled` / `.warning` / `.border` | — | **0** |
| `gray400` / `gray600` / `gray700` / `gray900` | warm ramp | 2 each |
| `gray100`/`200`/`300`/`500`/`800` | warm ramp | **0** |

**~30 references across 22 tokens.** This file never landed. Do not describe it as
"partially adopted."

### The warm cluster is intentional, not drift

The surviving warm uses are **not scattered** — they concentrate in onboarding,
conversational/artist-contact flows, and the profile screen:

- `WelcomeMessagePageView.swift` — private `WelcomePalette` (`#130000` / `#3A1212` / `#D7BFBF`)
- `WelcomeMessagePageModel.swift:203` — `#2A1313`, a warm disabled-button color in **no palette**
- `ContactPageView.swift` — `gray900` card, `gray700` avatar well, `gray600` outline, `gray400` glyph, `textSecondary` email
- `ListenerQuestionDetailPageView.swift`, `BroadcastersListenerQuestionPageView.swift`, `StationSuggestionPageView.swift`

**The app has two deliberate surface families: neutral for listener browsing, warm
for onboarding, conversation, and profile.** Preserve the distinction; give it names
instead of deleting it.

---

### …but the broadcast side splits it down the middle

Broadcast mode has four tabs. Two of them are neutral and two are warm:

| Tab | View | Page bg | Card / row bg |
|---|---|---|---|
| Broadcast | `BroadcastPageView` | `Color.black` | `#1A1A1A` / `#2A2A2A` / `#333333` / `#444444` |
| Library | `LibraryPageView` | `Color.black` | `#333333` |
| Listeners | `BroadcastersListenerQuestionPageView` | `Color.background` `#130000` | `Color.cardSurface` `#3A1212` |
| Profile | `ContactPageView` | `Color.black` | `gray900` `#3D3634` |

`BroadcastPageView` and `LibraryPageView` contain **zero** palette references — every
color is a `Color(hex:)` literal. Switching from Library to Listeners changes the page
background and the row surface with no semantic reason. This is the one place where the
neutral/warm split is *not* defensible: same mode, same session, adjacent tabs. See
defect 26.

---

## Defects

### Color

1. **Two page-background values.** `Color.black` (`#000000`, 91) vs `Color.background`
   (`#130000`, 7). `VIEWS.md:36`/`:102` documents `Color.black`, and the legacy
   `UITabBarAppearance` in `TabBarPlatformChrome.swift` is hard pure-black — a warm page
   base would show a seam at the tab bar.
2. **~120 unnamed neutral literals** across 45 view/model files (47 files match raw color
   construction; 2 of those are the palette/hex extensions themselves). `VIEWS.md`
   instructs devs to write `Color(hex: "#333333")` inline — the doc institutionalizes
   the hardcoding.
3. **A duplicated private palette.** `WelcomeMessagePageView.swift:9` redefines three
   tokens with values identical to the global ones. Root-cause signal: the system was
   not discoverable.
4. **Sites that bypass `.playolaRed`.** One escapes the view layer:
   `PlayerPageModel.swift:160` returns `"#EF6962"` as a `String`;
   `PlayerPageTests.swift:451` asserts on that literal.
5. **28 non-hex color escapes:** `Color(red:)` ×12, `Color(white:)` ×11, `UIColor` ×5.
6. **A second red.** `NewFeatureTile.swift` and `ListeningTimeTile.swift` set their CTA
   background to `Color(red: 0.8, green: 0.4, blue: 0.4)` = **`#CC6666`**, not brand
   `#EF6962`. This is the most prominent button on the Home screen.
7. **A third red.** `SmallPlayer`'s progress rule uses bare `Color.red` = `#FF3B30`
   (system red) rather than `.playolaRed`.
8. **Tile surface drift.** `Color(white: 0.15)` = `#262626` (`NewFeatureTile`,
   `ListeningTimeTile`, `StationCardView`) vs the intended raised surface `#2A2A2A`.
9. **Four different artwork placeholders** for the same conceptual thing:
   `#333333` (station rows, preset tiles), `Color.gray.opacity(0.3)` (SmallPlayer),
   `#666666` + `#999999` glyph (liked songs), `Color(white: 0.3)` = `#4D4D4D`
   (`HomePageStationList`), `Color(white: 0.2)` = `#333333` (`PlayerPage` hero).
10. **Near-miss grays.** `#888888` (inactive preset star, liked-song date) sits 2 off
    `.playolaGray` `#868686`; `.gray` `#8E8E93` sits 3 off `#999999`. Neither delta is
    intentional.
11. **Orphan colors.** `Color.purple` in `UpcomingGiveawayBadge`; `#4D4D4D` dashed border
    in `SuggestStationRow`; `#323232` in `SongDrawerView.presentationBackground`;
    `Color.info` `#6EC6FF` on the profile mode-switch buttons — a blue that appears
    nowhere else.
12. **Opacity-derived colors** in `WelcomeMessagePageView`: `white.opacity(0.14 / 0.35 /
    0.5 / 0.85)` instead of tokens.

### Typography

13. **No type scale.** 23 distinct sizes. `16`/`14`/`12` dominate (104/82/39); the long
    tail is `15`×22, `11`×13, `13`×12, `22`×6, `28`×4, `17`×3, `21`×2, and single uses of
    `8`, `19`, `26`, `30`, `36`, `56`.
14. **5 dead font tokens:** `Inter_100_Thin`, `Inter_300_Light`, `Inter_900_Black`,
    `SpaceGrotesk_300_Light`, `SpaceGrotesk_400_Regular` (declaration only, 0 call sites).
15. **`.fontWeight(.bold)` layered on a custom PostScript font.** `StationCardView`
    applies `.fontWeight(.bold)` to `.font(.custom(FontNames.Inter_500_Medium, size: 16))`.
    Weight modifiers on a `.custom(_:size:)` font are unreliable — either use
    `Inter_700_Bold` or drop the modifier.
16. **Two incompatible section-header treatments.** Space Grotesk 700/28 ("Presets",
    "Liked Songs") vs Inter 600/14 (Radio Stations section titles). Same structural role,
    2x size difference and a different family.

> **Investigated and dismissed:** the `SpaceGrotesk_*` constants derive from
> `"SpaceGrotesk-Light"` and *look* wrong (`_700_Bold = "SpaceGrotesk-Light_Bold"`), but
> CoreText resolves these correctly via PostScript-name synthesis. They render as
> intended. An earlier draft of this brief listed this as a bug. It is not one — do not
> "fix" it.

### Layout / spacing

17. **Inconsistent page gutter.** 20 (Your Library, Your Profile, Presets, Liked Songs)
    vs 16 (Radio Stations) vs 24 (Home scroll, Player now-playing block).
18. **Hardcoded tab-bar insets.** `ContactPageView` ends with `.padding(.bottom, 100)`
    "Account for tab bar". Under iOS 26 the floating tab bar plus the bottom accessory
    needs ~140. This should be `safeAreaInset`, not a magic number. In **broadcast mode**
    it is already failing: the extra `Switch to Listening Mode` button adds 74pt, pushing
    the Log out button to y≈692 on a 393×852 device — the mini player's top edge is y690,
    so at scroll top Log out is entirely behind the accessory.
19. **Radii off-scale.** `WelcomeMessagePageView` uses `14` (chips, primary button) and
    `16` (now-playing card); the rest of the app uses `4`/`6`/`8`/`12`/`20`/`24`.
20. **`RelatedTextCard` has no corner radius** — a bare `.background(Color(hex:"#333333"))`.
    It is the only square-cornered card in the app.

### Real bugs found while reconstructing the screens

21. **`PresetsCarousel` tile misalignment.** The tile row is a bare
    `HStack(spacing: presetTileSpacing)`, which defaults to `.center`. `PresetTile`'s
    title is `lineLimit(2)`, so tiles with one-line and two-line titles have different
    heights and their **artwork rectangles misalign vertically by up to 10pt**. Fix:
    `HStack(alignment: .top, spacing:)`.
22. **`LikedSongsSection` has no empty state.** `ForEach(songs.isEmpty ? [] : [0])` means
    the section — heading included — renders nothing at all when the user has no liked
    songs. On a fresh account, Your Library shows Presets and then blank space.
23. **Home buries its own content.** Measured against a 393×852 device: the intro block
    (logo + copy) is 332pt, the feature tile 252pt, the listening-time tile 115pt. The
    `"Artist stations for you"` list starts at **y≈699 inside the scroll view** — entirely
    below the fold. The first screenful of the app's home screen contains no stations.
24. **Four equal-weight primary buttons.** `ContactPageView` stacks Rewards,
    Notifications, Contact Us, and Ask An Artist as four full-width solid `.playolaRed`
    buttons. They are navigation rows dressed as primary CTAs; nothing reads as primary.
25. **Chevrons don't sit at the trailing edge.** Those same buttons use
    `HStack { icon; label; chevron }.frame(maxWidth: .infinity)`, which centers the whole
    group — so the disclosure chevron floats next to the label mid-button instead of at
    the edge, losing its affordance.

### Broadcast-side defects

26. **The broadcast tab bar spans both surface families.** See the table above. Unlike the
    listener-side warm cluster (onboarding / conversation / profile), this split has no
    narrative behind it — `BroadcastersListenerQuestionPageView` was written alongside the
    listener-facing question flows and inherited their palette. **Decision needed:**
    broadcast is a work surface; the recommendation is to make Broadcast / Library /
    Listeners uniformly neutral and treat the Listeners warm palette as drift.
27. **A private disabled palette.** `BroadcastActionButton` hardcodes `#666666` fill,
    `#888888` stroke, `#AAAAAA` glyph for its disabled state. No `disabled*` token exists.
    `#666666` simultaneously means "artwork placeholder" in `LibraryPageView` — one literal,
    two roles.
28. **`#AAAAAA` on `#666666` is 2.5:1.** The disabled Notify button's icon fails WCAG's
    3:1 minimum for non-text contrast. Whatever token replaces it needs a new value, not
    just a new name.
29. **Four greens meaning "good".** `.green` (`#34C759`) — staging-row checkmark
    (`BroadcastPageView.swift:235`), fulfilled-request badge (`LibraryPageView.swift:407`),
    plus `LiveBadge`, `PrizeTierRow`, `RedeemPrizeSheetView`, `AskQuestionPageView`,
    `ConversationListPageView`. `Color.success` (`#4CAF50`) — answered badge
    (`BroadcastersListenerQuestionPageView.swift:296`), `NotificationsSettingsPageModel:43`.
    `#2E7D32` — the commercial marker in the schedule. Two distinct roles are conflated:
    *confirmation* and *category*. They need different tokens, not one shared green.
30. **Row state is encoded positionally.** `ScheduleRowView.rowBackgroundColor` returns
    black / `#333333` / `#444444` for commercial / deletable / locked — three unnamed
    literals carrying three states in one ternary chain.
31. **One-off progress track `#5E5F5F`** behind the broadcast now-playing bar; the only
    use of that value in the app.
32. **The search field is copy-pasted three times.** `LibraryPageView:216`,
    `StationListPage:128`, `StationListPadView:63` are the same twelve lines
    (`magnifyingglass` 16 `.playolaGray`, Inter 400/16 field, `#333333`, radius 8, inner
    12/10 padding, outer 16/12 padding, black backing). Extract `PlayolaSearchField`.
33. **Nav titles disagree with their tab labels.** The Broadcast tab titles itself with the
    station name or `"My Station"`; the Listeners tab titles itself `"Listener Questions"`.
    Pick one vocabulary per destination.
34. **Dead model string.** `LibraryPageModel.songsSectionHeader` (`"SONGS (n)"`) is asserted
    by two tests (`LibraryPageTests:446`, `:460`) but never rendered — the view builds
    artist headers instead. Delete it with its tests, or render it.
35. **The Library section index overlaps the request rows' buttons.** `SectionIndexView` is
    a trailing overlay on the entire `List`, occupying the rightmost 24pt
    (`LibraryPageView:80–91`). `LibrarySongRow` reserves that space with
    `.padding(.trailing, 28)` (`:359`), but `LibraryRequestRow` uses
    `.padding(.horizontal, 12)` (`:465`) — so the A–Z letters sit on top of its
    DISMISS / CANCEL button. The index also floats over the REQUESTS section, where it
    indexes nothing. Fix: match the trailing inset and scope the overlay to the songs
    sections.

### Found by loading real production data onto the canvas

The canvas mocks now use the live `GET /v1/station-lists` payload (21 artist stations,
12 FM stations) instead of invented names — real curators, real station names, real
artwork. Three defects only became visible once real data was in place.

36. **FM rows render the same string twice.** `AnyStation.name` and `AnyStation.stationName`
    both return `station.name` for the `.url` case (`Models/StationList.swift:24–50`).
    `StationListStationRowModel` uses `name` for the title and `stationName` for the
    subtitle, so every active FM row shows e.g. `KOKE FM` over `KOKE FM`. The data to fix
    it is already on the wire and already decoded: `UrlStation.location` (`"Austin, TX"`,
    `"Lubbock, TX"`, …) is populated for all 12 FM stations and is **never rendered
    anywhere in the app**. `AnyStation.location` exists solely to return `nil` for Playola
    stations. Fix: subtitle should be `location` for url stations, `stationName` for
    Playola stations.
37. **14 of 21 artist stations have an empty `description`.** `HomePageStationList` renders
    `Text(station.description)` unconditionally as the card's third line
    (`HomePageStationList.swift:63`). With an empty string the text collapses and the card
    keeps its image-driven height, leaving a ~60pt void under the curator name — see the
    Jamie Lin Wilson card on the Home canvas. Fix: hide the line when the description is
    empty and let the card shrink, or fall back to a derived line.
38. **The two players disagree on now-playing word order.** `SmallPlayer.secondaryTitle`
    builds `"\(artistPlaying) - \(titlePlaying)"`
    (`Reusable Components/SmallPlayer/SmallPlayer.swift:62`); `PlayerPageModel.nowPlayingText`
    builds `"\(audioBlock.title) - \(audioBlock.artist)"` (`PlayerPageModel.swift:42`).
    Tapping the mini player to open the full player flips the two halves of the same
    string. Pick one order and extract a single formatter.

---

## Decisions

- **`surfaceBase` = `#000000`.** Reversed from the first draft: usage, `VIEWS.md`, and
  the pure-black UIKit tab bar all point to true black. `#130000` is perceptible on
  OLED and would seam against system chrome.
- **Keep the warm family; scope it.** Do not delete `cardSurface`/`elevatedSurface`.
  Rename to `warmSurface` / `warmSurfaceRaised` / `warmBase` and document them as the
  onboarding + conversation + profile treatment. Fold `#2A1313` in as
  `warmControlDisabled` and the `gray400`–`gray900` warm ramp in as named tokens.
- **Do not change `textSecondary`'s value.** The first draft silently moved it from
  warm `#D7BFBF` to neutral `#C7C7C7`. Keep `#D7BFBF` as the warm-family text token
  and add a separate neutral `textSecondary`.
- **Keep `.playolaRed`.** Brand tokens name identity, role tokens name usage; a mixed
  scheme is fine. Fix the bypasses only — no churn across 122 call sites.
- **Update `.claude/VIEWS.md` in place. Do not create `DESIGN.md`.** A second doc beside
  it is exactly how `Color+Palette.swift` came to exist beside `Color+Hex.swift`.
- **Defects 21–25 are behavior, not tokens.** They ship as their own PRs, outside the
  codemod sequence, so a visual regression stays bisectable.

---

## Stage 0: Lint guard first
**Goal**: Stop the bleeding before migrating, so the codemod cannot regress.

Add a SwiftLint `custom_rules` entry (`.swiftlint.yml` already exists; wired via
`Makefile:6`, `fastlane/Fastfile:216`, `.circleci/config.yml:20`) rejecting
`Color(hex:`, `Color(red:`, `Color(white:`, and `UIColor` outside
`DesignSystem/`. Ship it as **warning with a baseline** so existing debt does not
fail CI; flip to `error` at the end of Stage 3.

**Success criteria**: a newly-planted inline hex fails lint; existing debt does not.
**Status**: Not Started

## Stage 1: Token layer
**Goal**: One discoverable source of truth at `PlayolaRadio/DesignSystem/`.

Create `Colors.swift`, `Typography.swift`, `Spacing.swift`. Merge `Color+Palette.swift`
in and delete it. Leave `Color+Hex.swift` as the `init(hex:)` utility only.

```
NEUTRAL                              WARM (onboarding + conversation + profile)
surfaceBase       #000000            warmBase              #130000
surfaceSection    #1A1A1A            warmSurface           #3A1212
surfaceRaised     #2A2A2A            warmSurfaceRaised     #471818
surfaceRow        #333333            warmControlDisabled   #2A1313
surfaceControl    #444444            warmTextSecondary     #D7BFBF
surfaceMuted      #4A4A4A            warmGray900           #3D3634
surfacePlaceholder #666666           warmGray700           #6B6260
                                     warmGray600           #827876
textPrimary   #FFFFFF                warmGray400           #B0A7A5
textSecondary #C7C7C7
textTertiary  #999999
textDisabled  #868686
brandPrimary  #EF6962   (.playolaRed retained as alias)

STATE / BROADCAST
confirm            #34C759   checkmarks, "done" affordances (defect 29)
categoryCommercial #2E7D32   the "$" schedule marker — a category, not a confirmation
controlDisabled    TBD       replaces #666666 fill (defect 27)
controlDisabledStroke TBD    replaces #888888
onControlDisabled  TBD       replaces #AAAAAA — must clear 3:1 (defect 28)
scheduleRowLocked  #444444   = surfaceControl; alias, do not add a value
progressTrack      #5E5F5F   snap to an existing gray unless it must stay (defect 31)
```

Radius scale (from real usage — 8:30, 6:29, 4:18, 12:9, 24:9): `4, 6, 8, 12, 24`.
Spacing scale (padding 16:72, 12:61, 20:60, 8:43, 24:29): `4, 8, 12, 16, 20, 24, 32`.
Delete `playolaLightPurple` (0 uses), `border`, `warning`, `disabled`, and the five
zero-use `gray*` steps.

`Color.success` `#4CAF50` collapses into `confirm` unless a reviewer can name the
difference between it and `#34C759` on a dark surface.

**Success criteria**: builds clean; `Color+Palette.swift` gone; every new token has ≥1
reference by end of Stage 2b.
**Status**: Not Started

## Stage 2a: Mechanical view migration
**Goal**: Zero raw color literals in neutral view code. Exact-hex substitution only.

45 view/model files. Regenerate the exact list with:

```sh
grep -rIl --include='*.swift' -E 'Color\(hex:|Color\(red:|Color\(white:|UIColor\(' \
  PlayolaRadio | grep -v Tests | grep -v 'Extensions/Color'
```

Fold in defects 6–11 as part of this pass — they are all exact-hex substitutions once
the tokens exist, **except the second red (#CC6666) and the system red (#FF3B30)**,
which are visual changes. Land those two in Stage 2d.

**Success criteria**: no raw color construction in any view file.
**Status**: Not Started

## Stage 2b: Warm-family migration
**Goal**: Name the warm cluster without changing its pixels.

Delete `private enum WelcomePalette`; point its 3 sites at the warm tokens. Migrate
`WelcomeMessagePageView`, `WelcomeMessagePageModel:203`, `ContactPageView`,
`ListenerQuestionDetailPageView`, `StationSuggestionPageView`,
`BroadcastersListenerQuestionPageView`.

Migrate `BroadcastersListenerQuestionPageView` to the *warm* tokens here — moving it to
the neutral family is defect 26, a visual change, and belongs with Stage 2d.

**Success criteria**: **pixel-identical**. Screenshot all 6 screens before and after.
Any visual delta is a bug in this stage.
**Status**: Not Started

## Stage 2c: Model-layer semantics
**Goal**: Colors stop leaking out of the view layer.

`PlayerPageModel.swift:160` returns `"#EF6962"` as a `String` → return a semantic case;
move the color decision into the view; rewrite `PlayerPageTests.swift:451` to assert the
semantic value. Same for `HeartState.imageColorHex`, the literal in
`NotificationsSettingsPageModel`, and `PresetDisplayItem.subtitleColor`.

**Success criteria**: no model type vends a color or hex string.
**Status**: Not Started

## Stage 2d: Red, green, and the broadcast palette *(visual change — separate PR)*
**Goal**: One red, one confirmation green, one surface family per mode.

Repoint `#CC6666` (`NewFeatureTile`, `ListeningTimeTile` CTAs) and `Color.red`
(`SmallPlayer` progress rule) to `brandPrimary`. Collapse `Color.success` `#4CAF50` into
`confirm` `#34C759` (defect 29). Re-pick the disabled trio for 3:1 contrast (defect 28).
If the product decision on defect 26 goes the recommended way, move
`BroadcastersListenerQuestionPageView` from the warm family to the neutral one in the
same PR — it is the only change that makes the four broadcast tabs agree.

Screenshot Home, the mini player, and all four broadcast tabs before/after; this stage is
*supposed* to move pixels.

**Status**: Not Started

## Stage 3: Type scale
**Goal**: Collapse 23 ad-hoc sizes to `10, 12, 14, 16, 18, 20, 24, 32, 40, 48`.

Snap: `8→10`, `11→12`, `13→12|14`, `15→16`, `17→16|18`, `19→20`, `21→20`, `22→24`,
`26→24`, `28→24|32`, `30→32`, `36→32|40`, `56→48`. **Do not blind-sed the pipe cases** —
`15` has 22 uses, `11` has 13, `13` has 12; snapping the wrong way is visible.
Screenshot each.

Delete the 5 zero-use font tokens (defect 14). Fix defect 15 (`.fontWeight(.bold)` on a
custom font). **Do not touch the `SpaceGrotesk-Light_*` names** — see the dismissed note
above. Then flip Stage 0's lint rule from warning to error.

**Status**: Not Started

## Stage 4: Discoverability
**Goal**: The next dev does not write a third palette.

Rewrite the Colors and Fonts sections of `.claude/VIEWS.md` to reference tokens only.
**Delete every raw-hex example from that doc** — those examples taught the codebase to
hardcode. Add the rule: new colors go in `DesignSystem/Colors.swift` with a role name,
and state when to reach for the warm family vs the neutral one. Document the page gutter
(defect 17) and the section-header treatment (defect 16) as decided values.

**Status**: Not Started

---

## Out-of-band fixes (behavior, not tokens — one PR each)

| # | Fix | File |
|---|---|---|
| 21 | `HStack(alignment: .top,` in the preset tile row | `Presets/PresetsCarousel.swift` |
| 22 | Empty state for zero liked songs | `LikedSongsPage/LikedSongsSection.swift` |
| 23 | Reorder Home so stations are above the fold | `HomePage/HomePageView.swift` |
| 24 | Demote 3 of the 4 profile buttons to row treatment | `ContactPage/ContactPageView.swift` |
| 25 | `Spacer()` before the chevron | `ContactPage/ContactPageView.swift` |
| 18 | `safeAreaInset` instead of `.padding(.bottom, 100)` | `ContactPage/ContactPageView.swift` |
| 35 | Match the request-row trailing inset; scope the index overlay | `LibraryPage/LibraryPageView.swift` |
| 34 | Delete `songsSectionHeader` + its two tests | `LibraryPage/LibraryPageModel.swift` |
| 32 | Extract `PlayolaSearchField`, adopt in all three call sites | `Reusable Components/` |
| 28 | Re-pick the disabled fill/glyph pair for 3:1 contrast | `BroadcastPage/BroadcastPageView.swift` |
| 33 | Align nav titles with tab labels | `BroadcastPage/`, `BroadcastersListenerQuestionPage/` |
| 36 | Subtitle FM rows with `location`, not the duplicated name | `StationListStationRowModel.swift` |
| 37 | Hide the Home card description line when empty | `HomePage/UI Components/HomePageStationList.swift` |
| 38 | One now-playing formatter, one word order | `SmallPlayer.swift`, `PlayerPageModel.swift` |

Defects 23, 24, and 26 are product decisions, not cleanups — confirm before implementing.

## Non-goals

- No visual redesign, except Stage 2d and the font-size snaps in Stage 3.
- No renaming `.playolaRed` across 122 call sites.
- No dark/light mode work — the app is dark-only.
- Do not touch `IMPLEMENTATION_PLAN.md` (active, unrelated RecordPage plan).

## Sequencing

Separate PRs, in order: 0 → 1 → 2a → 2b → 2c → 2d → 3 → 4. Never combine a color codemod
with a type codemod; mixing them makes a visual regression impossible to bisect. The
out-of-band table above can land in parallel at any point.

## Not yet represented on the design canvas

**On the canvas:** Radio Stations, Player, Your Library, Home, Your Profile, Welcome,
Broadcast, Library (Broadcast), Listeners (Broadcast), Profile (Broadcast). All
station names, curator names, and artwork come from the live `GET /v1/station-lists`
payload; artwork is stored as local files beside the `.pen` (`./images/`) because pen.dev
does not resolve remote image fills.

**Not yet built:** `StationListPadView`, `HomePagePadView`, `ContactPagePadView`,
`SignInPadView` (iPad regular-size-class layouts); the Radio Stations
`isShowingNoResults` empty state; the broadcast empty states (`No songs in library`,
`No Questions Yet`, `All Caught Up!`); and the secondary broadcast flows —
`RecordPage`, `RecordIntroPage`, `SeriesListPage`, `ChooseStationToBroadcastPage`,
`ListenerQuestionDetailPage`, `SongSearchPage`, `NotifyListenersSheet`.
Reconstruct these before assuming the canvas is a complete reference.
