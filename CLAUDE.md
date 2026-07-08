# Playola Radio iOS

## Branch Policy

**`develop` must always be in a deployable state.** Both as a matter of policy and so we can ship from it at any time in an emergency. Never merge work into `develop` that doesn't compile, has failing tests, or leaves the app in a broken/half-finished runtime state. If a change can't be made deployable in one PR, keep it on a feature branch until it is (see the gating rule below — do NOT reach for an environment gate).

## NEVER NEVER NEVER gate a feature to an environment

**Do not gate any user-facing feature so that it behaves differently in production than in staging/development.** Absolutely never write code of the form `Config.shared.environment != .production` (or any equivalent) to turn a feature on in staging while leaving it dark in production.

**Why this rule exists.** We shipped a live prize contest to production while the giveaway data path was gated OFF in production (`isLiveDataEnabled = environment != .production`). Staging looked perfect; production was silently dark. Real listeners ran a real contest and the app did nothing. That is a production disaster with no runtime error to catch it — the gate made "broken in production" the *intended* behavior.

**What to do instead:**
- If a feature is ready, it ships on. No environment check.
- If a feature is NOT ready, keep it on a feature branch, or behind a build-time `#if DEBUG` guard for dev-only tooling — never behind a runtime environment check that a production build evaluates to "off".
- If you truly need staged rollout, use a *server-driven* flag that is explicitly turned on for production when the feature launches — and make turning it on part of the launch checklist. The default must never be "production is the disabled environment."
- Production must never be the environment where a feature is the most disabled.

## ALWAYS use the Point-Free Workflow (pfw-*) skills

This project is built on Point-Free libraries (`swift-dependencies`, `swift-sharing`, `swift-identified-collections`, `swift-custom-dump`, etc.). Before writing or planning Swift code in this repo, invoke every `pfw-*` skill that applies to the task. This is **mandatory**, not optional.

Rough mapping:
- Writing or editing `APIClient` / any `@DependencyClient` / anything using `@Dependency` → `pfw-dependencies`
- Writing or editing an `@Observable` model (any `*Model.swift` in `Views/Pages/`) → `pfw-observable-models`
- Writing tests (especially mutation/action tests) → `pfw-testing` AND `pfw-custom-dump` (use `expectDifference` / `expectNoDifference`, not raw `#expect(a == b)` for value comparisons)
- Adding or editing `@Shared` keys / state → `pfw-sharing`
- Working with `IdentifiedArrayOf<…>` → `pfw-identified-collections`
- Asserting on enum cases with associated values → `pfw-case-paths`
- SwiftUI views (bindings, `@State` init, modern patterns) → `pfw-modern-swiftui`
- Error reporting (`reportIssue`, `withErrorReporting`) → `pfw-issue-reporting`
- Snapshot testing → `pfw-snapshot-testing`

If you are dispatching subagents (via `superpowers:subagent-driven-development` or similar), instruct each subagent to invoke the relevant pfw skills before writing code, and reference them in their checklist.

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
- **Framework**: swift-testing (`@Test` / `@Suite` / `#expect`) with `@MainActor` on model/view-model suites

### Testing with @Shared state

Every test suite MUST carry the `.freshSharedState` trait so each test runs in a fresh, empty
dependency scope (see `PlayolaRadioTests/SharedStateTestTrait.swift`). Declare `@Shared` locally
inside each test method with an initial value:

```swift
@Suite(.freshSharedState)
@MainActor
struct SomeTests {
  @Test func something() {
    @Shared(.stationLists) var stationLists = makeTestStationLists()
    @Shared(.showSecretStations) var showSecretStations = false

    let model = SomeModel()
    // test...
  }
}
```

**New test files:** add `@Suite(.freshSharedState)` above the suite struct (merge with other
traits, e.g. `@Suite(.serialized, .freshSharedState)`). A suite without it can read `@Shared`
state leaked from another test.

**Why the trait is required.** `@Shared(.key) var x = value` sets a *default* that is used only
when the key has no already-loaded value — it is NOT a write. Persisted keys (`.fileStorage`,
`.appStorage`) resolve their backing store from a process-global dependency cache. That cache is
partitioned by the current Swift Testing test id, so a test's *own* task normally gets its own
store — but that isolation is fragile: async work that runs outside the test's task context
(overlapping/leaked `Task`s from another test under parallel execution, or `Task.detached`, which
drops the test context) resolves against the shared partition. An earlier test's write can then
survive into a later test, whose `= value` seed is silently ignored — the order-dependent,
parallel-only stale reads we used to see (e.g. `participations["e1"]` reading `nil` only when run
alongside other suites). `.freshSharedState` binds a fresh empty store as a task-local for the whole
test (inherited by child `Task {}` work), so the `= value` seed is authoritative. In-memory-only
keys are isolated too. (It does not cover `Task.detached` or state initialized outside the test
body.)

Because the store starts empty, you normally don't need `$shared.withLock` just to set up initial
state — the `= value` default is enough. Reach for `$shared.withLock { $0 = ... }` when you need to
drive a *change* mid-test (after the model is observing), or to force a real write for a value type
you then read back across an `await`. Do NOT use class-level `@Shared` properties in tests
(a stored property initialized outside the test body is not covered by the trait's scope).

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
