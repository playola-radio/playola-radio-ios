//
//  StagingItemTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import PlayolaPlayer
import SwiftUI
import XCTest

@testable import PlayolaRadio

final class StagingItemTests: XCTestCase {

  // MARK: - LocalVoicetrack Conformance Tests

  func testLocalVoicetrack_StagingId_ReturnsUUIDString() {
    let id = UUID()
    let voicetrack = LocalVoicetrack(
      id: id,
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Test"
    )

    XCTAssertEqual(voicetrack.stagingId, id.uuidString)
  }

  func testLocalVoicetrack_TitleText_ReturnsTitle() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Voice Track 10:00am"
    )

    XCTAssertEqual(voicetrack.titleText, "Voice Track 10:00am")
  }

  func testLocalVoicetrack_SubtitleText_WhenConverting_ReturnsConverting() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .converting,
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleText, "Converting...")
  }

  func testLocalVoicetrack_SubtitleText_WhenUploading_ReturnsProgress() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .uploading(progress: 0.5),
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleText, "Uploading 50%")
  }

  func testLocalVoicetrack_SubtitleText_WhenFinalizing_ReturnsFinalizing() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .finalizing,
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleText, "Finalizing...")
  }

  func testLocalVoicetrack_SubtitleText_WhenCompleted_ReturnsReady() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleText, "Ready")
  }

  func testLocalVoicetrack_SubtitleText_WhenFailed_ReturnsErrorMessage() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .failed(error: "Upload failed"),
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleText, "Upload failed")
  }

  func testLocalVoicetrack_SubtitleColor_WhenCompleted_ReturnsGreen() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleColor, .green)
  }

  func testLocalVoicetrack_SubtitleColor_WhenFailed_ReturnsRed() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .failed(error: "Error"),
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleColor, .playolaRed)
  }

  func testLocalVoicetrack_SubtitleColor_WhenProcessing_ReturnsGray() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .uploading(progress: 0.5),
      title: "Test"
    )

    XCTAssertEqual(voicetrack.subtitleColor, .playolaGray)
  }

  func testLocalVoicetrack_AlbumImageUrl_ReturnsNil() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Test"
    )

    XCTAssertNil(voicetrack.albumImageUrl)
  }

  func testLocalVoicetrack_Icon_ReturnsMicFill() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Test"
    )

    XCTAssertEqual(voicetrack.icon, "mic.fill")
  }

  func testLocalVoicetrack_IsReady_WhenCompleted_ReturnsTrue() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test",
      audioBlockId: "audio-block-123"
    )

    XCTAssertTrue(voicetrack.isReady)
  }

  func testLocalVoicetrack_IsReady_WhenProcessing_ReturnsFalse() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .uploading(progress: 0.5),
      title: "Test"
    )

    XCTAssertFalse(voicetrack.isReady)
  }

  func testLocalVoicetrack_IsReady_WhenCompletedButNoAudioBlockId_ReturnsFalse() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test",
      audioBlockId: nil
    )

    XCTAssertFalse(voicetrack.isReady)
  }

  // MARK: - AudioBlock Conformance Tests

  func testAudioBlock_StagingId_ReturnsId() {
    let audioBlock = AudioBlock.mockWith(id: "song-123")

    XCTAssertEqual(audioBlock.stagingId, "song-123")
  }

  func testAudioBlock_TitleText_ReturnsTitle() {
    let audioBlock = AudioBlock.mockWith(title: "Blowin' in the Wind")

    XCTAssertEqual(audioBlock.titleText, "Blowin' in the Wind")
  }

  func testAudioBlock_SubtitleText_ReturnsArtist() {
    let audioBlock = AudioBlock.mockWith(artist: "Bob Dylan")

    XCTAssertEqual(audioBlock.subtitleText, "Bob Dylan")
  }

  func testAudioBlock_SubtitleColor_ReturnsGray() {
    let audioBlock = AudioBlock.mockWith()

    XCTAssertEqual(audioBlock.subtitleColor, .playolaGray)
  }

  func testAudioBlock_AlbumImageUrl_ReturnsImageUrl() {
    let imageUrl = URL(string: "https://example.com/album.jpg")!
    let audioBlock = AudioBlock.mockWith(imageUrl: imageUrl)

    XCTAssertEqual(audioBlock.albumImageUrl, imageUrl)
  }

  func testAudioBlock_Icon_ReturnsNil() {
    let audioBlock = AudioBlock.mockWith()

    XCTAssertNil(audioBlock.icon)
  }

  func testAudioBlock_AudioBlockId_ReturnsId() {
    let audioBlock = AudioBlock.mockWith(id: "song-456")

    XCTAssertEqual(audioBlock.audioBlockId, "song-456")
  }

  func testAudioBlock_IsReady_ReturnsTrue() {
    let audioBlock = AudioBlock.mockWith()

    XCTAssertTrue(audioBlock.isReady)
  }

  func testAudioBlock_IsProcessing_ReturnsFalse() {
    let audioBlock = AudioBlock.mockWith()

    XCTAssertFalse(audioBlock.isProcessing)
  }
}
