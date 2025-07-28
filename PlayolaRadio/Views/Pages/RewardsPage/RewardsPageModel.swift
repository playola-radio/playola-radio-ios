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

  var prizeTiers: [PrizeTier] = []

  func onViewAppeared() async {
    await loadPrizeTiers()
  }

  func loadPrizeTiers() async {
    do {
      prizeTiers = try await api.getPrizeTiers()
    } catch {
      // TODO: Add error handling
      print("Failed to load prize tiers: \(error)")
    }
  }
}
