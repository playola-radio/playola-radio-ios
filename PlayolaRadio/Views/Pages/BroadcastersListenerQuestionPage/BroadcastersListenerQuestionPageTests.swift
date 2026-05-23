//
//  BroadcastersListenerQuestionPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct BroadcastersListenerQuestionPageTests {
  private let testStationId = "test-station-id"
  private let testJwt = "test-jwt-token"

  // MARK: - Initialization Tests

  @Test
  func testInitSetsStationId() {
    let model = makeModel()

    #expect(model.stationId == testStationId)
  }

  @Test
  func testInitialStateIsNotLoading() {
    let model = makeModel()

    #expect(!model.isLoading)
  }

  @Test
  func testInitialStateHasNoExpandedQuestions() {
    let model = makeModel()

    #expect(model.expandedQuestionIds.isEmpty)
  }

  @Test
  func testInitialStateHasNoPlayingQuestion() {
    let model = makeModel()

    #expect(model.playingQuestionId == nil)
  }

  @Test
  func testInitialStateHasEmptyQuestions() {
    let model = makeModel()

    #expect(model.questions.isEmpty)
  }

  // MARK: - Fetch Tests

  @Test
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

    #expect(calledStationId.value == testStationId)
  }

  @Test
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

    #expect(model.questions.count == 2)
    #expect(model.questions[0].id == "q1")
    #expect(model.questions[1].id == "q2")
  }

  @Test
  func testViewAppearedSetsIsLoadingDuringFetch() async {
    @Shared(.auth) var auth = Auth(currentUser: nil, jwt: testJwt)

    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        return []
      }
    } operation: {
      BroadcastersListenerQuestionPageModel(stationId: testStationId)
    }

    #expect(!model.isLoading)

    await model.viewAppeared()

    #expect(!model.isLoading)
  }

  @Test
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

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Error Loading Questions")
  }

  @Test
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

    #expect(!apiCalled.value)
  }

  @Test
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

    #expect(fetchCalled.value)
  }

  @Test
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

    #expect(fetchCalled.value)
  }

  // MARK: - Expand/Collapse Tests

  @Test
  func testIsExpandedReturnsFalseForCollapsedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    #expect(!model.isExpanded(questionId))
  }

  @Test
  func testToggleExpandedExpandsCollapsedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.showMoreButtonTapped(questionId)

    #expect(model.isExpanded(questionId))
  }

  @Test
  func testToggleExpandedCollapsesExpandedQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.showMoreButtonTapped(questionId)
    #expect(model.isExpanded(questionId))

    model.showMoreButtonTapped(questionId)
    #expect(!model.isExpanded(questionId))
  }

  @Test
  func testMultipleQuestionsCanBeExpandedSimultaneously() {
    let model = makeModelWithQuestions()
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.showMoreButtonTapped(firstQuestionId)
    model.showMoreButtonTapped(secondQuestionId)

    #expect(model.isExpanded(firstQuestionId))
    #expect(model.isExpanded(secondQuestionId))
  }

  // MARK: - Playback Tests

  @Test
  func testIsPlayingReturnsFalseWhenNotPlaying() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    #expect(!model.isPlaying(questionId))
  }

  @Test
  func testIsPlayingReturnsTrueForPlayingQuestion() {
    let model = makeModelWithQuestions()
    let questionId = model.questions.first!.id

    model.playingQuestionId = questionId

    #expect(model.isPlaying(questionId))
  }

  @Test
  func testIsPlayingReturnsFalseForDifferentQuestion() {
    let model = makeModelWithQuestions()
    let firstQuestionId = model.questions[0].id
    let secondQuestionId = model.questions[1].id

    model.playingQuestionId = firstQuestionId

    #expect(!model.isPlaying(secondQuestionId))
  }

  @Test
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

    #expect(loadFileCalled.value)
    #expect(playCalled.value)
    #expect(model.playingQuestionId == question.id)
  }

  @Test
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

    #expect(stopCalled.value)
    #expect(model.playingQuestionId == nil)
  }

  @Test
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

    #expect(stopCallCount.value == 1)
    #expect(loadFileCalled.value)
    #expect(model.playingQuestionId == secondQuestion.id)
  }

  @Test
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

    #expect(stopCalled.value)
    #expect(model.playingQuestionId == nil)
  }

  // MARK: - Error Handling Tests

  @Test
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

    #expect(model.presentedAlert == nil)

    await model.playButtonTapped(question)

    #expect(model.presentedAlert != nil)
    #expect(model.presentedAlert?.title == "Playback Error")
  }

  @Test
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

    #expect(!audioPlayerCalled.value)
  }

  // MARK: - Filter Tests

  @Test
  func testDefaultFilterIsPending() {
    let model = makeModel()

    #expect(model.selectedFilter == .pending)
  }

  @Test
  func testFilterOptionsContainsAllExpectedValues() {
    let model = makeModel()

    #expect(model.filterOptions == [.pending, .answered, .all])
  }

  @Test
  func testFilteredQuestionsReturnsOnlyPendingByDefault() {
    let model = makeModelWithMixedStatusQuestions()

    let filtered = model.filteredQuestions

    #expect(filtered.count == 2)
    #expect(filtered.allSatisfy { $0.status == .pending })
  }

  @Test
  func testFilteredQuestionsReturnsOnlyAnsweredWhenFilterIsAnswered() {
    let model = makeModelWithMixedStatusQuestions()

    model.selectedFilter = .answered

    let filtered = model.filteredQuestions
    #expect(filtered.count == 1)
    #expect(filtered.allSatisfy { $0.status == .answered })
  }

  @Test
  func testFilteredQuestionsReturnsAllExceptDeclinedWhenFilterIsAll() {
    let model = makeModelWithMixedStatusQuestions()

    model.selectedFilter = .all

    let filtered = model.filteredQuestions
    #expect(filtered.count == 3)
    #expect(filtered.allSatisfy { $0.status != .declined })
  }

  @Test
  func testFilterSelectedUpdatesSelectedFilter() {
    let model = makeModel()

    model.filterSelected(.answered)

    #expect(model.selectedFilter == .answered)
  }

  @Test
  func testFilterDisplayTextForPending() {
    #expect(ListenerQuestionFilter.pending.displayText == "Pending")
  }

  @Test
  func testFilterDisplayTextForAnswered() {
    #expect(ListenerQuestionFilter.answered.displayText == "Answered")
  }

  @Test
  func testFilterDisplayTextForAll() {
    #expect(ListenerQuestionFilter.all.displayText == "All")
  }

  // MARK: - Decline Question Tests

  @Test
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

    #expect(declineCalled.value)
    #expect(capturedStationId.value == testStationId)
    #expect(capturedQuestionId.value == "q1")
  }

  @Test
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

    #expect(model.questions[id: "q1"]?.status == .declined)
  }

  @Test
  func testCanDeclineReturnsTrueForPendingQuestion() {
    let model = makeModel()
    let pendingQuestion = ListenerQuestion.mockWith(status: .pending)

    #expect(model.canDecline(pendingQuestion))
  }

  @Test
  func testCanDeclineReturnsFalseForAnsweredQuestion() {
    let model = makeModel()
    let answeredQuestion = ListenerQuestion.mockWith(status: .answered)

    #expect(!model.canDecline(answeredQuestion))
  }

  @Test
  func testCanDeclineReturnsFalseForDeclinedQuestion() {
    let model = makeModel()
    let declinedQuestion = ListenerQuestion.mockWith(status: .declined)

    #expect(!model.canDecline(declinedQuestion))
  }

  @Test
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

    #expect(model.presentedAlert != nil)
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
