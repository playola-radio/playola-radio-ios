//
//  BroadcastersListenerQuestionPageTests.swift
//  PlayolaRadio
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class BroadcastersListenerQuestionPageTests: XCTestCase {
  private let testStationId = "test-station-id"

  // MARK: - Initialization Tests

  func testInitLoadsMockData() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)

    XCTAssertFalse(model.questions.isEmpty)
    XCTAssertEqual(model.questions.count, 4)
  }

  func testInitSetsStationId() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)

    XCTAssertEqual(model.stationId, testStationId)
  }

  func testInitialStateIsNotLoading() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)

    XCTAssertFalse(model.isLoading)
  }

  func testInitialStateHasNoExpandedQuestions() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)

    XCTAssertTrue(model.expandedQuestionIds.isEmpty)
  }

  func testInitialStateHasNoPlayingQuestion() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)

    XCTAssertNil(model.playingQuestionId)
  }

  // MARK: - Expand/Collapse Tests

  func testIsExpandedReturnsFalseForCollapsedQuestion() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let questionId = model.questions.first!.id

    XCTAssertFalse(model.isExpanded(questionId))
  }

  func testToggleExpandedExpandsCollapsedQuestion() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let questionId = model.questions.first!.id

    model.toggleExpanded(questionId)

    XCTAssertTrue(model.isExpanded(questionId))
  }

  func testToggleExpandedCollapsesExpandedQuestion() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let questionId = model.questions.first!.id

    model.toggleExpanded(questionId)
    XCTAssertTrue(model.isExpanded(questionId))

    model.toggleExpanded(questionId)
    XCTAssertFalse(model.isExpanded(questionId))
  }

  func testMultipleQuestionsCanBeExpandedSimultaneously() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.toggleExpanded(firstQuestionId)
    model.toggleExpanded(secondQuestionId)

    XCTAssertTrue(model.isExpanded(firstQuestionId))
    XCTAssertTrue(model.isExpanded(secondQuestionId))
  }

  // MARK: - Playback Tests

  func testIsPlayingReturnsFalseWhenNotPlaying() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let questionId = model.questions.first!.id

    XCTAssertFalse(model.isPlaying(questionId))
  }

  func testIsPlayingReturnsTrueForPlayingQuestion() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let questionId = model.questions.first!.id

    model.playingQuestionId = questionId

    XCTAssertTrue(model.isPlaying(questionId))
  }

  func testIsPlayingReturnsFalseForDifferentQuestion() {
    let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.playingQuestionId = firstQuestionId

    XCTAssertFalse(model.isPlaying(secondQuestionId))
  }

  func testOnPlayTappedStartsPlaybackWhenNotPlaying() async {
    var loadFileCalled = false
    var playCalled = false

    await withDependencies {
      $0.audioPlayer.loadFile = { _ in
        loadFileCalled = true
      }
      $0.audioPlayer.play = {
        playCalled = true
      }
      $0.audioPlayer.stop = {}
    } operation: {
      let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
      let question = model.questions.first!

      await model.onPlayTapped(question)

      XCTAssertTrue(loadFileCalled)
      XCTAssertTrue(playCalled)
      XCTAssertEqual(model.playingQuestionId, question.id)
    }
  }

  func testOnPlayTappedStopsPlaybackWhenAlreadyPlaying() async {
    var stopCalled = false

    await withDependencies {
      $0.audioPlayer.stop = {
        stopCalled = true
      }
    } operation: {
      let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
      let question = model.questions.first!
      model.playingQuestionId = question.id

      await model.onPlayTapped(question)

      XCTAssertTrue(stopCalled)
      XCTAssertNil(model.playingQuestionId)
    }
  }

  func testOnPlayTappedStopsPreviousBeforeStartingNew() async {
    var stopCallCount = 0
    var loadFileCalled = false

    await withDependencies {
      $0.audioPlayer.stop = {
        stopCallCount += 1
      }
      $0.audioPlayer.loadFile = { _ in
        loadFileCalled = true
      }
      $0.audioPlayer.play = {}
    } operation: {
      let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
      let firstQuestion = model.questions[0]
      let secondQuestion = model.questions[1]
      model.playingQuestionId = firstQuestion.id

      await model.onPlayTapped(secondQuestion)

      XCTAssertEqual(stopCallCount, 1)
      XCTAssertTrue(loadFileCalled)
      XCTAssertEqual(model.playingQuestionId, secondQuestion.id)
    }
  }

  func testStopPlaybackStopsAudioAndClearsPlayingId() async {
    var stopCalled = false

    await withDependencies {
      $0.audioPlayer.stop = {
        stopCalled = true
      }
    } operation: {
      let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
      model.playingQuestionId = "some-question-id"

      await model.stopPlayback()

      XCTAssertTrue(stopCalled)
      XCTAssertNil(model.playingQuestionId)
    }
  }

  // MARK: - Error Handling Tests

  func testOnPlayTappedShowsAlertOnError() async {
    await withDependencies {
      $0.audioPlayer.loadFile = { _ in
        throw TestError.audioLoadFailed
      }
      $0.audioPlayer.stop = {}
    } operation: {
      let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
      let question = model.questions.first!

      XCTAssertNil(model.presentedAlert)

      await model.onPlayTapped(question)

      XCTAssertNotNil(model.presentedAlert)
      XCTAssertEqual(model.presentedAlert?.title, "Playback Error")
    }
  }

  func testOnPlayTappedDoesNothingWhenNoAudioBlock() async {
    var audioPlayerCalled = false

    await withDependencies {
      $0.audioPlayer.loadFile = { _ in
        audioPlayerCalled = true
      }
      $0.audioPlayer.play = {
        audioPlayerCalled = true
      }
    } operation: {
      let model = BroadcastersListenerQuestionPageModel(stationId: testStationId)
      let questionWithoutAudio = ListenerQuestion(
        id: "no-audio-question",
        listenerId: "listener-1",
        stationId: testStationId,
        audioBlockId: "audio-1",
        status: .pending,
        answerAudioBlockId: nil,
        answerSpinId: nil,
        notificationSentAt: nil,
        declinedAt: nil,
        declinedReason: nil,
        createdAt: Date(),
        listener: nil,
        audioBlock: nil,
        answerAudioBlock: nil
      )
      model.questions = [questionWithoutAudio]

      await model.onPlayTapped(questionWithoutAudio)

      XCTAssertFalse(audioPlayerCalled)
    }
  }
}

// MARK: - Test Helpers

private enum TestError: Error, LocalizedError {
  case audioLoadFailed

  var errorDescription: String? {
    switch self {
    case .audioLoadFailed:
      return "Failed to load audio file"
    }
  }
}
