# iPad Radio Stations layout — design

_Date: 2026-08-05 · First screen of the multi-PR "Prettify iPad screens" effort (see `LONG_RUNNING.md`)._

## Goal

On iPad the Radio Stations screen renders as a single narrow full-width column with a
vast empty right half and the search bar stranded at the very bottom. Make it "not
embarrassing" on iPad by matching the provided mockup: title + search on the top row, a
filter row with a right-aligned suggest button, and a 2-column grid of stations.

**Explicit non-goal:** the iPad layout must never tax future iPhone work. iPhone is the
only maintained path. iPad is disposable and may lag iPhone in styling (design drift is
acceptable).

## Scope

- iPad / **regular** horizontal size class only.
- iPhone / **compact** stays **byte-for-byte identical** to today.
- Content-area only. Global nav (the top Home/Radio Stations/Your Library/Your Profile
  bar) is already handled by iOS and is out of scope.

## Architecture — quarantine, don't share

Reviewed with Codex (consult). Codex initially recommended extracting shared components
(DRY). Given the "iPad must not tax iPhone" constraint, we deliberately chose the
opposite — **isolation over DRY** — and Codex concurred: sharing components would turn
every future iPhone change into an implicit iPad change (coupling), which is exactly the
tech debt the owner is refusing.

`StationListPage`:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass

var body: some View {
  if horizontalSizeClass == .regular {
    StationListPadView(model: model)   // new, self-contained
  } else {
    compactBody                        // today's body, moved verbatim
  }
  // shared modifiers (.playolaAlert, .onAppear, .background) wrap both
}

private var compactBody: some View { /* exact current body */ }
```

- The current body content moves into `compactBody` **unchanged** — no refactor of the
  maintained path, no iPhone regression risk, nothing new in iPhone diffs.
- The single size-class branch is genuine **view geometry** (device knowledge), so it
  stays in the view, never in the model. This is a deliberate, isolated bend of the
  project's "no control flow in page Views" rule, approved for this one branch.
- `StationListPadView` lives in its own file. It can be ignored in every iPhone PR or
  deleted wholesale.

### What `StationListPadView` may and may not do

- **May** reuse `StationListStationRowView` (already the shared semantic row unit — low
  coupling risk; if iPhone changes row behavior, iPad inheriting it is desirable) and the
  shared `StationListModel` (same inputs/actions).
- **May** duplicate the small chip-pill and search-field styling (~40 lines).
- **Must NOT** copy any filtering / business logic. All of it stays in the model
  (`displayedSections`, `displayedRows(for:)`, `segmentTitles`, `selectedSegment`,
  `searchText`, `isShowingNoResults`, `suggestArtistTapped()`, `stationSelected(_:)`,
  preset toggling). The iPad view is a dumb layout over model state.

## iPad layout (matches mockup)

- **Header row:** `navigationTitle` left (SpaceGrotesk 700, 32) · search field right,
  fixed ~320pt, `#333333` rounded field with magnifying glass + clear button, bound to
  `model.searchText`.
- **Filter row:** All / Artist Stations / FM Stations chips left (same pill styling as
  compact) · compact "+ Suggest a station" pill right (playolaRed text + red border),
  calls `model.suggestArtistTapped()`.
- **Grid:** 2 columns (`GridItem(.flexible())` ×2), reusing `StationListStationRowView`
  per row. Section header (`section.title`) spans the full width above each section's
  grid. Empty sections skipped (driven by `model.displayedRows(for:)`).
- **No-results state:** reuse the model's no-results strings
  (`noResultsMessage` / `noResultsHint` / `noResultsIconName`) in a simple centered block.
- **Width cap:** content capped ~1100pt, centered, standard horizontal padding, so it
  doesn't stretch grotesquely on a 13" iPad.
- **Row polish for half width:** `lineLimit` + truncation on title/subtitle so long names
  don't crush the trailing badges/star; verify the preset star hit area stays ≥44×44.

## Model

**Unchanged.** Only the View layer changes.

## Testing

No new model behavior → existing `StationListModel` and `StationListStationRowView` tests
stay green (run them to confirm the `compactBody` move didn't regress). New code is
layout-only:

- Add a `#Preview` at regular width for the iPad layout.
- Verify against the mockup via an iPad simulator screenshot.
- Confirm iPhone renders identically after the `compactBody` extraction.

## Files

- `PlayolaRadio/Views/Pages/StationListPage/StationListPage.swift` — add branch + move
  current body into `compactBody` (no content change).
- `PlayolaRadio/Views/Pages/StationListPage/StationListPadView.swift` — **new**,
  self-contained iPad layout. Register in `project.pbxproj`.
- `LONG_RUNNING.md` — add the "Prettify iPad screens" effort with Radio Stations as
  the first screen.
