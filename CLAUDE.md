# Playola Radio iOS

## Task-Type Quick Reference

| Task Type | Read This |
|-----------|-----------|
| Creating a new page | `.claude/PAGE_CREATION.md` |
| Adding API calls (iOS) | `.claude/API_CLIENT.md` |
| Looking up server endpoints | `../playola/.claude/API_ENDPOINTS.md` then `../playola/server/src/api/[module]/ENDPOINTS.md` (ask user for monorepo path if not found) |
| Navigation (push/pop/sheets) | `.claude/NAVIGATION.md` |
| Adding shared state | `.claude/API_CLIENT.md` "State Management" section |
| Writing tests | "Testing" section below + `.claude/TESTING.md` |
| View styling (colors, fonts) | `.claude/VIEWS.md` |
| Analytics testing | `.claude/TESTING.md` |

## Server / API Documentation

The Playola server monorepo is expected at `../playola` (sibling directory). If not found, ask the user for the path.

- **API overview**: `../playola/.claude/API_ENDPOINTS.md`
- **Module endpoints**: `../playola/server/src/api/[module]/ENDPOINTS.md`
- **OpenAPI docs**: `../playola/server/src/api/[module]/[module].api.docs.yaml`

## Testing

- **Write tests first when possible** - prefer TDD, write regression tests for bug fixes
- **Tests run in Xcode** - the user will run all tests for you in Xcode
- **Test naming**: camelCase without underscores (e.g., `testOnRecordTappedRequestsPermission`)
- **Tests colocated with code**: `HomePageModel.swift` → `HomePageTests.swift` in same folder
- **Framework**: XCTest with `@MainActor` on all test classes

### Testing with @Shared state

Declare `@Shared` locally inside each test method with an initial value:

```swift
func testSomething() {
  @Shared(.stationLists) var stationLists = makeTestStationLists()
  @Shared(.showSecretStations) var showSecretStations = false

  let model = SomeModel()
  // test...
}
```

Do NOT use class-level `@Shared` properties or `$shared.withLock` in tests.

### Test anti-patterns

- **NEVER use `Task.sleep` in tests** - it makes tests slow and flaky. Use synchronous assertions or test doubles that execute synchronously.

## Architecture

**Pattern**: MV with `@Observable` models (not MVVM)

### Model Structure

Models should be organized with the following `// MARK:` sections in order:

```swift
@MainActor
@Observable
class SomePageModel: ViewModel {

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State
  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization
  init(stationId: String) { ... }

  // MARK: - Properties
  var items: IdentifiedArrayOf<Item> = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  // MARK: - User Actions
  func viewAppeared() async { }
  func itemRowTapped(_ item: Item) async { }

  // MARK: - View Helpers
  func isSelected(_ itemId: String) -> Bool { }

  // MARK: - Private Helpers
  private func fetchItems() async { }
}
```

### Model/View Responsibilities

**The Model is the complete, portable representation of the page.** If we port to another platform (Android, web, etc.), only the View should need to be rebuilt. The Model contains everything: all text, all behavior, all state.

**Model responsibilities (everything except visuals):**
- All display text (navigation titles, labels, button text, empty states, error messages)
- All computed display values (formatted dates, durations, progress percentages)
- All business logic and state management
- All action handlers (what happens when user taps something)
- Validation logic and error states

**View responsibilities (visuals only):**
- Layout, spacing, colors, fonts
- Binds to model properties for ALL content (never hardcode strings)
- Calls model methods for ALL user actions
- Contains zero logic - not even simple conditionals about what text to show

**Example - the Model provides everything:**
```swift
// Model
var navigationTitle: String { "My Library" }
var emptyStateMessage: String { "No songs yet. Like some songs to see them here!" }
var songCountLabel: String { "\(songs.count) songs" }
var isDeleteButtonEnabled: Bool { selectedSongs.count > 0 }
```

```swift
// View - just renders what Model provides
Text(model.emptyStateMessage)  // Good
Text("No songs yet")           // Bad - hardcoded string
```

**Action method naming** - use names that describe user actions:
```swift
// Good - describes what the user did
func recordButtonTapped() async { }
func stopButtonTapped() async { }

// Bad - describes implementation
func startRecording() async { }
func toggleExpanded() { }
```

## Dependencies

Uses Point-Free's `swift-dependencies` library:

- Inject via `@Dependency(\.serviceName)`
- Mock in tests via `withDependencies { $0.api = ... }`
- All clients are `Sendable` structs

## State Management

Uses Point-Free's `swift-sharing` library:

- `@Shared(.auth)` - persisted auth state
- `@Shared(.nowPlaying)` - in-memory playback state
- `@Shared(.mainContainerNavigationCoordinator)` - navigation

See `.claude/API_CLIENT.md` for detailed patterns.

## Project Structure

```
PlayolaRadio/
├── Core/           # Services and dependency clients
├── Models/         # Data models (Codable)
├── State/          # Shared state definitions
└── Views/
    ├── Pages/      # Each page has Model, View, Tests
    └── Reusable Components/
```

## Pre-PR Checklist

Before creating a PR, run through these checks in order:

### 1. Formatting & Linting
- Run `make format` to auto-fix formatting
- Run `make lint` to check SwiftLint — fix all violations before proceeding

### 2. Tests
- Ask the user to run tests in Xcode (tests cannot be run from the CLI)
- Ensure all new code has corresponding tests
- Verify tests follow `.claude/TESTING.md` patterns:
  - `@MainActor` on all test classes
  - camelCase test names (no underscores)
  - `@Shared` declared locally inside each test method
  - No `Task.sleep` in tests
  - All dependencies provided (especially `date.now` and notification clients for tests calling `viewAppeared`)

### 3. Architecture Conformance
- **Models** follow the MARK section order from `.claude/PAGE_CREATION.md`: Dependencies → Shared State → Initialization → Properties → User Actions → View Helpers → Private Helpers
- **Models** own all display text — no hardcoded strings in Views
- **Views** contain zero logic — only layout, styling, and bindings
- **Action methods** named after user actions (e.g., `recordButtonTapped`), not implementation (e.g., `startRecording`)
- All view models inherit from `ViewModel` base class

### 4. View Style Conformance
- Colors, fonts, buttons, row layout, and images follow `.claude/VIEWS.md`
- Navigation bar uses dark theme setup from `.claude/VIEWS.md`
- Remote images use `SDWebImageSwiftUI` with placeholder fallback

### 5. New files added to Xcode project
- Any new `.swift` files must be added to `PlayolaRadio.xcodeproj` (use `xcodeproj` gem via Ruby script)
- Source files added to both `PlayolaRadio` and `PlayolaRadio Staging` targets
- Test files added to `PlayolaRadioTests` target

## Code Style

- **Linting**: SwiftLint (auto-runs on commit via git hooks)
- **Formatting**: swift-format (auto-runs on commit)
- Run `make format` to format, `make lint` to check

## Conventions

- All view models inherit from `ViewModel` base class
- All view models and tests are `@MainActor`
- Use `async/await`, no completion handlers
- Alerts via `PlayolaAlert` enum
- Navigation via `PlayolaSheet` enum and navigation coordinator (see `.claude/NAVIGATION.md`)
