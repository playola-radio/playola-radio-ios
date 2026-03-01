//
//  IntroUploadService.swift
//  PlayolaRadio
//

import Dependencies
import Foundation

enum IntroUploadStatus: Equatable {
  case converting
  case uploading(progress: Double)
  case registering
  case completed
  case failed(String)
}

struct IntroUploadService: Sendable {
  var uploadIntro:
    @Sendable (
      _ recordingURL: URL,
      _ stationId: String,
      _ songTitle: String,
      _ onStatusChange: @escaping @MainActor @Sendable (IntroUploadStatus) -> Void
    ) async throws -> Void
}

// MARK: - Live Implementation

extension IntroUploadService: DependencyKey {
  static var liveValue: IntroUploadService {
    @Dependency(\.audioConverter) var audioConverter
    @Dependency(\.api) var api

    return IntroUploadService(
      uploadIntro: { recordingURL, stationId, songTitle, onStatusChange in
        // Step 1: Convert .wav to .m4a
        await onStatusChange(.converting)
        let m4aURL = try await audioConverter.convertToM4A(recordingURL)
        let durationMS = try await audioConverter.getDuration(m4aURL)

        // Step 2: Get presigned URL
        await onStatusChange(.uploading(progress: 0))
        let presignedResponse = try await api.getIntroPresignedURL(
          stationId,
          "\(songTitle).m4a"
        )

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

        // Step 4: Register source tape
        await onStatusChange(.registering)
        try await api.createIntroSourceTape(
          stationId,
          presignedResponse.s3Key,
          songTitle,
          durationMS
        )

        // Step 5: Cleanup temp files
        try? FileManager.default.removeItem(at: m4aURL)

        await onStatusChange(.completed)
      }
    )
  }
}

// MARK: - Test Implementation

extension IntroUploadService: TestDependencyKey {
  static var testValue: IntroUploadService {
    IntroUploadService(
      uploadIntro: { _, _, _, onStatusChange in
        await onStatusChange(.completed)
      }
    )
  }
}

// MARK: - Dependency Values

extension DependencyValues {
  var introUploadService: IntroUploadService {
    get { self[IntroUploadService.self] }
    set { self[IntroUploadService.self] = newValue }
  }
}
