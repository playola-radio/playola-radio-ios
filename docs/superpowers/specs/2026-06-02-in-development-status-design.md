# Display "In Development" status on suggested stations

**Date:** 2026-06-02
**Status:** Approved

## Problem

The server's artist-suggestion model gained a `status` field. We want the iOS
"Suggest a Station" page to surface when Playola is actively building a
suggested artist's station, matching the design in the `lovable-ios` prototype.

## Context

- **Server** (`~/playola/playola/server`): the model is `ArtistSuggestion`. It
  now returns a `status` string field — `allowNull: false`, default
  `"suggested"`. Possible values: `"suggested"`, `"in_development"`,
  `"streaming"`.
- **Design** (`lovable-ios/src/components/stations/SuggestStationModal.tsx`):
  an `IN DEVELOPMENT` badge rendered inline with the artist name — an outlined
  red pill. Text + border `#EF6962` (Playola red), transparent fill, 1px
  border, 4px corner radius, 10px extrabold all-caps, `0.14em` letter-spacing,
  8px×3px padding. Voting stays enabled. The design handles only the
  in-development case.
- **iOS** (this repo): `ArtistSuggestion.swift` has no `status` field.
  Suggestions render on `StationSuggestionPage`. The app already has a
  `LiveBadge` (outlined-pill idiom: `Inter_600_SemiBold` size 10, red stroke)
  and uses an `.unknown` enum fallback convention for resilient decoding
  (`StationListItemVisibility`).

## Scope

**In scope:** Show an "IN DEVELOPMENT" badge on a suggestion row when its
status is `in_development`.

**Out of scope:** Any badge for `streaming` or `suggested`; changes to voting;
admin status-editing UI. (A `streaming` badge can be added later when that
state matters in the UI.)

## Design

### 1. Model — `Models/ArtistSuggestion.swift`

Add a `status` field backed by a new enum mirroring the server's three values
plus an `.unknown` fallback (matching the existing `StationListItemVisibility`
convention so a future server status won't break decoding):

```swift
enum ArtistSuggestionStatus: String, Codable, Equatable, Sendable {
  case suggested
  case inDevelopment = "in_development"
  case streaming
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = ArtistSuggestionStatus(rawValue: raw) ?? .unknown
  }
}
```

Add `let status: ArtistSuggestionStatus` to the struct (non-optional — the
server always sends it). Synthesized `Codable` on the struct is kept. The
memberwise-init call sites get `status:` added, defaulting to `.suggested`:
- `StationSuggestionPageTests.swift` (3 in `mockSuggestions`, 1 in the create mock)
- `APIClient.swift` (2 default-closure stubs)

### 2. Model text — `StationSuggestionPageModel.swift`

The model owns the badge text. Add a view helper alongside `voteButtonText`:

```swift
func inDevelopmentBadgeText(_ suggestion: ArtistSuggestion) -> String? {
  suggestion.status == .inDevelopment ? "IN DEVELOPMENT" : nil
}
```

`nil` → no badge. Only `.inDevelopment` returns text; `suggested` / `streaming`
/ `unknown` return `nil`.

### 3. Badge view — `Views/Reusable Components/InDevelopmentBadge.swift`

A small view styled to match the lovable design (outlined red pill), in the
same spirit as `LiveBadge`. Takes the label string as a parameter (text comes
from the model):
- Playola red (`#EF6962`) text + 1px border, transparent fill
- `cornerRadius` 4, padding 8 horizontal × 3 vertical
- `Inter_700_Bold` size 10, `.tracking(~1.4)` for the `0.14em` letter-spacing

### 4. Row wiring — `StationSuggestionPageView.swift`

In `suggestionRow`, render `InDevelopmentBadge` after the artist name when
`model.inDevelopmentBadgeText(suggestion)` is non-nil. Voting unchanged.

## Testing (TDD — written first)

- **`Models/ArtistSuggestionTests.swift`** (new): decode `"in_development"` →
  `.inDevelopment`, `"streaming"` → `.streaming`, `"suggested"` →
  `.suggested`, and an unrecognized string → `.unknown`. Use
  `expectNoDifference`.
- **`StationSuggestionPageTests.swift`**: `inDevelopmentBadgeText` returns
  `"IN DEVELOPMENT"` for an in-development suggestion and `nil` for the others.
