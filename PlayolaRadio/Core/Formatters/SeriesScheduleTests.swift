//
//  SeriesScheduleTests.swift
//  PlayolaRadioTests
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct SeriesScheduleTests {
  private let chicago = TimeZone(identifier: "America/Chicago")!
  private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

  private let tuesdayAndThursdayRule = "FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0"

  private func instant(_ iso: String) throws -> Date {
    try Date(iso, strategy: .iso8601)
  }

  private func stationTime(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0
  ) throws -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = chicago
    let components = DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute)
    return try #require(calendar.date(from: components))
  }

  private func withDeviceTimeZone<T>(_ timeZone: TimeZone, _ body: () throws -> T) rethrows -> T {
    let original = NSTimeZone.default
    NSTimeZone.default = timeZone
    defer { NSTimeZone.default = original }
    return try body()
  }

  private func weekly(
    _ weekdays: Set<Locale.Weekday>, hour: Int, minute: Int = 0
  ) -> SeriesSchedule {
    SeriesSchedule(weekdays: weekdays, hour: hour, minute: minute)
  }

  // MARK: - Reading and writing

  @Test func weeklyRuleRoundTrips() throws {
    let schedule = try #require(SeriesSchedule(rrule: tuesdayAndThursdayRule))

    expectNoDifference(schedule.weekdays, [.tuesday, .thursday])
    expectNoDifference(schedule.hour, 20)
    expectNoDifference(schedule.minute, 0)
    expectNoDifference(schedule.rrule, tuesdayAndThursdayRule)
  }

  @Test func everyOtherWeekRuleIsNotEditable() {
    #expect(SeriesSchedule(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=TU;BYHOUR=20;BYMINUTE=0") == nil)
  }

  @Test func dailyRuleIsNotEditable() {
    #expect(SeriesSchedule(rrule: "FREQ=DAILY;BYHOUR=20;BYMINUTE=0") == nil)
  }

  @Test(
    arguments: [
      "FREQ=MONTHLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0",
      "FREQ=WEEKLY;COUNT=4;BYDAY=TU;BYHOUR=20;BYMINUTE=0",
      "FREQ=WEEKLY;UNTIL=20271231T000000Z;BYDAY=TU;BYHOUR=20;BYMINUTE=0",
      "DTSTART=20261103T200000;FREQ=WEEKLY;BYDAY=TU;BYHOUR=20;BYMINUTE=0",
      "FREQ=WEEKLY;BYDAY=TU;BYHOUR=19,20;BYMINUTE=0",
      "FREQ=WEEKLY;BYDAY=1TU;BYHOUR=20;BYMINUTE=0",
      "FREQ=WEEKLY;BYDAY=TU;BYHOUR=24;BYMINUTE=0",
      "FREQ=WEEKLY;BYDAY=TU;BYHOUR=20",
      "FREQ=WEEKLY;BYHOUR=20;BYMINUTE=0",
      "",
    ])
  func otherRulesAreNotEditable(rrule: String) {
    #expect(SeriesSchedule(rrule: rrule) == nil)
  }

  @Test func writtenRuleListsDaysInWeekOrder() {
    let schedule = weekly([.sunday, .monday, .friday], hour: 7, minute: 30)

    expectNoDifference(schedule.rrule, "FREQ=WEEKLY;BYDAY=MO,FR,SU;BYHOUR=7;BYMINUTE=30")
  }

  // MARK: - Text

  @Test func textUsesRuleTimeNotDeviceTime() throws {
    let schedule = try #require(SeriesSchedule(rrule: "FREQ=WEEKLY;BYDAY=SU;BYHOUR=19;BYMINUTE=0"))

    let text = withDeviceTimeZone(tokyo) { schedule.text }

    expectNoDifference(text, "Every Sunday at 7pm")
  }

  @Test func textForSeveralDays() throws {
    let schedule = try #require(SeriesSchedule(rrule: tuesdayAndThursdayRule))

    expectNoDifference(schedule.text, "Every Tuesday and Thursday at 8pm")
  }

  @Test func textListsThreeDaysWithCommasAndAnd() {
    expectNoDifference(
      weekly([.wednesday, .monday, .friday], hour: 9).text,
      "Every Monday, Wednesday and Friday at 9am")
  }

  @Test func textShowsMinutesAndTwelveHourClockEdges() {
    expectNoDifference(weekly([.saturday], hour: 0, minute: 5).text, "Every Saturday at 12:05am")
    expectNoDifference(weekly([.saturday], hour: 12, minute: 30).text, "Every Saturday at 12:30pm")
  }

  // MARK: - Open slots

  @Test func openSlotsSkipOccupiedIntervals() throws {
    let schedule = weekly([.tuesday], hour: 20)
    let now = try stationTime(2026, 11, 2, 12)
    let occupied = DateInterval(
      start: try stationTime(2026, 11, 3, 19, 30), end: try stationTime(2026, 11, 3, 20, 30))

    let slots = schedule.openSlots(
      after: now, in: chicago, occupiedIntervals: [occupied], limit: 2)

    expectNoDifference(
      slots, [try stationTime(2026, 11, 10, 20), try stationTime(2026, 11, 17, 20)])
  }

  @Test func openSlotsAllowSlotAtExactIntervalEnd() throws {
    let schedule = weekly([.tuesday], hour: 20)
    let now = try stationTime(2026, 11, 2, 12)
    let occupied = DateInterval(
      start: try stationTime(2026, 11, 3, 19), end: try stationTime(2026, 11, 3, 20))

    let slots = schedule.openSlots(
      after: now, in: chicago, occupiedIntervals: [occupied], limit: 1)

    expectNoDifference(slots, [try stationTime(2026, 11, 3, 20)])
  }

  @Test func openSlotsSkipSlotsAlreadyPast() throws {
    let schedule = weekly([.tuesday], hour: 20)
    let now = try stationTime(2026, 11, 3, 20)

    let slots = schedule.openSlots(after: now, in: chicago, occupiedIntervals: [], limit: 1)

    expectNoDifference(slots, [try stationTime(2026, 11, 10, 20)])
  }

  @Test func openSlotsStopAtEight() throws {
    let everyDay: Set<Locale.Weekday> = [
      .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]
    let slots = weekly(everyDay, hour: 20).openSlots(
      after: try stationTime(2026, 11, 2, 12), in: chicago, occupiedIntervals: [])

    expectNoDifference(slots.count, 8)
  }

  @Test func openSlotsStopAtFiftyTwoWeeks() throws {
    let slots = weekly([.tuesday], hour: 20).openSlots(
      after: try stationTime(2026, 11, 2, 12), in: chicago, occupiedIntervals: [], limit: 100)

    expectNoDifference(slots.count, 52)
    expectNoDifference(slots.last, try stationTime(2027, 10, 26, 20))
  }

  @Test func openSlotsSkipSpringForwardGap() throws {
    let schedule = weekly([.sunday], hour: 2, minute: 30)

    let slots = schedule.openSlots(
      after: try stationTime(2027, 3, 5, 12), in: chicago, occupiedIntervals: [], limit: 3)

    expectNoDifference(
      slots,
      [
        try instant("2027-03-07T08:30:00Z"),
        try instant("2027-03-21T07:30:00Z"),
        try instant("2027-03-28T07:30:00Z"),
      ])
  }

  @Test func openSlotsUseEarlierInstantOnFallBack() throws {
    let schedule = weekly([.sunday], hour: 1, minute: 30)

    let slots = schedule.openSlots(
      after: try stationTime(2026, 10, 30, 12), in: chicago, occupiedIntervals: [], limit: 2)

    expectNoDifference(
      slots,
      [try instant("2026-11-01T06:30:00Z"), try instant("2026-11-08T07:30:00Z")])
  }

  @Test func openSlotsIncludeMidnight() throws {
    let schedule = weekly([.tuesday], hour: 0)

    let slots = schedule.openSlots(
      after: try stationTime(2026, 11, 2, 12), in: chicago, occupiedIntervals: [], limit: 1)

    expectNoDifference(slots, [try instant("2026-11-03T06:00:00Z")])
  }

  @Test func openSlotsUseStationTimeNotDeviceTime() throws {
    let schedule = weekly([.tuesday], hour: 20)
    let now = try stationTime(2026, 11, 2, 12)

    let slots = withDeviceTimeZone(tokyo) {
      schedule.openSlots(after: now, in: chicago, occupiedIntervals: [], limit: 2)
    }

    expectNoDifference(
      slots, [try instant("2026-11-04T02:00:00Z"), try instant("2026-11-11T02:00:00Z")])
  }
}
