//
//  ScheduledShow.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 10/8/25.
//

import Foundation

/// Represents a scheduled instance of a show
struct ScheduledShow: Codable, Equatable, Identifiable {
  let id: String
  let showId: String
  let stationId: String
  let airtime: Date
  let createdAt: Date
  let updatedAt: Date
  let show: Show?
  let station: RadioStation?
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
