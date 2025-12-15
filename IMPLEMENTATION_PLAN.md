# RecordPage Implementation Plan

## Overview
Implement audio recording functionality for voicetracks, following existing codebase patterns.

**Presentation:** Full screen modal (via `PlayolaSheet.recordPage`)

**Flow:**
1. RecordPage: Record → Accept → calls `onRecordingAccepted(url)` callback → dismisses
2. BroadcastPage: Receives URL, stages recording, converts to m4a, uploads

---

## Stage 1: RecordPageModel State Design ✅ COMPLETE

### Recording Phase Enum
```swift
enum RecordingPhase: Equatable {
  case idle        // No recording yet, show record button
  case recording   // Currently recording audio
  case review      // Has recording, can play/discard/accept
}
```

### Model Properties
```swift
@MainActor
@Observable
class RecordPageModel: ViewModel {
  // MARK: - State
  var recordingPhase: RecordingPhase = .idle
  var recordingDuration: TimeInterval = 0
  var playbackPosition: TimeInterval = 0
  var isPlaying: Bool = false
  var isUploading: Bool = false
  var presentedAlert: PlayolaAlert?
  var recordingURL: URL?

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.audioRecorder) var audioRecorder
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Computed Properties
  var displayTime: String { formatTime(recordingDuration) }
  var playbackProgress: Double { ... }
  var canAcceptRecording: Bool { recordingPhase == .review && !isUploading }
}
```

### Actions
```swift
// Recording
func onRecordTapped() async
func onStopTapped() async

// Review phase
func onPlayPauseTapped()
func onRewindTapped()
func onReRecordTapped()
func onDiscardTapped()
func onAcceptRecordingTapped() async

// Navigation
func onDoneTapped()
```

---

## Stage 2: AudioRecorderClient

**File:** `PlayolaRadio/Core/AudioRecording/AudioRecorderClient.swift`

```swift
import AVFoundation
import Dependencies

@DependencyClient
public struct AudioRecorderClient: Sendable {
  public var requestPermission: @Sendable () async -> Bool
  public var startRecording: @Sendable () async throws -> Void
  public var stopRecording: @Sendable () async throws -> URL
  public var currentTime: @Sendable () -> TimeInterval
  public var isRecording: @Sendable () -> Bool
  public var deleteRecording: @Sendable (URL) async -> Void
}

extension AudioRecorderClient: DependencyKey {
  public static var liveValue: AudioRecorderClient { ... }
}

extension AudioRecorderClient: TestDependencyKey {
  public static let testValue = AudioRecorderClient.noop
}

extension DependencyValues {
  public var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}
```

---

## Stage 3: AudioPlayerClient (for playback)

**File:** `PlayolaRadio/Core/AudioRecording/AudioPlayerClient.swift`

```swift
@DependencyClient
public struct AudioPlayerClient: Sendable {
  public var loadFile: @Sendable (URL) async throws -> Void
  public var play: @Sendable () async -> Void
  public var pause: @Sendable () async -> Void
  public var seek: @Sendable (TimeInterval) async -> Void
  public var currentTime: @Sendable () -> TimeInterval
  public var duration: @Sendable () -> TimeInterval
  public var isPlaying: @Sendable () -> Bool
  public var onPlaybackFinished: @Sendable () -> AsyncStream<Void>
}
```

---

## Stage 4: View Updates

Update `RecordPageView.swift` to:
1. Show different UI based on `recordingPhase`
2. Connect buttons to model actions
3. Update time displays from model state
4. Show recording button (mic) in `.idle` and `.recording` phases
5. Show play button in `.review` phase

### Phase-based UI
```swift
var body: some View {
  switch model.recordingPhase {
  case .idle:
    // Large record button (mic icon)
  case .recording:
    // Large stop button, animated waveform, timer counting up
  case .review:
    // Play button, waveform, scrubber, discard/accept buttons
  }
}
```

---

## Stage 5: API Integration

Add to `APIClient.swift`:
```swift
public var uploadVoiceTrack: @Sendable (
  _ jwt: String,
  _ stationId: String,
  _ audioURL: URL
) async throws -> VoiceTrack
```

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `Core/AudioRecording/AudioRecorderClient.swift` | Create |
| `Core/AudioRecording/AudioPlayerClient.swift` | Create |
| `Views/Pages/RecordPage/RecordPageModel.swift` | Update |
| `Views/Pages/RecordPage/RecordPageView.swift` | Update |
| `Views/Pages/RecordPage/RecordPageTests.swift` | Update |
| `Core/API/APIClient.swift` | Add upload endpoint |
| `Views/Reusable Components/PlayolaAlert.swift` | Add recording alerts |

---

## Alert Extensions Needed
```swift
extension PlayolaAlert {
  static var microphonePermissionDenied: PlayolaAlert
  static var recordingFailed: PlayolaAlert
  static var uploadFailed: PlayolaAlert
  static var discardConfirmation: PlayolaAlert  // with confirm/cancel
}
```

---

## Status: Not Started
