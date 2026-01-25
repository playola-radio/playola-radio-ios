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
  private let testJwt = "test-jwt-token"

  // MARK: - Initialization Tests

  func testInitSetsStationId() {
    let model = makeModel()

    XCTAssertEqual(model.stationId, testStationId)
  }

  func testInitialStateIsNotLoading() {
    let model = makeModel()

    XCTAssertFalse(model.isLoading)
  }

  func testInitialStateHasNoExpandedQuestions() {
    let model = makeModel()

    XCTAssertTrue(model.expandedQuestionIds.isEmpty)
  }

  func testInitialStateHasNoPlayingQuestion() {
    let model = makeModel()

    XCTAssertNil(model.playingQuestionId)
  }

  func testInitialStateHasEmptyQuestions() {
    let model = makeModel()

    XCTAssertTrue(model.questions.isEmpty)
  }

  // MARK: - Fetch Tests

  func testFetchQuestionsCallsAPIWithStationId() async {
    var calledStationId: String?

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, stationId in
        calledStationId = stationId
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.fetchQuestions()

    XCTAssertEqual(calledStationId, testStationId)
  }

  func testFetchQuestionsPopulatesQuestionsArray() async {
    let mockQuestions: [ListenerQuestion] = [
      .mockWith(id: "q1"),
      .mockWith(id: "q2"),
    ]

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in mockQuestions }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.fetchQuestions()

    XCTAssertEqual(model.questions.count, 2)
    XCTAssertEqual(model.questions[0].id, "q1")
    XCTAssertEqual(model.questions[1].id, "q2")
  }

  func testFetchQuestionsSetsIsLoadingDuringFetch() async {
    var wasLoadingDuringFetch = false

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { [weak model] _, _ in
        wasLoadingDuringFetch = model?.isLoading ?? false
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.fetchQuestions()

    XCTAssertTrue(wasLoadingDuringFetch)
    XCTAssertFalse(model.isLoading)
  }

  func testFetchQuestionsShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        throw TestError.fetchFailed
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.fetchQuestions()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Error Loading Questions")
  }

  func testFetchQuestionsDoesNothingWithoutJwt() async {
    var apiCalled = false

    @Shared(.auth) var auth = Auth()

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        apiCalled = true
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.fetchQuestions()

    XCTAssertFalse(apiCalled)
  }

  func testViewAppearedCallsFetchQuestions() async {
    var fetchCalled = false

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        fetchCalled = true
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.viewAppeared()

    XCTAssertTrue(fetchCalled)
  }

  // MARK: - Expand/Collapse Tests

  func testIsExpandedReturnsFalseForCollapsedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    XCTAssertFalse(model.isExpanded(questionId))
  }

  func testToggleExpandedExpandsCollapsedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.toggleExpanded(questionId)

    XCTAssertTrue(model.isExpanded(questionId))
  }

  func testToggleExpandedCollapsesExpandedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.toggleExpanded(questionId)
    XCTAssertTrue(model.isExpanded(questionId))

    model.toggleExpanded(questionId)
    XCTAssertFalse(model.isExpanded(questionId))
  }

  func testMultipleQuestionsCanBeExpandedSimultaneously() {
    let model = makeModelWithQuestions()
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.toggleExpanded(firstQuestionId)
    model.toggleExpanded(secondQuestionId)

    XCTAssertTrue(model.isExpanded(firstQuestionId))
    XCTAssertTrue(model.isExpanded(secondQuestionId))
  }

  // MARK: - Playback Tests

  func testIsPlayingReturnsFalseWhenNotPlaying() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    XCTAssertFalse(model.isPlaying(questionId))
  }

  func testIsPlayingReturnsTrueForPlayingQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.playingQuestionId = questionId

    XCTAssertTrue(model.isPlaying(questionId))
  }

  func testIsPlayingReturnsFalseForDifferentQuestion() {
    let model = makeModelWithQuestions()
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.playingQuestionId = firstQuestionId

    XCTAssertFalse(model.isPlaying(secondQuestionId))
  }

  func testOnPlayTappedStartsPlaybackWhenNotPlaying() async {
    var loadFileCalled = false
    var playCalled = false

    let model = withDependencies {
      $0.audioPlayer.loadFile = { _ in
        loadFileCalled = true
      }
      $0.audioPlayer.play = {
        playCalled = true
      }
      $0.audioPlayer.stop = {}
    } operation: {
      makeModelWithQuestions()
    }

    let question = model.questions.first!

    await model.onPlayTapped(question)

    XCTAssertTrue(loadFileCalled)
    XCTAssertTrue(playCalled)
    XCTAssertEqual(model.playingQuestionId, question.id)
  }

  func testOnPlayTappedStopsPlaybackWhenAlreadyPlaying() async {
    var stopCalled = false

    let model = withDependencies {
      $0.audioPlayer.stop = {
        stopCalled = true
      }
    } operation: {
      makeModelWithQuestions()
    }

    let question = model.questions.first!
    model.playingQuestionId = question.id

    await model.onPlayTapped(question)

    XCTAssertTrue(stopCalled)
    XCTAssertNil(model.playingQuestionId)
  }

  func testOnPlayTappedStopsPreviousBeforeStartingNew() async {
    var stopCallCount = 0
    var loadFileCalled = false

    let model = withDependencies {
      $0.audioPlayer.stop = {
        stopCallCount += 1
      }
      $0.audioPlayer.loadFile = { _ in
        loadFileCalled = true
      }
      $0.audioPlayer.play = {}
    } operation: {
      makeModelWithQuestions()
    }

    let firstQuestion = model.questions[0]
    let secondQuestion = model.questions[1]
    model.playingQuestionId = firstQuestion.id

    await model.onPlayTapped(secondQuestion)

    XCTAssertEqual(stopCallCount, 1)
    XCTAssertTrue(loadFileCalled)
    XCTAssertEqual(model.playingQuestionId, secondQuestion.id)
  }

  func testStopPlaybackStopsAudioAndClearsPlayingId() async {
    var stopCalled = false

    let model = withDependencies {
      $0.audioPlayer.stop = {
        stopCalled = true
      }
    } operation: {
      makeModelWithQuestions()
    }

    model.playingQuestionId = "some-question-id"

    await model.stopPlayback()

    XCTAssertTrue(stopCalled)
    XCTAssertNil(model.playingQuestionId)
  }

  // MARK: - Error Handling Tests

  func testOnPlayTappedShowsAlertOnError() async {
    let model = withDependencies {
      $0.audioPlayer.loadFile = { _ in
        throw TestError.audioLoadFailed
      }
      $0.audioPlayer.stop = {}
    } operation: {
      makeModelWithQuestions()
    }

    let question = model.questions.first!

    XCTAssertNil(model.presentedAlert)

    await model.onPlayTapped(question)

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Playback Error")
  }

  func testOnPlayTappedDoesNothingWhenNoAudioBlock() async {
    var audioPlayerCalled = false

    let model = withDependencies {
      $0.audioPlayer.loadFile = { _ in
        audioPlayerCalled = true
      }
      $0.audioPlayer.play = {
        audioPlayerCalled = true
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    let questionWithoutAudio = ListenerQuestion.mockWith(
      id: "no-audio-question",
      audioBlock: nil
    )
    model.questions = [questionWithoutAudio]

    await model.onPlayTapped(questionWithoutAudio)

    XCTAssertFalse(audioPlayerCalled)
  }

  // MARK: - Test Helpers

  private func makeModel() -> BroadcastersListenerQuestionPageModel {
    withDependencies {
      $0.api.getListenerQuestions = { _, _ in [] }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }
  }

  private func makeModelWithQuestions() -> BroadcastersListenerQuestionPageModel {
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in [] }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }
    model.questions = IdentifiedArray(uniqueElements: [
      .mockWith(
        id: "q1",
        audioBlock: AudioBlock.mockWith(
          id: "audio-1", downloadUrl: URL(string: "https://example.com/audio1.mp3"))
      ),
      .mockWith(
        id: "q2",
        audioBlock: AudioBlock.mockWith(
          id: "audio-2", downloadUrl: URL(string: "https://example.com/audio2.mp3"))
      ),
    ])
    return model
  }
}

// MARK: - Test Errors

private enum TestError: Error, LocalizedError {
  case audioLoadFailed
  case fetchFailed

  var errorDescription: String? {
    switch self {
    case .audioLoadFailed:
      return "Failed to load audio file"
    case .fetchFailed:
      return "Failed to fetch questions"
    }
  }
}
