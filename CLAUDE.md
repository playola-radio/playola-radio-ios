# Playola Radio iOS

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
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let navigationTitle = "Page Title"

  var items: IdentifiedArrayOf<Item> = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?
  var selectedFilter: FilterType = .default

  var filteredItems: IdentifiedArrayOf<Item> {
    items.filter { ... }
  }

  var emptyStateMessage: String {
    "No items to display"
  }

  // MARK: - User Actions

  func viewAppeared() async { }
  func refreshPulledDown() async { }
  func filterButtonTapped(_ filter: FilterType) { }
  func itemRowTapped(_ item: Item) async { }
  func deleteItemSwiped(_ item: Item) async { }

  // MARK: - View Helpers

  func isSelected(_ itemId: String) -> Bool { }
  func canDelete(_ item: Item) -> Bool { }

  // MARK: - Private Helpers

  private func fetchItems() async { }
  private func stopPlayback() async { }
}

// MARK: - Alerts

extension PlayolaAlert {
  static func someError(_ message: String) -> PlayolaAlert { ... }
}
```

### Model/View Responsibilities

**Models are the full representation of the view.** All text, titles, labels, and display values should come from the model as stored or computed properties. The view should only describe *how* things appear, never *what* they do.

**Model responsibilities:**
- All display text (titles, labels, button text, status messages)
- All computed display values (formatted dates, durations, progress)
- All business logic and state management
- Action methods that describe user interactions

**View responsibilities:**
- Layout and styling only
- Binds to model properties for all content
- Calls model methods for all user actions
- Contains zero business logic

**Action method naming** - use names that describe user actions:
```swift
// Good - describes what the user did
func recordButtonTapped() async { }
func stopButtonTapped() async { }
func showMoreButtonTapped() { }
func listReordered(from: IndexSet, to: Int) { }

// Bad - describes implementation
func startRecording() async { }
func toggleExpanded() { }
```

**Helper functions** should be private and placed at the bottom of the model.

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

## Code Style

- **Linting**: SwiftLint (auto-runs on commit via git hooks)
- **Formatting**: swift-format (auto-runs on commit)
- Run `make format` to format, `make lint` to check

## Conventions

- All view models inherit from `ViewModel` base class
- All view models and tests are `@MainActor`
- Use `async/await`, no completion handlers
- Alerts via `PlayolaAlert` enum
- Navigation via `PlayolaSheet` enum and navigation coordinator

## Sheet Presentation

Sheets are presented via the `PlayolaSheet` enum and `MainContainerNavigationCoordinator`.

### Adding a new sheet type

1. Add a case to `PlayolaSheet` enum in `Views/Reusable Components/PlayolaSheet.swift`:
```swift
enum PlayolaSheet: Hashable, Identifiable, Equatable {
  case player(PlayerPageModel)
  case myNewSheet(MyNewSheetModel)  // Add your case
}
```

2. Handle the case in `MainContainer.swift`'s `.sheet()` or `.fullScreenCover()` modifier:
```swift
.sheet(
  item: Binding(
    get: {
      switch model.mainContainerNavigationCoordinator.presentedSheet {
      case .player, .feedbackSheet, .myNewSheet:  // Add to the list
        return model.mainContainerNavigationCoordinator.presentedSheet
      // ...
      }
    },
    // ...
  ),
  content: { item in
    switch item {
    case .myNewSheet(let myModel):  // Add case
      MyNewSheetView(model: myModel)
    // ...
    }
  }
)
```

### Presenting a sheet from a model

```swift
// In your model, inject the navigation coordinator
@ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
var mainContainerNavigationCoordinator

// Present the sheet
func shareButtonTapped() {
  let model = MyNewSheetModel(items: [...])
  mainContainerNavigationCoordinator.presentedSheet = .myNewSheet(model)
}

// Dismiss the sheet
func dismissButtonTapped() {
  mainContainerNavigationCoordinator.presentedSheet = nil
}
```
