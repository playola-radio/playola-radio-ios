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

  func testViewAppearedCallsAPIWithStationId() async {
    let calledStationId = LockIsolated<String?>(nil)

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, stationId in
        calledStationId.setValue(stationId)
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.viewAppeared()

    XCTAssertEqual(calledStationId.value, testStationId)
  }

  func testViewAppearedPopulatesQuestionsArray() async {
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

    await model.viewAppeared()

    XCTAssertEqual(model.questions.count, 2)
    XCTAssertEqual(model.questions[0].id, "q1")
    XCTAssertEqual(model.questions[1].id, "q2")
  }

  func testViewAppearedSetsIsLoadingDuringFetch() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    XCTAssertFalse(model.isLoading)

    await model.viewAppeared()

    XCTAssertFalse(model.isLoading)
  }

  func testViewAppearedShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        throw TestError.fetchFailed
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.viewAppeared()

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Error Loading Questions")
  }

  func testViewAppearedDoesNothingWithoutJwt() async {
    let apiCalled = LockIsolated(false)

    @Shared(.auth) var auth = Auth()

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        apiCalled.setValue(true)
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.viewAppeared()

    XCTAssertFalse(apiCalled.value)
  }

  func testViewAppearedCallsFetchQuestions() async {
    let fetchCalled = LockIsolated(false)

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        fetchCalled.setValue(true)
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.viewAppeared()

    XCTAssertTrue(fetchCalled.value)
  }

  func testRefreshPulledDownCallsFetchQuestions() async {
    let fetchCalled = LockIsolated(false)

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        fetchCalled.setValue(true)
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    await model.refreshPulledDown()

    XCTAssertTrue(fetchCalled.value)
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

    model.showMoreButtonTapped(questionId)

    XCTAssertTrue(model.isExpanded(questionId))
  }

  func testToggleExpandedCollapsesExpandedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.showMoreButtonTapped(questionId)
    XCTAssertTrue(model.isExpanded(questionId))

    model.showMoreButtonTapped(questionId)
    XCTAssertFalse(model.isExpanded(questionId))
  }

  func testMultipleQuestionsCanBeExpandedSimultaneously() {
    let model = makeModelWithQuestions()
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.showMoreButtonTapped(firstQuestionId)
    model.showMoreButtonTapped(secondQuestionId)

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
    let loadFileCalled = LockIsolated(false)
    let playCalled = LockIsolated(false)

    let model = withDependencies {
      $0.audioPlayer.loadFile = { _ in
        loadFileCalled.withValue { $0 = true }
      }
      $0.audioPlayer.play = {
        playCalled.withValue { $0 = true }
      }
      $0.audioPlayer.stop = {}
    } operation: {
      makeModelWithQuestions()
    }

    let question = model.questions.first!

    await model.playButtonTapped(question)

    XCTAssertTrue(loadFileCalled.value)
    XCTAssertTrue(playCalled.value)
    XCTAssertEqual(model.playingQuestionId, question.id)
  }

  func testOnPlayTappedStopsPlaybackWhenAlreadyPlaying() async {
    let stopCalled = LockIsolated(false)

    let model = withDependencies {
      $0.audioPlayer.stop = {
        stopCalled.withValue { $0 = true }
      }
    } operation: {
      makeModelWithQuestions()
    }

    let question = model.questions.first!
    model.playingQuestionId = question.id

    await model.playButtonTapped(question)

    XCTAssertTrue(stopCalled.value)
    XCTAssertNil(model.playingQuestionId)
  }

  func testOnPlayTappedStopsPreviousBeforeStartingNew() async {
    let stopCallCount = LockIsolated(0)
    let loadFileCalled = LockIsolated(false)

    let model = withDependencies {
      $0.audioPlayer.stop = {
        stopCallCount.withValue { $0 += 1 }
      }
      $0.audioPlayer.loadFile = { _ in
        loadFileCalled.withValue { $0 = true }
      }
      $0.audioPlayer.play = {}
    } operation: {
      makeModelWithQuestions()
    }

    let firstQuestion = model.questions[0]
    let secondQuestion = model.questions[1]
    model.playingQuestionId = firstQuestion.id

    await model.playButtonTapped(secondQuestion)

    XCTAssertEqual(stopCallCount.value, 1)
    XCTAssertTrue(loadFileCalled.value)
    XCTAssertEqual(model.playingQuestionId, secondQuestion.id)
  }

  func testPlayButtonTappedOnSameQuestionStopsPlayback() async {
    let stopCalled = LockIsolated(false)

    let model = withDependencies {
      $0.audioPlayer.stop = {
        stopCalled.withValue { $0 = true }
      }
      $0.audioPlayer.loadFile = { _ in }
      $0.audioPlayer.play = {}
    } operation: {
      makeModelWithQuestions()
    }

    let question = model.questions.first!
    model.playingQuestionId = question.id

    await model.playButtonTapped(question)

    XCTAssertTrue(stopCalled.value)
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

    await model.playButtonTapped(question)

    XCTAssertNotNil(model.presentedAlert)
    XCTAssertEqual(model.presentedAlert?.title, "Playback Error")
  }

  func testOnPlayTappedDoesNothingWhenNoAudioBlock() async {
    let audioPlayerCalled = LockIsolated(false)

    let model = withDependencies {
      $0.audioPlayer.loadFile = { _ in
        audioPlayerCalled.withValue { $0 = true }
      }
      $0.audioPlayer.play = {
        audioPlayerCalled.withValue { $0 = true }
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    let questionWithoutAudio = ListenerQuestion.mockWith(
      id: "no-audio-question",
      audioBlock: nil
    )
    model.questions = [questionWithoutAudio]

    await model.playButtonTapped(questionWithoutAudio)

    XCTAssertFalse(audioPlayerCalled.value)
  }

  // MARK: - Filter Tests

  func testDefaultFilterIsPending() {
    let model = makeModel()

    XCTAssertEqual(model.selectedFilter, .pending)
  }

  func testFilterOptionsContainsAllExpectedValues() {
    let model = makeModel()

    XCTAssertEqual(model.filterOptions, [.pending, .answered, .all])
  }

  func testFilteredQuestionsReturnsOnlyPendingByDefault() {
    let model = makeModelWithMixedStatusQuestions()

    let filtered = model.filteredQuestions

    XCTAssertEqual(filtered.count, 2)
    XCTAssertTrue(filtered.allSatisfy { $0.status == .pending })
  }

  func testFilteredQuestionsReturnsOnlyAnsweredWhenFilterIsAnswered() {
    let model = makeModelWithMixedStatusQuestions()

    model.selectedFilter = .answered

    let filtered = model.filteredQuestions
    XCTAssertEqual(filtered.count, 1)
    XCTAssertTrue(filtered.allSatisfy { $0.status == .answered })
  }

  func testFilteredQuestionsReturnsAllExceptDeclinedWhenFilterIsAll() {
    let model = makeModelWithMixedStatusQuestions()

    model.selectedFilter = .all

    let filtered = model.filteredQuestions
    XCTAssertEqual(filtered.count, 3)
    XCTAssertTrue(filtered.allSatisfy { $0.status != .declined })
  }

  func testFilterSelectedUpdatesSelectedFilter() {
    let model = makeModel()

    model.filterSelected(.answered)

    XCTAssertEqual(model.selectedFilter, .answered)
  }

  func testFilterDisplayTextForPending() {
    XCTAssertEqual(ListenerQuestionFilter.pending.displayText, "Pending")
  }

  func testFilterDisplayTextForAnswered() {
    XCTAssertEqual(ListenerQuestionFilter.answered.displayText, "Answered")
  }

  func testFilterDisplayTextForAll() {
    XCTAssertEqual(ListenerQuestionFilter.all.displayText, "All")
  }

  // MARK: - Decline Question Tests

  func testDeclineQuestionCallsAPI() async {
    let declineCalled = LockIsolated(false)
    let capturedStationId = LockIsolated<String?>(nil)
    let capturedQuestionId = LockIsolated<String?>(nil)

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in [] }
      $0.api.declineListenerQuestion = { _, stationId, questionId in
        declineCalled.setValue(true)
        capturedStationId.setValue(stationId)
        capturedQuestionId.setValue(questionId)
        return .mockWith(id: questionId, stationId: stationId, status: .declined)
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    model.questions = IdentifiedArray(uniqueElements: [
      .mockWith(id: "q1", stationId: testStationId, status: .pending)
    ])

    await model.declineQuestionSwiped(model.questions[0])

    XCTAssertTrue(declineCalled.value)
    XCTAssertEqual(capturedStationId.value, testStationId)
    XCTAssertEqual(capturedQuestionId.value, "q1")
  }

  func testDeclineQuestionUpdatesLocalState() async {
    let declinedQuestion = ListenerQuestion.mockWith(
      id: "q1",
      stationId: testStationId,
      status: .declined
    )

    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in [] }
      $0.api.declineListenerQuestion = { _, _, _ in declinedQuestion }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    model.questions = IdentifiedArray(uniqueElements: [
      .mockWith(id: "q1", stationId: testStationId, status: .pending)
    ])

    await model.declineQuestionSwiped(model.questions[0])

    XCTAssertEqual(model.questions[id: "q1"]?.status, .declined)
  }

  func testCanDeclineReturnsTrueForPendingQuestion() {
    let model = makeModel()
    let pendingQuestion = ListenerQuestion.mockWith(status: .pending)

    XCTAssertTrue(model.canDecline(pendingQuestion))
  }

  func testCanDeclineReturnsFalseForAnsweredQuestion() {
    let model = makeModel()
    let answeredQuestion = ListenerQuestion.mockWith(status: .answered)

    XCTAssertFalse(model.canDecline(answeredQuestion))
  }

  func testCanDeclineReturnsFalseForDeclinedQuestion() {
    let model = makeModel()
    let declinedQuestion = ListenerQuestion.mockWith(status: .declined)

    XCTAssertFalse(model.canDecline(declinedQuestion))
  }

  func testDeclineQuestionShowsAlertOnError() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in [] }
      $0.api.declineListenerQuestion = { _, _, _ in
        throw APIError.validationError("Failed to decline")
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    model.questions = IdentifiedArray(uniqueElements: [
      .mockWith(id: "q1", stationId: testStationId, status: .pending)
    ])

    await model.declineQuestionSwiped(model.questions[0])

    XCTAssertNotNil(model.presentedAlert)
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

  private func makeModelWithMixedStatusQuestions() -> BroadcastersListenerQuestionPageModel {
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in [] }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }
    model.questions = IdentifiedArray(uniqueElements: [
      .mockWith(id: "q1", status: .pending),
      .mockWith(id: "q2", status: .pending),
      .mockWith(id: "q3", status: .answered),
      .mockWith(id: "q4", status: .declined),
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
