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

  private func noopAir(_ id: String) async throws {}

  private func makeModel(
    questions: [ListenerQuestion],
    showStartedAt: Date? = nil,
    airQuestion: @escaping @MainActor (String) async throws -> Void
  ) -> AMAQuestionPickerPageModel {
    withDependencies {
      $0.date.now = baseDate
      $0.api.getListenerQuestions = { _, _ in questions }
    } operation: {
      AMAQuestionPickerPageModel(
        stationId: stationId, showStartedAt: showStartedAt, airQuestion: airQuestion)
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
    let model = makeModel(questions: questions, airQuestion: noopAir)
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
      questions: [.mockWith(id: "pending", status: .pending)], airQuestion: noopAir)
    await model.viewAppeared()

    model.filterSelected(.answered)

    #expect(model.showEmptyState)
    #expect(model.filterPillsVisible)
    expectNoDifference(model.filterPillsOpacity, 1)
  }

  @Test func marksQuestionsCreatedAfterShowStartAsNewThisShow() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    let showStart = baseDate.addingTimeInterval(-100)
    let before = ListenerQuestion.mockWith(
      id: "before", createdAt: baseDate.addingTimeInterval(-200))
    let after = ListenerQuestion.mockWith(id: "after", createdAt: baseDate.addingTimeInterval(-50))
    let model = makeModel(
      questions: [before, after], showStartedAt: showStart, airQuestion: noopAir)
    await model.viewAppeared()

    #expect(!model.isNewThisShow(before))
    #expect(model.isNewThisShow(after))
  }

  @Test func answeredRowTapAirsWithoutOpeningTheAnswerPage() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let aired = LockIsolated<[String]>([])
    let question = ListenerQuestion.mockWith(id: "answered-1", status: .answered)

    coordinator.push(.askMeAnythingLivePage(AskMeAnythingLivePageModel(stationId: stationId)))
    let model = makeModel(
      questions: [question],
      airQuestion: { id in aired.withValue { $0.append(id) } })
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    expectNoDifference(aired.value, ["answered-1"])
    guard case .askMeAnythingLivePage = coordinator.path.last else {
      Issue.record("Expected to pop back to the live page")
      return
    }
    #expect(model.presentedAlert == nil)
  }

  @Test func unansweredRowTapPushesTheAnswerPageWithoutAiring() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let aired = LockIsolated<[String]>([])
    let question = ListenerQuestion.mockWith(id: "pending-1", status: .pending)

    let model = makeModel(
      questions: [question],
      airQuestion: { id in aired.withValue { $0.append(id) } })
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    expectNoDifference(aired.value, [])
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
    let model = makeModel(questions: [question], airQuestion: noopAir)
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

  @Test func airFailureSurfacesAnAlertAndReenablesRows() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let question = ListenerQuestion.mockWith(id: "answered-1", status: .answered)

    coordinator.push(.askMeAnythingLivePage(AskMeAnythingLivePageModel(stationId: stationId)))
    let model = makeModel(
      questions: [question],
      airQuestion: { _ in throw NSError(domain: "offline", code: 1) })
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    #expect(model.presentedAlert != nil)
    #expect(model.airingQuestionId == nil)
    #expect(model.rowInteractive(question.id))
    guard case .amaQuestionPickerPage = coordinator.path.last else {
      Issue.record("Expected to remain on the picker after a failure")
      return
    }
  }

  @Test func silentCancellationLeavesThePickerWithoutAnAlert() async {
    @Shared(.auth) var auth = Auth(jwt: "jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let question = ListenerQuestion.mockWith(id: "answered-1", status: .answered)

    let model = makeModel(
      questions: [question],
      airQuestion: { _ in throw CancellationError() })
    coordinator.push(.amaQuestionPickerPage(model))
    await model.viewAppeared()

    await model.questionRowTapped(question)

    #expect(model.presentedAlert == nil)
    #expect(model.airingQuestionId == nil)
  }
}
