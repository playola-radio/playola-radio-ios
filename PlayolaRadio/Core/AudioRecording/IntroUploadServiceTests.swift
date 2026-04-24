//
//  IntroUploadServiceTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import XCTest

@testable import PlayolaRadio

@MainActor
final class IntroUploadServiceTests: XCTestCase {

  private let testStationId = "test-station-id"
  private let testSongTitle = "Bohemian Rhapsody"

  func testUploadIntroTransitionsThroughAllStatuses() async throws {
    let statusChanges = LockIsolated<[IntroUploadStatus]>([])
    let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getIntroPresignedURL = { _, _, _ in
        IntroPresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: "station/uuid-intro.m4a"
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.createIntroSourceTape = { _, _, _, _, _, _ in }
    } operation: {
      IntroUploadService.liveValue
    }

    try await service.uploadIntro(
      "test-jwt-token",
      testURL,
      testStationId,
      testSongTitle,
      "test-audio-block-id"
    ) { status in
      statusChanges.withValue { $0.append(status) }
    }

    let recordedStatuses = statusChanges.value
    XCTAssertTrue(recordedStatuses.contains(.converting))
    XCTAssertTrue(
      recordedStatuses.contains(where: {
        if case .uploading = $0 { return true }
        return false
      }))
    XCTAssertTrue(recordedStatuses.contains(.registering))
    XCTAssertTrue(recordedStatuses.contains(.completed))
  }

  func testUploadIntroPassesCorrectStationIdAndFilename() async throws {
    let capturedStationId = LockIsolated<String?>(nil)
    let capturedFilename = LockIsolated<String?>(nil)
    let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getIntroPresignedURL = { _, stationId, filename in
        capturedStationId.setValue(stationId)
        capturedFilename.setValue(filename)
        return IntroPresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: "station/uuid-intro.m4a"
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.createIntroSourceTape = { _, _, _, _, _, _ in }
    } operation: {
      IntroUploadService.liveValue
    }

    try await service.uploadIntro(
      "test-jwt-token",
      testURL,
      testStationId,
      testSongTitle,
      "test-audio-block-id"
    ) { _ in }

    XCTAssertEqual(capturedStationId.value, testStationId)
    XCTAssertEqual(capturedFilename.value, "Bohemian Rhapsody.m4a")
  }

  func testUploadIntroPassesCorrectDataToCreateSourceTape() async throws {
    let capturedS3Key = LockIsolated<String?>(nil)
    let capturedName = LockIsolated<String?>(nil)
    let capturedDurationMS = LockIsolated<Int?>(nil)
    let capturedAudioBlockId = LockIsolated<String?>(nil)
    let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getIntroPresignedURL = { _, _, _ in
        IntroPresignedURLResponse(
          presignedUrl: URL(string: "https://intake.s3.amazonaws.com/test.m4a")!,
          s3Key: "station/uuid-intro.m4a"
        )
      }
      $0.api.uploadToS3 = { _, _, _, _ in }
      $0.api.createIntroSourceTape = { _, _, s3Key, name, durationMS, audioBlockId in
        capturedS3Key.setValue(s3Key)
        capturedName.setValue(name)
        capturedDurationMS.setValue(durationMS)
        capturedAudioBlockId.setValue(audioBlockId)
      }
    } operation: {
      IntroUploadService.liveValue
    }

    try await service.uploadIntro(
      "test-jwt-token",
      testURL,
      testStationId,
      testSongTitle,
      "test-audio-block-id"
    ) { _ in }

    XCTAssertEqual(capturedS3Key.value, "station/uuid-intro.m4a")
    XCTAssertEqual(capturedName.value, "Bohemian Rhapsody")
    XCTAssertEqual(capturedDurationMS.value, 15000)
    XCTAssertEqual(capturedAudioBlockId.value, "test-audio-block-id")
  }
}
