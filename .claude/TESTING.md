# Testing Patterns

## General Rules

1. **Never use `Task.sleep` in tests** - makes tests slow and flaky
2. **Prefer computed properties** for model state derived from `@Shared` - enables synchronous testing
3. **Use `.mockWith()` factories** for test data (see `HomePageTests.swift` for examples)
4. **Tests colocated with code** - `SomeModel.swift` → `SomeTests.swift` in same folder
5. **Test naming**: camelCase without underscores (e.g., `testRecordButtonTappedRequestsPermission`)
6. **All test classes use `@MainActor`**

## @Shared State in Tests

### The harness: `.freshSharedState` on every suite

Every test suite MUST carry the `.freshSharedState` trait (defined in
`PlayolaRadioTests/SharedStateTestTrait.swift`). It runs each test in a fresh, empty dependency
scope, so persisted (`.fileStorage` / `.appStorage`) and in-memory `@Shared` keys start empty and
are isolated from every other test — including tests running in parallel.

```swift
@Suite(.freshSharedState)
@MainActor
struct HomePageTests {
  @Test func toggleUpdatesStations() async {
    @Shared(.showSecretStations) var showSecretStations = false
    let model = HomePageModel()

    #expect(model.forYouStations.count == 1)

    $showSecretStations.withLock { $0 = true }   // drive a mid-test change
    #expect(model.forYouStations.count == 2)     // No sleep needed!
  }
}
```

With the trait, the `= value` seed is authoritative — you do **not** need `withLock` just to
establish initial state, and you do **not** need `withMainSerialExecutor` for isolation.

### Why the trait is required: @Shared initialization is a DEFAULT, not a write

`@Shared(.auth) var auth = Auth(jwt: "test-jwt")` sets a **default** used only when the key has no
already-loaded value — it does NOT write to the store. Persisted keys resolve their backing store
from the `defaultFileStorage` / `defaultAppStorage` / `defaultInMemoryStorage` dependencies, which
swift-dependencies caches in a **process-global** `DependencyValues`. That cache is partitioned by
the current Swift Testing test id, so a test's *own* task normally gets its own store — but the
isolation is fragile: async work running outside the test's task context (overlapping/leaked `Task`s
from another test under parallel execution, or `Task.detached`, which drops the test context)
resolves against the shared partition. So without the trait, an earlier test's write to a persisted
key can survive into a later test, whose `= value` seed is then silently ignored — stale reads,
order-dependent, flaky under parallel execution (e.g. `participations["e1"]` reads `nil` only when
run alongside other suites).

`.freshSharedState` fixes this at the harness level by binding each test its own empty stores and a
fresh `@Shared` reference cache as a task-local for the whole test (inherited by child `Task {}`
work; it does not cover `Task.detached` or state built outside the test body). It reproduces
DependenciesTestSupport's `.dependencies` trait (which this test target does not link) in ~20 lines.

### When you still reach for `withLock` / `withMainSerialExecutor`

The trait makes these unnecessary for *isolation*, but they remain valid tools:

- `$shared.withLock { $0 = ... }` — to drive a **mid-test change** after the model is observing, or
  to force a real write for a value you then read back across an `await`.
- `withMainSerialExecutor { ... }` — to deterministically order a model's **internal** fire-and-forget
  `Task { }` work (see "Code That Spawns Internal Tasks" below). This is about task scheduling, not
  `@Shared` isolation, so those uses are NOT redundant with the trait.

Do **not** use class-level `@Shared` stored properties in tests: a property initialized outside the
test method body runs outside the trait's per-test scope and will not be isolated.

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
