//
//  AskMeAnythingSetupPageTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import PlayolaPlayer
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

  @Test func backButtonTappedPopsNavigation() {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()

    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

    model.backButtonTapped()

    #expect(coordinator.path.isEmpty)
  }

  // MARK: - Intro-recorded state (01b · Build Your Opening)

  @Test func startsInIntroPromptState() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    #expect(!model.hasRecordedIntro)
    expectNoDifference(model.introPromptOpacity, 1)
    #expect(model.introPromptInteractive)
    expectNoDifference(model.openingPlaylistOpacity, 0)
    #expect(!model.openingPlaylistInteractive)
  }

  @Test func hiddenSetupLayerAccessibilityFlipsWithRecordedIntro() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    #expect(!model.introPromptAccessibilityHidden)
    #expect(model.openingPlaylistAccessibilityHidden)

    model.introDuration = 30

    #expect(model.introPromptAccessibilityHidden)
    #expect(!model.openingPlaylistAccessibilityHidden)
  }

  @Test func recordIntroButtonPushesRecorderThatFlipsToOpeningPlaylist() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

    model.recordIntroButtonTapped()

    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected record page to be pushed")
      return
    }
    await recorder.onCompleted?(.mockWith(durationMS: 30000))

    #expect(model.hasRecordedIntro)
    expectNoDifference(model.introPromptOpacity, 0)
    #expect(!model.introPromptInteractive)
    expectNoDifference(model.openingPlaylistOpacity, 1)
    #expect(model.openingPlaylistInteractive)
  }

  @Test func nonPositiveIntroDurationDoesNotFlipToOpeningPlaylist() async {
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)
    coordinator.push(.askMeAnythingSetupPage(model))

    model.recordIntroButtonTapped()

    guard case .recordWithMultiStepPromptPage(let recorder) = coordinator.path.last else {
      Issue.record("Expected record page to be pushed")
      return
    }
    await recorder.onCompleted?(.mockWith(durationMS: 0))
    await recorder.onCompleted?(.mockWith(durationMS: -30000))

    #expect(!model.hasRecordedIntro)
    expectNoDifference(model.introPromptOpacity, 1)
    expectNoDifference(model.readyProgress, 0)
  }

  @Test func displaysOpeningPlaylistCopyAfterIntroRecorded() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    model.introDuration = 30

    expectNoDifference(model.openingPlaylistTitle, "Your opening playlist")
    expectNoDifference(
      model.openingPlaylistSubtitle, "Your station keeps playing while you prepare.")
    expectNoDifference(model.introRowTitle, "Show Intro")
    expectNoDifference(model.introRowSubtitle, "Your voice")
    expectNoDifference(model.introRowDurationLabel, "0:30")
    expectNoDifference(model.addSectionTitle, "Let\u{2019}s get a little ahead")
    expectNoDifference(
      model.addSectionExplanation,
      "Build the first 10 minutes of your show with songs and past Q&As. "
        + "Use Voicetrack to record a quick intro for a song.")
    expectNoDifference(model.voicetrackActionLabel, "Voicetrack")
    expectNoDifference(model.songActionLabel, "Song")
    expectNoDifference(model.qaActionLabel, "Q/A")
  }

  @Test func bottomBarReflectsRecordedIntroProgress() {
    let model = AskMeAnythingSetupPageModel(stationId: testStationId)

    model.introDuration = 30

    expectNoDifference(model.preparedAudioLabel, "0:30 / 10:00 ready")
    expectNoDifference(model.readinessHint, "Add 9:30 more")
    expectNoDifference(model.readyProgress, 0.05)
    #expect(!model.isStartShowEnabled)
  }
}
