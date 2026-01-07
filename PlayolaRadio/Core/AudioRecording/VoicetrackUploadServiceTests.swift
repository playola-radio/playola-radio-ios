//
//  VoicetrackUploadServiceTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/16/25.
//

import Dependencies
import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

final class VoicetrackUploadServiceTests: XCTestCase {

  // MARK: - Test Data

  private let testStationId = "test-station-id"
  private let testJwtToken = "test-jwt-token"

  private func createTestVoicetrack() -> LocalVoicetrack {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")
    return LocalVoicetrack(
      originalURL: tempURL,
      status: .converting,
      title: "Test Voicetrack"
    )
  }

  // MARK: - Normalization Polling Tests

  func testProcessVoicetrack_transitionsThroughNormalizingStatus() async throws {
    var statusChanges: [LocalVoicetrackStatus] = []
    let voicetrack = createTestVoicetrack()

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getVoicetrackPresignedURL = { _, _ in
        PresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: "test.m4a",
          voicetrackUrl: URL(string: "https://voicetracks.s3.amazonaws.com/test.m4a")!
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.getVoicetrackStatus = { _, _, _ in
        VoicetrackStatusResponse(ready: true, s3Key: "test.m4a")
      }
      $0.api.createVoicetrack = { _, _, _, _ in AudioBlock.mockWith() }
    } operation: {
      VoicetrackUploadService.liveValue
    }

    _ = try await service.processVoicetrack(
      voicetrack,
      testStationId,
      testJwtToken
    ) { status in
      statusChanges.append(status)
    }

    // Verify that .normalizing status was reached
    XCTAssertTrue(
      statusChanges.contains(.normalizing),
      "Expected .normalizing status, got: \(statusChanges)"
    )

    // Verify correct order: uploading comes before normalizing
    if let uploadingIndex = statusChanges.firstIndex(where: {
      if case .uploading = $0 { return true }
      return false
    }),
      let normalizingIndex = statusChanges.firstIndex(of: .normalizing)
    {
      XCTAssertLessThan(uploadingIndex, normalizingIndex)
    }

    // Verify normalizing comes before finalizing
    if let normalizingIndex = statusChanges.firstIndex(of: .normalizing),
      let finalizingIndex = statusChanges.firstIndex(of: .finalizing)
    {
      XCTAssertLessThan(normalizingIndex, finalizingIndex)
    }
  }

  func testProcessVoicetrackPassesS3KeyWithSlashesToStatusCheck() async throws {
    let voicetrack = createTestVoicetrack()
    let s3KeyWithSlashes = "voicetracks/station123/abc-def-123.m4a"
    var capturedS3Key: String?

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getVoicetrackPresignedURL = { _, _ in
        PresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: s3KeyWithSlashes,
          voicetrackUrl: URL(string: "https://voicetracks.s3.amazonaws.com/test.m4a")!
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.getVoicetrackStatus = { _, _, s3Key in
        capturedS3Key = s3Key
        return VoicetrackStatusResponse(ready: true, s3Key: s3Key)
      }
      $0.api.createVoicetrack = { _, _, _, _ in AudioBlock.mockWith() }
    } operation: {
      VoicetrackUploadService.liveValue
    }

    _ = try await service.processVoicetrack(
      voicetrack,
      testStationId,
      testJwtToken
    ) { _ in }

    XCTAssertEqual(capturedS3Key, s3KeyWithSlashes)
  }
}
