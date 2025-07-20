//
//  RewardsProfile.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/20/25.
//

import Combine
import Dependencies
import Foundation

@MainActor
public class RewardsProfile: Decodable {
  private var disposeBag = Set<AnyCancellable>()

  @Dependency(\.date.now) var now

  let totalListeningReportedByServerMS: Int
  let totalMSAvailableForRewards: Int
  let accurateAsOfTime: Date

  var timeListenedLocallyBeforeCurrentSession: Int = 0

  private let stationPlayer: StationPlayer

  private var localListeningStartTime: Date?

  public var timeListenedDuringCurrentSessionMS: Int {
    guard let localListeningStartTime else { return 0 }
    return Int(now.timeIntervalSince(localListeningStartTime) * 1000)
  }

  public var totalTimeListenedMS: Int {
    return timeListenedDuringCurrentSessionMS + totalListeningReportedByServerMS
      + timeListenedLocallyBeforeCurrentSession
  }

  enum CodingKeys: String, CodingKey {
    case totalListeningReportedByServerMS = "totalTimeListenedMS"
    case totalMSAvailableForRewards
    case accurateAsOfTime
  }

  init(
    totalListeningReportedByServerMS: Int,
    totalMSAvailableForRewards: Int,
    accurateAsOfTime: Date,
    stationPlayer: StationPlayer = .shared,
  ) {
    self.totalListeningReportedByServerMS = totalListeningReportedByServerMS
    self.totalMSAvailableForRewards = totalMSAvailableForRewards
    self.accurateAsOfTime = accurateAsOfTime
    self.stationPlayer = stationPlayer

    // Start listening to station player state changes
    startObservingStationPlayer()
  }

  required public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.totalListeningReportedByServerMS = try container.decode(
      Int.self, forKey: .totalListeningReportedByServerMS)
    self.totalMSAvailableForRewards = try container.decode(
      Int.self, forKey: .totalMSAvailableForRewards)
    self.accurateAsOfTime = try container.decode(Date.self, forKey: .accurateAsOfTime)
    self.stationPlayer = .shared

    startObservingStationPlayer()
  }

  private func startObservingStationPlayer() {
    stationPlayer.$state
      .map(\.playbackStatus)
      .removeDuplicates { lhs, rhs in
        switch (lhs, rhs) {
        case (.playing, .playing), (.stopped, .stopped), (.error, .error):
          return true
        case (.loading, .loading):
          return true
        case (.startingNewStation, .startingNewStation):
          return true
        default:
          return false
        }
      }
      .sink { [weak self] playbackStatus in
        self?.handlePlaybackStatusChange(playbackStatus)
      }
      .store(in: &disposeBag)
  }

  func handlePlaybackStatusChange(_ status: StationPlayer.PlaybackStatus) {
    switch status {
    case .playing:
      startLocalListening()
    case .stopped, .error:
      stopLocalListening()
    case .loading, .startingNewStation:
      // Don't count loading time
      stopLocalListening()
    }
  }

  func startLocalListening() {
    if localListeningStartTime == nil {
      localListeningStartTime = now
    }
  }

  private func stopLocalListening() {
    guard let localListeningStartTime else {
      print("Error stopping listening time tracking -- localListeningStartTime was nil")
      return
    }
    self.timeListenedLocallyBeforeCurrentSession += timeListenedDuringCurrentSessionMS
    self.localListeningStartTime = nil
  }
}
