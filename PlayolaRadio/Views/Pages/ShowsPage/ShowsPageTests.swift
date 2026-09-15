//
//  ShowsPageTests.swift
//  PlayolaRadio
//

import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ShowsPageTests {

  private let testStationId = "station-abc"

  @Test func displaysIntroCopy() {
    let model = ShowsPageModel(stationId: testStationId)

    expectNoDifference(model.navigationTitle, "Shows")
    expectNoDifference(model.introTitle, "Go live on your station")
    expectNoDifference(model.introBody, "Start a new show now.")
    expectNoDifference(model.sectionLabel, "GET STARTED")
  }

  @Test func offersAskMeAnythingAsTheOnlyShowType() {
    let model = ShowsPageModel(stationId: testStationId)

    expectNoDifference(
      model.showTypes,
      [
        ShowTypeRow(
          id: .askMeAnything,
          title: "Ask Me Anything",
          description: "Take questions from your listeners live.",
          iconSystemName: "bubble.left.and.bubble.right.fill")
      ])
  }

  @Test func askMeAnythingRowTappedPushesSetupPage() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = ShowsPageModel(stationId: testStationId)

    model.showTypeRowTapped(model.showTypes[0])

    guard case .askMeAnythingSetupPage(let pushedModel) = coordinator.path.last else {
      Issue.record("Expected an askMeAnythingSetupPage to be pushed")
      return
    }
    expectNoDifference(pushedModel.stationId, testStationId)
  }
}
