//
//  RedeemPrizeSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import Observation
import Sharing

struct RedeemOption: Identifiable, Equatable {
  let id: String
  let name: String
  let stationId: String?

  init(prize: Prize) {
    self.id = "prize-\(prize.id)"
    self.name = prize.name
    self.stationId = nil
  }

  init(station: AnyStation, tierName: String) {
    self.id = "station-\(station.id)"
    self.name = "\(station.name) \(tierName)"
    self.stationId = station.id
  }
}

@MainActor
@Observable
class RedeemPrizeSheetModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.stationLists) var stationLists
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  init(prizeTier: PrizeTier, onSuccess: ((UserPrize) -> Void)? = nil) {
    self.prizeTier = prizeTier
    self.onSuccess = onSuccess
    self.emailAddress = ""
    self.hasVerifiedEmail = false
    super.init()
    if let verifiedEmail = auth.currentUser?.verifiedEmail {
      self.emailAddress = verifiedEmail
      self.hasVerifiedEmail = true
    } else {
      self.emailAddress = auth.currentUser?.email ?? ""
    }
  }

  // MARK: - Properties

  let prizeTier: PrizeTier
  var emailAddress: String
  var hasVerifiedEmail: Bool
  var selectedOption: RedeemOption?
  var isSubmitting = false
  var presentedAlert: PlayolaAlert?
  var onSuccess: ((UserPrize) -> Void)?

  // MARK: - View Helpers

  var navigationTitle: String { "Redeem Reward" }
  var emailLabel: String { "Email for follow-up" }
  var emailPlaceholder: String { "your@email.com" }
  var choosePrizeLabel: String { "Choose your prize" }
  var submitButtonText: String { "Redeem" }
  var cancelButtonText: String { "Cancel" }

  var needsEmail: Bool { !hasVerifiedEmail }

  var canSubmit: Bool {
    selectedOption != nil
      && !emailAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isSubmitting
  }

  var redeemOptions: [RedeemOption] {
    var options: [RedeemOption] = []

    if prizeTier.perStation {
      let stations = stationLists.flatMap { $0.visibleStationItems.map { $0.anyStation } }
      let seen = NSMutableSet()
      for station in stations where !seen.contains(station.id) {
        seen.add(station.id)
        options.append(RedeemOption(station: station, tierName: prizeTier.name))
      }
    }

    for prize in prizeTier.prizes {
      options.append(RedeemOption(prize: prize))
    }

    return options
  }

  func isSelected(_ option: RedeemOption) -> Bool {
    selectedOption?.id == option.id
  }

  // MARK: - User Actions

  func optionTapped(_ option: RedeemOption) {
    selectedOption = option
  }

  func submitButtonTapped() async {
    guard let jwt = auth.jwt, let option = selectedOption, canSubmit else { return }

    isSubmitting = true

    do {
      if needsEmail {
        let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let updatedAuth = try await api.updateUser(
          jwtToken: jwt, firstName: auth.currentUser?.firstName ?? "", lastName: nil,
          verifiedEmail: email)
        $auth.withLock { $0 = updatedAuth }
      }

      let prizeId = prizeTier.prizes.first?.id ?? prizeTier.id
      let userPrize = try await api.redeemPrize(
        jwtToken: jwt, prizeId: prizeId, stationId: option.stationId)
      isSubmitting = false
      mainContainerNavigationCoordinator.presentedSheet = nil
      onSuccess?(userPrize)
    } catch {
      isSubmitting = false
      presentedAlert = .errorRedeemingPrize
    }
  }

  func cancelButtonTapped() {
    mainContainerNavigationCoordinator.presentedSheet = nil
  }
}
