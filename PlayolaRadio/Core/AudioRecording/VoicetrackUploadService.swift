//
//  VoicetrackUploadService.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Dependencies
import Foundation
import PlayolaPlayer

struct VoicetrackUploadService: Sendable {
  var processVoicetrack:
    @Sendable (
      _ voicetrack: LocalVoicetrack,
      _ stationId: String,
      _ jwtToken: String,
      _ onStatusChange: @escaping @MainActor @Sendable (LocalVoicetrackStatus) -> Void
    ) async throws -> AudioBlock
}

// MARK: - Live Implementation

extension VoicetrackUploadService: DependencyKey {
  static var liveValue: VoicetrackUploadService {
    @Dependency(\.audioConverter) var audioConverter
    @Dependency(\.api) var api
    @Dependency(\.continuousClock) var clock

    return VoicetrackUploadService(
      processVoicetrack: { voicetrack, stationId, jwtToken, onStatusChange in
        // Step 1: Convert .wav to .m4a
        await onStatusChange(.converting)
        let m4aURL = try await audioConverter.convertToM4A(voicetrack.originalURL)
        let durationMS = try await audioConverter.getDuration(m4aURL)

        // Step 2: Get presigned URL
        await onStatusChange(.uploading(progress: 0))
        let presignedResponse = try await api.getVoicetrackPresignedURL(jwtToken, stationId)

        // Step 3: Upload to S3
        try await api.uploadToS3(
          presignedResponse.presignedUrl,
          m4aURL,
          "audio/mp4"
        ) { progress in
          Task { @MainActor in
            onStatusChange(.uploading(progress: progress))
          }
        }

        // Step 4: Wait for normalization to complete. Processing time grows with the
        // recording's length, so long recordings get proportionally more time.
        await onStatusChange(.normalizing)
        let maxWait = Duration.seconds(120) + .milliseconds(durationMS)
        let pollInterval = Duration.seconds(2)
        var waited = Duration.zero
        var isReady = false

        while !isReady, waited < maxWait {
          isReady = try await api.getVoicetrackStatus(
            jwtToken,
            stationId,
            presignedResponse.s3Key
          ).ready
          if !isReady {
            try await clock.sleep(for: pollInterval)
            waited += pollInterval
          }
        }
        guard isReady else { throw VoicetrackUploadError.normalizationTimeout }

        // Step 5: Create voicetrack
        await onStatusChange(.finalizing)
        let audioBlock = try await api.createVoicetrack(
          jwtToken,
          stationId,
          presignedResponse.s3Key,
          durationMS
        )

        // Step 5: Cleanup temp files
        try? FileManager.default.removeItem(at: m4aURL)

        await onStatusChange(.completed)
        return audioBlock
      }
    )
  }
}

enum VoicetrackUploadError: Error, LocalizedError {
  case normalizationTimeout

  var errorDescription: String? {
    switch self {
    case .normalizationTimeout:
      return "Audio processing is taking longer than expected. Please try again."
    }
  }
}

// MARK: - Test Implementation

extension VoicetrackUploadService: TestDependencyKey {
  static var testValue: VoicetrackUploadService {
    VoicetrackUploadService(
      processVoicetrack: { _, _, _, onStatusChange in
        await onStatusChange(.completed)
        return AudioBlock.mockWith()
      }
    )
  }
}

// MARK: - Dependency Values

extension DependencyValues {
  var voicetrackUploadService: VoicetrackUploadService {
    get { self[VoicetrackUploadService.self] }
    set { self[VoicetrackUploadService.self] = newValue }
  }
}
