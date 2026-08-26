//
//  StationPlayerRenderBackendTests.swift
//  PlayolaRadio
//
//  Server-flagged sample-buffer renderer selection (PlayolaPlayer 0.21.0+):
//  the flag rides on the client config (/v1/users/me/client-config), is projected into
//  @Shared(.sampleBufferRendererEnabled), and is read only at the
//  renderer-selection seam in StationPlayer.play — before the SDK play() that
//  locks the backend.
//

import AVFAudio
import Combine
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

/// Ordered-event transport spy: the seam's contract is not just *that* the
/// backend/latency calls happen, but that they happen BEFORE the SDK `play()`
/// (the backend locks at first play), so the events are recorded as one list.
/// Internal (not private) so NowPlayingUpdaterTests can lock a real
/// StationPlayer's backend the same way the app does — by playing.
@MainActor
final class RenderBackendSpyTransport: PlayolaTransport {
  enum Event: Equatable {
    case setRenderBackend(PlayolaRenderBackend)
    case setOutputLatencyCompensation(TimeInterval)
    case play(stationId: String)
  }

  private let stateSubject = CurrentValueSubject<PlayolaStationPlayer.State, Never>(.idle)
  var statePublisher: AnyPublisher<PlayolaStationPlayer.State, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  var events: [Event] = []
  var outputLatencyCompensation: TimeInterval = 0 {
    didSet { events.append(.setOutputLatencyCompensation(outputLatencyCompensation)) }
  }

  func configure(authProvider: PlayolaAuthenticationProvider, baseURL: URL) {}
  func setRenderBackend(_ backend: PlayolaRenderBackend) {
    events.append(.setRenderBackend(backend))
  }
  func play(stationId: String) async throws { events.append(.play(stationId: stationId)) }
  func stop() {}
  func pauseForInterruption() {}
  func resumeAfterInterruption() async throws {}
}

@Suite(.freshSharedState)
@MainActor
struct StationPlayerRenderBackendTests {

  private func makePlayer(transport: RenderBackendSpyTransport) -> StationPlayer {
    StationPlayer(
      playolaStationPlayer: transport,
      audioSessionCoordinator: AudioSessionCoordinator(session: NoOpAudioSession()))
  }

  // MARK: - Seam (StationPlayer.play)

  @Test
  func flagOffAssertsLegacyBackendAndSkipsLatency() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)
    let station = AnyStation.mockPlayola()

    await player.play(station: station)

    // Legacy is asserted (not merely left alone) so a pre-lock .sampleBuffer
    // selection from a previous flag-on account cannot leak into this session,
    // and no latency compensation is fed on the legacy path.
    #expect(
      transport.events == [
        .setRenderBackend(.legacyEngine),
        .play(stationId: station.id),
      ])
  }

  @Test
  func flagOnSelectsSampleBufferAndSetsLatencyBeforePlay() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)
    let station = AnyStation.mockPlayola()

    await player.play(station: station)

    guard transport.events.count == 3 else {
      Issue.record("expected backend+latency+play, got \(transport.events)")
      return
    }
    #expect(transport.events[0] == .setRenderBackend(.sampleBuffer))
    guard case .setOutputLatencyCompensation = transport.events[1] else {
      Issue.record("latency was not fed before play: \(transport.events)")
      return
    }
    #expect(transport.events[2] == .play(stationId: station.id))
  }

  @Test
  func localOverrideForcesSampleBufferWhenServerFlagOff() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false
    @Shared(.sampleBufferRendererLocalOverride) var localOverride = true
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)

    await player.play(station: AnyStation.mockPlayola())

    #expect(transport.events.first == .setRenderBackend(.sampleBuffer))
  }

  @Test
  func serverKillGateBlocksBothServerFlagAndLocalOverride() async {
    @Shared(.sampleBufferRendererAllowed) var sampleBufferRendererAllowed = false
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    @Shared(.sampleBufferRendererLocalOverride) var localOverride = true
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)
    let station = AnyStation.mockPlayola()

    await player.play(station: station)

    #expect(
      transport.events == [
        .setRenderBackend(.legacyEngine),
        .play(stationId: station.id),
      ])
  }

  // MARK: - Locked-backend record (telemetry seam)

  @Test
  func lockedRenderBackendRecordsFirstSelectionAndIgnoresLaterFlagChanges() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)

    #expect(player.lockedRenderBackend == nil)
    await player.play(station: AnyStation.mockPlayola())
    #expect(player.lockedRenderBackend == .sampleBuffer)

    // The SDK locks the backend at the first play(), so the record must not
    // follow a flag change mid-process.
    $sampleBufferRendererEnabled.withLock { $0 = false }
    await player.play(station: AnyStation.mockPlayola(id: "different-station"))
    #expect(player.lockedRenderBackend == .sampleBuffer)
  }

  @Test
  func lockedRenderBackendRecordsLegacyWhenFlagOff() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)

    await player.play(station: AnyStation.mockPlayola())

    #expect(player.lockedRenderBackend == .legacyEngine)
  }

  @Test
  func firstPlaySetsSentryRenderBackendTagExactlyOnce() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true
    let capturedTags = LockIsolated<[(key: String, value: String)]>([])

    let transport = RenderBackendSpyTransport()
    let player = withDependencies {
      $0.errorReporting.setGlobalTag = { key, value in
        capturedTags.withValue { $0.append((key: key, value: value)) }
      }
    } operation: {
      makePlayer(transport: transport)
    }

    await player.play(station: AnyStation.mockPlayola())
    await player.play(station: AnyStation.mockPlayola(id: "different-station"))

    #expect(capturedTags.value.count == 1)
    #expect(capturedTags.value.first?.key == "render_backend")
    #expect(capturedTags.value.first?.value == "sampleBuffer")
  }

  // MARK: - Decode (ClientConfig)

  @Test
  func clientConfigDecodesFlagAndDefaultsToNilWhenAbsent() throws {
    let decoder = JSONDecoder()

    let withFlag = Data(#"{"sampleBufferRendererEnabled":true}"#.utf8)
    #expect(
      try decoder.decode(ClientConfig.self, from: withFlag).sampleBufferRendererEnabled == true)

    let withoutFlag = Data("{}".utf8)
    #expect(
      try decoder.decode(ClientConfig.self, from: withoutFlag).sampleBufferRendererEnabled == nil)
  }

  // MARK: - Projection (MainContainerModel.loadClientConfig)

  @Test
  func loadClientConfigEnablesFlagWhenServerSendsTrue() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false

    let model = withDependencies {
      $0.api.getClientConfig = { _ in
        ClientConfig(sampleBufferRendererEnabled: true)
      }
    } operation: {
      MainContainerModel()
    }

    await model.loadClientConfig()

    #expect(sampleBufferRendererEnabled == true)
  }

  @Test
  func loadClientConfigClearsFlagWhenServerOmitsIt() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true

    let model = withDependencies {
      $0.api.getClientConfig = { _ in ClientConfig() }
    } operation: {
      MainContainerModel()
    }

    await model.loadClientConfig()

    #expect(sampleBufferRendererEnabled == false)
  }

  @Test
  func loadClientConfigProjectsKillGateAndDefaultsToAllowed() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererAllowed) var sampleBufferRendererAllowed = true

    let killed = withDependencies {
      $0.api.getClientConfig = { _ in ClientConfig(sampleBufferRendererAllowed: false) }
    } operation: {
      MainContainerModel()
    }
    await killed.loadClientConfig()
    #expect(sampleBufferRendererAllowed == false)

    let absent = withDependencies {
      $0.api.getClientConfig = { _ in ClientConfig() }
    } operation: {
      MainContainerModel()
    }
    await absent.loadClientConfig()
    #expect(sampleBufferRendererAllowed == true)
  }

  @Test
  func loadClientConfigDiscardsResponseAfterSignOutMidFlight() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false

    let model = withDependencies {
      $0.api.getClientConfig = { _ in
        // Simulate a sign-out landing while the request is in flight.
        @Shared(.auth) var innerAuth: Auth
        $innerAuth.withLock { $0 = Auth() }
        return ClientConfig(sampleBufferRendererEnabled: true)
      }
    } operation: {
      MainContainerModel()
    }

    await model.loadClientConfig()

    #expect(sampleBufferRendererEnabled == false)
  }

  @Test
  func loadClientConfigFailureLeavesConservativeDefault() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false

    struct FetchFailed: Error {}
    let model = withDependencies {
      $0.api.getClientConfig = { _ in throw FetchFailed() }
    } operation: {
      MainContainerModel()
    }

    await model.loadClientConfig()

    #expect(sampleBufferRendererEnabled == false)
  }
}
