//
//  ListeningTracker.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/22/25.
//
import Combine
import Foundation
import PlayolaCore
import Sharing
import SwiftUI

final class ListeningTracker: Sendable {
  let rewardsProfile: RewardsProfile
  var localListeningSessions: [LocalListeningSession]
  private var cancellables = Set<AnyCancellable>()

  var isListening: Bool {
    guard let lastSession = localListeningSessions.last else {
      return false
    }
    return lastSession.endTime == nil
  }

  @Shared(.nowPlaying) var nowPlaying

  init(rewardsProfile: RewardsProfile, localListeningSessions: [LocalListeningSession] = []) {
    self.rewardsProfile = rewardsProfile
    self.localListeningSessions = localListeningSessions

    $nowPlaying.publisher.sink { nowPlaying in

      if self.isCurrentlyPlaying(nowPlaying?.playbackStatus) && !self.isListening {
        print("Starting a new session!")
        self.localListeningSessions.append(LocalListeningSession(startTime: .now))
      } else if !self.isCurrentlyPlaying(nowPlaying?.playbackStatus) && self.isListening {
        if !self.localListeningSessions.isEmpty {
          print("Ending the current session")
          let lastIndex = self.localListeningSessions.count - 1
          self.localListeningSessions[lastIndex].endTime = .now
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
    let localListeningMS = localListeningSessions.reduce(0) { $0 + $1.totalTimeMS }
    let serverListeningTimeMS = rewardsProfile.totalTimeListenedMS
    return localListeningMS + serverListeningTimeMS
  }
}
