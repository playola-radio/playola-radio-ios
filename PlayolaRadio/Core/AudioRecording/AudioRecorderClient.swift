//
//  AudioRecorderClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import AVFoundation
import Dependencies

public struct AudioRecorderClient: Sendable {
  public var requestPermission: @Sendable () async -> Bool
  public var startRecording: @Sendable () async throws -> Void
  public var stopRecording: @Sendable () async throws -> URL
  public var currentTime: @Sendable () async -> TimeInterval
  public var isRecording: @Sendable () async -> Bool
  public var deleteRecording: @Sendable (URL) async -> Void
}

// MARK: - Live Implementation

extension AudioRecorderClient: DependencyKey {
  public static var liveValue: AudioRecorderClient {
    // TODO: Implement
    AudioRecorderClient(
      requestPermission: { false },
      startRecording: {},
      stopRecording: { URL(fileURLWithPath: "") },
      currentTime: { 0 },
      isRecording: { false },
      deleteRecording: { _ in }
    )
  }
}

// MARK: - Test Implementation

extension AudioRecorderClient: TestDependencyKey {
  public static var testValue: AudioRecorderClient {
    AudioRecorderClient(
      requestPermission: { false },
      startRecording: {},
      stopRecording: { URL(fileURLWithPath: "") },
      currentTime: { 0 },
      isRecording: { false },
      deleteRecording: { _ in }
    )
  }
}

// MARK: - Dependency Values

extension DependencyValues {
  public var audioRecorder: AudioRecorderClient {
    get { self[AudioRecorderClient.self] }
    set { self[AudioRecorderClient.self] = newValue }
  }
}
