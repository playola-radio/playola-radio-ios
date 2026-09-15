//
//  ShowsPageModel.swift
//  PlayolaRadio
//

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

  var navigationTitle: String { "Shows" }
  var introTitle: String { "Go live on your station" }
  var introBody: String { "Start a new show now." }
  var sectionLabel: String { "GET STARTED" }

  // MARK: - View Helpers

  var showTypes: [ShowTypeRow] {
    [
      ShowTypeRow(
        id: .askMeAnything,
        title: "Ask Me Anything",
        description: "Take questions from your listeners live.",
        iconSystemName: "bubble.left.and.bubble.right.fill")
    ]
  }

  // MARK: - User Actions

  func showTypeRowTapped(_ row: ShowTypeRow) {
    switch row.id {
    case .askMeAnything:
      navigationCoordinator.push(
        .askMeAnythingSetupPage(AskMeAnythingSetupPageModel(stationId: stationId)))
    }
  }
}

struct ShowTypeRow: Identifiable, Equatable {
  enum ShowType: Equatable {
    case askMeAnything
  }

  let id: ShowType
  let title: String
  let description: String
  let iconSystemName: String
}
