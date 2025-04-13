//
//  AudioRecorder.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/3/25.
//

import Foundation
import AVFoundation
import Dependencies

public enum AudioRecorderError: Error {
  case permissionDenied
  case recordingFailed(Error)
  case notRecording
  case savingFailed(Error)
  case audioSessionError(Error)
  case other(Error)

  public var localizedDescription: String {
    switch self {
    case .permissionDenied:
      return "Microphone access denied"
    case .recordingFailed(let error):
      return "Recording failed: \(error.localizedDescription)"
    case .notRecording:
      return "Not currently recording"
    case .savingFailed(let error):
      return "Failed to save recording: \(error.localizedDescription)"
    case .audioSessionError(let error):
      return "Audio session error: \(error.localizedDescription)"
    case .other(let error):
      return "Error: \(error.localizedDescription)"
    }
  }
}

public struct RecordingInfo: Sendable {
  public let averagePower: Float
  public let peakPower: Float
  public let duration: TimeInterval
}

public struct AudioRecorder: Sendable {
  public var startRecording: @Sendable () async throws -> URL
  public var stopRecording: @Sendable () async throws -> LocalVoicetrack
  public var pauseRecording: @Sendable () async -> Void
  public var resumeRecording: @Sendable () async -> Void
  public var currentRecordingInfo: @Sendable () async -> RecordingInfo
  public var isRecording: @Sendable () async -> Bool
}

// MARK: - Dependency Registration

extension AudioRecorder: DependencyKey {
  public static let liveValue: Self = {
    let recorder = LiveAudioRecorder()

    return Self(
      startRecording: { try await recorder.startRecording() },
      stopRecording: { try await recorder.stopRecording() },
      pauseRecording: { recorder.pauseRecording() },
      resumeRecording: {  recorder.resumeRecording() },
      currentRecordingInfo: { recorder.currentRecordingInfo },
      isRecording: { recorder.isRecording }
    )
  }()
}
// MARK: - Live Implementation

private actor LiveAudioRecorder {
  private var audioRecorder: AVAudioRecorder?
  private var recordingURL: URL?
  private var startTime: Date?

  private let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 2,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    AVEncoderBitRateKey: 320000, // High quality: 320kbps
    AVLinearPCMBitDepthKey: 16,
    AVLinearPCMIsBigEndianKey: false,
    AVLinearPCMIsFloatKey: false
  ]

  var currentRecordingInfo: RecordingInfo {
    guard let recorder = audioRecorder else {
      return RecordingInfo(averagePower: -160, peakPower: -160, duration: 0)
    }

    recorder.updateMeters()
    let avgPower = recorder.averagePower(forChannel: 0)
    let peakPower = recorder.peakPower(forChannel: 0)
    let duration = recorder.currentTime

    return RecordingInfo(
      averagePower: avgPower,
      peakPower: peakPower,
      duration: duration
    )
  }

  var isRecording: Bool {
    return audioRecorder?.isRecording ?? false
  }

  func startRecording() async throws -> URL {
    // Clean up any existing recording
    cleanup()

    // Request permission if needed
    try await requestPermissionIfNeeded()

    // Create temporary URL for recording
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "\(UUID().uuidString).m4a"
    let url = tempDir.appendingPathComponent(fileName)

    do {
      audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      guard let recorder = audioRecorder else {
        throw AudioRecorderError.recordingFailed(NSError(domain: "", code: -1))
      }

      recorder.isMeteringEnabled = true
      recorder.prepareToRecord()
      recorder.record()
      recordingURL = url
      startTime = Date()

      return url
    } catch {
      throw AudioRecorderError.recordingFailed(error)
    }
  }

  func stopRecording() async throws -> LocalVoicetrack {
    guard let recorder = audioRecorder, let url = recordingURL else {
      throw AudioRecorderError.notRecording
    }

    recorder.stop()
    let durationMS = Int(recorder.currentTime / 1000)

    do {
      try AVAudioSession.sharedInstance().setActive(false)
    } catch {
      throw AudioRecorderError.audioSessionError(error)
    }

    cleanup()

    return LocalVoicetrack(fileURL: url, durationMS: durationMS)
  }

  func pauseRecording() {
    audioRecorder?.pause()
  }

  func resumeRecording() {
    audioRecorder?.record()
  }

  private func cleanup() {
    audioRecorder?.stop()
    audioRecorder = nil
    recordingURL = nil
    startTime = nil
  }

  private func requestPermissionIfNeeded() async throws {
    let status = AVAudioApplication.shared.recordPermission

    switch status {
    case .undetermined:
      let granted = await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
          continuation.resume(returning: granted)
        }
      }
      if !granted {
        throw AudioRecorderError.permissionDenied
      }
    case .denied:
      throw AudioRecorderError.permissionDenied
    case .granted:
      break
    @unknown default:
      break
    }

    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playAndRecord,
        mode: .default,
        options: [.defaultToSpeaker, .allowBluetooth]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      throw AudioRecorderError.audioSessionError(error)
    }
  }
}

extension DependencyValues {
  var audioRecorder: AudioRecorder {
    get { self[AudioRecorder.self] }
    set { self[AudioRecorder.self] = newValue }
  }
}
