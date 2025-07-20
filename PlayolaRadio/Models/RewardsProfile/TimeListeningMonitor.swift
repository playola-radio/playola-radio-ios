//
//  TimeListeningMonitor.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/20/25.
//

import Combine
import Dependencies
import Foundation

@MainActor
public class TimeListeningMonitor {
  //  private var disposeBag = Set<AnyCancellable>()
  //
  //  @Dependency(\.date.now) var now
  //  @Dependency(\.stationPlayer) var stationPlayer
  //
  //  var rewardsProfile: RewardsProfile
  //
  //  var timeListenedLocallyBeforeCurrentSession: Int = 0
  //
  //  private var localListeningStartTime: Date?
  //
  //  public var timeListenedDuringCurrentSessionMS: Int {
  //    guard let localListeningStartTime else { return 0 }
  //    return Int(now.timeIntervalSince(localListeningStartTime) * 1000)
  //  }
  //
  //  public var totalTimeListenedMS: Int {
  //    return timeListenedDuringCurrentSessionMS + rewardsProfile.totalTimeListenedMS
  //      + timeListenedLocallyBeforeCurrentSession
  //  }
  //
  //  enum CodingKeys: String, CodingKey {
  //    case totalListeningReportedByServerMS = "totalTimeListenedMS"
  //    case totalMSAvailableForRewards
  //    case accurateAsOfTime
  //  }
  //
  //  init(
  //    rewardsProfile: RewardsProfile,
  //    stationPlayer: StationPlayer = .shared,
  //  ) {
  //    self.rewardsProfile = rewardsProfile
  //    self.stationPlayer = stationPlayer
  //    // Start listening to station player state changes
  //    startObservingStationPlayer()
  //  }
  //
  //  private func startObservingStationPlayer() {
  //    stationPlayer.$state
  //      .map(\.playbackStatus)
  //      .removeDuplicates { lhs, rhs in
  //        switch (lhs, rhs) {
  //        case (.playing, .playing), (.stopped, .stopped), (.error, .error):
  //          return true
  //        case (.loading, .loading):
  //          return true
  //        case (.startingNewStation, .startingNewStation):
  //          return true
  //        default:
  //          return false
  //        }
  //      }
  //      .sink { [weak self] playbackStatus in
  //        self?.handlePlaybackStatusChange(playbackStatus)
  //      }
  //      .store(in: &disposeBag)
  //  }
  //
  //  func handlePlaybackStatusChange(_ status: StationPlayer.PlaybackStatus) {
  //    switch status {
  //    case .playing:
  //      startLocalListening()
  //    case .stopped, .error:
  //      stopLocalListening()
  //    case .loading, .startingNewStation:
  //      // Don't count loading time
  //      stopLocalListening()
  //    }
  //  }
  //
  //  func startLocalListening() {
  //    if localListeningStartTime == nil {
  //      localListeningStartTime = now
  //    }
  //  }
  //
  //  private func stopLocalListening() {
  //    guard let localListeningStartTime else {
  //      print("Error stopping listening time tracking -- localListeningStartTime was nil")
  //      return
  //    }
  //    self.timeListenedLocallyBeforeCurrentSession += timeListenedDuringCurrentSessionMS
  //    self.localListeningStartTime = nil
  //  }
}
