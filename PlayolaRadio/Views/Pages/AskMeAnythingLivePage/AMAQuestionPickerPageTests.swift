//
//  AMAQuestionPickerPageTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AMAQuestionPickerPageTests {

  private let stationId = "station-abc"
  private let baseDate = Date(timeIntervalSince1970: 1_000_000)

  private func noopAdd(_ qa: AMAQuestionAnswer) async throws {}

  private func makeModel(
    questions: [ListenerQuestion],
    showStartedAt: Date? = nil,
    addToShow: @escaping @MainActor (AMAQuestionAnswer) async throws -> Void
  ) -> AMAQuestionPickerPageModel {
    withDependencies {
      $0.date.now = baseDate
      $0.api.getListenerQuestions = { _, _ in questions }
    } operation: {
      AMAQuestionPickerPageModel(
        stationId: stationId, showStartedAt: showStartedAt, addToShow: addToShow)
    }
  }

  private func makePollingModel(
    clock: TestClock<Duration>,
    response: LockIsolated<Result<[ListenerQuestion], any Error>>,
    reportedErrors: LockIsolated<[[String: String]]> = LockIsolated([])
  ) -> AMAQuestionPickerPageModel {
    withDependencies {
      $0.date.now = baseDate
      $0.continuousClock = clock
      $0.api.getListenerQuestions = { _, _ in try response.value.get() }
      $0.errorReporting.reportError = { _, tags in reportedErrors.withValue { $0.append(tags) } }
    } operation: {
      AMAQuestionPickerPageModel(stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
  }

  @Test func newQuestionsArrivingWhileOpenAreAppendedAtTheBottom() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let older = ListenerQuestion.mockWith(
        id: "older", status: .pending, createdAt: baseDate.addingTimeInterval(-300))
      let newer = ListenerQuestion.mockWith(
        id: "newer", status: .pending, createdAt: baseDate.addingTimeInterval(-10))
      let arrived = ListenerQuestion.mockWith(
        id: "arrived", status: .pending, createdAt: baseDate.addingTimeInterval(-1))
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(.success([older, newer]))
      let model = makePollingModel(clock: clock, response: response)
      model.filterSelected(.unanswered)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      expectNoDifference(model.filteredQuestions.map(\.id), ["newer", "older"])

      response.setValue(.success([arrived, older, newer]))
      await clock.advance(by: .seconds(10))
      expectNoDifference(model.filteredQuestions.map(\.id), ["newer", "older", "arrived"])

      task.cancel()
      await task.value
    }
  }

  @Test func questionsArrivingAfterAnEmptyFirstLoadAreAppendedOldestFirst() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let first = ListenerQuestion.mockWith(
        id: "first", createdAt: baseDate.addingTimeInterval(-20))
      let second = ListenerQuestion.mockWith(
        id: "second", createdAt: baseDate.addingTimeInterval(-10))
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(.success([]))
      let model = makePollingModel(clock: clock, response: response)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      response.setValue(.success([second, first]))
      await clock.advance(by: .seconds(10))

      expectNoDifference(model.filteredQuestions.map(\.id), ["first", "second"])
      task.cancel()
      await task.value
    }
  }

  @Test func pollingUpdatesExistingQuestionsInPlaceAndDropsRemovedOnes() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let top = ListenerQuestion.mockWith(
        id: "top", status: .pending, createdAt: baseDate.addingTimeInterval(-10))
      let middle = ListenerQuestion.mockWith(
        id: "middle", status: .pending, createdAt: baseDate.addingTimeInterval(-20))
      let bottom = ListenerQuestion.mockWith(
        id: "bottom", status: .pending, createdAt: baseDate.addingTimeInterval(-30))
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(
        .success([bottom, middle, top]))
      let model = makePollingModel(clock: clock, response: response)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      response.setValue(
        .success([
          .mockWith(id: "top", status: .answered, createdAt: baseDate.addingTimeInterval(-10)),
          bottom,
        ]))
      await clock.advance(by: .seconds(10))

      expectNoDifference(model.questions.map(\.id), ["top", "bottom"])
      expectNoDifference(model.questions[id: "top"]?.status, .answered)
      task.cancel()
      await task.value
    }
  }

  @Test func aFailedPollDoesNotAlertOrShowLoading() async {
    struct PollFailure: Error {}
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let question = ListenerQuestion.mockWith(id: "question")
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(.success([question]))
      let model = makePollingModel(clock: clock, response: response)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      response.setValue(.failure(PollFailure()))
      await clock.advance(by: .seconds(10))

      #expect(model.presentedAlert == nil)
      #expect(!model.isLoading)
      expectNoDifference(model.questions.map(\.id), ["question"])
      task.cancel()
      await task.value
    }
  }

  @Test func aFailedPollIsReportedToErrorReporting() async {
    struct PollFailure: Error {}
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(.success([]))
      let reportedErrors = LockIsolated<[[String: String]]>([])
      let model = makePollingModel(clock: clock, response: response, reportedErrors: reportedErrors)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      response.setValue(.failure(PollFailure()))
      await clock.advance(by: .seconds(10))

      expectNoDifference(reportedErrors.value.map { $0["endpoint"] }, ["getListenerQuestions"])
      task.cancel()
      await task.value
    }
  }

  @Test func aPollThatFailsForLackOfConnectionIsNotReported() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(.success([]))
      let reportedErrors = LockIsolated<[[String: String]]>([])
      let model = makePollingModel(clock: clock, response: response, reportedErrors: reportedErrors)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      response.setValue(.failure(URLError(.notConnectedToInternet)))
      await clock.advance(by: .seconds(10))

      #expect(reportedErrors.value.isEmpty)
      task.cancel()
      await task.value
    }
  }

  @Test func pollingPausesWhileTheAppIsInTheBackground() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let arrived = ListenerQuestion.mockWith(id: "arrived")
      let response = LockIsolated<Result<[ListenerQuestion], any Error>>(.success([]))
      let model = makePollingModel(clock: clock, response: response)
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      model.scenePhaseChanged(newPhase: .background)
      response.setValue(.success([arrived]))
      await clock.advance(by: .seconds(10))
      expectNoDifference(model.questions.map(\.id), [])

      model.scenePhaseChanged(newPhase: .active)
      await clock.advance(by: .seconds(10))
      expectNoDifference(model.questions.map(\.id), ["arrived"])

      task.cancel()
      await task.value
    }
  }

  @Test func aRefreshThatRemovesThePlayingQuestionStopsItsPreview() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let playing = ListenerQuestion.mockWith(id: "playing", status: .pending)
    let response = LockIsolated<[ListenerQuestion]>([playing])
    let stopCount = LockIsolated(0)
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in response.value }
      $0.audioPlayer.stop = { stopCount.withValue { $0 += 1 } }
    } operation: {
      AMAQuestionPickerPageModel(stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
    await model.viewAppeared()
    model.playingQuestionId = "playing"

    response.setValue([.mockWith(id: "playing", status: .declined)])
    await model.refreshPulledDown()

    expectNoDifference(stopCount.value, 1)
    #expect(model.playingQuestionId == nil)
  }

  @Test func aNewPreviewStartedWhileStoppingAnOldOneIsNotClearedByTheOldStop() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let removed = ListenerQuestion.mockWith(id: "removed", status: .pending)
    let response = LockIsolated<[ListenerQuestion]>([removed])
    let stopStarted = AsyncStream<Void>.makeStream()
    let releaseStop = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in response.value }
      $0.audioPlayer.stop = {
        stopStarted.continuation.yield()
        var iterator = releaseStop.stream.makeAsyncIterator()
        await iterator.next()
      }
    } operation: {
      AMAQuestionPickerPageModel(stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
    await model.viewAppeared()
    model.playingQuestionId = "removed"

    response.setValue([.mockWith(id: "removed", status: .declined)])
    let refresh = Task { await model.refreshPulledDown() }
    var startedIterator = stopStarted.stream.makeAsyncIterator()
    await startedIterator.next()

    model.playingQuestionId = "newPreview"
    releaseStop.continuation.yield()
    await refresh.value

    #expect(model.playingQuestionId == "newPreview")
  }

  @Test func aFailedRefreshDuringTheFirstLoadKeepsTheEarlierSuccessfulResponse() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    struct RefreshFailure: Error {}
    let question = ListenerQuestion.mockWith(id: "question")
    let callCount = LockIsolated(0)
    let firstFetchStarted = AsyncStream<Void>.makeStream()
    let releaseFirstFetch = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        let call = callCount.withValue {
          $0 += 1
          return $0
        }
        if call == 1 {
          firstFetchStarted.continuation.yield()
          var iterator = releaseFirstFetch.stream.makeAsyncIterator()
          await iterator.next()
          return [question]
        }
        throw RefreshFailure()
      }
    } operation: {
      AMAQuestionPickerPageModel(stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }

    let firstLoad = Task { await model.viewAppeared() }
    var startedIterator = firstFetchStarted.stream.makeAsyncIterator()
    await startedIterator.next()

    await model.refreshPulledDown()
    releaseFirstFetch.continuation.yield()
    await firstLoad.value

    expectNoDifference(model.questions.map(\.id), ["question"])
    #expect(model.presentedAlert != nil)
  }

  @Test func aFetchThatStartedBeforeADeclineDoesNotUndoIt() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let pending = ListenerQuestion.mockWith(id: "pending", status: .pending)
    let declined = ListenerQuestion.mockWith(id: "pending", status: .declined)
    let blocksFetch = LockIsolated(false)
    let fetchStarted = AsyncStream<Void>.makeStream()
    let releaseFetch = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        if blocksFetch.value {
          fetchStarted.continuation.yield()
          var iterator = releaseFetch.stream.makeAsyncIterator()
          await iterator.next()
        }
        return [pending]
      }
      $0.api.declineListenerQuestion = { _, _, _ in declined }
    } operation: {
      AMAQuestionPickerPageModel(stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
    await model.viewAppeared()

    blocksFetch.setValue(true)
    let refresh = Task { await model.refreshPulledDown() }
    var startedIterator = fetchStarted.stream.makeAsyncIterator()
    await startedIterator.next()
    await model.declineQuestionSwiped(pending)
    releaseFetch.continuation.yield()
    await refresh.value

    expectNoDifference(model.questions[id: "pending"]?.status, .declined)
  }

  @Test func refetchingAfterTheFirstLoadKeepsTheListVisible() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let blocksFetch = LockIsolated(false)
    let fetchStarted = AsyncStream<Void>.makeStream()
    let releaseFetch = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        if blocksFetch.value {
          fetchStarted.continuation.yield()
          var iterator = releaseFetch.stream.makeAsyncIterator()
          await iterator.next()
        }
        return [.mockWith(id: "question")]
      }
    } operation: {
      AMAQuestionPickerPageModel(stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
    await model.viewAppeared()

    blocksFetch.setValue(true)
    let refresh = Task { await model.refreshPulledDown() }
    var startedIterator = fetchStarted.stream.makeAsyncIterator()
    await startedIterator.next()

    #expect(!model.isLoading)
    releaseFetch.continuation.yield()
    await refresh.value
  }

  @Test func filtersAndSortsByNewestFirst() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let questions: [ListenerQuestion] = [
      .mockWith(
        id: "old-answered", status: .answered, createdAt: baseDate.addingTimeInterval(-300)),
      .mockWith(id: "new-pending", status: .pending, createdAt: baseDate.addingTimeInterval(-10)),
      .mockWith(id: "declined", status: .declined, createdAt: baseDate.addingTimeInterval(-5)),
    ]
    let model = makeModel(questions: questions, addToShow: noopAdd)
    await model.viewAppeared()

    model.filterSelected(.all)
    expectNoDifference(model.filteredQuestions.map(\.id), ["new-pending", "old-answered"])

    model.filterSelected(.unanswered)
    expectNoDifference(model.filteredQuestions.map(\.id), ["new-pending"])

    model.filterSelected(.answered)
    expectNoDifference(model.filteredQuestions.map(\.id), ["old-answered"])
  }

  @Test func filterPillsStayVisibleWhenTheActiveFilterIsEmpty() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let model = makeModel(
      questions: [.mockWith(id: "pending", status: .pending)], addToShow: noopAdd)
    await model.viewAppeared()

    model.filterSelected(.answered)

    #expect(model.showEmptyState)
    #expect(model.filterPillsVisible)
    expectNoDifference(model.filterPillsOpacity, 1)
  }

  @Test func answeredBadgeUsesGreenTextAndUnansweredBadgeUsesSecondaryText() {
    let model = makeModel(questions: [], addToShow: noopAdd)

    expectNoDifference(
      model.badgeForeground(.mockWith(id: "answered", status: .answered)),
      Color.playolaSuccessGreen)
    expectNoDifference(
      model.badgeForeground(.mockWith(id: "pending", status: .pending)),
      Color.playolaTextSecondary)
  }

  @Test func decliningAPendingQuestionUpdatesTheIdentifiedQuestion() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let pending = ListenerQuestion.mockWith(id: "pending", status: .pending)
    let declined = ListenerQuestion.mockWith(id: "pending", status: .declined)
    let model = withDependencies {
      $0.api.declineListenerQuestion = { jwt, stationId, questionId in
        expectNoDifference([jwt, stationId, questionId], ["jwt", self.stationId, "pending"])
        return declined
      }
    } operation: {
      AMAQuestionPickerPageModel(
        stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
    model.questions = [pending]

    await model.declineQuestionSwiped(pending)

    expectNoDifference(model.questions[id: "pending"]?.status, .declined)
    #expect(!model.canDecline(declined))
  }

  @Test func decliningAQuestionTwiceWhileTheRequestIsInFlightOnlySendsOnce() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let pending = ListenerQuestion.mockWith(id: "pending", status: .pending)
    let declined = ListenerQuestion.mockWith(id: "pending", status: .declined)
    let calls = LockIsolated(0)
    let started = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let model = withDependencies {
      $0.api.declineListenerQuestion = { _, _, _ in
        calls.withValue { $0 += 1 }
        started.continuation.yield()
        var iterator = release.stream.makeAsyncIterator()
        await iterator.next()
        return declined
      }
    } operation: {
      AMAQuestionPickerPageModel(
        stationId: stationId, showStartedAt: nil, addToShow: noopAdd)
    }
    model.questions = [pending]

    let first = Task { await model.declineQuestionSwiped(pending) }
    var startedIterator = started.stream.makeAsyncIterator()
    await startedIterator.next()
    await model.declineQuestionSwiped(pending)
    release.continuation.yield()
    await first.value

    expectNoDifference(calls.value, 1)
    expectNoDifference(model.questions[id: "pending"]?.status, .declined)
  }

  @Test func marksQuestionsCreatedAfterShowStartAsNewThisShow() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let showStart = baseDate.addingTimeInterval(-100)
    let before = ListenerQuestion.mockWith(
      id: "before", createdAt: baseDate.addingTimeInterval(-200))
    let after = ListenerQuestion.mockWith(id: "after", createdAt: baseDate.addingTimeInterval(-50))
    let model = makeModel(
      questions: [before, after], showStartedAt: showStart, addToShow: noopAdd)
    await model.viewAppeared()

    #expect(!model.isNewThisShow(before))
    #expect(model.isNewThisShow(after))
  }

  @Test func answeredRowTapPushesTheDetailScreenWithoutAdding() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let added = LockIsolated<[String]>([])
    let question = ListenerQuestion.mockWith(
      id: "answered-1", status: .answered, answerAudioBlock: .mockWith(id: "answer"))

    coordinator.push(.askMeAnythingLivePage(AskMeAnythingLivePageModel(stationId: stationId)))
    let model = makeModel(
      questions: [question],
      addToShow: { qa in added.withValue { $0.append(qa.questionId) } })
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    expectNoDifference(added.value, [])
    #expect(model.presentedAlert == nil)
    guard case .amaAnswerQuestionPage = coordinator.path.last else {
      Issue.record("Expected the answer detail page to be pushed")
      return
    }
  }

  @Test func answeredRowTapWithoutAProcessedAnswerAlertsInsteadOfPushing() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let question = ListenerQuestion.mockWith(
      id: "answered-1", status: .answered, answerAudioBlock: nil)

    let model = makeModel(questions: [question], addToShow: noopAdd)
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    #expect(model.presentedAlert != nil)
    #expect(model.airingQuestionId == nil)
    expectNoDifference(coordinator.path.count, 1)
  }

  @Test func unansweredRowTapPushesTheAnswerPageWithoutAdding() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let added = LockIsolated<[String]>([])
    let question = ListenerQuestion.mockWith(id: "pending-1", status: .pending)

    let model = makeModel(
      questions: [question],
      addToShow: { qa in added.withValue { $0.append(qa.questionId) } })
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    expectNoDifference(added.value, [])
    guard case .amaAnswerQuestionPage = coordinator.path.last else {
      Issue.record("Expected the answer page to be pushed")
      return
    }
  }

  @Test func unansweredRowTapHoldsTheRowLockUntilThePickerReappears() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let question = ListenerQuestion.mockWith(id: "pending-1", status: .pending)
    let model = makeModel(questions: [question], addToShow: noopAdd)
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)
    #expect(model.airingQuestionId == "pending-1")
    expectNoDifference(coordinator.path.count, 2)

    await model.questionRowTapped(question)
    expectNoDifference(coordinator.path.count, 2)

    await model.viewAppeared()
    #expect(model.airingQuestionId == nil)
  }
}
