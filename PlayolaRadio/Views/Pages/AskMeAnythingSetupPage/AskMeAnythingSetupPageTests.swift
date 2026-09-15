//
//  AskMeAnythingSetupPageTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AskMeAnythingSetupPageTests {

  private let testStationId = "station-abc"

  @Test func displaysIntroCopy() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    expectNoDifference(model.navigationTitle, "Ask Me Anything")
    expectNoDifference(model.setupLabel, "SETUP")
    expectNoDifference(model.introTitle, "First, record your intro")
    expectNoDifference(model.recordIntroButtonTitle, "Record Intro")
    expectNoDifference(
      model.preparationReassurance, "Your station will keep playing while you prepare.")
  }

  @Test func startShowIsDisabledAtZeroProgress() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    expectNoDifference(model.preparedAudioLabel, "0:00 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Record your intro")
    expectNoDifference(model.readyProgress, 0)
    #expect(!model.isStartShowEnabled)
  }
}
