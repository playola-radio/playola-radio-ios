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
  var isLoading = true
  private var hasLoadFailed = false
  @ObservationIgnored private var isCheckingForShow = false
  @ObservationIgnored private var checkGeneration = 0

  // MARK: - User Actions

  func viewAppeared() async {
    guard isCurrentPage else {
      viewDisappeared()
      return
    }
    guard !isCheckingForShow else { return }
    let generation = checkGeneration
    isCheckingForShow = true
    isLoading = true
    hasLoadFailed = false
    defer {
      if generation == checkGeneration {
        isCheckingForShow = false
        if isLoading && isCurrentPage {
          hasLoadFailed = true
          isLoading = false
        }
      }
    }

    let show = AskMeAnythingLivePageModel(stationId: stationId)
    await show.broadcast.loadSchedule()
    guard generation == checkGeneration, !Task.isCancelled, isCurrentPage else { return }
    guard show.broadcast.schedule != nil else {
      hasLoadFailed = true
      isLoading = false
      return
    }
    show.schedulePlaybackChanged()
    guard show.isShowActive else {
      isLoading = false
      return
    }
    var path = navigationCoordinator.path
    path[path.count - 1] = .askMeAnythingLivePage(show)
    navigationCoordinator.path = path
  }

  func viewDisappeared() {
    checkGeneration += 1
    isCheckingForShow = false
    isLoading = true
    hasLoadFailed = false
  }

  func showTypeRowTapped(_ row: ShowTypeRow) {
    guard canChooseShow, isCurrentPage else { return }
    switch row.id {
    case .askMeAnything:
      navigationCoordinator.push(
        .askMeAnythingLivePage(AskMeAnythingLivePageModel(stationId: stationId)))
    }
  }

  // MARK: - View Helpers

  var canChooseShow: Bool { !isLoading && !hasLoadFailed }
  var chooserOpacity: Double { canChooseShow ? 1 : 0 }
  var isStatusVisible: Bool { !canChooseShow }
  var statusOpacity: Double { isStatusVisible ? 1 : 0 }
  var loadingOpacity: Double { isLoading ? 1 : 0 }
  var checkStatusMessage: String {
    hasLoadFailed
      ? "Unable to check for an active show. Please try again."
      : "Checking for an active show…"
  }
  var retryTitles: [String] { hasLoadFailed ? ["Retry"] : [] }
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

  var isCurrentPage: Bool {
    guard case .showsPage(let model) = navigationCoordinator.path.last else { return false }
    return model === self
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
