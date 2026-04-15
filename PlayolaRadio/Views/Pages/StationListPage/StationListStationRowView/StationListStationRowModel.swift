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

  var imageUrl: URL {
    return item.anyStation.processedImageURL()
  }

  var titleText: String {
    return item.anyStation.name
  }

  var comingSoonText: String {
    if let date = item.station?.releaseDate {
      return "Coming \(formattedMonthDay(with: date))"
    } else {
      return "Coming Soon"
    }
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
    let isInactive = !item.anyStation.active
    let isComingSoonAndHidden = item.visibility == .comingSoon && !showSecretStations

    if isInactive || isComingSoonAndHidden {
      return comingSoonText
    }
    return item.anyStation.stationName
  }

  var subtitleColor: Color {
    return subtitleText == comingSoonText ? Color.playolaRed : Color.white
  }

  init(item: APIStationItem, liveStatus: LiveStatus? = nil) {
    self.item = item
    self.liveStatus = liveStatus
  }
}

extension StationListStationRowModel: Equatable {
  static func == (lhs: StationListStationRowModel, rhs: StationListStationRowModel) -> Bool {
    return lhs.item.anyStation.id == rhs.item.anyStation.id
  }
}
