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
        case .other(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}

public actor AudioRecorder {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    private let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 2,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    // MARK: - Public Methods

    /// Start recording audio
    /// - Returns: URL where the recording will be saved
    public func startRecording() async throws -> URL {
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

            recorder.record()
            recordingURL = url
            return url
        } catch {
            throw AudioRecorderError.recordingFailed(error)
        }
    }

    /// Stop recording and save the file
    /// - Returns: URL of the saved recording
    public func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, let url = recordingURL else {
            throw AudioRecorderError.notRecording
        }

        recorder.stop()
        audioRecorder = nil
        recordingURL = nil

        return url
    }

    // MARK: - Private Methods

    private func requestPermissionIfNeeded() async throws {
        let status = AVAudioSession.sharedInstance().recordPermission

        switch status {
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
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

        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - Dependency Registration

extension AudioRecorder: DependencyKey {
    public static let liveValue = AudioRecorder()
}

extension DependencyValues {
    var audioRecorder: AudioRecorder {
        get { self[AudioRecorder.self] }
        set { self[AudioRecorder.self] = newValue }
    }
}
