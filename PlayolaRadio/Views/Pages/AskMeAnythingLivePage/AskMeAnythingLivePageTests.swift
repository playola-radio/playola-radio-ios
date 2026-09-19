//
//  AskMeAnythingLivePageTests.swift
//  PlayolaRadioTests
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AskMeAnythingLivePageTests {
  private func makeSpin(
    id: String, airtimeOffset: TimeInterval, durationMS: Int, now: Date,
    liveShowId: String?, isFiller: Bool? = nil
  ) -> Spin {
    Spin.mockWith(
      id: id,
      airtime: now.addingTimeInterval(airtimeOffset),
      audioBlock: .mockWith(endOfMessageMS: durationMS),
      liveShowId: liveShowId,
      isFiller: isFiller)
  }

  @Test func phaseIsRunningWhenNowPlayingBelongsToShow() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let spins = [
      makeSpin(id: "s1", airtimeOffset: -30, durationMS: 120_000, now: now, liveShowId: "show-1")
    ]
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 1, uniqueUsers: 38, uniqueDevices: 1, anonymousSessions: 0))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()

      #expect(model.phase == .running)
      #expect(model.listenerCountLabel == "38 listening")
    }
  }

  @Test func phaseIsWaitingWhenShowSpinsAreUpcoming() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let spins = [
      makeSpin(id: "cur", airtimeOffset: -10, durationMS: 60_000, now: now, liveShowId: nil),
      makeSpin(id: "s1", airtimeOffset: 50, durationMS: 120_000, now: now, liveShowId: "show-1"),
    ]
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()
      #expect(model.phase == .waiting)
    }
  }

  @Test func neverRevertsRunningToWaitingOnEmptySchedule() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let running = [
      makeSpin(id: "s1", airtimeOffset: -5, durationMS: 120_000, now: now, liveShowId: "show-1")
    ]
    let empty: [Spin] = []
    let box = LockIsolated([running, empty])
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in box.withValue { $0.removeFirst() } }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()  // running
      #expect(model.phase == .running)
      await model.refreshNow()  // schedule momentarily empty
      #expect(model.phase != .waiting)
    }
  }

  @Test func bufferedMeterStopsAtFillerBoundary() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    // running show spin (60s remaining) + a contiguous show spin (120s) + a filler (should stop).
    let spins = [
      makeSpin(id: "s1", airtimeOffset: -60, durationMS: 120_000, now: now, liveShowId: "show-1"),
      makeSpin(id: "s2", airtimeOffset: 60, durationMS: 120_000, now: now, liveShowId: "show-1"),
      makeSpin(
        id: "f1", airtimeOffset: 180, durationMS: 180_000, now: now, liveShowId: "show-1",
        isFiller: true),
    ]
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()
      // s1 ends at now+60, s2 ends at now+180; filler excluded → 180s buffered.
      #expect(model.bufferedMilliseconds == 180_000)
      #expect(model.bufferedMeterLabel == "3:00 buffered")
    }
  }

  @Test func endShowDisabledOnceEnding() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let spins = [
      Spin.mockWith(
        id: "s1", airtime: now.addingTimeInterval(-5),
        audioBlock: .mockWith(endOfMessageMS: 120_000), liveShowId: "show-1")
    ]
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
      $0.api.endLiveShow = { _, _, _, _ in
        EndLiveShowResponse(endingSpinId: "end-1", effectiveEndsAt: now.addingTimeInterval(60))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()
      #expect(model.isEndShowEnabled == true)
      await model.submitEnd(outroAudioBlock: .mockWith(id: "outro"))
      #expect(model.phase == .ending)
      #expect(model.isEndShowEnabled == false)
    }
  }

  @Test func endReplacedDiscardsOutroAndLandsTerminal() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let ourRunning = [
      makeSpin(id: "s1", airtimeOffset: -5, durationMS: 120_000, now: now, liveShowId: "show-1")
    ]
    // Another show has superseded ours: the schedule now shows a different live show.
    let replacing = [
      makeSpin(id: "o1", airtimeOffset: -5, durationMS: 120_000, now: now, liveShowId: "show-2")
    ]
    let box = LockIsolated([ourRunning, replacing])
    let endCalls = LockIsolated(0)
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in box.withValue { $0.removeFirst() } }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
      $0.api.endLiveShow = { _, _, _, _ in
        endCalls.withValue { $0 += 1 }
        throw APIError.liveShowReplaced
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()
      #expect(model.phase == .running)

      await model.submitEnd(outroAudioBlock: .mockWith(id: "outro"))
      #expect(endCalls.value == 1)

      // The outro was discarded; Retry must not re-hit the permanently-gone show.
      await model.retryEndButtonTapped()
      #expect(endCalls.value == 1)

      await model.refreshNow()  // schedule now reflects the replacing show
      #expect(model.phase == .ended)
      #expect(model.doneButtonOpacity == 1)
    }
  }

  @Test func endingStaysUntilEffectiveEndsAtEvenIfScheduleDropsShowSpins() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    let ourRunning = [
      makeSpin(id: "s1", airtimeOffset: -5, durationMS: 120_000, now: now, liveShowId: "show-1")
    ]
    let empty: [Spin] = []  // a post-End refresh that dropped our show spins
    let box = LockIsolated([ourRunning, empty])
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in box.withValue { $0.removeFirst() } }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
      $0.api.endLiveShow = { _, _, _, _ in
        EndLiveShowResponse(endingSpinId: "end-1", effectiveEndsAt: now.addingTimeInterval(120))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()
      await model.submitEnd(outroAudioBlock: .mockWith(id: "outro"))
      // The outro airs until effectiveEndsAt (+120s); a schedule that already dropped the show
      // spins must not flip the monitor to .ended and expose Done prematurely.
      #expect(model.phase == .ending)
      #expect(model.doneButtonOpacity == 0)
    }
  }

  @Test func bufferedCountsUpcomingShowSpinWhenFillerAiringNow() async {
    let now = Date(timeIntervalSince1970: 1_000_000)
    @Shared(.auth) var auth = Auth(jwt: "t")
    // A protected filler is airing now; an upcoming show spin follows. Per spec §7.4 the meter
    // starts at the first upcoming show spin (it does NOT collapse to zero on the filler).
    let spins = [
      makeSpin(
        id: "f0", airtimeOffset: -10, durationMS: 60_000, now: now, liveShowId: "show-1",
        isFiller: true),
      makeSpin(id: "s1", airtimeOffset: 50, durationMS: 120_000, now: now, liveShowId: "show-1"),
    ]
    await withDependencies {
      $0.date = .constant(now)
      $0.api.fetchSchedule = { _, _ in spins }
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        ActiveListeningSessionsResponse(
          summary: .init(totalSessions: 0, uniqueUsers: 0, uniqueDevices: 0, anonymousSessions: 0))
      }
    } operation: {
      let model = AskMeAnythingLivePageModel(
        stationId: "station-1", liveShowId: "show-1", scheduledStartsAt: now)

      await model.refreshNow()
      #expect(model.bufferedMilliseconds == 120_000)
    }
  }
}
