//
//  LiveStationsPollerTests.swift
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
struct LiveStationsPollerTests {
  nonisolated private static let accountALiveStation = LiveStationInfo(
    stationId: "account-a-station",
    liveStatus: .voicetracking,
    station: .mockWith(id: "account-a-station")
  )

  @Test
  func testFetchLiveStationsPublishesResponseWhenAccountUnchanged() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []

    let poller = withDependencies {
      $0.api.fetchLiveStations = { _ in [Self.accountALiveStation] }
    } operation: {
      LiveStationsPoller()
    }

    await poller.fetchLiveStations()

    expectNoDifference(liveStations, [Self.accountALiveStation])
  }

  @Test
  func testFetchLiveStationsDiscardsResponseWhenSignedOutDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)

    let poller = withDependencies {
      $0.api.fetchLiveStations = { _ in
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [Self.accountALiveStation]
      }
    } operation: {
      LiveStationsPoller()
    }

    let fetch = Task { await poller.fetchLiveStations() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    $auth.withLock { $0 = Auth() }
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await fetch.value

    expectNoDifference(liveStations, [])
  }

  @Test
  func testFetchLiveStationsDiscardsResponseWhenAccountSwitchesDuringFetch() async {
    @Shared(.auth) var auth = Auth(jwt: "account-a-jwt")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let (fetchStarted, fetchStartedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (releaseFetch, releaseFetchContinuation) = AsyncStream.makeStream(of: Void.self)

    let poller = withDependencies {
      $0.api.fetchLiveStations = { _ in
        fetchStartedContinuation.yield(())
        var releaseFetchIterator = releaseFetch.makeAsyncIterator()
        _ = await releaseFetchIterator.next()
        return [Self.accountALiveStation]
      }
    } operation: {
      LiveStationsPoller()
    }

    let fetch = Task { await poller.fetchLiveStations() }
    var fetchStartedIterator = fetchStarted.makeAsyncIterator()
    _ = await fetchStartedIterator.next()
    $auth.withLock { $0 = Auth(jwt: "account-b-jwt") }
    releaseFetchContinuation.yield(())
    releaseFetchContinuation.finish()
    await fetch.value

    expectNoDifference(liveStations, [])
  }

  @Test
  func testFetchLiveStationsPublishesResponseWhenSameAccountRefreshesTokenDuringFetch() async {
    let user = LoggedInUser(id: "account-a", firstName: "A", email: "a@example.com")
    @Shared(.auth) var auth = Auth(currentUser: user, jwt: "token-before")
    @Shared(.liveStations) var liveStations: [LiveStationInfo] = []
    let (started, startedContinuation) = AsyncStream.makeStream(of: Void.self)
    let (release, releaseContinuation) = AsyncStream.makeStream(of: Void.self)
    let poller = withDependencies {
      $0.api.fetchLiveStations = { _ in
        startedContinuation.yield(())
        var iterator = release.makeAsyncIterator()
        _ = await iterator.next()
        return [Self.accountALiveStation]
      }
    } operation: {
      LiveStationsPoller()
    }

    let fetch = Task { await poller.fetchLiveStations() }
    var startedIterator = started.makeAsyncIterator()
    _ = await startedIterator.next()
    $auth.withLock { $0 = Auth(currentUser: user, jwt: "token-after") }
    releaseContinuation.yield(())
    releaseContinuation.finish()
    await fetch.value

    expectNoDifference(liveStations, [Self.accountALiveStation])
  }
}
