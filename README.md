[![CircleCI](https://dl.circleci.com/status-badge/img/gh/playola-radio/playola-radio-ios/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/playola-radio/playola-radio-ios/tree/main)

# Playola Radio iOS

Playola Radio is a streaming radio app for iOS featuring curated artist stations, traditional FM radio, and a rewards system for listening time.

## Features

- 🎵 Stream curated artist radio stations and traditional FM stations
- 🎁 Earn rewards points based on listening time
- 🚗 Full CarPlay support
- 👤 User authentication (Apple Sign-In, Google Sign-In)
- 📊 Analytics tracking for listening sessions
- 🎨 Custom station artwork and branding

## Architecture Overview

### Core Technologies

- **UI Framework**: SwiftUI
- **Architecture**: MV (Model-View) with Swift's @Observable framework
- **Dependency Injection**: [Dependencies](https://github.com/pointfreeco/swift-dependencies)
- **State Management**: [Sharing](https://github.com/pointfreeco/swift-sharing)
- **Streaming**: [FRadioPlayer](https://github.com/fethica/FRadioPlayer) + [PlayolaPlayer](https://github.com/playola-radio/playola-player-swift)
- **Analytics**: Mixpanel
- **CI/CD**: GitHub Actions + CircleCI + Fastlane

### Project Structure

```
PlayolaRadio/
├── Assets.xcassets/        # Images, colors, and app icons
├── CarPlay/                # CarPlay scene delegates
├── Config/                 # App configuration and secrets
├── Core/                   # Core business logic and services
│   ├── Analytics/          # Analytics tracking
│   ├── API/                # API client
│   ├── Audio/              # Audio streaming and playback
│   ├── Auth/               # Authentication services
│   ├── ListeningTracker/   # Listening session tracking
│   ├── Mail/               # Email services
│   └── Navigation/         # Navigation coordination
├── Extensions/             # Swift extensions and utilities
├── Models/                 # Data models
├── State/                  # State management
└── Views/                  # SwiftUI views and view models
    ├── Pages/              # Full-screen page views
    └── Reusable Components/# Shared UI components
```

## Getting Started

### Prerequisites

- Xcode 16.0+
- iOS 17.0+ deployment target
- [Homebrew](https://brew.sh) (for development tools)
- Ruby (for Fastlane)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/playola-radio/playola-radio-ios.git
   cd playola-radio-ios
   ```

2. **Install Ruby dependencies**
   ```bash
   bundle install
   ```

3. **Configure secrets**
   ```bash
   cp PlayolaRadio/Config/Secrets-Example.xcconfig PlayolaRadio/Config/Secrets-Local.xcconfig
   ```
   Edit `Secrets-Local.xcconfig` with your API keys and tokens.
   Edit `Secrets-Staging.xcconfig` with your API keys and tokens.

4. **Install Git hooks**
   ```bash
   ./.githooks/install-hooks.sh
   ```

5. **Open in Xcode**
   ```bash
   open PlayolaRadio.xcodeproj
   ```

6. **Select scheme and run**
   - Use `PlayolaRadio` scheme for production
   - Use `PlayolaRadio-Local` scheme for local development
   - Use `PlayolaRadio-Staging` scheme for staging environment

## Development Conventions

### Architecture Patterns

#### Models
All page models inherit from a base `ViewModel` class that provides `Hashable` conformance:

```swift
@MainActor
@Observable
class MyPageModel: ViewModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  
  // State properties
  var isLoading = false
  
  // Actions
  func viewAppeared() async {
    // Implementation
  }
}
```

#### Shared State
Use `@Shared` property wrapper for cross-view state:

```swift
@Shared(.auth) var auth
@Shared(.nowPlaying) var nowPlaying
```

#### Dependencies
Define dependencies using the `@DependencyClient` macro:

```swift
@DependencyClient
struct APIClient: Sendable {
  var getStations: @Sendable () async throws -> IdentifiedArrayOf<StationList>
}
```

### Testing

Tests use XCTest with `@MainActor` for UI-related tests:

```swift
@MainActor
final class MyPageTests: XCTestCase {
  func testSomething() async {
    let model = MyPageModel()
    await model.viewAppeared()
    XCTAssertTrue(model.someState)
  }
}
```

### Code Style

The project uses SwiftLint and swift-format for code consistency:

- SwiftLint rules are defined in `.swiftlint.yml`
- Code is automatically formatted on commit via Git hooks
- Force unwraps require SwiftLint exemption comments

## Common Tasks

### Running Tests
```bash
bundle exec fastlane test
```

### Linting Code
```bash
bundle exec fastlane lint_code
```

### Release Process

1. Go to **Actions** → **Prepare Release** → **Run workflow**
2. Optionally enter a new version number (leave blank to keep current)
3. Wait for workflow to complete (runs tests, bumps build number, commits)
4. `git pull` locally
5. Archive **PlayolaRadio-Staging** → Upload to TestFlight
6. Archive **PlayolaRadio** → Upload to App Store Connect

#### Fixing Bugs During Release
If bugs are found during testing:
1. Fix the bug on `develop` as usual
2. Run the workflow again (build number auto-increments)
3. Pull, archive, upload - no branch juggling needed

## Key Components

### Core Services

#### StationPlayer (`Core/Audio/`)
Central service managing radio playback state and FRadioPlayer integration.

#### ListeningTracker (`Core/ListeningTracker/`)
Tracks listening sessions for analytics and rewards calculation, persisting data locally.

#### APIClient (`Core/API/`)
Handles all network requests to the Playola backend.

#### AnalyticsClient (`Core/Analytics/`)
Manages analytics tracking through Mixpanel.

### View Models

#### MainContainerModel (`Views/Pages/MainContainer/`)
Root view model managing app-wide navigation and sheet presentation.

### Shared State Keys
- `auth`: User authentication state
- `nowPlaying`: Current playback information
- `stationLists`: Available radio stations
- `activeTab`: Current tab selection
- `listeningTracker`: Listening session tracking

## Troubleshooting

### Build Errors
1. Ensure all dependencies are resolved: Product → Update to Latest Package Versions
2. Clean build folder: Product → Clean Build Folder (⇧⌘K)
3. Delete derived data if needed

### Secrets Configuration
Missing secrets will cause build failures. Ensure your `Secrets-Local.xcconfig` contains:
- `MIXPANEL_TOKEN`
- `DEV_ENVIRONMENT`
- API endpoints configuration

## Contributing

1. Create a feature branch from `develop`
2. Make your changes following the coding conventions
3. Ensure all tests pass
4. Submit a pull request to `develop`

## License

Proprietary - All rights reserved