//
//  ScheduledShow.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Dependencies
import Foundation
import PlayolaPlayer

/// Represents a scheduled instance of a show
struct ScheduledShow: Codable, Equatable, Identifiable {
  let id: String
  let showId: String
  let stationId: String
  let airtime: Date
  let createdAt: Date
  let updatedAt: Date
  let show: Show?
  let station: PlayolaPlayer.Station?

  var endTime: Date {
    guard let show = show, show.durationMS > 0 else {
      return airtime
    }
    let durationInSeconds = TimeInterval(show.durationMS) / 1000.0
    return airtime.addingTimeInterval(durationInSeconds)
  }

  var hasEnded: Bool {
    @Dependency(\.date.now) var now
    return endTime <= now
  }
}

extension ScheduledShow {
  static let mock: ScheduledShow = .init(
    id: "live",
    showId: "live",
    stationId: "live",
    airtime: Date(),
    createdAt: Date(),
    updatedAt: Date(),
    show: .mock,
    station: nil
  )
}
