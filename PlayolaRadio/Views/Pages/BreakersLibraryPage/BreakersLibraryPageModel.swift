//
//  BreakersLibraryPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import SwiftUI

@MainActor
@Observable
class BreakersLibraryPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  var categories: IdentifiedArrayOf<StationCategory> = []
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  var navigationTitle: String { "Breakers Library" }
  var emptyStateMessage: String { "No breakers yet." }

  var showsEmptyState: Bool { !isLoading && categories.isEmpty }
  var emptyStateOpacity: Double { showsEmptyState ? 1 : 0 }

  // MARK: - User Actions

  func viewAppeared() async {
    await loadCategories()
  }

  func categoryRowTapped(_ category: StationCategory) {
    navigationCoordinator.push(
      .breakerCategoryDetailPage(BreakerCategoryDetailPageModel(category: category)))
  }

  // MARK: - View Helpers

  func blockCountLabel(for category: StationCategory) -> String {
    let count = category.audioBlocks.count
    return count == 1 ? "1 clip" : "\(count) clips"
  }

  // MARK: - Private Helpers

  private func loadCategories() async {
    guard let token = auth.jwt else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let all = try await api.getStationCategories(token, stationId)
      categories = IdentifiedArray(
        uniqueElements:
          all
          .filter { !$0.isSong }
          .filter { !$0.audioBlocks.isEmpty }
          .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
      )
    } catch {
      presentedAlert = .errorLoadingBreakers(error.localizedDescription)
    }
  }
}

extension PlayolaAlert {
  static func errorLoadingBreakers(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
