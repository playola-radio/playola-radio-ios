//
//  AskMeAnythingLiveAirQuestionTests.swift
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
struct AskMeAnythingLiveAirQuestionTests {

  private let testStationId = "station-abc"

  private func makeLiveAirModel(
    now: Date,
    insert: @escaping @Sendable (String, String, String) async throws -> [Spin],
    getQuestions: @escaping @Sendable (String, String) async throws -> [ListenerQuestion] = {
      _, _ in []
    }
  ) -> AskMeAnythingLivePageModel {
    withDependencies {
      $0.date.now = now
      $0.api.insertListenerQuestionSpin = insert
      $0.api.getListenerQuestions = getQuestions
    } operation: {
      let model = AskMeAnythingLivePageModel(stationId: testStationId)
      model.broadcast.liveShowId = "show"
      model.broadcast.schedule = Schedule(
        stationId: testStationId,
        spins: [
          .mockWith(
            id: "current", airtime: now.addingTimeInterval(-30),
            audioBlock: .mockWith(endOfMessageMS: 120_000), liveShowId: "show"),
          .mockWith(
            id: "filler", airtime: now.addingTimeInterval(150),
            audioBlock: .mockWith(endOfMessageMS: 185_000), liveShowId: "show", isFiller: true),
        ],
        dateProvider: DependencyDateProvider())
      return model
    }
  }

  nonisolated private static func airedPair(now: Date) -> [Spin] {
    [
      .mockWith(
        id: "aired-question", airtime: now.addingTimeInterval(30),
        audioBlock: .mockWith(id: "q", endOfMessageMS: 30_000),
        spinGroupId: "pair", liveShowId: "show"),
      .mockWith(
        id: "aired-answer", airtime: now.addingTimeInterval(60),
        audioBlock: .mockWith(id: "a", endOfMessageMS: 54_000),
        spinGroupId: "pair", liveShowId: "show"),
    ]
  }

  @Test func airingAnsweredQuestionInsertsThePairAndRefreshesQuestions() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let insertArgs = LockIsolated<[String]>([])
    let model = makeLiveAirModel(
      now: now,
      insert: { jwt, questionId, placeAfter in
        insertArgs.withValue { $0 = [jwt, questionId, placeAfter] }
        return Self.airedPair(now: now)
      },
      getQuestions: { _, _ in [.mockWith(id: "refreshed", status: .answered)] })

    try await withDependencies {
      $0.date.now = now
    } operation: {
      try await model.airQuestion("question-1")

      expectNoDifference(insertArgs.value, ["test-jwt", "question-1", "current"])
      expectNoDifference(
        model.broadcast.upcomingSpins.map(\.id), ["aired-question", "aired-answer"])
      expectNoDifference(model.listenerQuestions.map(\.id), ["refreshed"])
      #expect(!model.isAddingToShow)
    }
  }

  @Test func airingRethrowsInsertFailureWithoutRefreshing() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let refreshed = LockIsolated(false)
    let model = makeLiveAirModel(
      now: now,
      insert: { _, _, _ in throw APIError.dataNotValid },
      getQuestions: { _, _ in
        refreshed.setValue(true)
        return []
      })

    await #expect(throws: APIError.self) {
      try await model.airQuestion("question-1")
    }
    #expect(!refreshed.value)
    expectNoDifference(model.broadcast.upcomingSpins.map(\.id), [])
    #expect(!model.isAddingToShow)
  }

  @Test func airingWhileAlreadyAddingThrowsWithoutInserting() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let insertCalls = LockIsolated(0)
    let model = makeLiveAirModel(
      now: now,
      insert: { _, _, _ in
        insertCalls.withValue { $0 += 1 }
        return Self.airedPair(now: now)
      })
    model.isAddingToShow = true

    await #expect(throws: CancellationError.self) {
      try await model.airQuestion("question-1")
    }
    expectNoDifference(insertCalls.value, 0)
  }

  @Test func airingWithoutLiveShowThrowsWithoutInserting() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let insertCalls = LockIsolated(0)
    let model = makeLiveAirModel(
      now: now,
      insert: { _, _, _ in
        insertCalls.withValue { $0 += 1 }
        return Self.airedPair(now: now)
      })
    model.broadcast.liveShowId = nil

    await #expect(throws: CancellationError.self) {
      try await model.airQuestion("question-1")
    }
    expectNoDifference(insertCalls.value, 0)
  }

  @Test func refreshFailureAfterAiringKeepsTheNewScheduleWithoutReinserting() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let now = Date(timeIntervalSince1970: 1_000_000)
    let insertCalls = LockIsolated(0)
    let model = makeLiveAirModel(
      now: now,
      insert: { _, _, _ in
        insertCalls.withValue { $0 += 1 }
        return Self.airedPair(now: now)
      },
      getQuestions: { _, _ in throw APIError.dataNotValid })

    try await withDependencies {
      $0.date.now = now
    } operation: {
      try await model.airQuestion("question-1")

      expectNoDifference(insertCalls.value, 1)
      expectNoDifference(
        model.broadcast.upcomingSpins.map(\.id), ["aired-question", "aired-answer"])
      #expect(model.presentedAlert == nil)
    }
  }

  @Test func qaActionTappedPushesPickerWiredToAir() async throws {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let now = Date(timeIntervalSince1970: 1_000_000)
    let insertCalls = LockIsolated(0)
    let model = makeLiveAirModel(
      now: now,
      insert: { _, _, _ in
        insertCalls.withValue { $0 += 1 }
        return Self.airedPair(now: now)
      })
    model.scheduledStartsAt = now.addingTimeInterval(-120)
    coordinator.push(.askMeAnythingLivePage(model))

    model.qaActionTapped()

    guard case .amaQuestionPickerPage(let picker) = coordinator.path.last else {
      Issue.record("Expected the question picker to be pushed")
      return
    }
    expectNoDifference(picker.showStartedAt, now.addingTimeInterval(-120))

    try await picker.airQuestion("question-1")
    expectNoDifference(insertCalls.value, 1)
  }

  @Test func airingAfterTheShowIsReplacedThrowsWithoutInserting() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.mainContainerNavigationCoordinator) var coordinator =
      MainContainerNavigationCoordinator()
    let now = Date(timeIntervalSince1970: 1_000_000)
    let insertCalls = LockIsolated(0)
    let model = makeLiveAirModel(
      now: now,
      insert: { _, _, _ in
        insertCalls.withValue { $0 += 1 }
        return Self.airedPair(now: now)
      })
    coordinator.push(.askMeAnythingLivePage(model))

    model.qaActionTapped()
    guard case .amaQuestionPickerPage(let picker) = coordinator.path.last else {
      Issue.record("Expected the question picker to be pushed")
      return
    }

    model.broadcast.liveShowId = "show-2"

    await #expect(throws: CancellationError.self) {
      try await picker.airQuestion("question-1")
    }
    expectNoDifference(insertCalls.value, 0)
  }
}
