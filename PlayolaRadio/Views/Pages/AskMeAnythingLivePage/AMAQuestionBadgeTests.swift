//
//  AMAQuestionBadgeTests.swift
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
struct AMAQuestionBadgeTests {

  private let testStationId = "station-abc"

  nonisolated private static let now = Date(timeIntervalSince1970: 1_000_000)

  nonisolated private static func playingShowSpin(startedAt airtime: Date) -> Spin {
    .mockWith(
      id: "playing", airtime: airtime, audioBlock: .mockWith(endOfMessageMS: 180_000),
      liveShowId: "show")
  }

  /// Runs `operation` inside the dependency scope: the schedule resolves "now" lazily, so the
  /// model must be exercised there, not just constructed there.
  private func withBadgeModel(
    showSpinAirtime: Date,
    endedShowSpins: [Spin] = [],
    questions: LockIsolated<[ListenerQuestion]>,
    clock: TestClock<Duration> = TestClock(),
    operation: (AskMeAnythingLivePageModel) async -> Void
  ) async {
    await withDependencies {
      $0.date.now = Self.now
      $0.continuousClock = clock
      $0.api.fetchSchedule = { _, _ in
        endedShowSpins + [Self.playingShowSpin(startedAt: showSpinAirtime)]
      }
      $0.api.getActiveListeningSessions = { _, _, _, _ in .init(summary: .init(uniqueUsers: 1)) }
      $0.api.getListenerQuestions = { _, _ in questions.value }
    } operation: {
      await operation(AskMeAnythingLivePageModel(stationId: testStationId))
    }
  }

  @Test func qaBadgeCountsUnansweredQuestionsAskedDuringTheShow() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let showStart = Self.now.addingTimeInterval(-30)
    let questions = LockIsolated<[ListenerQuestion]>([
      .mockWith(id: "before", status: .pending, createdAt: showStart.addingTimeInterval(-1)),
      .mockWith(id: "at-start", status: .pending, createdAt: showStart),
      .mockWith(id: "later", status: .pending, createdAt: Self.now),
      .mockWith(id: "answered", status: .answered, createdAt: Self.now),
      .mockWith(id: "declined", status: .declined, createdAt: Self.now),
    ])
    await withBadgeModel(showSpinAirtime: showStart, questions: questions) { model in
      await model.viewAppeared()

      expectNoDifference(model.qaBadgeLabels, ["2"])
      expectNoDifference(model.qaBadgeAccessibilityLabel, "2 new questions")
    }
  }

  @Test func qaBadgeIsHiddenWithoutAShow() {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let model = AskMeAnythingLivePageModel(stationId: testStationId)
    model.listenerQuestions = [.mockWith(status: .pending, createdAt: Self.now)]

    expectNoDifference(model.qaBadgeLabels, [])
  }

  @Test func startingAShowRemembersItsStartTime() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.amaShowStartTimes) var amaShowStartTimes = ["old-show": .distantPast]
    let startsAt = Self.now.addingTimeInterval(120)
    let model = withDependencies {
      $0.date.now = Self.now
      $0.api.startLiveShow = { _, _, _ in
        StartLiveShowResponse(
          liveShowId: "show-1", scheduledStartsAt: startsAt, scheduledEndsAt: .distantFuture)
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }
    model.openingItems.append(
      AMAOpeningItem(id: UUID(), content: .intro(.mockWith(id: "intro", durationMS: 600_000))))

    await model.startShowButtonTapped()

    expectNoDifference(amaShowStartTimes, ["old-show": .distantPast, "show-1": startsAt])
  }

  @Test func reenteringAShowCountsQuestionsSinceItsRememberedStart() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let rememberedStart = Self.now.addingTimeInterval(-600)
    @Shared(.amaShowStartTimes) var amaShowStartTimes = ["show": rememberedStart]
    let questions = LockIsolated<[ListenerQuestion]>([
      .mockWith(id: "early", status: .pending, createdAt: Self.now.addingTimeInterval(-300))
    ])
    await withBadgeModel(
      showSpinAirtime: Self.now.addingTimeInterval(-30), questions: questions
    ) { model in
      await model.viewAppeared()

      expectNoDifference(model.scheduledStartsAt, rememberedStart)
      expectNoDifference(model.qaBadgeLabels, ["1"])
    }
  }

  @Test func firstVisitToAShowRemembersTheObservedStart() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.amaShowStartTimes) var amaShowStartTimes = [:]
    let showStart = Self.now.addingTimeInterval(-30)
    await withBadgeModel(showSpinAirtime: showStart, questions: LockIsolated([])) { model in
      await model.viewAppeared()
    }

    expectNoDifference(amaShowStartTimes, ["show": showStart])
  }

  @Test func firstVisitMidShowRemembersTheShowsEarliestSpin() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.amaShowStartTimes) var amaShowStartTimes = [:]
    let showStart = Self.now.addingTimeInterval(-600)
    let endedSpin = Spin.mockWith(
      id: "ended", airtime: showStart, audioBlock: .mockWith(endOfMessageMS: 60_000),
      liveShowId: "show")
    await withBadgeModel(
      showSpinAirtime: Self.now.addingTimeInterval(-30), endedShowSpins: [endedSpin],
      questions: LockIsolated([])
    ) { model in
      await model.viewAppeared()
    }

    expectNoDifference(amaShowStartTimes, ["show": showStart])
  }

  @Test func anOlderQuestionFetchNeverOverwritesANewerOne() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let (staleStarted, staleStartedContinuation) = AsyncStream<Void>.makeStream()
    let (releaseStale, releaseStaleContinuation) = AsyncStream<Void>.makeStream()
    let calls = LockIsolated(0)
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in
        let call = calls.withValue { calls in
          calls += 1
          return calls
        }
        guard call == 1 else { return [.mockWith(id: "newer", status: .pending)] }
        staleStartedContinuation.yield()
        for await _ in releaseStale { break }
        return []
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }

    let staleRefresh = Task { await model.refreshListenerQuestions() }
    for await _ in staleStarted { break }
    await model.refreshListenerQuestions()
    releaseStaleContinuation.yield()
    await staleRefresh.value

    expectNoDifference(model.listenerQuestions.map(\.id), ["newer"])
  }

  @Test func aNonNetworkQuestionRefreshFailureIsReported() async {
    struct RefreshFailure: Error {}
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let reportedTags = LockIsolated<[String: String]?>(nil)
    let model = withDependencies {
      $0.api.getListenerQuestions = { _, _ in throw RefreshFailure() }
      $0.errorReporting.reportError = { _, tags in reportedTags.setValue(tags) }
    } operation: {
      AskMeAnythingLivePageModel(stationId: testStationId)
    }

    await model.refreshListenerQuestions()

    expectNoDifference(reportedTags.value?["endpoint"], "getListenerQuestions")
  }

  @Test func qaBadgePicksUpQuestionsArrivingDuringTheShow() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let questions = LockIsolated<[ListenerQuestion]>([])
      await withBadgeModel(
        showSpinAirtime: Self.now.addingTimeInterval(-30), questions: questions, clock: clock
      ) { model in
        let task = Task { await model.task() }
        await clock.advance(by: .seconds(1))
        expectNoDifference(model.qaBadgeLabels, [])

        questions.setValue([.mockWith(id: "arrived", status: .pending, createdAt: Self.now)])
        await clock.advance(by: .seconds(10))

        expectNoDifference(model.qaBadgeLabels, ["1"])
        task.cancel()
        await task.value
      }
    }
  }
}
