import Alamofire
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
struct ListeningHistoryPageTests {
  @Test
  func libraryEntryLoadsTheFirstServerPage() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let page = ListeningHistoryResponse(
      spins: [
        ListeningHistorySpin(
          id: "spin-one",
          airtime: Date(timeIntervalSince1970: 1_700_000_000),
          audioBlock: AudioBlock.mockWith(id: "song-one"),
          station: ListeningHistoryStation(id: "station-one", name: "Texas Country")
        )
      ],
      pagination: .init(limit: 20, offset: 0, total: 1, hasMore: false)
    )
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, _ in page }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()

    expectNoDifference(model.displaySpins.map(\.id), ["spin-one"])
    expectNoDifference(model.nextOffset, 1)
    expectNoDifference(model.pageState, .loaded)
  }

  @Test
  func detailReusesRecentHistoryAndRefreshesAfterOneMinute() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let clock = LockIsolated(Date(timeIntervalSince1970: 1_700_000_000))
    let calls = LockIsolated(0)
    let page = makeHistoryPage(ids: ["one"])
    let model = withDependencies {
      $0.date = DateGenerator { clock.value }
      $0.api.getListeningHistory = { _, _ in
        calls.withValue { $0 += 1 }
        return page
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    await model.detailAppeared()
    expectNoDifference(calls.value, 1)

    clock.setValue(Date(timeIntervalSince1970: 1_700_000_061))
    await model.detailAppeared()
    expectNoDifference(calls.value, 2)
  }

  @Test
  func laterPageUsesReturnedCountAndDeduplicatesSpins() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let offsets = LockIsolated<[Int]>([])
    let firstPage = makeHistoryPage(ids: ["one", "two"], hasMore: true)
    let nextPage = makeHistoryPage(ids: ["two", "three"], offset: 2)
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, offset in
        offsets.withValue { $0.append(offset) }
        return offset == 0 ? firstPage : nextPage
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    await model.loadMoreIfNeeded(visibleSpinID: "two")

    expectNoDifference(offsets.value, [0, 2])
    expectNoDifference(model.displaySpins.map(\.id), ["one", "two", "three"])
    expectNoDifference(model.nextOffset, 4)
  }

  @Test
  func failedLaterPageWaitsForExplicitRetry() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let calls = LockIsolated(0)
    let firstPage = makeHistoryPage(ids: ["one"], hasMore: true)
    let secondPage = makeHistoryPage(ids: ["two"], offset: 1)
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, offset in
        if offset == 0 { return firstPage }
        let count = calls.withValue { value in
          value += 1
          return value
        }
        if count == 1 { throw URLError(.notConnectedToInternet) }
        return secondPage
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    await model.loadMoreIfNeeded(visibleSpinID: "one")
    #expect(model.loadMoreFailed)
    await model.loadMoreIfNeeded(visibleSpinID: "one")
    #expect(calls.value == 1)
    await model.loadMoreRetryButtonTapped()
    #expect(calls.value == 2)
    expectNoDifference(model.displaySpins.map(\.id), ["one", "two"])
  }

  @Test
  func accountSwitchHidesPriorRowsBeforeLoadingTheNewAccount() async {
    let firstToken = createTestJWT(id: "listener-one")
    let secondToken = createTestJWT(id: "listener-two")
    @Shared(.auth) var auth = Auth(jwtToken: firstToken)
    let firstPage = makeHistoryPage(ids: ["one"])
    let secondPage = makeHistoryPage(ids: ["two"])
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { token, _ in
        token == firstToken ? firstPage : secondPage
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    $auth.withLock { $0 = Auth(jwtToken: secondToken) }
    expectNoDifference(model.displaySpins.map(\.id), [])

    await model.detailAppeared()
    expectNoDifference(model.displaySpins.map(\.id), ["two"])
  }

  @Test
  func failedPullToRefreshKeepsPreviouslyLoadedRows() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let shouldFail = LockIsolated(false)
    let page = makeHistoryPage(ids: ["one"])
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, _ in
        if shouldFail.value { throw URLError(.notConnectedToInternet) }
        return page
      }
      $0.toast.show = { _ in }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    shouldFail.setValue(true)
    await model.refreshRequested()

    expectNoDifference(model.displaySpins.map(\.id), ["one"])
    expectNoDifference(model.pageState, .loaded)
  }

  @Test
  func detailJoinsAnInFlightLibraryRequest() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let started = AsyncStream.makeStream(of: Void.self)
    let pending = LockIsolated<CheckedContinuation<ListeningHistoryResponse, Error>?>(nil)
    let calls = LockIsolated(0)
    let page = makeHistoryPage(ids: ["one"])
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, _ in
        calls.withValue { $0 += 1 }
        started.continuation.yield()
        return try await withCheckedThrowingContinuation { pending.setValue($0) }
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    let libraryLoad = Task { await model.libraryTabSelected() }
    var starts = started.stream.makeAsyncIterator()
    _ = await starts.next()
    let detailLoad = Task { await model.detailAppeared() }
    pending.withValue { continuation in
      continuation?.resume(returning: page)
      continuation = nil
    }
    await libraryLoad.value
    await detailLoad.value

    expectNoDifference(calls.value, 1)
    expectNoDifference(model.displaySpins.map(\.id), ["one"])
  }

  @Test
  func oldAccountResponseCannotReplaceNewAccountRows() async {
    let firstToken = createTestJWT(id: "listener-one")
    let secondToken = createTestJWT(id: "listener-two")
    @Shared(.auth) var auth = Auth(jwtToken: firstToken)
    let started = AsyncStream.makeStream(of: Void.self)
    let pending = LockIsolated<CheckedContinuation<ListeningHistoryResponse, Error>?>(nil)
    let oldPage = makeHistoryPage(ids: ["one"])
    let newPage = makeHistoryPage(ids: ["two"])
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { token, _ in
        if token == secondToken { return newPage }
        started.continuation.yield()
        return try await withCheckedThrowingContinuation { pending.setValue($0) }
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    let oldLoad = Task { await model.libraryTabSelected() }
    var starts = started.stream.makeAsyncIterator()
    _ = await starts.next()
    $auth.withLock { $0 = Auth(jwtToken: secondToken) }
    await model.detailAppeared()
    pending.withValue { continuation in
      continuation?.resume(returning: oldPage)
      continuation = nil
    }
    await oldLoad.value

    expectNoDifference(model.displaySpins.map(\.id), ["two"])
  }

  @Test
  func failedLibraryPrefetchRetriesWhenDetailOpens() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let calls = LockIsolated(0)
    let page = makeHistoryPage(ids: ["one"])
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, _ in
        let call = calls.withValue { value -> Int in
          value += 1
          return value
        }
        if call == 1 { throw URLError(.notConnectedToInternet) }
        return page
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    expectNoDifference(model.pageState, .error)
    await model.detailAppeared()

    expectNoDifference(calls.value, 2)
    expectNoDifference(model.displaySpins.map(\.id), ["one"])
  }

  @Test
  func unauthorizedHistoryShowsSignedOutState() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.api.getListeningHistory = { _, _ in
        throw AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
      }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()

    expectNoDifference(model.pageState, .signedOut)
    expectNoDifference(model.displaySpins.map(\.id), [])
  }

  @Test
  func historyGroupsSpinsByThePhonesCurrentDay() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let currentDay = Date(timeIntervalSince1970: 1_700_000_000)
    let priorDay = Calendar.current.date(byAdding: .day, value: -1, to: currentDay)!
    let page = ListeningHistoryResponse(
      spins: [
        ListeningHistorySpin(
          id: "today", airtime: currentDay,
          audioBlock: AudioBlock.mockWith(id: "song-today"),
          station: ListeningHistoryStation(id: "station-one", name: "Texas Country")
        ),
        ListeningHistorySpin(
          id: "yesterday", airtime: priorDay,
          audioBlock: AudioBlock.mockWith(id: "song-yesterday"),
          station: ListeningHistoryStation(id: "station-one", name: "Texas Country")
        ),
      ],
      pagination: .init(limit: 20, offset: 0, total: 2, hasMore: false)
    )
    let model = withDependencies {
      $0.date = .constant(currentDay)
      $0.api.getListeningHistory = { _, _ in page }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()

    expectNoDifference(model.sections.map(\.title), ["Today", "Yesterday"])
  }

  @Test
  func heartAddsTheSongToExistingLikedSongs() async {
    @Shared(.auth) var auth = Auth(jwtToken: createTestJWT(id: "listener-one"))
    let page = makeHistoryPage(ids: ["one"])
    let likes = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.uuid = .incrementing
      $0.api.getLikedSongs = { _ in [] }
      $0.api.likeSong = { _, _, _ in }
    } operation: {
      LikesManager()
    }
    let model = withDependencies {
      $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
      $0.likesManager = likes
      $0.api.getListeningHistory = { _, _ in page }
    } operation: {
      ListeningHistoryPageModel()
    }

    await model.libraryTabSelected()
    let spin = model.displaySpins[0]
    expectNoDifference(model.isLiked(spin), false)

    model.heartButtonTapped(for: spin)

    expectNoDifference(model.isLiked(spin), true)
    expectNoDifference(likes.userLikes["song-one"]?.spinId, "one")
  }

  private func makeHistoryPage(
    ids: [String], offset: Int = 0, hasMore: Bool = false
  ) -> ListeningHistoryResponse {
    ListeningHistoryResponse(
      spins: ids.map { id in
        ListeningHistorySpin(
          id: id,
          airtime: Date(timeIntervalSince1970: 1_700_000_000),
          audioBlock: AudioBlock.mockWith(id: "song-\(id)"),
          station: ListeningHistoryStation(id: "station-one", name: "Texas Country")
        )
      },
      pagination: .init(limit: 20, offset: offset, total: 10, hasMore: hasMore)
    )
  }
}
