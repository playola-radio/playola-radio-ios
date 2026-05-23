//
//  ToastClientTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Testing

@testable import PlayolaRadio

@MainActor
struct ToastClientTests {

  // MARK: - Basic Show/Dismiss

  @Test
  func testShowSetsCurrentToast() async {
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
      #expect(currentToast?.message == "Test message")
      #expect(currentToast?.buttonTitle == "OK")
    }
  }

  @Test
  func testDismissClearsCurrentToast() async {
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
      #expect(currentToast != nil)

      await client.dismiss()

      let dismissedToast = await client.currentToast()
      #expect(dismissedToast == nil)
    }
  }

  // MARK: - Queue Management

  @Test
  func testShowQueuesMultipleToasts() async {
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
      #expect(currentToast?.message == "First toast")

      await client.dismiss()

      let nextToast = await client.currentToast()
      #expect(nextToast?.message == "Second toast")
    }
  }

  @Test
  func testQueueShowsToastsInOrder() async {
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
      #expect(currentToast?.message == "First")

      await client.dismiss()
      currentToast = await client.currentToast()
      #expect(currentToast?.message == "Second")

      await client.dismiss()
      currentToast = await client.currentToast()
      #expect(currentToast?.message == "Third")

      await client.dismiss()
      currentToast = await client.currentToast()
      #expect(currentToast == nil)
    }
  }

  // MARK: - Auto-dismiss

  @Test
  func testAutoDismissAfterSpecifiedDuration() async {
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
      #expect(currentToast?.message == "Test message")

      await clock.advance(by: .seconds(1.0))
      currentToast = await client.currentToast()
      #expect(currentToast != nil)

      await clock.advance(by: .seconds(1.5))
      currentToast = await client.currentToast()
      #expect(currentToast == nil)
    }
  }

  @Test
  func testAutoDismissShowsNextToastInQueue() async {
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
      #expect(currentToast?.message == "First toast")

      await clock.advance(by: .seconds(1.5))

      currentToast = await client.currentToast()
      #expect(currentToast?.message == "Second toast")
    }
  }

  // MARK: - Manual Dismiss

  @Test
  func testManualDismissCancelsAutoDismissTimer() async {
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
      #expect(currentToast != nil)

      await client.dismiss()

      currentToast = await client.currentToast()
      #expect(currentToast == nil)

      // Ensure timer was cancelled - toast shouldn't resurrect
      await clock.advance(by: .seconds(5.0))
      currentToast = await client.currentToast()
      #expect(currentToast == nil)
    }
  }

  @Test
  func testManualDismissShowsNextToastInQueue() async {
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
      #expect(currentToast?.message == "First toast")

      await client.dismiss()

      currentToast = await client.currentToast()
      #expect(currentToast?.message == "Second toast")
    }
  }

  // MARK: - Concurrent Access

  @Test
  func testConcurrentShowSafelyQueuesAllToasts() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let toast1 = PlayolaToast(message: "Toast 1", buttonTitle: "OK")
      let toast2 = PlayolaToast(message: "Toast 2", buttonTitle: "OK")
      let toast3 = PlayolaToast(message: "Toast 3", buttonTitle: "OK")

      let client = ToastClient.liveValue

      async let show1: Void = client.show(toast1)
      async let show2: Void = client.show(toast2)
      async let show3: Void = client.show(toast3)

      await show1
      await show2
      await show3

      let currentToast = await client.currentToast()
      #expect(currentToast != nil)
      #expect(["Toast 1", "Toast 2", "Toast 3"].contains(currentToast?.message))

      await client.dismiss()
      let secondToast = await client.currentToast()
      #expect(secondToast != nil)

      await client.dismiss()
      let thirdToast = await client.currentToast()
      #expect(thirdToast != nil)

      await client.dismiss()
      let finalToast = await client.currentToast()
      #expect(finalToast == nil)
    }
  }

  // MARK: - Toast Actions

  @Test
  func testToastActionExecutesWhenInvoked() {
    withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let actionExecuted = LockIsolated(false)

      let toast = PlayolaToast(
        message: "Test",
        buttonTitle: "OK",
        action: {
          actionExecuted.setValue(true)
        }
      )

      toast.action?()

      #expect(actionExecuted.value)
    }
  }

  // MARK: - Edge Cases

  @Test
  func testDismissWhenNoCurrentToastDoesNothing() async {
    await withDependencies {
      $0.continuousClock = TestClock()
    } operation: {
      let client = ToastClient.liveValue

      await client.dismiss()

      let currentToast = await client.currentToast()
      #expect(currentToast == nil)
    }
  }

  @Test
  func testShowWithZeroDurationStillShowsToast() async {
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
      #expect(currentToast?.message == "Zero duration")
    }
  }
}
