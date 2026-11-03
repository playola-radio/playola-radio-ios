//
//  RecordingOrientationControllerTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct RecordingOrientationControllerTests {
  let first = UUID(0)
  let second = UUID(1)

  @Test
  func testAcquireRotatesBeforeEnablingKeyboardAndBanner() async {
    let events = LockIsolated<[String]>([])
    let controller = makeController(events: events)

    let acquired = await controller.acquire(first)

    #expect(acquired)
    expectNoDifference(events.value, ["rotate true", "keyboard true", "banner true"])
  }

  @Test
  func testReleaseByOwnerDisablesKeyboardAndBannerBeforeRotatingBack() async {
    let events = LockIsolated<[String]>([])
    let controller = makeController(events: events)
    _ = await controller.acquire(first)
    events.setValue([])

    await controller.release(first)

    expectNoDifference(events.value, ["keyboard false", "banner false", "rotate false"])
    #expect(!controller.isOwner(first))
  }

  @Test
  func testStaleReleaseDoesNotUndoANewerOwner() async {
    let events = LockIsolated<[String]>([])
    let controller = makeController(events: events)
    _ = await controller.acquire(first)
    _ = await controller.acquire(second)
    events.setValue([])

    await controller.release(first)

    expectNoDifference(events.value, [])
    #expect(controller.isOwner(second))
  }

  @Test
  func testForceResetDuringAcquireLeavesKeyboardAndBannerOff() async {
    await withMainSerialExecutor {
      let events = LockIsolated<[String]>([])
      let (gate, openGate) = AsyncStream<Void>.makeStream()
      let controller = makeController(events: events) { isUpsideDown in
        guard isUpsideDown else { return true }
        for await _ in gate { break }
        return true
      }

      let acquire = Task { await controller.acquire(first) }
      await Task.megaYield()
      await controller.forceReset()
      openGate.yield()
      let acquired = await acquire.value

      #expect(!acquired)
      #expect(!controller.isOwner(first))
      expectNoDifference(
        events.value, ["rotate true", "keyboard false", "banner false", "rotate false"])
    }
  }

  @Test
  func testAcquireFailsWhenTheWindowDoesNotRotate() async {
    let events = LockIsolated<[String]>([])
    let controller = makeController(events: events) { _ in false }

    let acquired = await controller.acquire(first)

    #expect(!acquired)
    #expect(!controller.isOwner(first))
    expectNoDifference(events.value, ["rotate true"])
  }

  private func makeController(
    events: LockIsolated<[String]>,
    onRotate: @escaping @MainActor @Sendable (Bool) async -> Bool = { _ in true }
  ) -> RecordingOrientationController {
    withDependencies {
      $0.windowOrientation.setUpsideDown = { isUpsideDown in
        events.withValue { $0.append("rotate \(isUpsideDown)") }
        return await onRotate(isUpsideDown)
      }
      $0.upsideDownKeyboard.setUpsideDownModeEnabled = { isEnabled in
        events.withValue { $0.append("keyboard \(isEnabled)") }
      }
      $0.upsideDownNotificationBanner.setUpsideDownModeEnabled = { isEnabled in
        events.withValue { $0.append("banner \(isEnabled)") }
      }
    } operation: {
      RecordingOrientationController()
    }
  }
}
