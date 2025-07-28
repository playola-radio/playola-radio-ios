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
  var redeemedPrizeTierIds: Set<String> = []

  func onViewAppeared() async {
    await loadPrizeTiers()
    await loadUserPrizes()
  }

  struct PrizeTierInfo {
    let prizeTier: PrizeTier
    let status: RedemptionStatus
  }

  var prizeTierInfos: [PrizeTierInfo] {
    return prizeTiers.map {
      return PrizeTierInfo(
        prizeTier: $0,
        status: redemptionStatus(for: $0))
    }
  }

  func redemptionStatus(for prizeTier: PrizeTier) -> RedemptionStatus {
    // Check if already redeemed
    if redeemedPrizeTierIds.contains(prizeTier.id) {
      return .redeemed
    }

    // Check if user has enough hours
    let userListeningHours: Int = {
      guard let totalMSListened = listeningTracker?.totalListenTimeMS, totalMSListened > 0 else {
        return 0
      }
      // Convert milliseconds to hours, rounding down to get completed hours
      let totalSeconds = Double(totalMSListened) / 1000.0
      let totalHours = totalSeconds / 3600.0
      return Int(totalHours)
    }()

    if userListeningHours >= prizeTier.requiredListeningHours {
      return .redeemable
    }

    // Calculate hours remaining
    let hoursToGo = prizeTier.requiredListeningHours - userListeningHours
    return .moreTimeRequired(hoursToGo)
  }

  func loadPrizeTiers() async {
    do {
      prizeTiers = try await api.getPrizeTiers()
    } catch {
      // TODO: Add error handling
      print("Failed to load prize tiers: \(error)")
    }
  }

  func loadUserPrizes() async {
    // TODO: Actually download this.
    // This should populate redeemedPrizeTierIds with the IDs of prize tiers the user has already redeemed
    //    do {
    //      let userPrizes = try await api.getUserPrizes()
    //      redeemedPrizeTierIds = Set(userPrizes.map { $0.prizeTierId })
    //    } catch {
    //      print("Failed to load user prizes: \(error)")
    //    }
  }
}
