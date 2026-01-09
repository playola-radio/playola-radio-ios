//
//  RRuleFormatterTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import XCTest

@testable import PlayolaRadio

@MainActor
final class RRuleFormatterTests: XCTestCase {
  // MARK: - Single Day Tests

  func testFormatsWeeklyMondayAt4pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Mondays at 4pm")
  }

  func testFormatsWeeklyTuesdayAt9am() {
    let rrule = "FREQ=WEEKLY;BYDAY=TU"
    let airtime = dateAt(hour: 9, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Tuesdays at 9am")
  }

  func testFormatsWeeklyWednesdayAt830pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=WE"
    let airtime = dateAt(hour: 20, minute: 30)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Wednesdays at 8:30pm")
  }

  func testFormatsWeeklyThursdayAtNoon() {
    let rrule = "FREQ=WEEKLY;BYDAY=TH"
    let airtime = dateAt(hour: 12, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Thursdays at 12pm")
  }

  func testFormatsWeeklyFridayAt6pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=FR"
    let airtime = dateAt(hour: 18, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Fridays at 6pm")
  }

  func testFormatsWeeklySaturdayAt10am() {
    let rrule = "FREQ=WEEKLY;BYDAY=SA"
    let airtime = dateAt(hour: 10, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Saturdays at 10am")
  }

  func testFormatsWeeklySundayAt7pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=SU"
    let airtime = dateAt(hour: 19, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Sundays at 7pm")
  }

  // MARK: - Multiple Days Tests

  func testFormatsTwoDays() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,WE"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Mondays and Wednesdays at 4pm")
  }

  func testFormatsThreeDays() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Mondays, Wednesdays, and Fridays at 4pm")
  }

  func testFormatsWeekdays() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
    let airtime = dateAt(hour: 8, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Weekdays at 8am")
  }

  func testFormatsWeekends() {
    let rrule = "FREQ=WEEKLY;BYDAY=SA,SU"
    let airtime = dateAt(hour: 10, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Weekends at 10am")
  }

  func testFormatsEveryDay() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"
    let airtime = dateAt(hour: 20, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Every day at 8pm")
  }

  // MARK: - Daily Frequency Tests

  func testFormatsDailyFrequency() {
    let rrule = "FREQ=DAILY"
    let airtime = dateAt(hour: 14, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Every day at 2pm")
  }

  // MARK: - Edge Cases

  func testReturnsNilForInvalidRRule() {
    let rrule = "INVALID_RRULE"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertNil(result)
  }

  func testReturnsNilForEmptyRRule() {
    let rrule = ""
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertNil(result)
  }

  func testReturnsNilForNilRRule() {
    let result = RRuleFormatter.formatToPlainEnglish(rrule: nil, airtime: Date())

    XCTAssertNil(result)
  }

  func testHandlesDaysInDifferentOrder() {
    let rrule = "FREQ=WEEKLY;BYDAY=FR,MO,WE"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Mondays, Wednesdays, and Fridays at 4pm")
  }

  func testHandlesLowercaseDays() {
    let rrule = "FREQ=WEEKLY;BYDAY=mo,we,fr"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    XCTAssertEqual(result, "Mondays, Wednesdays, and Fridays at 4pm")
  }

  // MARK: - Helpers

  private func dateAt(hour: Int, minute: Int) -> Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 1
    components.day = 8
    components.hour = hour
    components.minute = minute
    return Calendar.current.date(from: components)!
  }
}
