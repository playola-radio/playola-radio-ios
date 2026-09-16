//
//  AskMeAnythingSetupPageModel.swift
//  PlayolaRadio
//

import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class AskMeAnythingSetupPageModel: ViewModel {

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  private let targetDuration: TimeInterval = 600

  var introDuration: TimeInterval?

  // MARK: - User Actions

  func backButtonTapped() {
    navigationCoordinator.pop()
  }

  func recordIntroButtonTapped() {
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingIntro(stationId: stationId)
    recorder.onCompleted = { [weak self] audioBlock in
      guard audioBlock.durationMS > 0 else { return }
      self?.introDuration = TimeInterval(audioBlock.durationMS) / 1000
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func voicetrackActionTapped() {}
  func songActionTapped() {}
  func qaActionTapped() {}

  func startShowButtonTapped() {}

  // MARK: - View Helpers

  var navigationTitle: String { "Ask Me Anything" }
  var setupLabel: String { "SETUP" }

  var hasRecordedIntro: Bool { introDuration != nil }
  var introPromptOpacity: Double { hasRecordedIntro ? 0 : 1 }
  var introPromptInteractive: Bool { !hasRecordedIntro }
  var introPromptAccessibilityHidden: Bool { hasRecordedIntro }
  var openingPlaylistOpacity: Double { hasRecordedIntro ? 1 : 0 }
  var openingPlaylistInteractive: Bool { hasRecordedIntro }
  var openingPlaylistAccessibilityHidden: Bool { !hasRecordedIntro }

  var introTitle: String { "First, record your intro" }
  var introBody: String {
    "Tell your listeners you\u{2019}re about to do an Ask Me Anything session."
      + "\n\nAsk them to tap the Question button on the Player screen to send a question. "
      + "Let them know you\u{2019}ll do your best to answer as many as you can."
  }
  var recordIntroButtonTitle: String { "Record Intro" }
  var preparationReassurance: String { "Your station will keep playing while you prepare." }

  var openingPlaylistTitle: String { "Your opening playlist" }
  var openingPlaylistSubtitle: String { "Your station keeps playing while you prepare." }

  var introRowTitle: String { "Show Intro" }
  var introRowSubtitle: String { "Your voice" }
  var introRowDurationLabel: String { durationLabel(introDuration ?? 0) }

  var addSectionTitle: String { "Let\u{2019}s get a little ahead" }
  var addSectionExplanation: String {
    "Build the first 10 minutes of your show with songs and past Q&As. "
      + "Use Voicetrack to record a quick intro for a song."
  }
  var voicetrackActionLabel: String { "Voicetrack" }
  var songActionLabel: String { "Song" }
  var qaActionLabel: String { "Q/A" }

  var preparedAudioLabel: String {
    "\(durationLabel(introDuration ?? 0)) / \(durationLabel(targetDuration)) ready"
  }
  var readinessHint: String {
    guard let introDuration else { return "Record your intro" }
    return "Add \(durationLabel(max(0, targetDuration - introDuration).rounded(.up))) more"
  }
  var readyProgress: Double {
    guard let introDuration else { return 0 }
    return min(1, introDuration / targetDuration)
  }

  var startShowButtonTitle: String { "Start Show" }
  var isStartShowEnabled: Bool { false }
  var startShowButtonTitleColor: Color { isStartShowEnabled ? .white : .playolaGray }

  // MARK: - Private Helpers

  private func durationLabel(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}
