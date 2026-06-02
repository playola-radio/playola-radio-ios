# In Development Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show an "IN DEVELOPMENT" badge on a suggested-station row when the server reports its status as `in_development`.

**Architecture:** Add a `status` enum to the `ArtistSuggestion` model (with an `.unknown` fallback for forward-compat), expose the badge text from `StationSuggestionPageModel`, add a small reusable `InDevelopmentBadge` view, and render it in the suggestion row when the model returns text.

**Tech Stack:** Swift, SwiftUI, swift-testing (`import Testing`), CustomDump (`expectNoDifference`). Point-Free skills in force: pfw-observable-models, pfw-modern-swiftui, pfw-testing, pfw-custom-dump. No comments in generated code; avoid `self` where not needed.

---

### Task 1: Add `status` to the `ArtistSuggestion` model

**Files:**
- Test: `PlayolaRadio/Models/ArtistSuggestionTests.swift` (create)
- Modify: `PlayolaRadio/Models/ArtistSuggestion.swift`
- Modify: `PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageTests.swift:23-34,50-53`
- Modify: `PlayolaRadio/Core/API/APIClient.swift:739-742` (and the empty-stub default at `726-729` returns `[]`, so no change there)

- [ ] **Step 1: Write the failing decoding test**

Create `PlayolaRadio/Models/ArtistSuggestionTests.swift`:

```swift
//
//  ArtistSuggestionTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

struct ArtistSuggestionStatusTests {

  @Test
  func decodesKnownStatuses() throws {
    let json = Data(#"["suggested", "in_development", "streaming"]"#.utf8)

    let statuses = try JSONDecoder().decode([ArtistSuggestionStatus].self, from: json)

    expectNoDifference(statuses, [.suggested, .inDevelopment, .streaming])
  }

  @Test
  func decodesUnrecognizedStatusAsUnknown() throws {
    let json = Data(#"["archived"]"#.utf8)

    let statuses = try JSONDecoder().decode([ArtistSuggestionStatus].self, from: json)

    expectNoDifference(statuses, [.unknown])
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run in Xcode (user runs tests). Expected: compile failure — `ArtistSuggestionStatus` is undefined.

- [ ] **Step 3: Add the enum and field**

Replace the contents of `PlayolaRadio/Models/ArtistSuggestion.swift` with:

```swift
//
//  ArtistSuggestion.swift
//  PlayolaRadio
//

import Foundation

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

struct ArtistSuggestion: Codable, Identifiable, Equatable, Sendable {
  let id: String
  let artistName: String
  let createdByUserId: String
  let voteCount: Int
  let hasVoted: Bool
  let status: ArtistSuggestionStatus
  let createdAt: Date
  let updatedAt: Date
}
```

- [ ] **Step 4: Update the memberwise-init call sites so the project compiles**

In `PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageTests.swift`, update `mockSuggestions()` (lines 23-34) so the three suggestions carry distinct statuses for later use, and the create stub (lines 50-53):

```swift
  nonisolated private func mockSuggestions() -> [ArtistSuggestion] {
    [
      ArtistSuggestion(
        id: "s1", artistName: "Bri Bagwell", createdByUserId: "u1",
        voteCount: 10, hasVoted: true, status: .inDevelopment,
        createdAt: Date(), updatedAt: Date()),
      ArtistSuggestion(
        id: "s2", artistName: "Charley Crockett", createdByUserId: "u2",
        voteCount: 7, hasVoted: false, status: .suggested,
        createdAt: Date(), updatedAt: Date()),
      ArtistSuggestion(
        id: "s3", artistName: "Colter Wall", createdByUserId: "u3",
        voteCount: 3, hasVoted: false, status: .streaming,
        createdAt: Date(), updatedAt: Date()),
    ]
  }
```

```swift
    let defaultCreate: @Sendable (String, String) async throws -> ArtistSuggestion = { _, name in
      ArtistSuggestion(
        id: "new", artistName: name, createdByUserId: "u1",
        voteCount: 1, hasVoted: true, status: .suggested,
        createdAt: Date(), updatedAt: Date())
    }
```

In `PlayolaRadio/Core/API/APIClient.swift`, update the `createArtistSuggestion` default stub (lines 739-742):

```swift
  var createArtistSuggestion:
    @Sendable (_ jwtToken: String, _ artistName: String) async throws -> ArtistSuggestion = {
      _, _ in
      ArtistSuggestion(
        id: "", artistName: "", createdByUserId: "", voteCount: 0, hasVoted: false,
        status: .suggested, createdAt: Date(), updatedAt: Date())
    }
```

Note: the `getArtistSuggestions` default (lines 726-729) returns `[]` and needs no change. If a search across the repo finds any other `ArtistSuggestion(` construction site, add `status: .suggested` there too.

- [ ] **Step 5: Run the tests to verify they pass**

Run in Xcode. Expected: `ArtistSuggestionStatusTests` passes; existing `StationSuggestionPageTests` still pass.

- [ ] **Step 6: Commit**

```bash
git add PlayolaRadio/Models/ArtistSuggestion.swift PlayolaRadio/Models/ArtistSuggestionTests.swift PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageTests.swift PlayolaRadio/Core/API/APIClient.swift
git commit -m "Add status field to ArtistSuggestion model"
```

---

### Task 2: Expose badge text from the page model

**Files:**
- Test: `PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageTests.swift`
- Modify: `PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageModel.swift:119-125`

- [ ] **Step 1: Write the failing test**

Add to `StationSuggestionPageTests.swift` (inside the `StationSuggestionPageTests` struct):

```swift
  @Test
  func inDevelopmentBadgeTextShownOnlyForInDevelopment() {
    let model = makeModel()

    let inDevelopment = ArtistSuggestion(
      id: "a", artistName: "A", createdByUserId: "u", voteCount: 0, hasVoted: false,
      status: .inDevelopment, createdAt: Date(), updatedAt: Date())
    let suggested = ArtistSuggestion(
      id: "b", artistName: "B", createdByUserId: "u", voteCount: 0, hasVoted: false,
      status: .suggested, createdAt: Date(), updatedAt: Date())
    let streaming = ArtistSuggestion(
      id: "c", artistName: "C", createdByUserId: "u", voteCount: 0, hasVoted: false,
      status: .streaming, createdAt: Date(), updatedAt: Date())

    #expect(model.inDevelopmentBadgeText(inDevelopment) == "IN DEVELOPMENT")
    #expect(model.inDevelopmentBadgeText(suggested) == nil)
    #expect(model.inDevelopmentBadgeText(streaming) == nil)
  }
```

- [ ] **Step 2: Run the test to verify it fails**

Run in Xcode. Expected: compile failure — `inDevelopmentBadgeText` is undefined.

- [ ] **Step 3: Add the helper**

In `StationSuggestionPageModel.swift`, in the `// MARK: - View Helpers` section, add after `voteCountText` (line 125):

```swift
  func inDevelopmentBadgeText(_ suggestion: ArtistSuggestion) -> String? {
    suggestion.status == .inDevelopment ? "IN DEVELOPMENT" : nil
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run in Xcode. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageModel.swift PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageTests.swift
git commit -m "Add in-development badge text to StationSuggestionPageModel"
```

---

### Task 3: Create the `InDevelopmentBadge` view

**Files:**
- Create: `PlayolaRadio/Views/Reusable Components/InDevelopmentBadge.swift`

- [ ] **Step 1: Create the view**

Create `PlayolaRadio/Views/Reusable Components/InDevelopmentBadge.swift`:

```swift
//
//  InDevelopmentBadge.swift
//  PlayolaRadio
//

import SwiftUI

struct InDevelopmentBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.custom(FontNames.Inter_700_Bold, size: 10))
      .tracking(1.4)
      .foregroundColor(.playolaRed)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(Color.playolaRed, lineWidth: 1)
      )
  }
}

#Preview {
  InDevelopmentBadge(text: "IN DEVELOPMENT")
    .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Verify it builds**

Build in Xcode. Expected: builds; the preview renders an outlined red pill.

- [ ] **Step 3: Commit**

```bash
git add "PlayolaRadio/Views/Reusable Components/InDevelopmentBadge.swift"
git commit -m "Add InDevelopmentBadge reusable view"
```

---

### Task 4: Render the badge in the suggestion row

**Files:**
- Modify: `PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageView.swift:141-177`

- [ ] **Step 1: Wire the badge into the row**

In `suggestionRow(_:)`, place the badge between the artist name and the vote-count line. Replace the `VStack(alignment: .leading, spacing: 2)` block (lines 143-151) with:

```swift
      VStack(alignment: .leading, spacing: 4) {
        Text(suggestion.artistName)
          .font(.custom(FontNames.Inter_500_Medium, size: 18))
          .foregroundColor(.textPrimary)

        if let badgeText = model.inDevelopmentBadgeText(suggestion) {
          InDevelopmentBadge(text: badgeText)
        }

        Text("\(model.voteCountText(suggestion)) votes")
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.textSecondary)
      }
```

- [ ] **Step 2: Verify it builds and renders**

Build in Xcode and open `StationSuggestionPageView`'s preview. Expected: the in-development mock suggestion ("Bri Bagwell") shows the "IN DEVELOPMENT" badge; the others do not.

- [ ] **Step 3: Commit**

```bash
git add PlayolaRadio/Views/Pages/StationSuggestionPage/StationSuggestionPageView.swift
git commit -m "Show In Development badge on suggested station rows"
```

---

## Notes for the implementer

- Run `make format` before each commit; SwiftLint/swift-format run on commit via git hooks. Do not use `--no-verify`.
- Tests run in Xcode (the user runs them). Do not add `Task.sleep` to any test.
- `Color.playolaRed` and `FontNames.Inter_700_Bold` / `Inter_500_Medium` / `Inter_400_Regular` already exist in the app.
