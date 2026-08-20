//
//  StationPlayerRenderBackendTests.swift
//  PlayolaRadio
//
//  Server-flagged sample-buffer renderer selection (PlayolaPlayer 0.21.0+):
//  the flag rides on the rewards profile, is projected into
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
@MainActor
private final class RenderBackendSpyTransport: PlayolaTransport {
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
  func flagOffPlaysWithoutTouchingRenderBackend() async {
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false
    let transport = RenderBackendSpyTransport()
    let player = makePlayer(transport: transport)
    let station = AnyStation.mockPlayola()

    await player.play(station: station)

    #expect(transport.events == [.play(stationId: station.id)])
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

  // MARK: - Decode (RewardsProfile)

  @Test
  func rewardsProfileDecodesFlagAndDefaultsToNilWhenAbsent() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let withFlag = Data(
      """
      {"totalTimeListenedMS":0,"totalMSAvailableForRewards":0,\
      "accurateAsOfTime":"2026-01-01T00:00:00Z","sampleBufferRendererEnabled":true}
      """.utf8)
    #expect(
      try decoder.decode(RewardsProfile.self, from: withFlag).sampleBufferRendererEnabled == true)

    let withoutFlag = Data(
      """
      {"totalTimeListenedMS":0,"totalMSAvailableForRewards":0,\
      "accurateAsOfTime":"2026-01-01T00:00:00Z"}
      """.utf8)
    #expect(
      try decoder.decode(RewardsProfile.self, from: withoutFlag).sampleBufferRendererEnabled == nil)
  }

  // MARK: - Projection (MainContainerModel.loadListeningTracker)

  @Test
  func loadListeningTrackerEnablesFlagWhenServerSendsTrue() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = false

    let model = withDependencies {
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 0,
          totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date(),
          sampleBufferRendererEnabled: true
        )
      }
    } operation: {
      MainContainerModel()
    }

    await model.loadListeningTracker()

    #expect(sampleBufferRendererEnabled == true)
  }

  @Test
  func loadListeningTrackerClearsFlagWhenServerOmitsIt() async {
    @Shared(.auth) var auth = Auth(jwt: "test-jwt")
    @Shared(.sampleBufferRendererEnabled) var sampleBufferRendererEnabled = true

    let model = withDependencies {
      $0.api.getRewardsProfile = { _ in
        RewardsProfile(
          totalTimeListenedMS: 0,
          totalMSAvailableForRewards: 0,
          accurateAsOfTime: Date()
        )
      }
    } operation: {
      MainContainerModel()
    }

    await model.loadListeningTracker()

    #expect(sampleBufferRendererEnabled == false)
  }
}
