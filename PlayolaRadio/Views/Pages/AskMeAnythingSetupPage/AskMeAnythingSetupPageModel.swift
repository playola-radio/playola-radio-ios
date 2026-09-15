//
//  AskMeAnythingSetupPageModel.swift
//  PlayolaRadio
//

import SwiftUI

@MainActor
@Observable
class AskMeAnythingSetupPageModel: ViewModel {

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String

  var navigationTitle: String { "Ask Me Anything" }
  var setupLabel: String { "SETUP" }

  var introTitle: String { "First, record your intro" }
  var introBody: String {
    "Tell your listeners you\u{2019}re about to do an Ask Me Anything session."
      + "\n\nAsk them to tap the Question button on the Player screen to send a question. "
      + "Let them know you\u{2019}ll do your best to answer as many as you can."
  }
  var recordIntroButtonTitle: String { "Record Intro" }
  var preparationReassurance: String { "Your station will keep playing while you prepare." }

  var preparedAudioLabel: String { "0:00 / 10:00 ready" }
  var readinessHint: String { "Record your intro" }
  var readyProgress: Double { 0 }

  var startShowButtonTitle: String { "Start Show" }
  var isStartShowEnabled: Bool { false }
  var startShowButtonTitleColor: Color { isStartShowEnabled ? .white : .playolaGray }

  // MARK: - User Actions

  func recordIntroButtonTapped() {}

  func startShowButtonTapped() {}
}
