//
//  SharedStateTestTrait.swift
//  PlayolaRadioTests
//
//  Gives every test a fresh, empty dependency scope so `@Shared` state cannot leak between tests.
//

import Dependencies
import Testing

/// A swift-testing trait that isolates each test's `@Shared` state by running the test (and any
/// child `Task {}` work it spawns) in a fresh, empty dependency scope.
///
/// Why this exists: `@Shared(.key) var x = value` sets a *default* that is used only when the key
/// has no already-loaded value — it is not a write. Persisted keys (`.fileStorage`, `.appStorage`)
/// resolve their backing store from the `defaultFileStorage` / `defaultAppStorage` /
/// `defaultInMemoryStorage` dependencies, which swift-dependencies caches in a process-global
/// `DependencyValues`. That cache is partitioned by the current Swift Testing test id, so a test's
/// *own* task normally gets its own store — but that isolation is fragile: async work that runs
/// outside the test's task context (overlapping / leaked `Task`s from another test under parallel
/// execution, and `Task.detached`, which drops the test context entirely) resolves against the
/// shared partition. An earlier test's write can then survive into a later test, whose `= value`
/// seed is silently ignored — the observed order-dependent, parallel-only stale reads.
///
/// This reproduces the behavior of DependenciesTestSupport's `.dependencies` trait (which the test
/// target does not link): each test runs inside `withDependencies { $0 = DependencyValues() }`, so
/// it gets fresh, empty in-memory file/app storage and a fresh `@Shared` reference cache, bound as a
/// task-local for the whole test. Child `Task {}` work inherits it, so the isolation no longer
/// depends on the fragile per-test-id cache partition. (It does not extend to `Task.detached` or to
/// state initialized outside the test body.) Because `isRecursive` is `true`, a suite-level trait
/// scopes each test individually, so parallel tests in the same suite are still isolated. The
/// `isRoot` guard mirrors the library: only the outermost application resets the scope, so nested
/// suites don't wipe an enclosing scope's overrides.
struct FreshSharedStateTrait: TestTrait, SuiteTrait, TestScoping {
  @TaskLocal static var isRoot = true

  var isRecursive: Bool { true }

  func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    try await withDependencies {
      if Self.isRoot {
        $0 = DependencyValues()
      }
    } operation: {
      try await Self.$isRoot.withValue(false) {
        try await function()
      }
    }
  }
}

extension Trait where Self == FreshSharedStateTrait {
  /// Isolates a suite's (or test's) `@Shared` state from every other test by running each test in a
  /// fresh, empty dependency scope. Apply to every test suite via `@Suite(.freshSharedState)`.
  static var freshSharedState: FreshSharedStateTrait { FreshSharedStateTrait() }
}
