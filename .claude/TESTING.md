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

### Important: @Shared initialization is a DEFAULT, not a write

`@Shared(.auth) var auth = Auth(jwt: "test-jwt")` sets a **default fallback** — it does NOT write to the store. If a leaked async task from a prior test already wrote to that key, the existing value persists. The swift-sharing library resets its `PersistentReferences` cache between tests via a `testCaseWillStart:` observer, but leaked escaping `Task { }` blocks from prior tests can interfere with this reset timing (see [swift-dependencies#127](https://github.com/pointfreeco/swift-dependencies/issues/127)).

**When tests are flaky on CI but pass locally**, wrap in `withMainSerialExecutor` to serialize async execution and prevent leaked tasks from other tests from running during your test's `@Shared` initialization:

```swift
func testSomethingWithSharedAuth() async {
  await withMainSerialExecutor {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    // ... rest of test
  }
}
```

This is especially important for `@Shared` keys backed by `.fileStorage` (like `.auth`), which go through more async machinery than `.inMemory` keys.

## Provide ALL Dependencies Reached by the Code Path

`swift-dependencies` will crash the test if any `@Dependency` is accessed from a test context without being provided. This means you must trace every code path your test exercises and provide every dependency it touches — not just the one you're testing.

Common pitfall: `viewAppeared()` often calls multiple private methods. If you mock one API call but the method also accesses `date.now` or calls `pushNotifications.scheduleNotification`, those must be provided too:

```swift
// BAD — crashes because viewAppeared also uses date.now and scheduleNotification
await withDependencies {
  $0.api.getMyListenerQuestionAirings = { _ in [airing] }
} operation: { ... }

// GOOD — provide every dependency the code path touches
await withDependencies {
  $0.date.now = Date()
  $0.api.getMyListenerQuestionAirings = { _ in [airing] }
  $0.pushNotifications.scheduleNotification = { _, _, _, _ in }
} operation: { ... }
```

When adding new dependency usage to an existing method (e.g., adding `scheduleAiringReminders` to `viewAppeared`), you must update ALL existing tests that call that method.

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

When model code spawns its own `Task { }` (fire-and-forget), use `withMainSerialExecutor` + `Task.yield()` to deterministically advance execution. From [Point-Free's blog](https://www.pointfree.co/blog/posts/169-new-in-swift-6-1-test-scoping-traits):

- `withMainSerialExecutor` overrides Swift's global async enqueue hook to serialize all work to the main thread
- Each `await Task.yield()` advances the spawned Task past one suspension point
- Count the suspension points in the spawned Task to know how many yields you need

```swift
func testActionThatSpawnsTask() async {
  await withMainSerialExecutor {
    let model = SomeModel()
    model.actionThatSpawnsTask()  // Spawns Task { await apiCall(); await analytics.track() }
    await Task.yield()  // Advances past apiCall()
    await Task.yield()  // Advances past analytics.track()
    XCTAssertTrue(model.didComplete)
  }
}
```

**Rule of thumb**: If a spawned `Task` has N suspension points (`await` calls), you need N+1 `Task.yield()` calls to be safe (one to start the task, one per suspension point).
