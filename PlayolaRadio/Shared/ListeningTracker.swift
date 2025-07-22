//
//  ListeningTracker.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//
import Combine
import Foundation
import Sharing
import SwiftUI

class ListeningTracker {
  var rewardsProfile: RewardsProfile
  var localListeningSessions: [LocalListeningSession]
  private var cancellables = Set<AnyCancellable>()

  var isListening: Bool {
    localListeningSessions.last?.endTime == nil
  }

  @Shared(.nowPlaying) var nowPlaying

  init(rewardsProfile: RewardsProfile, localListeningSessions: [LocalListeningSession] = []) {
    self.rewardsProfile = rewardsProfile
    self.localListeningSessions = localListeningSessions

    $nowPlaying.publisher.sink { nowPlaying in
      if self.isCurrentlyPlaying(nowPlaying?.playbackStatus) && !self.isListening {
        self.localListeningSessions.append(LocalListeningSession(startTime: .now))
      } else if !self.isCurrentlyPlaying(nowPlaying?.playbackStatus) && self.isListening {
        if var lastSession = self.localListeningSessions.last {
          lastSession.endTime = .now
        }
      }
    }.store(in: &cancellables)
  }

  private func isCurrentlyPlaying(_ status: StationPlayer.PlaybackStatus?) -> Bool {
    guard let status else { return false }
    if case .playing = status { return true }
    return false
  }

  var totalListenTimeMS: Int {
    let localListeningMS = localListeningSessions.reduce(into: 0) { $0 + $1.totalTimeMS }
    let serverListeningTimeMS = rewardsProfile.totalTimeListenedMS
    return localListeningMS + serverListeningTimeMS
  }
}
