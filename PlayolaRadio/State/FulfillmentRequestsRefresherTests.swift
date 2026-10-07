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
}
