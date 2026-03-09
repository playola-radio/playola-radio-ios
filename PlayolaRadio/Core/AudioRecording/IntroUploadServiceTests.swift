//
//  IntroUploadServiceTests.swift
//  PlayolaRadio
//

import Dependencies
import XCTest

@testable import PlayolaRadio

@MainActor
final class IntroUploadServiceTests: XCTestCase {

  private let testStationId = "test-station-id"
  private let testSongTitle = "Bohemian Rhapsody"

  func testUploadIntroTransitionsThroughAllStatuses() async throws {
    var statusChanges: [IntroUploadStatus] = []
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
      statusChanges.append(status)
    }

    XCTAssertTrue(statusChanges.contains(.converting))
    XCTAssertTrue(
      statusChanges.contains(where: {
        if case .uploading = $0 { return true }
        return false
      }))
    XCTAssertTrue(statusChanges.contains(.registering))
    XCTAssertTrue(statusChanges.contains(.completed))
  }

  func testUploadIntroPassesCorrectStationIdAndFilename() async throws {
    var capturedStationId: String?
    var capturedFilename: String?
    let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.wav")

    let service = withDependencies {
      $0.audioConverter = .testValue
      $0.api.getIntroPresignedURL = { _, stationId, filename in
        capturedStationId = stationId
        capturedFilename = filename
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

    XCTAssertEqual(capturedStationId, testStationId)
    XCTAssertEqual(capturedFilename, "Bohemian Rhapsody.m4a")
  }

  func testUploadIntroPassesCorrectDataToCreateSourceTape() async throws {
    var capturedS3Key: String?
    var capturedName: String?
    var capturedDurationMS: Int?
    var capturedAudioBlockId: String?
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
        capturedS3Key = s3Key
        capturedName = name
        capturedDurationMS = durationMS
        capturedAudioBlockId = audioBlockId
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

    XCTAssertEqual(capturedS3Key, "station/uuid-intro.m4a")
    XCTAssertEqual(capturedName, "Bohemian Rhapsody")
    XCTAssertEqual(capturedDurationMS, 15000)
    XCTAssertEqual(capturedAudioBlockId, "test-audio-block-id")
  }
}
