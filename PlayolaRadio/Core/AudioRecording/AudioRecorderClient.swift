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
  public var prepareForRecording: @Sendable () async throws -> Void
  public var startRecording: @Sendable () async throws -> Void
  public var stopRecording: @Sendable () async throws -> URL
  public var currentTime: @Sendable () async -> TimeInterval
  public var deleteRecording: @Sendable (URL) async -> Void
  public var getAudioLevel: @Sendable () async -> Float
}

// MARK: - Live Implementation

extension AudioRecorderClient: DependencyKey {
  public static var liveValue: AudioRecorderClient {
    let recorder = LiveAudioRecorder()

    return AudioRecorderClient(
      requestPermission: { await recorder.requestPermission() },
      prepareForRecording: { try await recorder.prepareForRecording() },
      startRecording: { try await recorder.startRecording() },
      stopRecording: { try await recorder.stopRecording() },
      currentTime: { await recorder.currentTime() },
      deleteRecording: { url in await recorder.deleteRecording(url) },
      getAudioLevel: { await recorder.getAudioLevel() }
    )
  }
}

// MARK: - Test Implementation

extension AudioRecorderClient: TestDependencyKey {
  public static var testValue: AudioRecorderClient {
    AudioRecorderClient(
      requestPermission: { true },
      prepareForRecording: {},
      startRecording: {},
      stopRecording: { URL(fileURLWithPath: "/tmp/test.wav") },
      currentTime: { 0 },
      deleteRecording: { _ in },
      getAudioLevel: { 0 }
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

// MARK: - Live Recorder

private final class LiveAudioRecorder: @unchecked Sendable {
  private var audioRecorder: AVAudioRecorder?
  private var recordingURL: URL?
  private var isPrepared = false
  private let lock = NSLock()

  private let recordingSettings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatLinearPCM),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 1,
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsFloatKey: false,
    AVLinearPCMIsBigEndianKey: false,
  ]

  func requestPermission() async -> Bool {
    await withCheckedContinuation { continuation in
      AVAudioApplication.requestRecordPermission { granted in
        continuation.resume(returning: granted)
      }
    }
  }

  func prepareForRecording() async throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
    try session.setActive(true)

    lock.lock()
    isPrepared = true
    lock.unlock()
  }

  func startRecording() async throws {
    lock.lock()
    let prepared = isPrepared
    lock.unlock()

    if !prepared {
      try await prepareForRecording()
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("voicetrack_\(UUID().uuidString).wav")

    let recorder = try AVAudioRecorder(url: url, settings: recordingSettings)
    recorder.isMeteringEnabled = true
    recorder.record()

    lock.lock()
    self.audioRecorder = recorder
    self.recordingURL = url
    lock.unlock()
  }

  func stopRecording() async throws -> URL {
    lock.lock()
    let recorder = audioRecorder
    let url = recordingURL
    audioRecorder = nil
    recordingURL = nil
    lock.unlock()

    guard let recorder, let url else {
      throw AudioRecorderError.noActiveRecording
    }

    recorder.stop()
    return url
  }

  func currentTime() -> TimeInterval {
    lock.lock()
    defer { lock.unlock() }
    return audioRecorder?.currentTime ?? 0
  }

  func deleteRecording(_ url: URL) async {
    try? FileManager.default.removeItem(at: url)
  }

  func getAudioLevel() -> Float {
    lock.lock()
    defer { lock.unlock() }
    guard let recorder = audioRecorder else { return 0 }
    recorder.updateMeters()
    let level = recorder.averagePower(forChannel: 0)
    // Convert from dB (-160 to 0) to normalized (0 to 1)
    let normalizedLevel = max(0, (level + 50) / 50)
    return normalizedLevel
  }
}

// MARK: - Errors

enum AudioRecorderError: Error, LocalizedError {
  case noActiveRecording
  case permissionDenied

  var errorDescription: String? {
    switch self {
    case .noActiveRecording:
      return "No active recording"
    case .permissionDenied:
      return "Microphone permission denied"
    }
  }
}
