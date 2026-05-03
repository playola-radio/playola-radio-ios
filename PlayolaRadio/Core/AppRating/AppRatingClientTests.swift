//
//  AppRatingClientTests.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

// swiftlint:disable redundant_optional_initialization

@MainActor
struct AppRatingClientTests {

  // MARK: - shouldShowRatingPrompt Tests

  @Test
  func testShouldShowRatingPromptReturnsFalseWhenListenTimeTooShort() {
    @Shared(.appInstallDate) var appInstallDate: Date? = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue
    let thirtyMinutesMS = 30 * 60 * 1000

    #expect(!client.shouldShowRatingPrompt(thirtyMinutesMS))
  }

  @Test
  func testShouldShowRatingPromptReturnsFalseWhenInstallTooRecent() {
    @Shared(.appInstallDate) var appInstallDate: Date? = Calendar.current.date(
      byAdding: .day, value: -3, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    #expect(!client.shouldShowRatingPrompt(twoHoursMS))
  }

  @Test
  func testShouldShowRatingPromptReturnsFalseWhenNoInstallDate() {
    @Shared(.appInstallDate) var appInstallDate: Date? = nil
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    #expect(!client.shouldShowRatingPrompt(twoHoursMS))
  }

  @Test
  func testShouldShowRatingPromptReturnsFalseWhenAlreadyShownThisVersion() {
    @Shared(.appInstallDate) var appInstallDate: Date? = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? =
      Bundle.main.releaseVersionNumber
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    #expect(!client.shouldShowRatingPrompt(twoHoursMS))
  }

  @Test
  func testShouldShowRatingPromptReturnsFalseWhenDismissedRecently() {
    @Shared(.appInstallDate) var appInstallDate: Date? = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? =
      Calendar.current.date(byAdding: .day, value: -3, to: Date())

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    #expect(!client.shouldShowRatingPrompt(twoHoursMS))
  }

  @Test
  func testShouldShowRatingPromptReturnsTrueWhenAllConditionsMet() {
    @Shared(.appInstallDate) var appInstallDate: Date? = Calendar.current.date(
      byAdding: .day, value: -10, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    #expect(client.shouldShowRatingPrompt(twoHoursMS))
  }

  @Test
  func testShouldShowRatingPromptReturnsTrueWhenDismissedOver7DaysAgo() {
    @Shared(.appInstallDate) var appInstallDate: Date? = Calendar.current.date(
      byAdding: .day, value: -20, to: Date()
    )
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? =
      Calendar.current.date(byAdding: .day, value: -10, to: Date())

    let client = AppRatingClient.liveValue
    let twoHoursMS = 2 * 60 * 60 * 1000

    #expect(client.shouldShowRatingPrompt(twoHoursMS))
  }

  // MARK: - recordInstallDateIfNeeded Tests

  @Test
  func testRecordInstallDateOnlyRecordsOnce() {
    @Shared(.appInstallDate) var appInstallDate: Date? = nil
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue

    #expect(appInstallDate == nil)

    client.recordInstallDateIfNeeded()
    let firstDate = appInstallDate
    #expect(firstDate != nil)

    // Wait a tiny bit and try again
    client.recordInstallDateIfNeeded()
    #expect(appInstallDate == firstDate)
  }

  // MARK: - markRatingPromptShown Tests

  @Test
  func testMarkRatingPromptShownSetsVersionAndClearsDismissDate() {
    @Shared(.appInstallDate) var appInstallDate: Date? = nil
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = Date()

    let client = AppRatingClient.liveValue
    client.markRatingPromptShown()

    #expect(lastRatingPromptVersion == Bundle.main.releaseVersionNumber)
    #expect(lastRatingPromptDismissDate == nil)
  }

  // MARK: - markRatingPromptDismissed Tests

  @Test
  func testMarkRatingPromptDismissedSetsDate() {
    @Shared(.appInstallDate) var appInstallDate: Date? = nil
    @Shared(.lastRatingPromptVersion) var lastRatingPromptVersion: String? = nil
    @Shared(.lastRatingPromptDismissDate) var lastRatingPromptDismissDate: Date? = nil

    let client = AppRatingClient.liveValue

    #expect(lastRatingPromptDismissDate == nil)

    client.markRatingPromptDismissed()

    #expect(lastRatingPromptDismissDate != nil)
  }
}

// swiftlint:enable redundant_optional_initialization
