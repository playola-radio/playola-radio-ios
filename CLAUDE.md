# Playola Radio iOS

## Testing

- **Write tests first when possible** - prefer TDD, write regression tests for bug fixes
- **Tests run in Xcode** - the user will run all tests for you in Xcode
- **Test naming**: camelCase without underscores (e.g., `testOnRecordTappedRequestsPermission`)
- **Tests colocated with code**: `HomePageModel.swift` → `HomePageTests.swift` in same folder
- **Framework**: XCTest with `@MainActor` on all test classes

## Architecture

**Pattern**: MV with `@Observable` models (not MVVM)

```swift
@MainActor
@Observable
class SomePageModel: ViewModel {
  // Shared state
  @ObservationIgnored @Shared(.auth) var auth

  // Dependencies
  @ObservationIgnored @Dependency(\.api) var api

  // Local state
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  // Actions
  func viewAppeared() async { }
}
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
