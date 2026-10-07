import Dependencies
import Sharing

struct FulfillmentRefreshGenerations: Equatable {
  var started = 0
  var applied = 0
}

extension SharedKey where Self == InMemoryKey<FulfillmentRefreshGenerations>.Default {
  fileprivate static var fulfillmentRefreshGenerations: Self {
    Self[.inMemory("fulfillmentRefreshGenerations"), default: FulfillmentRefreshGenerations()]
  }
}

/// The one place that refreshes `@Shared(.fulfillmentRequests)`. Keeps the last-known list on failure.
/// A response never overwrites the result of a refresh that started after it and already landed.
@MainActor
@discardableResult
func refreshFulfillmentRequests() async -> Bool {
  @Dependency(\.api) var api
  @Dependency(\.analytics) var analytics
  @Shared(.auth) var auth
  @Shared(.fulfillmentRequests) var requests
  @Shared(.fulfillmentRefreshGenerations) var generations
  guard let jwt = auth.jwt else { return false }
  let identity = auth.identity
  $generations.withLock { $0.started += 1 }
  let generation = generations.started
  do {
    let fetched = try await api.getMyFulfillmentRequests(jwt)
    guard auth.identity == identity else { return false }
    guard generation > generations.applied else { return true }
    $generations.withLock { $0.applied = generation }
    $requests.withLock { $0 = fetched }
    return true
  } catch {
    await analytics.track(
      .apiError(endpoint: "getMyFulfillmentRequests", error: error.localizedDescription))
    return false
  }
}
