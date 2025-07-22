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

  var isListening: Bool {
    localListeningSessions.last?.endTime == nil
  }

  @Shared(.nowPlaying) var nowPlaying

  init(rewardsProfile: RewardsProfile, localListeningSessions: [LocalListeningSession] = []) {
    self.rewardsProfile = rewardsProfile
    self.localListeningSessions = localListeningSessions

    //    nowPlaying?.publisher.$sink { nowPlaying in
    //      if nowPlaying.playbackStatus == .playing && !.isListening {
    //        self.localListeningSessions.append(LocalListeningSession(startTime: .now))
    //      } else if nowPlaying.playbackStatus != .playing && .isListening {
    //        self.localListeningSessions.last?.endTime = .now
    //      }
    //    }
  }

  var totalListenTimeMS: Int {
    let localListeningMS = localListeningSessions.reduce(into: 0) { $0 + $1.totalTimeMS }
    let serverListeningTimeMS = rewardsProfile.totalTimeListenedMS
    return localListeningMS + serverListeningTimeMS
  }
}
