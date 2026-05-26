# Presets on StationListPage — Design Spec

**Date:** 2026-05-25
**Branch:** `briankeane/juba`
**Status:** Approved, ready for implementation plan

## Summary

Add a "Presets" feature to the existing `StationListPage`. Users can star/unstar any station to save it as a preset. Presets render as a horizontal carousel at the top of the list (on the "All" segment and on a new dedicated "Presets" segment). Long-press on a preset tile opens an action sheet to remove. Drag-to-reorder is supported. Presets are persisted server-side via four new endpoints; the UI is fully optimistic.

The screen is reachable only when the user is signed in, so all logic assumes an authenticated token is available.

## Server endpoints (already specified)

| Method | Path | Body | Returns |
|---|---|---|---|
| GET | `/v1/presets` | — | `[Preset]` sorted by `position` ASC |
| POST | `/v1/presets` | `{ stationId? , urlStationId? }` | Created `Preset` (appends at `max + 1`). 409 if duplicate. |
| PUT | `/v1/presets/:id` | `{ position }` | Updated `Preset`. Shifts affected range. 400 if out-of-range or not owner. |
| DELETE | `/v1/presets/:id` | — | 204. Hard delete; decrements every `position > deleted.position` for that user. |

### Preset JSON shape

```json
{
  "id": "8e2c4f1a-9b3d-4e6c-9f1a-2b8e4c6d8f10",
  "userId": "6d00ed09-b85d-425b-a68a-a3f82891dcc5",
  "stationId": "f4a1b2c3-d4e5-6789-abcd-ef0123456789",
  "urlStationId": null,
  "position": 0,
  "createdAt": "2026-05-25T14:00:00.000Z",
  "updatedAt": "2026-05-25T14:00:00.000Z",
  "station":    { "id": "...", "name": "...", "slug": "...", "imageUrl": "..." },
  "urlStation": null
}
```

Exactly one of `stationId`/`urlStationId` is non-null, with the corresponding `station`/`urlStation` populated. The embedded station is a **slim** projection (id, name, slug/url, imageUrl) — not the full `PlayolaPlayer.Station` or `UrlStation`. The carousel tile renders from the slim data; full station data for **playback** is looked up from `@Shared(.stationLists)`.

## Data model (`PlayolaRadio/Models/Preset.swift`)

```swift
struct Preset: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let userId: String
  let stationId: String?
  let urlStationId: String?
  var position: Int
  let createdAt: Date
  let updatedAt: Date
  let station: PresetStation?
  let urlStation: PresetUrlStation?

  /// Whichever of stationId / urlStationId is non-nil.
  var embeddedStationId: String { (stationId ?? urlStationId) ?? "" }
}

struct PresetStation: Codable, Equatable, Sendable {
  let id: String
  let name: String
  let slug: String
  let imageUrl: String?
}

struct PresetUrlStation: Codable, Equatable, Sendable {
  let id: String
  let name: String
  let url: String
  let imageUrl: String?
}
```

## API client additions (`Core/API/APIClient.swift`)

Four new endpoints on the existing `APIClient` struct (alongside `likeSong`, etc.):

```swift
var getPresets:
  @Sendable (_ jwtToken: String) async throws -> [Preset] = { _ in [] }

var createPreset:
  @Sendable (_ jwtToken: String, _ stationId: String?, _ urlStationId: String?)
    async throws -> Preset = { _, _, _ in /* mock */ }

var movePreset:
  @Sendable (_ jwtToken: String, _ presetId: String, _ position: Int)
    async throws -> Preset = { _, _, _ in /* mock */ }

var deletePreset:
  @Sendable (_ jwtToken: String, _ presetId: String) async throws -> Void = { _, _ in }
```

### Live wiring (`APIClient+Live.swift`)

```swift
getPresets: { token in
  try await authenticatedGet(path: "/v1/presets", token: token)
},
createPreset: { token, stationId, urlStationId in
  var params: [String: Any] = [:]
  if let stationId    { params["stationId"]    = stationId }
  if let urlStationId { params["urlStationId"] = urlStationId }
  return try await authenticatedPost(path: "/v1/presets", token: token, parameters: params)
},
movePreset: { token, presetId, position in
  try await authenticatedPut(
    path: "/v1/presets/\(presetId)",
    token: token,
    parameters: ["position": position])
},
deletePreset: { token, presetId in
  try await authenticatedDelete(path: "/v1/presets/\(presetId)", token: token)
},
```

> **Implementation check:** verify `authenticatedPut(_:token:parameters:)` exists with a parameters overload. If not, add one matching the `authenticatedPost` helper.

The model layer guarantees exactly one of `stationId` / `urlStationId` is non-nil per call. 409 and 400 responses surface as `APIError.validationError`, handled by the model with rollback + alert.

## Shared state (`State/SharedUserDefaults.swift`)

```swift
extension SharedKey where Self == InMemoryKey<IdentifiedArrayOf<Preset>>.Default {
  static var presets: Self { Self[.inMemory("presets"), default: []] }
}

extension SharedKey where Self == InMemoryKey<Set<String>>.Default {
  /// Station ids (playola or url) for which a preset create is in flight.
  static var pendingPresetStationIds: Self {
    Self[.inMemory("pendingPresetStationIds"), default: []]
  }

  /// Preset ids for which a delete is in flight (prevents double-tap).
  static var pendingPresetRemovalIds: Self {
    Self[.inMemory("pendingPresetRemovalIds"), default: []]
  }
}
```

InMemory storage chosen because:
- User is always signed in; server is source of truth.
- Re-fetched on `StationListPage.viewAppeared()` — no stale-cache concern.
- Matches `liveStations` / `nowPlaying`.

## Model changes (`StationListModel.swift`)

### New shared state

```swift
@ObservationIgnored @Shared(.presets)                  var presets
@ObservationIgnored @Shared(.pendingPresetStationIds)  var pendingPresetStationIds
@ObservationIgnored @Shared(.pendingPresetRemovalIds)  var pendingPresetRemovalIds
@ObservationIgnored @Shared(.auth)                     var auth
```

### New properties

```swift
let presetsSectionTitle  = "Presets"
let presetsEmptyStateText = "Tap the ★ on any station to save it here."
private let presetsSegmentTitle = "Presets"

var presentedPresetActionSheetPreset: Preset?
```

### New / changed methods

**`viewAppeared()`** — after existing publisher subscriptions, also fetch presets:

```swift
await loadPresets()
```

**Star tap** (called by `StationListStationRowView` and by the "Remove from Presets" action in the sheet):

```swift
func starTapped(for item: APIStationItem) async {
  let stationId = item.anyStation.id
  if let existing = presets.first(where: { $0.embeddedStationId == stationId }) {
    await removePreset(presetId: existing.id)
  } else if !pendingPresetStationIds.contains(stationId) {
    await addPreset(for: item)
  }
}
```

**Preset tile tap → play:**

```swift
func presetTileTapped(_ display: PresetDisplayItem) async {
  await stationSelected(display.stationItem)   // reuses existing playback flow
}
```

**Long press → action sheet:**

```swift
func presetTileLongPressed(_ display: PresetDisplayItem) {
  guard !display.isPending,
        let preset = presets[id: display.id] else { return }
  presentedPresetActionSheetPreset = preset
}
```

**Drag-to-reorder commit:**

```swift
func presetMoved(from: Int, to: Int) async { /* optimistic reorder + PUT */ }
```

**Remove from action sheet:**

```swift
func removePresetTapped(_ preset: Preset) async {
  await removePreset(presetId: preset.id)
}
```

### View helpers

```swift
func isPreset(stationId: String) -> Bool {
  pendingPresetStationIds.contains(stationId)
    || presets.contains { $0.embeddedStationId == stationId }
}

var showsPresetsSection: Bool {
  selectedSegment == "All" || selectedSegment == presetsSegmentTitle
}

var showsPresetsOnly: Bool { selectedSegment == presetsSegmentTitle }

/// Real presets (orphans filtered) + ghost entries for pending adds.
/// Sorted by position; pending entries appended at the end.
var displayPresets: [PresetDisplayItem]
```

### `PresetDisplayItem`

```swift
struct PresetDisplayItem: Identifiable, Equatable {
  let id: String                   // preset.id, or "pending-<stationId>"
  let stationItem: APIStationItem  // looked up from stationLists
  let isPending: Bool              // disables long-press / drag
}
```

### Segment titles

`loadStationListsForDisplay` extended to produce:

```swift
segmentTitles = ["All", "Presets"] + visibleLists.map { $0.title }
```

When `selectedSegment == "Presets"`, `stationListsForDisplay` is set to empty so the page renders only the carousel.

### Optimistic flow details

| Operation | Optimistic action | On success | On failure |
|---|---|---|---|
| Add | Insert stationId into `$pendingPresetStationIds` | Remove from pending, append returned `Preset` into `$presets` | Remove from pending, set `presentedAlert = .errorSavingPreset` |
| Remove | Insert presetId into `$pendingPresetRemovalIds`; capture preset; remove from `$presets`; decrement all `position > removed.position` | Remove from pending removals | Restore captured preset + positions; remove from pending removals; set `presentedAlert = .errorRemovingPreset` |
| Move | Capture snapshot; local reorder; reassign `position` 0..n-1 | (nothing — server returns updated preset, used to overwrite the local one only on next refresh) | Restore snapshot; set `presentedAlert = .errorMovingPreset` |

### New `PlayolaAlert` cases

```swift
extension PlayolaAlert {
  static let errorSavingPreset    = PlayolaAlert(title: "Couldn't save preset", message: "Please try again.", ...)
  static let errorRemovingPreset  = PlayolaAlert(title: "Couldn't remove preset", message: "Please try again.", ...)
  static let errorMovingPreset    = PlayolaAlert(title: "Couldn't reorder presets", message: "Please try again.", ...)
}
```

### Analytics

New events tracked via `analytics.track(...)`:
- `presetAdded(station:)` — POST success
- `presetRemoved(station:)` — DELETE success
- `presetMoved(station:, fromIndex:, toIndex:)` — PUT success
- `presetTileTapped(station:, position:)` — before `stationSelected` runs from the carousel

Exact event-builder names will match existing analytics conventions in the codebase.

## View layer

### New folder

```
Views/Pages/StationListPage/Presets/
├── PresetStarButton.swift
├── PresetTile.swift
├── PresetsCarousel.swift
└── PresetActionSheet.swift
```

### `PresetStarButton`

```swift
struct PresetStarButton: View {
  let isPreset: Bool
  let label: String
  let onToggle: () async -> Void
}
```

- Filled gold star (`#FFD24A`) when `isPreset`; outlined gray (`#888888`) otherwise.
- 44×44 tap target.
- Accessibility label switches between "Add X to presets" / "Remove X from presets".

### `PresetTile`

```swift
struct PresetTile: View {
  let display: PresetDisplayItem
  let onTap: () async -> Void
  let onLongPress: () -> Void
}
```

- 92×92 rounded image (corner radius 8), title underneath (2-line cap, Inter Medium 13).
- "Coming <Date>" subtitle in playola-red for coming-soon stations.
- `.opacity(0.6)` while `display.isPending`; long-press disabled.
- `.onLongPressGesture(minimumDuration: 0.5)`.

### `PresetsCarousel`

```swift
struct PresetsCarousel: View {
  let displays: [PresetDisplayItem]
  let sectionTitle: String
  let emptyStateText: String
  let onTilePlay:      (PresetDisplayItem) async -> Void
  let onTileLongPress: (PresetDisplayItem) -> Void
  let onMove:          (Int, Int) async -> Void
}
```

- Header label ("Presets") above the row.
- Empty state: dashed-border rounded rectangle, gold star icon, `emptyStateText`.
- Horizontal `ScrollView` of `PresetTile`s with 12pt spacing, 16pt horizontal padding.
- Right-edge black gradient overlay (mirrors existing `FilterPills` pattern).
- Drag-to-reorder via SwiftUI `.onDrag` / `.onDrop` with a custom `DropDelegate`. Drop calls `onMove(from, to)`. Falls back to `DragGesture` with manual offset tracking if SwiftUI's drag-and-drop is janky inside a horizontal `ScrollView` (decision deferred to implementation).

### `PresetActionSheet`

Driven by `model.presentedPresetActionSheetPreset: Preset?` binding. Visual style matches the Lovable design:
- Gray rounded-top sheet (`#323232`).
- Grabber pill.
- Header: station thumbnail + title + "Preset" subtitle.
- Single row: gold star icon + "Remove from Presets".
- On tap → `model.removePresetTapped(preset)` and dismiss.

Implementation: SwiftUI `.sheet(item:)` with `.presentationDetents([.height(220)])` and a custom content view.

### Edits to `StationListStationRowView`

Two new init params:

```swift
struct StationListStationRowView: View {
  let model: StationListStationRowModel
  let action: () -> Void
  let isPreset: Bool              // NEW
  let onTogglePreset: () async -> Void  // NEW
```

The star button is rendered as the trailing element of the existing `HStack` (or adjoining the current trailing content — final placement determined during implementation against the current layout).

### Edits to `StationListPage`

Inside the main `ScrollView` of station lists, before the existing `ForEach`:

```swift
if model.showsPresetsSection {
  PresetsCarousel(
    displays: model.displayPresets,
    sectionTitle: model.presetsSectionTitle,
    emptyStateText: model.presetsEmptyStateText,
    onTilePlay:      { await model.presetTileTapped($0) },
    onTileLongPress: { model.presetTileLongPressed($0) },
    onMove:          { from, to in await model.presetMoved(from: from, to: to) }
  )
}
```

`stationSection(list:)` passes the new row params:

```swift
StationListStationRowView(
  model: rowModel,
  action: { Task { await model.stationSelected(item) } },
  isPreset: model.isPreset(stationId: item.anyStation.id),
  onTogglePreset: { await model.starTapped(for: item) }
)
```

Action sheet wired at the page level:

```swift
.sheet(item: $model.presentedPresetActionSheetPreset) { preset in
  PresetActionSheet(
    preset: preset,
    onRemove: { Task { await model.removePresetTapped(preset) } },
    onClose:  { model.presentedPresetActionSheetPreset = nil }
  )
}
```

## Edge cases

| Case | Behavior |
|---|---|
| Rapid double-tap of star | Toggle gated on `pendingPresetStationIds` / `pendingPresetRemovalIds`; second tap is a no-op while the first op is in flight. |
| 409 duplicate on POST | Rollback + `errorSavingPreset` alert. Practically unreachable due to pending guard. |
| 400 on PUT | Rollback + `errorMovingPreset` alert. Local reorder logic should never produce an invalid position; only fires on race conditions. |
| Orphan preset (station no longer in `stationLists`) | Filtered out of `displayPresets`. Backing record stays in `$presets` until next refresh. |
| Coming-soon station as preset | Allowed. Tile shows "Coming <Date>" subtitle. Tap behavior matches `stationSelected` (same `showSecretStations` / `active` gating). |
| Empty preset list | Dashed-border empty state inside the carousel section. |
| Long-press during drag | Drag wins (standard SwiftUI gesture priority). |
| Drag end with no movement | Detected as `from == to`; no API call. |
| User signs out | Out of scope — page not reachable signed out. |

## Testing

### `Tests/Models/PresetTests.swift` (new)

- `testPresetDecodesPlayolaStationPayload`
- `testPresetDecodesUrlStationPayload`
- `testEmbeddedStationIdReturnsPlayolaIdWhenStationSet`
- `testEmbeddedStationIdReturnsUrlIdWhenUrlStationSet`

Uses the sample JSON from the design as the fixture.

### `StationListPageTests.swift` (edits)

New `@MainActor` test methods on the existing class:

- `testViewAppearedLoadsPresets`
- `testStarTappedOnNonPresetAddsOptimistically`
- `testStarTappedOnPresetRemovesOptimistically`
- `testStarTappedIgnoredWhilePendingAdd`
- `testStarTappedIgnoredWhilePendingRemoval`
- `testAddPresetFailureRollsBackAndShowsAlert`
- `testRemovePresetFailureRestoresPresetAndPositions`
- `testPresetMovedSendsServerPositionAndReassignsLocalPositions`
- `testPresetMoveFailureRevertsToSnapshot`
- `testPresetMoveNoOpWhenFromEqualsTo`
- `testPresetTileTappedPlaysFullStationFromStationLists`
- `testOrphanPresetsFilteredFromDisplayPresets`
- `testDisplayPresetsAppendPendingAdditionsAtEnd`
- `testPresetsSegmentShowsOnlyCarouselAndNoStationSections`
- `testSegmentTitlesPlacePresetsSecond`
- `testPresetAddedAnalyticsTrackedOnSuccess`
- `testPresetRemovedAnalyticsTrackedOnSuccess`
- `testPresetMovedAnalyticsTrackedOnSuccess`
- `testPresetTileTappedAnalyticsTracked`

Tests use `withDependencies { ... }` to mock `api` and `analytics`, declare `@Shared` state locally per project convention, assert synchronously (no `Task.sleep`).

## File layout summary

```
PlayolaRadio/
├── Core/API/
│   ├── APIClient.swift                (edited)
│   └── APIClient+Live.swift           (edited)
├── Models/
│   └── Preset.swift                   (new)
├── State/
│   └── SharedUserDefaults.swift       (edited — 3 new shared keys)
└── Views/Pages/StationListPage/
    ├── StationListModel.swift         (edited)
    ├── StationListPage.swift          (edited)
    ├── StationListPageTests.swift     (edited)
    ├── Presets/                       (new folder)
    │   ├── PresetStarButton.swift
    │   ├── PresetTile.swift
    │   ├── PresetsCarousel.swift
    │   └── PresetActionSheet.swift
    └── StationListStationRowView/
        └── StationListStationRowView.swift   (edited — 2 new params)

PlayolaRadioTests/Models/
└── PresetTests.swift                  (new)
```

## Open implementation-time decisions

These are small enough not to need pre-approval; flagged so the implementer doesn't get blocked:

1. `authenticatedPut(_:token:parameters:)` — add overload if missing.
2. Star button placement inside `StationListStationRowView` — verify against current row layout.
3. Drag-and-drop API choice — SwiftUI `.onDrag`/`.onDrop` first; fall back to manual `DragGesture` if janky in a horizontal scroll.
4. `PresetActionSheet` sheet height — start with `.presentationDetents([.height(220)])`, tune visually.
5. Snapshot tests — add only if the project already uses SnapshotTesting; otherwise skip and rely on model tests.

## Out of scope

- Sign-out / multi-user state transitions.
- Server-side anything (endpoints are owned by the server team).
- Cross-device sync UX (server handles it; no UI affordance).
- Per-preset notifications, sorting modes, grouping. Just position-ordered presets.
