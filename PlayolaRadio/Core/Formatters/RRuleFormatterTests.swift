//
//  RRuleFormatterTests.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Foundation
import Testing

@testable import PlayolaRadio

@MainActor
struct RRuleFormatterTests {
  // MARK: - Single Day Tests

  @Test
  func testFormatsWeeklyMondayAt4pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Mondays at 4pm")
  }

  @Test
  func testFormatsWeeklyTuesdayAt9am() {
    let rrule = "FREQ=WEEKLY;BYDAY=TU"
    let airtime = dateAt(hour: 9, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Tuesdays at 9am")
  }

  @Test
  func testFormatsWeeklyWednesdayAt830pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=WE"
    let airtime = dateAt(hour: 20, minute: 30)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Wednesdays at 8:30pm")
  }

  @Test
  func testFormatsWeeklyThursdayAtNoon() {
    let rrule = "FREQ=WEEKLY;BYDAY=TH"
    let airtime = dateAt(hour: 12, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Thursdays at 12pm")
  }

  @Test
  func testFormatsWeeklyFridayAt6pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=FR"
    let airtime = dateAt(hour: 18, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Fridays at 6pm")
  }

  @Test
  func testFormatsWeeklySaturdayAt10am() {
    let rrule = "FREQ=WEEKLY;BYDAY=SA"
    let airtime = dateAt(hour: 10, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Saturdays at 10am")
  }

  @Test
  func testFormatsWeeklySundayAt7pm() {
    let rrule = "FREQ=WEEKLY;BYDAY=SU"
    let airtime = dateAt(hour: 19, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Sundays at 7pm")
  }

  // MARK: - Multiple Days Tests

  @Test
  func testFormatsTwoDays() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,WE"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Mondays and Wednesdays at 4pm")
  }

  @Test
  func testFormatsThreeDays() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Mondays, Wednesdays, and Fridays at 4pm")
  }

  @Test
  func testFormatsWeekdays() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
    let airtime = dateAt(hour: 8, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Weekdays at 8am")
  }

  @Test
  func testFormatsWeekends() {
    let rrule = "FREQ=WEEKLY;BYDAY=SA,SU"
    let airtime = dateAt(hour: 10, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Weekends at 10am")
  }

  @Test
  func testFormatsEveryDay() {
    let rrule = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"
    let airtime = dateAt(hour: 20, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Every day at 8pm")
  }

  // MARK: - Daily Frequency Tests

  @Test
  func testFormatsDailyFrequency() {
    let rrule = "FREQ=DAILY"
    let airtime = dateAt(hour: 14, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Every day at 2pm")
  }

  // MARK: - Edge Cases

  @Test
  func testReturnsNilForInvalidRRule() {
    let rrule = "INVALID_RRULE"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == nil)
  }

  @Test
  func testReturnsNilForEmptyRRule() {
    let rrule = ""
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == nil)
  }

  @Test
  func testReturnsNilForNilRRule() {
    let result = RRuleFormatter.formatToPlainEnglish(rrule: nil, airtime: Date())

    #expect(result == nil)
  }

  @Test
  func testHandlesDaysInDifferentOrder() {
    let rrule = "FREQ=WEEKLY;BYDAY=FR,MO,WE"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Mondays, Wednesdays, and Fridays at 4pm")
  }

  @Test
  func testHandlesLowercaseDays() {
    let rrule = "FREQ=WEEKLY;BYDAY=mo,we,fr"
    let airtime = dateAt(hour: 16, minute: 0)

    let result = RRuleFormatter.formatToPlainEnglish(rrule: rrule, airtime: airtime)

    #expect(result == "Mondays, Wednesdays, and Fridays at 4pm")
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
