//
//  SeriesSchedule.swift
//  PlayolaRadio
//
//  A Series' repeating schedule in the only form iOS reads and writes:
//  `FREQ=WEEKLY;BYDAY=TU,TH;BYHOUR=20;BYMINUTE=0`. Hours and minutes are station wall-clock time.
//

import Foundation

struct SeriesSchedule: Equatable, Sendable {
  static let maxWeeksAhead = 52

  let weekdays: Set<Locale.Weekday>
  let hour: Int
  let minute: Int

  var rrule: String {
    let days = Self.weekOrder.filter(weekdays.contains).map { Self.dayCodes[$0] ?? "" }
    return "FREQ=WEEKLY;BYDAY=\(days.joined(separator: ","));BYHOUR=\(hour);BYMINUTE=\(minute)"
  }

  /// "Every Tuesday and Thursday at 8pm". Straight from the rule's numbers, never converted.
  var text: String {
    let names = Self.weekOrder.filter(weekdays.contains).map { Self.dayNames[$0] ?? "" }
    return "Every \(Self.joinWithAnd(names)) at \(timeText)"
  }

  /// Station-time slots after `now`, ascending, skipping any that fall inside an occupied interval
  /// (start inclusive, end exclusive). A wall time that does not exist (spring forward) is skipped;
  /// a repeated one (fall back) is used once, at the earlier instant.
  func openSlots(
    after now: Date, in timeZone: TimeZone, occupiedIntervals: [DateInterval], limit: Int = 8
  ) -> [Date] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    guard
      let horizon = calendar.date(byAdding: .weekOfYear, value: Self.maxWeeksAhead, to: now)
    else { return [] }

    var slots: [Date] = []
    var day = calendar.startOfDay(for: now)
    while day <= horizon, slots.count < limit {
      defer { day = calendar.date(byAdding: .day, value: 1, to: day) ?? .distantFuture }
      guard let weekday = Locale.Weekday(calendarWeekday: calendar.component(.weekday, from: day)),
        weekdays.contains(weekday),
        let slot = slot(on: day, calendar: calendar),
        slot > now, slot <= horizon,
        !occupiedIntervals.contains(where: { $0.start <= slot && slot < $0.end })
      else { continue }
      slots.append(slot)
    }
    return slots
  }

  private func slot(on day: Date, calendar: Calendar) -> Date? {
    let candidate = calendar.date(
      bySettingHour: hour, minute: minute, second: 0, of: day,
      matchingPolicy: .strict, repeatedTimePolicy: .first, direction: .forward)
    guard let candidate, calendar.isDate(candidate, inSameDayAs: day) else { return nil }
    return candidate
  }

  private var timeText: String {
    let displayHour = hour % 12 == 0 ? 12 : hour % 12
    let suffix = hour < 12 ? "am" : "pm"
    let minutes = minute == 0 ? "" : String(format: ":%02d", minute)
    return "\(displayHour)\(minutes)\(suffix)"
  }

  private static func joinWithAnd(_ names: [String]) -> String {
    guard let last = names.last, names.count > 1 else { return names.first ?? "" }
    return "\(names.dropLast().joined(separator: ", ")) and \(last)"
  }

  fileprivate static let weekOrder: [Locale.Weekday] = [
    .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
  ]

  fileprivate static let dayCodes: [Locale.Weekday: String] = [
    .monday: "MO", .tuesday: "TU", .wednesday: "WE", .thursday: "TH", .friday: "FR",
    .saturday: "SA", .sunday: "SU",
  ]

  private static let dayNames: [Locale.Weekday: String] = [
    .monday: "Monday", .tuesday: "Tuesday", .wednesday: "Wednesday", .thursday: "Thursday",
    .friday: "Friday", .saturday: "Saturday", .sunday: "Sunday",
  ]
}

extension SeriesSchedule {
  /// Nil for anything but a plain weekly rule with one or more days and exactly one time. A rule
  /// that fails here is shown as "Custom schedule" by callers and is never edited or rewritten.
  init?(rrule: String) {
    var fields: [String: String] = [:]
    for part in rrule.split(separator: ";", omittingEmptySubsequences: false) {
      let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
      guard pair.count == 2, fields[String(pair[0])] == nil else { return nil }
      fields[String(pair[0])] = String(pair[1])
    }
    guard fields["FREQ"] == "WEEKLY", fields["INTERVAL"] ?? "1" == "1",
      Set(fields.keys).isSubset(of: ["FREQ", "INTERVAL", "BYDAY", "BYHOUR", "BYMINUTE"]),
      let byDay = fields["BYDAY"],
      let hour = fields["BYHOUR"].flatMap({ Int($0) }), (0...23).contains(hour),
      let minute = fields["BYMINUTE"].flatMap({ Int($0) }), (0...59).contains(minute)
    else { return nil }

    let days = byDay.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
    let weekdays = Set(days.compactMap { code in Self.dayCodes.first { $0.value == code }?.key })
    guard weekdays.count == days.count else { return nil }

    self.init(weekdays: weekdays, hour: hour, minute: minute)
  }
}

extension Locale.Weekday {
  fileprivate init?(calendarWeekday: Int) {
    let sundayFirst: [Locale.Weekday] = [
      .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday,
    ]
    guard (1...7).contains(calendarWeekday) else { return nil }
    self = sundayFirst[calendarWeekday - 1]
  }
}
