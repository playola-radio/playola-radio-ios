# Playola Radio iOS — Review Rules

## Architecture: MV Pattern (Not MVVM)

This project uses an MV pattern with `@Observable` models. The **Model is the complete, portable representation of the page** — if ported to another platform, only the View should need rebuilding.

### Model Provides Everything (except visuals)

- All display text: navigation titles, labels, button text, empty states, error messages
- All computed display values: formatted dates, durations, progress percentages
- All business logic, state management, and action handlers
- Validation logic and error states

```swift
// Model — provides all content
var navigationTitle: String { "My Library" }
var emptyStateMessage: String { "No songs yet." }
var isDeleteButtonEnabled: Bool { selectedSongs.count > 0 }
```

### Views Are Visuals Only

- Layout, spacing, colors, fonts
- Binds to model properties for ALL content
- Calls model methods for ALL user actions
- Contains zero logic

```swift
// Good
Text(model.emptyStateMessage)

// Bad — hardcoded string in View
Text("No songs yet")
```

## Model Structure

Models must follow this MARK section order:

1. `// MARK: - Dependencies` — `@ObservationIgnored @Dependency` injections
2. `// MARK: - Shared State` — `@ObservationIgnored @Shared` declarations
3. `// MARK: - Initialization`
4. `// MARK: - Properties` — observable state (`isLoading`, `items`, `presentedAlert`, etc.)
5. `// MARK: - User Actions` — methods named after user actions
6. `// MARK: - View Helpers` — computed display properties
7. `// MARK: - Private Helpers`

## User Action Naming

Method names describe what the **user** did, not the implementation:

```swift
// Good — describes user action
func recordButtonTapped() async { }
func stopButtonTapped() async { }
func itemRowTapped(_ item: Item) async { }

// Bad — describes implementation
func startRecording() async { }
func toggleExpanded() { }
```

## Dependencies & Shared State

- All `@Dependency` and `@Shared` properties **must** be `@ObservationIgnored`
- Update shared state via `$sharedVar.withLock { $0 = newValue }`
- Dependencies are `Sendable` structs from `swift-dependencies`

## Alerts & Navigation

- **Alerts**: Use `.playolaAlert($model.presentedAlert)` with `PlayolaAlert` enum cases. Never use SwiftUI's `.alert()` directly.
- **Sheets**: Present via `mainContainerNavigationCoordinator.presentedSheet = .someSheet(model)` using `PlayolaSheet` enum.
- **Navigation**: Push/pop via `MainContainerNavigationCoordinator`. Don't use `NavigationLink` directly.

## Testing Rules

- **Test location**: Colocated — `SomePageModel.swift` → `SomePageTests.swift` in same folder
- **Test class**: `@MainActor final class SomeTests: XCTestCase`
- **Naming**: camelCase, no underscores — `testOnRecordTappedRequestsPermission`
- **NEVER use `Task.sleep` in tests** — it makes tests slow and flaky
- **@Shared in tests**: Declare locally per test method with initial value:

```swift
func testSomething() async {
  @Shared(.auth) var auth = Auth(jwt: "test-jwt")
  let model = withDependencies { ... } operation: { SomeModel() }
  // ...
}
```

Do NOT use class-level `@Shared` properties in tests.

## Error Handling

- All API calls must be in `do/catch` blocks
- Errors set `presentedAlert` to a `PlayolaAlert` case
- Use `isLoading = true` / `defer { isLoading = false }` pattern
- Never silently swallow errors

## Code Style

- Use async/await, never completion handlers
- Use `IdentifiedArrayOf<T>` for identifiable collections
- Run `make format` and `make lint` before committing
- Comments only when code isn't self-explanatory
