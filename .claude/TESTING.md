# Testing Patterns

## General Rules

1. **Never use `Task.sleep` in tests** - makes tests slow and flaky
2. **Prefer computed properties** for model state derived from `@Shared` - enables synchronous testing
3. **Use `.mockWith()` factories** for test data (see `HomePageTests.swift` for examples)
4. **Tests colocated with code** - `SomeModel.swift` → `SomeTests.swift` in same folder
5. **Test naming**: camelCase without underscores (e.g., `testRecordButtonTappedRequestsPermission`)
6. **All test classes use `@MainActor`**

## @Shared State in Tests

Declare `@Shared` inside each test with initial values. Use `$shared.withLock { }` to update:

```swift
func testToggleUpdatesStations() async {
  @Shared(.showSecretStations) var showSecretStations = false
  let model = HomePageModel()

  XCTAssertEqual(model.forYouStations.count, 1)

  $showSecretStations.withLock { $0 = true }
  XCTAssertEqual(model.forYouStations.count, 2)  // No sleep needed!
}
```

## Mocking Dependencies

Use `withDependencies` to mock API calls:

```swift
func testViewAppearedLoadsAirings() async {
  @Shared(.auth) var auth = Auth(jwt: "test-jwt")

  await withDependencies {
    $0.api.getAirings = { _, _ in [Airing.mockWith(id: "airing-1")] }
  } operation: {
    let model = HomePageModel()
    await model.viewAppeared()
    XCTAssertTrue(model.hasScheduledShows)
  }
}
```

## Analytics Event Capture

Use `LockIsolated` for thread-safe capture:

```swift
let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

let model = withDependencies {
  $0.analytics.track = { @Sendable event in
    capturedEvents.withValue { $0.append(event) }
  }
} operation: {
  SomeModel()
}

await model.someAction()
XCTAssertEqual(capturedEvents.value.count, 1)
```

## Code That Spawns Internal Tasks

When code spawns its own `Task { }`, use `withMainSerialExecutor` + `Task.yield()`:

```swift
func testActionThatSpawnsTask() async {
  await withMainSerialExecutor {
    let model = SomeModel()
    model.actionThatSpawnsTask()
    await Task.yield()
    XCTAssertTrue(model.didComplete)
  }
}
```
