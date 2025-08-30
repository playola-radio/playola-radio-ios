//
//  ToastClientTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import XCTest

@testable import PlayolaRadio

@MainActor
final class ToastClientTests: XCTestCase {

  // MARK: - Basic Show/Dismiss

  func testShow_SetsCurrentToast() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast = PlayolaToast(
        message: "Test message",
        buttonTitle: "OK"
      )

      let client = ToastClient.liveValue

      await client.show(toast)

      let currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Test message")
      XCTAssertEqual(currentToast?.buttonTitle, "OK")
    }
  }

  func testDismiss_ClearsCurrentToast() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast = PlayolaToast(
        message: "Test message",
        buttonTitle: "OK"
      )

      let client = ToastClient.liveValue

      await client.show(toast)
      let currentToast = await client.currentToast()
      XCTAssertNotNil(currentToast)

      await client.dismiss()

      let dismissedToast = await client.currentToast()
      XCTAssertNil(dismissedToast)
    }
  }

  // MARK: - Queue Management

  func testShow_QueuesMultipleToasts() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast1 = PlayolaToast(
        message: "First toast",
        buttonTitle: "OK"
      )
      let toast2 = PlayolaToast(
        message: "Second toast",
        buttonTitle: "OK"
      )

      let client = ToastClient.liveValue

      await client.show(toast1)
      await client.show(toast2)

      let currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "First toast")

      await client.dismiss()

      let nextToast = await client.currentToast()
      XCTAssertEqual(nextToast?.message, "Second toast")
    }
  }

  func testQueue_ShowsToastsInOrder() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast1 = PlayolaToast(message: "First", buttonTitle: "OK")
      let toast2 = PlayolaToast(message: "Second", buttonTitle: "OK")
      let toast3 = PlayolaToast(message: "Third", buttonTitle: "OK")

      let client = ToastClient.liveValue

      await client.show(toast1)
      await client.show(toast2)
      await client.show(toast3)

      var currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "First")

      await client.dismiss()
      currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Second")

      await client.dismiss()
      currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Third")

      await client.dismiss()
      currentToast = await client.currentToast()
      XCTAssertNil(currentToast)
    }
  }

  // MARK: - Auto-dismiss

  func testAutoDismiss_AfterSpecifiedDuration() async {
    let clock = TestClock()

    await withDependencies {
      $0.continuousClock = clock
    } operation: {
      let toast = PlayolaToast(
        message: "Test message",
        buttonTitle: "OK",
        duration: 2.0
      )

      let client = ToastClient.liveValue

      await client.show(toast)

      var currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Test message")

      await clock.advance(by: .seconds(1.0))
      currentToast = await client.currentToast()
      XCTAssertNotNil(currentToast)

      await clock.advance(by: .seconds(1.5))
      currentToast = await client.currentToast()
      XCTAssertNil(currentToast)
    }
  }

  func testAutoDismiss_ShowsNextToastInQueue() async {
    let clock = TestClock()

    await withDependencies {
      $0.continuousClock = clock
    } operation: {
      let toast1 = PlayolaToast(
        message: "First toast",
        buttonTitle: "OK",
        duration: 1.0
      )
      let toast2 = PlayolaToast(
        message: "Second toast",
        buttonTitle: "OK",
        duration: 2.0
      )

      let client = ToastClient.liveValue

      await client.show(toast1)
      await client.show(toast2)

      var currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "First toast")

      await clock.advance(by: .seconds(1.5))

      currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Second toast")
    }
  }

  // MARK: - Manual Dismiss

  func testManualDismiss_CancelsAutoDismissTimer() async {
    let clock = TestClock()

    await withDependencies {
      $0.continuousClock = clock
    } operation: {
      let toast = PlayolaToast(
        message: "Test toast",
        buttonTitle: "OK",
        duration: 3.0
      )

      let client = ToastClient.liveValue

      await client.show(toast)

      var currentToast = await client.currentToast()
      XCTAssertNotNil(currentToast)

      await client.dismiss()

      currentToast = await client.currentToast()
      XCTAssertNil(currentToast)

      // Ensure timer was cancelled - toast shouldn't resurrect
      await clock.advance(by: .seconds(5.0))
      currentToast = await client.currentToast()
      XCTAssertNil(currentToast)
    }
  }

  func testManualDismiss_ShowsNextToastInQueue() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast1 = PlayolaToast(
        message: "First toast",
        buttonTitle: "OK",
        duration: 5.0  // Long duration to ensure we dismiss manually
      )
      let toast2 = PlayolaToast(
        message: "Second toast",
        buttonTitle: "OK"
      )

      let client = ToastClient.liveValue

      await client.show(toast1)
      await client.show(toast2)

      var currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "First toast")

      await client.dismiss()

      currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Second toast")
    }
  }

  // MARK: - Concurrent Access

  func testConcurrentShow_SafelyQueuesAllToasts() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast1 = PlayolaToast(message: "Toast 1", buttonTitle: "OK")
      let toast2 = PlayolaToast(message: "Toast 2", buttonTitle: "OK")
      let toast3 = PlayolaToast(message: "Toast 3", buttonTitle: "OK")

      let client = ToastClient.liveValue

      async let show1 = client.show(toast1)
      async let show2 = client.show(toast2)
      async let show3 = client.show(toast3)

      await show1
      await show2
      await show3

      let currentToast = await client.currentToast()
      XCTAssertNotNil(currentToast)
      XCTAssertTrue(
        ["Toast 1", "Toast 2", "Toast 3"].contains(currentToast?.message)
      )

      await client.dismiss()
      let secondToast = await client.currentToast()
      XCTAssertNotNil(secondToast)

      await client.dismiss()
      let thirdToast = await client.currentToast()
      XCTAssertNotNil(thirdToast)

      await client.dismiss()
      let finalToast = await client.currentToast()
      XCTAssertNil(finalToast)
    }
  }

  // MARK: - Toast Actions

  func testToastAction_ExecutesWhenInvoked() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      var actionExecuted = false

      let toast = PlayolaToast(
        message: "Test",
        buttonTitle: "OK",
        action: {
          actionExecuted = true
        }
      )

      toast.action?()

      XCTAssertTrue(actionExecuted)
    }
  }

  // MARK: - Edge Cases

  func testDismiss_WhenNoCurrentToast_DoesNothing() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let client = ToastClient.liveValue

      await client.dismiss()

      let currentToast = await client.currentToast()
      XCTAssertNil(currentToast)
    }
  }

  func testShow_WithZeroDuration_StillShowsToast() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast = PlayolaToast(
        message: "Zero duration",
        buttonTitle: "OK",
        duration: 0.0
      )

      let client = ToastClient.liveValue

      await client.show(toast)

      let currentToast = await client.currentToast()
      XCTAssertEqual(currentToast?.message, "Zero duration")
    }
  }
}
