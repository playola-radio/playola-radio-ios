//
//  RewardsPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Combine
import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class RewardsPageModel: ViewModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

  var prizes: [Prize] = []

  func onViewAppeared() async {
    await loadPrizes()
  }

  func loadPrizes() async {
    do {
      prizes = try await api.getPrizes()
    } catch {
      // TODO: Add error handling
      print("Failed to load prizes: \(error)")
    }
  }
}
