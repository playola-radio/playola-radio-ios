import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AMALiveRefreshTests {
  @Test func taskRefreshesListenerCountWithoutReloadingSchedule() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    await withMainSerialExecutor {
      let clock = TestClock()
      let listenerFetches = LockIsolated(0)
      let scheduleFetches = LockIsolated(0)
      let model = withDependencies {
        $0.date.now = Date(timeIntervalSince1970: 1_000_000)
        $0.continuousClock = clock
        $0.api.fetchSchedule = { _, _ in
          scheduleFetches.withValue { $0 += 1 }
          return [.mockWith(liveShowId: "show")]
        }
        $0.api.getActiveListeningSessions = { _, _, _, _ in
          let count = listenerFetches.withValue {
            $0 += 1
            return $0
          }
          return .init(summary: .init(uniqueUsers: count))
        }
        $0.api.getListenerQuestions = { _, _ in [] }
      } operation: {
        AskMeAnythingLivePageModel(stationId: "station-abc")
      }
      let task = Task { await model.task() }

      await clock.advance(by: .seconds(1))
      expectNoDifference(model.listenerCount, 1)
      model.broadcast.liveShowId = "show"
      await clock.advance(by: .seconds(10))

      expectNoDifference(model.listenerCount, 2)
      expectNoDifference(scheduleFetches.value, 1)
      task.cancel()
      await task.value
    }
  }
}

extension AMALiveRefreshTests {
  @Test(arguments: [false, true])
  func staleOrCancelledListenerCountIsDiscarded(cancel: Bool) async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    let entered = AsyncStream<Void>.makeStream()
    let release = AsyncStream<Void>.makeStream()
    let calls = LockIsolated(0)
    let model = withDependencies {
      $0.date.now = Date(timeIntervalSince1970: 1_000_000)
      $0.api.getActiveListeningSessions = { _, _, _, _ in
        let call = calls.withValue {
          $0 += 1
          return $0
        }
        if call == 1 {
          entered.continuation.yield()
          await withCheckedContinuation { continuation in
            Task {
              var iterator = release.stream.makeAsyncIterator()
              await iterator.next()
              continuation.resume()
            }
          }
        }
        return .init(summary: .init(uniqueUsers: call * 10))
      }
    } operation: {
      AskMeAnythingLivePageModel(stationId: "station-abc")
    }
    model.listenerCount = 5
    let first = Task { await model.refreshListenerCount() }
    var iterator = entered.stream.makeAsyncIterator()
    await iterator.next()
    if cancel { first.cancel() } else { await model.refreshListenerCount() }
    release.continuation.yield()
    await first.value
    expectNoDifference(model.listenerCount, cancel ? 5 : 20)
  }
}
