import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct FulfillmentRequestsRefresherTests {
  @Test func testFailureKeepsLastKnownList() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    let ok = await withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in throw URLError(.notConnectedToInternet) }
    } operation: {
      await refreshFulfillmentRequests()
    }
    #expect(!ok)
    expectNoDifference(requests, [FulfillmentRequest.mock()])
  }

  @Test func testSuccessReplacesList() async {
    @Shared(.auth) var auth = Auth(jwt: "token")
    @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest.mock()]
    let ok = await withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in [] }
    } operation: {
      await refreshFulfillmentRequests()
    }
    #expect(ok)
    expectNoDifference(requests, [])
  }

  @Test func testAccountChangeDiscardsFetchedList() async {
    let initialAuth = Auth(
      loggedInUser: LoggedInUser(
        id: "first-user", firstName: "First", email: "first@example.com"))
    let changedAuth = Auth(
      loggedInUser: LoggedInUser(
        id: "second-user", firstName: "Second", email: "second@example.com"))
    let initialRequests = [FulfillmentRequest.mock()]
    @Shared(.auth) var auth = initialAuth
    @Shared(.fulfillmentRequests) var requests = initialRequests
    let sharedAuth = $auth
    let ok = await withDependencies {
      $0.api.getMyFulfillmentRequests = { _ in
        sharedAuth.withLock { $0 = changedAuth }
        return []
      }
    } operation: {
      await refreshFulfillmentRequests()
    }
    #expect(!ok)
    expectNoDifference(requests, initialRequests)
  }

  @Test func testOlderRefreshCannotOverwriteNewerRefresh() async {
    await withMainSerialExecutor {
      @Shared(.auth) var auth = Auth(jwt: "token")
      @Shared(.fulfillmentRequests) var requests = [FulfillmentRequest]()
      let stale = [FulfillmentRequest.mock(id: "stale")]
      let fresh = [FulfillmentRequest.mock(id: "fresh")]
      let (startedStream, started) = AsyncStream<Void>.makeStream()
      let gate = LockIsolated<CheckedContinuation<Void, Never>?>(nil)
      let calls = LockIsolated(0)
      await withDependencies {
        $0.api.getMyFulfillmentRequests = { _ in
          let call = calls.withValue {
            $0 += 1
            return $0
          }
          guard call == 1 else { return fresh }
          await withCheckedContinuation { continuation in
            gate.setValue(continuation)
            started.yield()
          }
          return stale
        }
      } operation: {
        let first = Task { await refreshFulfillmentRequests() }
        for await _ in startedStream { break }
        await refreshFulfillmentRequests()
        gate.value?.resume()
        _ = await first.value
      }
      expectNoDifference(requests, fresh)
    }
  }
}
