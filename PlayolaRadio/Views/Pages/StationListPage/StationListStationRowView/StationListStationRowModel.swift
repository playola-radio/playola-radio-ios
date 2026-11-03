//
//  StationListStationRowModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 9/26/25.
//

import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

struct StationListStationRowModel {
  @Shared(.showSecretStations) var showSecretStations: Bool
  let item: APIStationItem
  let liveStatus: LiveStatus?
  let hasUpcomingGiveaway: Bool

  var imageUrl: URL {
    return item.anyStation.processedImageURL()
  }

  var titleText: String {
    return item.anyStation.name
  }

  func formattedMonthDay(with date: Date) -> String {
    // Use UTC calendar to match how releaseDate is parsed from server
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = calendar.component(.day, from: date)

    // Ordinal suffix
    let suffix: String
    switch day {
    case 11, 12, 13: suffix = "th"
    default:
      switch day % 10 {
      case 1: suffix = "st"
      case 2: suffix = "nd"
      case 3: suffix = "rd"
      default: suffix = "th"
      }
    }

    // Month abbreviation
    let formatter = DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "MMM"
    let month = formatter.string(from: date)

    return "\(month) \(day)\(suffix)"
  }

  var subtitleText: String {
    if item.isPlayable(unlocked: showSecretStations) { return item.anyStation.stationName }
    if item.visibility == .comingSoon, let date = item.station?.releaseDate {
      return "Coming \(formattedMonthDay(with: date))"
    }
    return "Coming Soon"
  }

  var subtitleColor: Color {
    item.isPlayable(unlocked: showSecretStations) ? Color.white : Color.playolaRed
  }

  init(item: APIStationItem, liveStatus: LiveStatus? = nil, hasUpcomingGiveaway: Bool = false) {
    self.item = item
    self.liveStatus = liveStatus
    self.hasUpcomingGiveaway = hasUpcomingGiveaway
  }
}
