//
//  RewardsPageModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Dependencies
import Foundation
import Observation
import Sharing

@MainActor
@Observable
class RewardsPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  var prizeTiers: [PrizeTier] = []
  var redeemedPrizeTierIds: Set<String> = []
  var presentedAlert: PlayolaAlert?

  // MARK: - View Helpers

  struct PrizeTierInfo {
    let prizeTier: PrizeTier
    let status: RedemptionStatus
  }

  var prizeTierInfos: [PrizeTierInfo] {
    prizeTiers.map {
      PrizeTierInfo(prizeTier: $0, status: redemptionStatus(for: $0))
    }
  }

  func redemptionStatus(for prizeTier: PrizeTier) -> RedemptionStatus {
    if redeemedPrizeTierIds.contains(prizeTier.id) {
      return .redeemed
    }

    let userListeningHours = getUserListeningHours()

    if userListeningHours >= prizeTier.requiredListeningHours {
      return .redeemable
    }

    let hoursToGo = prizeTier.requiredListeningHours - userListeningHours
    return .moreTimeRequired(hoursToGo)
  }

  func prizeTierLabel(for index: Int) -> String {
    "Tier \(index + 1)"
  }

  func prizeTierRequiredHoursLabel(for prizeTier: PrizeTier) -> String {
    let hours = prizeTier.requiredListeningHours
    return "\(hours) \(hours == 1 ? "hour" : "hours")"
  }

  var prizeTierButtonText: String { "Redeem" }
  var prizeTierRedeemedText: String { "Redeemed" }

  // MARK: - User Actions

  func viewAppeared() async {
    let currentHours = getCurrentListeningHours()
    await analytics.track(.viewedRewardsScreen(currentHours: currentHours))

    await loadPrizeTiers()
    await loadUserPrizes()
  }

  func redeemPrizeTapped(for prizeTier: PrizeTier) async {
    let currentHours = getCurrentListeningHours()
    await analytics.track(.tappedRedeemRewards(currentHours: currentHours))

    let sheetModel = RedeemPrizeSheetModel(
      prizeTier: prizeTier,
      onSuccess: { [weak self] userPrize in
        guard let self else { return }
        if let prize = userPrize.prize {
          self.redeemedPrizeTierIds.insert(prize.prizeTierId)
        } else {
          self.redeemedPrizeTierIds.insert(prizeTier.id)
        }
        self.presentedAlert = .prizeRedeemed
      }
    )
    mainContainerNavigationCoordinator.presentedSheet = .redeemPrize(sheetModel)
  }

  // MARK: - Private Helpers

  private func loadPrizeTiers() async {
    do {
      prizeTiers = try await api.getPrizeTiers()
    } catch {
      // TODO: Add error handling
      print("Failed to load prize tiers: \(error)")
    }
  }

  private func loadUserPrizes() async {
    guard let jwt = auth.jwt else { return }
    do {
      let userPrizes = try await api.getUserPrizes(jwt)
      redeemedPrizeTierIds = Set(
        userPrizes.compactMap { $0.prize?.prizeTierId }
      )
    } catch {
      print("Failed to load user prizes: \(error)")
    }
  }

  private func getUserListeningHours() -> Int {
    guard let totalMSListened = listeningTracker?.totalListenTimeMS, totalMSListened > 0 else {
      return 0
    }
    let totalSeconds = Double(totalMSListened) / 1000.0
    let totalHours = totalSeconds / 3600.0
    return Int(totalHours)
  }

  private func getCurrentListeningHours() -> Double {
    guard let totalMSListened = listeningTracker?.totalListenTimeMS, totalMSListened > 0 else {
      return 0.0
    }
    let totalSeconds = Double(totalMSListened) / 1000.0
    return totalSeconds / 3600.0
  }
}
