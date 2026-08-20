//
//  StationPlayerTestDoubles.swift
//  PlayolaRadio
//
//  Shared PlayolaTransport doubles for the StationPlayer test files (kept out
//  of StationPlayerTests.swift, which sits at the file_length lint limit).
//

import Combine
import Foundation
import PlayolaPlayer

@testable import PlayolaRadio

/// Records transport calls so StationPlayer's backend routing can be asserted
/// without constructing a real (CoreAudio-backed) PlayolaStationPlayer.
@MainActor
final class SpyPlayolaStationPlayer: PlayolaTransport {
  private let stateSubject = CurrentValueSubject<PlayolaStationPlayer.State, Never>(.idle)
  var statePublisher: AnyPublisher<PlayolaStationPlayer.State, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  var configureCount = 0
  var playCount = 0
  var stopCount = 0
  var pauseForInterruptionCount = 0
  var resumeAfterInterruptionCount = 0
  var outputLatencyCompensation: TimeInterval = 0
  var setRenderBackendCalls: [PlayolaRenderBackend] = []

  func configure(authProvider: PlayolaAuthenticationProvider, baseURL: URL) { configureCount += 1 }
  func setRenderBackend(_ backend: PlayolaRenderBackend) { setRenderBackendCalls.append(backend) }
  func play(stationId: String) async throws { playCount += 1 }
  func stop() { stopCount += 1 }
  func pauseForInterruption() { pauseForInterruptionCount += 1 }
  func resumeAfterInterruption() async throws { resumeAfterInterruptionCount += 1 }
}
