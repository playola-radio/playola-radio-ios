//
//  APIClientTestStubs.swift
//  PlayolaRadio
//

import Foundation

@testable import PlayolaRadio

extension APIClient {
  /// Empty responses for the refreshes a live show page fires on its own.
  mutating func stubLiveShowRefreshes() {
    fetchSchedule = { _, _ in [] }
    getListenerQuestions = { _, _ in [] }
    getActiveListeningSessions = { _, _, _, _ in .init(summary: .init(uniqueUsers: 0)) }
  }

  /// Empty responses for everything the main container loads on appear and on foreground.
  mutating func stubMainContainerRefreshes() {
    getStations = { [] }
    getAirings = { _, _ in [] }
    getMyFulfillmentRequests = { _ in [] }
    getSupportConversation = { _ in .init(conversation: nil, unreadCount: 0) }
    giveawayEventsFeed = { _ in [] }
    fetchLiveStations = { _ in [] }
    fetchUserStations = { _ in [] }
    getClientConfig = { _ in ClientConfig() }
    getRewardsProfile = { _ in
      .init(totalTimeListenedMS: 0, totalMSAvailableForRewards: 0, accurateAsOfTime: .distantPast)
    }
  }
}
