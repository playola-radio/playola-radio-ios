//
//  EpisodeRowModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer

@MainActor
@Observable
class EpisodeRowModel: ViewModel {
  @ObservationIgnored @Dependency(\.date.now) var now

  let airing: Airing

  init(airing: Airing) {
    self.airing = airing
    super.init()
  }

  var isUpcoming: Bool {
    airing.airtime > now
  }

  var tuneInText: String {
    let time = formattedTime
    let dayOfWeek = dayOfWeekString

    if isThisWeek {
      return "Tune in \(dayOfWeek) at \(time)"
    } else if isNextWeek {
      return "Tune in next \(dayOfWeek) at \(time)"
    } else {
      let dayWithOrdinal = dayOfMonthWithOrdinal
      return "Tune in \(dayOfWeek) the \(dayWithOrdinal) at \(time)"
    }
  }

  var episodeTitle: String { airing.episode?.title ?? "Unknown Episode" }

  // MARK: - Private Helpers

  private var formattedTime: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mma"
    return formatter.string(from: airing.airtime).lowercased()
  }

  private var dayOfWeekString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: airing.airtime)
  }

  private var dayOfMonthWithOrdinal: String {
    let day = Calendar.current.component(.day, from: airing.airtime)
    return "\(day)\(ordinalSuffix(for: day))"
  }

  private func ordinalSuffix(for day: Int) -> String {
    switch day {
    case 11, 12, 13:
      return "th"
    default:
      switch day % 10 {
      case 1: return "st"
      case 2: return "nd"
      case 3: return "rd"
      default: return "th"
      }
    }
  }

  private var isThisWeek: Bool {
    let calendar = Calendar.current
    guard let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
      let endOfThisWeek = calendar.date(byAdding: .day, value: 7, to: startOfThisWeek)
    else { return false }

    return airing.airtime >= startOfThisWeek && airing.airtime < endOfThisWeek
  }

  private var isNextWeek: Bool {
    let calendar = Calendar.current
    guard let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
      let startOfNextWeek = calendar.date(byAdding: .day, value: 7, to: startOfThisWeek),
      let endOfNextWeek = calendar.date(byAdding: .day, value: 14, to: startOfThisWeek)
    else { return false }

    return airing.airtime >= startOfNextWeek && airing.airtime < endOfNextWeek
  }
}
