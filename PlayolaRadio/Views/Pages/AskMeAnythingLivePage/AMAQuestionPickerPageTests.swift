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
