import Dependencies
import Sharing

/// The one place that refreshes `@Shared(.fulfillmentRequests)`. Keeps the last-known list on failure.
@MainActor
@discardableResult
func refreshFulfillmentRequests() async -> Bool {
  @Dependency(\.api) var api
  @Dependency(\.analytics) var analytics
  @Shared(.auth) var auth
  @Shared(.fulfillmentRequests) var requests
  guard let jwt = auth.jwt else { return false }
  let userId = auth.currentUser?.id
  do {
    let fetched = try await api.getMyFulfillmentRequests(jwt)
    guard auth.jwt == jwt, auth.currentUser?.id == userId else { return false }
    $requests.withLock { $0 = fetched }
    return true
  } catch {
    await analytics.track(
      .apiError(endpoint: "getMyFulfillmentRequests", error: error.localizedDescription))
    return false
  }
}
