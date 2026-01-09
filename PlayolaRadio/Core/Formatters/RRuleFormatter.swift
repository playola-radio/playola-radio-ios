//
//  RRuleFormatter.swift
//  PlayolaRadio
//
//  Created by Claude on 1/8/26.
//

import Foundation

enum RRuleFormatter {
  private static let dayOrder = ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
  private static let dayNames = [
    "MO": "Mondays",
    "TU": "Tuesdays",
    "WE": "Wednesdays",
    "TH": "Thursdays",
    "FR": "Fridays",
    "SA": "Saturdays",
    "SU": "Sundays",
  ]

  private static let weekdays = Set(["MO", "TU", "WE", "TH", "FR"])
  private static let weekends = Set(["SA", "SU"])
  private static let allDays = Set(["MO", "TU", "WE", "TH", "FR", "SA", "SU"])

  static func formatToPlainEnglish(rrule: String?, airtime: Date) -> String? {
    guard let rrule = rrule, !rrule.isEmpty else { return nil }

    let components = parseRRule(rrule)
    guard let freq = components["FREQ"] else { return nil }

    let timeString = formatTime(airtime)

    switch freq.uppercased() {
    case "DAILY":
      return "Every day at \(timeString)"

    case "WEEKLY":
      guard let byDay = components["BYDAY"] else { return nil }
      let days = parseDays(byDay)
      guard !days.isEmpty else { return nil }

      let daysDescription = formatDays(days)
      return "\(daysDescription) at \(timeString)"

    default:
      return nil
    }
  }

  private static func parseRRule(_ rrule: String) -> [String: String] {
    var result: [String: String] = [:]
    let parts = rrule.split(separator: ";")

    for part in parts {
      let keyValue = part.split(separator: "=", maxSplits: 1)
      if keyValue.count == 2 {
        result[String(keyValue[0]).uppercased()] = String(keyValue[1])
      }
    }

    return result
  }

  private static func parseDays(_ byDay: String) -> [String] {
    let days = byDay.split(separator: ",").map { String($0).uppercased() }
    return days.sorted { day1, day2 in
      let index1 = dayOrder.firstIndex(of: day1) ?? Int.max
      let index2 = dayOrder.firstIndex(of: day2) ?? Int.max
      return index1 < index2
    }
  }

  private static func formatDays(_ days: [String]) -> String {
    let daySet = Set(days)

    if daySet == allDays {
      return "Every day"
    }

    if daySet == weekdays {
      return "Weekdays"
    }

    if daySet == weekends {
      return "Weekends"
    }

    let names = days.compactMap { dayNames[$0] }

    switch names.count {
    case 1:
      return names[0]
    case 2:
      return "\(names[0]) and \(names[1])"
    default:
      let allButLast = names.dropLast().joined(separator: ", ")
      return "\(allButLast), and \(names.last!)"
    }
  }

  private static func formatTime(_ date: Date) -> String {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    let period = hour < 12 ? "am" : "pm"
    let displayHour = hour % 12 == 0 ? 12 : hour % 12

    if minute == 0 {
      return "\(displayHour)\(period)"
    } else {
      return "\(displayHour):\(String(format: "%02d", minute))\(period)"
    }
  }
}
