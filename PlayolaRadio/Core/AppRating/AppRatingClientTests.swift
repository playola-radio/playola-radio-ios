//
//  AppRatingClientTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class AppRatingClientTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Reset shared state before each test
    @Shared(.appInstallDate) var appInstallDate: Date?
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date?

    $appInstallDate.withLock { $0 = nil }
    $lastRatingPromptVersion.withLock { $0 = nil }
    $lastRatingPromptDismissDate.withLock { $0 = nil }
  }

  // MARK: - shouldShowRatingPrompt Tests

  func testShouldShowRatingPromptReturnsFalseWhenListenTimeTooShort() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )

    let client = AppRatingClient.liveValue
    let thirtyMinutesMS = 30 * 60 * 1000

    XCTAssertFalse(client.shouldShowRatingPrompt(thirtyMinutesMS))
  }

  func testShouldShowRatingPromptReturnsFalseWhenInstallTooRecent() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -3, to: Date()
    )

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    XCTAssertFalse(client.shouldShowRatingPrompt(twoHoursMS))
  }

  func testShouldShowRatingPromptReturnsFalseWhenNoInstallDate() {
    @Shared(.appInstallDate) var appInstallDate: Date?

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    XCTAssertFalse(client.shouldShowRatingPrompt(twoHoursMS))
  }

  func testShouldShowRatingPromptReturnsFalseWhenAlreadyShownThisVersion() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion =
      Bundle.main.releaseVersionNumber

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    XCTAssertFalse(client.shouldShowRatingPrompt(twoHoursMS))
  }

  func testShouldShowRatingPromptReturnsFalseWhenDismissedRecently() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate = Calendar.current.date(
      byAdding: .day, value: -3, to: Date()
    )

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    XCTAssertFalse(client.shouldShowRatingPrompt(twoHoursMS))
  }

  func testShouldShowRatingPromptReturnsTrueWhenAllConditionsMet() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    XCTAssertTrue(client.shouldShowRatingPrompt(twoHoursMS))
  }

  func testShouldShowRatingPromptReturnsTrueWhenDismissedOver7DaysAgo() {
    @Shared(.appInstallDate) var appInstallDate = Calendar.current.date(
      byAdding: .day, value: -20, to: Date()
    )
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    XCTAssertTrue(client.shouldShowRatingPrompt(twoHoursMS))
  }

  // MARK: - recordInstallDateIfNeeded Tests

  func testRecordInstallDateOnlyRecordsOnce() {
    @Shared(.appInstallDate) var appInstallDate: Date?

    let client = AppRatingClient.liveValue

    XCTAssertNil(appInstallDate)

    client.recordInstallDateIfNeeded()
    let firstDate = appInstallDate
    XCTAssertNotNil(firstDate)

    // Wait a tiny bit and try again
    client.recordInstallDateIfNeeded()
    XCTAssertEqual(appInstallDate, firstDate)
  }

  // MARK: - markRatingPromptShown Tests

  func testMarkRatingPromptShownSetsVersionAndClearsDismissDate() {
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String?
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate = Date()

    let client = AppRatingClient.liveValue
    client.markRatingPromptShown()

    XCTAssertEqual(lastRatingPromptVersion, Bundle.main.releaseVersionNumber)
    XCTAssertNil(lastRatingPromptDismissDate)
  }

  // MARK: - markRatingPromptDismissed Tests

  func testMarkRatingPromptDismissedSetsDate() {
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date?

    let client = AppRatingClient.liveValue

    XCTAssertNil(lastRatingPromptDismissDate)

    client.markRatingPromptDismissed()

    XCTAssertNotNil(lastRatingPromptDismissDate)
  }
}
