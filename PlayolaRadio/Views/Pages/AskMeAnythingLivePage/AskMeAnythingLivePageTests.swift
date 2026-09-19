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
}
