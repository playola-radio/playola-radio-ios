//
//  CuratorEpisode.swift
//  PlayolaRadio
//
//  App-local types for the curator recorded-show screens. UX "Show" = `Episode`,
//  UX "Series" = server `Show`. Decoded straight from the API so no SDK release is needed.
//

import Foundation
import PlayolaPlayer

struct CuratorSeries: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let stationId: String
  let title: String
  let isOneTime: Bool
  let rrule: String?
}

struct CuratorAiring: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let episodeId: String
  let stationId: String
  let airtime: Date
  let startTime: Date?
  let endTime: Date?
}

struct CuratorEpisodeSegment: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let position: Int
  let offsetMS: Int
  let audioBlock: AudioBlock?
}

struct CuratorEpisode: Codable, Equatable, Identifiable, Sendable {
  let id: String
  let showId: String
  let title: String
  let durationMS: Int
  let show: CuratorSeries?
  let segments: [CuratorEpisodeSegment]
  let airings: [CuratorAiring]

  init(
    id: String, showId: String, title: String, durationMS: Int, show: CuratorSeries?,
    segments: [CuratorEpisodeSegment], airings: [CuratorAiring]
  ) {
    self.id = id
    self.showId = showId
    self.title = title
    self.durationMS = durationMS
    self.show = show
    self.segments = segments
    self.airings = airings
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    showId = try container.decode(String.self, forKey: .showId)
    title = try container.decode(String.self, forKey: .title)
    durationMS = try container.decode(Int.self, forKey: .durationMS)
    show = try container.decodeIfPresent(CuratorSeries.self, forKey: .show)
    segments = try container.decodeIfPresent([CuratorEpisodeSegment].self, forKey: .segments) ?? []
    airings = try container.decodeIfPresent([CuratorAiring].self, forKey: .airings) ?? []
  }

  private enum CodingKeys: String, CodingKey {
    case id, showId, title, durationMS, show, segments, airings
  }
}

struct StationSchedulingSettings: Codable, Equatable, Sendable {
  static let fallbackTimeZoneIdentifier = "America/Chicago"

  let timezone: String
  let airingEditLockMS: Int

  var timeZone: TimeZone {
    TimeZone(identifier: timezone)
      ?? TimeZone(identifier: Self.fallbackTimeZoneIdentifier) ?? .gmt
  }
}

enum CuratorEpisodeState: Equatable {
  case draft
  case scheduled(CuratorAiring)
  case locked(CuratorAiring)
  case aired
}

extension CuratorEpisode {
  var isMultiAiring: Bool { airings.count > 1 }

  var hasAudio: Bool { durationMS > 0 }

  /// The server locks a Show when any Airing has aired, is on air, or starts within
  /// `airingEditLockMS`, so a Show with one ended Airing and one future Airing is `.locked`
  /// (carrying the next Airing) even though the future Airing is still outside the window.
  func state(now: Date, lockMS: Int) -> CuratorEpisodeState {
    guard !airings.isEmpty else { return .draft }

    let upcoming = airings.filter { !hasEnded($0, now: now) }.sorted { $0.airtime < $1.airtime }
    guard let next = upcoming.first else { return .aired }

    if upcoming.count < airings.count { return .locked(next) }
    if let lockedAiring = upcoming.first(where: { isLocked($0, now: now, lockMS: lockMS) }) {
      return .locked(lockedAiring)
    }
    return .scheduled(next)
  }

  private func hasEnded(_ airing: CuratorAiring, now: Date) -> Bool {
    let end = airing.endTime ?? airing.airtime.addingTimeInterval(Double(durationMS) / 1000)
    return now >= end
  }

  private func isLocked(_ airing: CuratorAiring, now: Date, lockMS: Int) -> Bool {
    let lockStart = airing.airtime.addingTimeInterval(-Double(lockMS) / 1000)
    let started = airing.startTime.map { now >= $0 } ?? false
    return now >= lockStart || started
  }
}
