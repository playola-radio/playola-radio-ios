//
//  VoicetrackUploadServiceTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/16/25.
//

import ConcurrencyExtras
import Dependencies
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
struct VoicetrackUploadServiceTests {

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

  @Test
  func testProcessVoicetrackHandlesS3KeyWithSlash() async throws {
    let capturedS3Key = LockIsolated<String?>(nil)
    let voicetrack = createTestVoicetrack()
    let s3KeyWithSlash = "station123/mock-uuid.m4a"

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getVoicetrackPresignedURL = { _, _ in
        PresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: s3KeyWithSlash,
          voicetrackUrl: URL(string: "https://voicetracks.s3.amazonaws.com/test.m4a")!
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.getVoicetrackStatus = { _, _, s3Key in
        capturedS3Key.setValue(s3Key)
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

    #expect(
      capturedS3Key.value == s3KeyWithSlash, "s3Key with slash should be passed through correctly")
  }

  @Test
  func testProcessVoicetrackTransitionsThroughNormalizingStatus() async throws {
    let statusChanges = LockIsolated<[LocalVoicetrackStatus]>([])
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
      statusChanges.withValue { $0.append(status) }
    }

    let recordedStatuses = statusChanges.value
    // Verify that .normalizing status was reached
    #expect(
      recordedStatuses.contains(.normalizing),
      "Expected .normalizing status, got: \(recordedStatuses)"
    )

    // Verify correct order: uploading comes before normalizing
    if let uploadingIndex = recordedStatuses.firstIndex(where: {
      if case .uploading = $0 { return true }
      return false
    }),
      let normalizingIndex = recordedStatuses.firstIndex(of: .normalizing)
    {
      #expect(uploadingIndex < normalizingIndex)
    }

    // Verify normalizing comes before finalizing
    if let normalizingIndex = recordedStatuses.firstIndex(of: .normalizing),
      let finalizingIndex = recordedStatuses.firstIndex(of: .finalizing)
    {
      #expect(normalizingIndex < finalizingIndex)
    }
  }

  @Test
  func testProcessVoicetrackPassesS3KeyWithSlashesToStatusCheck() async throws {
    let voicetrack = createTestVoicetrack()
    let s3KeyWithSlashes = "voicetracks/station123/abc-def-123.m4a"
    let capturedS3Key = LockIsolated<String?>(nil)

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
        capturedS3Key.setValue(s3Key)
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

    #expect(capturedS3Key.value == s3KeyWithSlashes)
  }

  @Test
  func testProcessVoicetrackWaitsLongerForLongerRecordingsThenTimesOut() async throws {
    let statusChecks = LockIsolated(0)
    let createCalls = LockIsolated(0)
    let voicetrack = createTestVoicetrack()

    let service = withDependencies {
      $0.continuousClock = NonYieldingClock()
      $0.audioConverter = .testValue
      $0.audioConverter.getDuration = { _ in 600_000 }
      $0.api.getVoicetrackPresignedURL = { _, _ in
        PresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: "test.m4a",
          voicetrackUrl: URL(string: "https://voicetracks.s3.amazonaws.com/test.m4a")!
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.getVoicetrackStatus = { _, _, s3Key in
        statusChecks.withValue { $0 += 1 }
        return VoicetrackStatusResponse(ready: false, s3Key: s3Key)
      }
      $0.api.createVoicetrack = { _, _, _, _ in
        createCalls.withValue { $0 += 1 }
        return AudioBlock.mockWith()
      }
    } operation: {
      VoicetrackUploadService.liveValue
    }

    await #expect(throws: VoicetrackUploadError.normalizationTimeout) {
      _ = try await service.processVoicetrack(voicetrack, testStationId, testJwtToken) { _ in }
    }

    // 2 minutes of headroom plus the 10-minute recording, polled every 2 seconds
    #expect(statusChecks.value == 360)
    #expect(createCalls.value == 0)
  }
}

/// Sleeps return immediately without yielding, so a poll loop with hundreds of iterations finishes
/// instantly (`ImmediateClock` yields on every sleep, which made this test take over a minute).
private struct NonYieldingClock: Clock {
  struct Instant: InstantProtocol {
    var offset: Duration = .zero
    func advanced(by duration: Duration) -> Self { Self(offset: offset + duration) }
    func duration(to other: Self) -> Duration { other.offset - offset }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
  }

  var now: Instant { Instant() }
  var minimumResolution: Duration { .zero }
  func sleep(until deadline: Instant, tolerance: Duration?) async throws {}
}
