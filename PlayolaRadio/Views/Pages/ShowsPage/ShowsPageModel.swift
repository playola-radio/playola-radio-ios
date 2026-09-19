//
//  ShowsPageModel.swift
//  PlayolaRadio
//

import IdentifiedCollections
import Sharing
import SwiftUI

@MainActor
@Observable
class ShowsPageModel: ViewModel {

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String

  // MARK: - User Actions

  func showTypeRowTapped(_ row: ShowTypeRow) {
    switch row.id {
    case .askMeAnything:
      navigationCoordinator.push(
        .askMeAnythingLivePage(AskMeAnythingLivePageModel(stationId: stationId)))
    }
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Shows" }
  var introTitle: String { "Go live on your station" }
  var introBody: String { "Start a new show now." }
  var sectionLabel: String { "GET STARTED" }

  var showTypes: IdentifiedArrayOf<ShowTypeRow> {
    [
      ShowTypeRow(
        id: .askMeAnything,
        title: "Ask Me Anything",
        description: "Take questions from your listeners live.",
        iconSystemName: "bubble.left.and.bubble.right.fill")
    ]
  }
}

struct ShowTypeRow: Identifiable, Equatable {
  enum ShowType: Hashable {
    case askMeAnything
  }

  let id: ShowType
  let title: String
  let description: String
  let iconSystemName: String
}
