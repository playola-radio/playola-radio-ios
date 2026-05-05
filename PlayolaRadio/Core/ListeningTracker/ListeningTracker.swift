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

@MainActor
final class ListeningTracker {
  let rewardsProfile: RewardsProfile
  var localListeningSessions: [LocalListeningSession]

  // The sink closure captures `self` weakly so the cancellable owned by this
  // tracker is the only thing keeping the subscription alive. When the tracker
  // is deallocated, `cancellables` releases the cancellable and the subscription
  // is torn down — without this, the strong self/closure/cancellables cycle
  // would keep replaced trackers alive forever.
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

    $nowPlaying.publisher
      .sink { [weak self] in self?.handleNowPlayingChange($0) }
      .store(in: &cancellables)
  }

  private func handleNowPlayingChange(_ nowPlaying: NowPlaying?) {
    if isCurrentlyPlaying(nowPlaying?.playbackStatus) && !isListening {
      print("Starting a new session!")
      localListeningSessions.append(LocalListeningSession(startTime: .now))
    } else if !isCurrentlyPlaying(nowPlaying?.playbackStatus) && isListening {
      if !localListeningSessions.isEmpty {
        print("Ending the current session")
        let lastIndex = localListeningSessions.count - 1
        localListeningSessions[lastIndex].endTime = .now
      }
    }
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
