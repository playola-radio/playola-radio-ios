# API Client & State Management

## Adding API Endpoints

API calls go through `APIClient` dependency (`Core/API/APIClient.swift`).

### Adding a new endpoint

1. Add the endpoint signature to `APIClient` struct:
```swift
@DependencyClient
struct APIClient: Sendable {
  // ... existing endpoints ...

  /// Fetches items for a station
  var getItems: (_ jwtToken: String, _ stationId: String) async throws -> [Item] = { _, _ in [] }
}
```

2. Add the implementation in `APIClient+Live.swift`:
```swift
extension APIClient: DependencyKey {
  static let liveValue: Self = {
    return Self(
      // ... existing implementations ...

      getItems: { token, stationId in
        try await authenticatedGet(path: "/v1/stations/\(stationId)/items", token: token)
      }
    )
  }()
}
```

### Helper functions (in APIClient+Live.swift)

```swift
// GET with auth
try await authenticatedGet<T>(path: "/v1/...", token: token)
try await authenticatedGet<T>(path: "/v1/...", token: token, queryParams: ["status": "active"])

// POST with auth
try await authenticatedPost<T>(path: "/v1/...", token: token, parameters: ["key": "value"])
try await authenticatedPostVoid(path: "/v1/...", token: token)  // No response body

// PUT with auth
try await authenticatedPut<T>(path: "/v1/...", token: token)
try await authenticatedPutVoid(path: "/v1/...", token: token)

// DELETE with auth
try await authenticatedDelete(path: "/v1/...", token: token)
```

### Using in models

```swift
@ObservationIgnored @Dependency(\.api) var api
@ObservationIgnored @Shared(.auth) var auth

func loadItems() async {
  guard let token = auth.playolaToken else { return }
  do {
    items = try await api.getItems(token, stationId)
  } catch {
    presentedAlert = .errorLoadingItems
  }
}
```

## State Management

Uses Point-Free's `swift-sharing` library.

### Using shared state in models

```swift
@ObservationIgnored @Shared(.auth) var auth
@ObservationIgnored @Shared(.stationLists) var stationLists
```

### Modifying shared state (thread-safe)

```swift
$activeTab.withLock { $0 = .rewards }
$stationLists.withLock { $0 = newLists }
```

### Three storage types

All defined in `State/SharedUserDefaults.swift`:

**AppStorage** - persisted to UserDefaults (simple values):
```swift
extension SharedKey where Self == AppStorageKey<Bool>.Default {
  static var showSecretStations: Self {
    Self[.appStorage("showSecretStations"), default: false]
  }
}
```

**FileStorage** - persisted to JSON files (complex objects):
```swift
extension SharedKey where Self == FileStorageKey<Auth>.Default {
  static var auth: Self {
    Self[.fileStorage(.documentsDirectory.appending(component: "auth.json")), default: Auth()]
  }
}
```

**InMemory** - session-only, not persisted:
```swift
extension SharedKey where Self == InMemoryKey<NowPlaying?>.Default {
  static var nowPlaying: Self {
    Self[.inMemory("nowPlaying"), default: nil]
  }
}
```

### Adding new shared state

1. Add extension in `State/SharedUserDefaults.swift`
2. Choose storage type based on persistence needs
3. Use in models with `@ObservationIgnored @Shared(.yourKey)`
