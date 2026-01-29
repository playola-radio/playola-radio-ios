# Testing Patterns

## Analytics Event Testing

### Basic Pattern

Use `LockIsolated` for thread-safe event capture:

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

let events = capturedEvents.value
XCTAssertEqual(events.count, 1)
```

### Testing Code That Spawns Internal Tasks

When the code under test spawns its own `Task { }` (like `showFeedbackSheet()`), use `withMainSerialExecutor` + `Task.yield()`:

```swift
func testSomethingThatSpawnsTask() async {
  await withMainSerialExecutor {
    let capturedEvents = LockIsolated<[AnalyticsEvent]>([])

    let model = withDependencies {
      $0.analytics.track = { @Sendable event in
        capturedEvents.withValue { $0.append(event) }
      }
    } operation: {
      SomeModel()
    }

    model.actionThatSpawnsTask()

    // Let spawned Task run
    await Task.yield()

    // Assert immediately - no sleep needed
    XCTAssertTrue(capturedEvents.value.contains { $0 == .expectedEvent })
  }
}
```

**Why this works:**
- `withMainSerialExecutor` forces all async work onto a single executor
- `Task.yield()` gives spawned Tasks a chance to run
- No arbitrary sleep durations - deterministic execution

### What NOT to Do

**Never use `Task.sleep` in tests:**

```swift
// BAD - flaky and slow
await model.someAction()
try? await Task.sleep(for: .milliseconds(100))
XCTAssertTrue(capturedEvents.value.contains { ... })
```

**Why it's bad:**
- Arbitrary timing makes tests slow
- Can still be flaky if sleep isn't long enough
- No guarantee the work completed

### Asserting Event Properties

Use pattern matching for events with associated values:

```swift
let events = capturedEvents.value
if case .startedStation(let stationInfo, let entryPoint) = events.first {
  XCTAssertEqual(stationInfo.id, expectedId)
  XCTAssertEqual(entryPoint, "home_recommendations")
} else {
  XCTFail("Expected startedStation event, got: \(String(describing: events.first))")
}
```

For checking presence without caring about values:

```swift
XCTAssertTrue(
  capturedEvents.value.contains {
    if case .feedbackSheetFailed = $0 { return true }
    return false
  },
  "Should track feedbackSheetFailed event"
)
```

### Thread Safety

Always use:
- `LockIsolated<[AnalyticsEvent]>` for event capture
- `@Sendable` closures in dependency injection
- `.withValue { $0.append(event) }` for thread-safe append

## General Testing Rules

1. **Never use `Task.sleep` in tests** - it makes tests slow and flaky
2. **Use synchronous assertions** or test doubles that execute synchronously
3. **Tests are colocated with code** - `SomeModel.swift` → `SomeTests.swift` in same folder
4. **Test naming**: camelCase without underscores (e.g., `testOnRecordTappedRequestsPermission`)
5. **All test classes use `@MainActor`**
