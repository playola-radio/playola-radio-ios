//
//  StagingItemTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import Foundation
import PlayolaPlayer
import SwiftUI
import Testing

@testable import PlayolaRadio

struct StagingItemTests {

  // MARK: - LocalVoicetrack Conformance Tests

  @Test
  func testLocalVoicetrackStagingIdReturnsUUIDString() {
    let id = UUID()
    let voicetrack = LocalVoicetrack(
      id: id,
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Test"
    )

    #expect(voicetrack.stagingId == id.uuidString)
  }

  @Test
  func testLocalVoicetrackTitleTextReturnsTitle() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Voice Track 10:00am"
    )

    #expect(voicetrack.titleText == "Voice Track 10:00am")
  }

  @Test
  func testLocalVoicetrackSubtitleTextWhenConvertingReturnsConverting() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .converting,
      title: "Test"
    )

    #expect(voicetrack.subtitleText == "Converting...")
  }

  @Test
  func testLocalVoicetrackSubtitleTextWhenUploadingReturnsProgress() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .uploading(progress: 0.5),
      title: "Test"
    )

    #expect(voicetrack.subtitleText == "Uploading 50%")
  }

  @Test
  func testLocalVoicetrackSubtitleTextWhenFinalizingReturnsFinalizing() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .finalizing,
      title: "Test"
    )

    #expect(voicetrack.subtitleText == "Finalizing...")
  }

  @Test
  func testLocalVoicetrackSubtitleTextWhenCompletedReturnsReady() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test"
    )

    #expect(voicetrack.subtitleText == "Ready")
  }

  @Test
  func testLocalVoicetrackSubtitleTextWhenFailedReturnsErrorMessage() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .failed(error: "Upload failed"),
      title: "Test"
    )

    #expect(voicetrack.subtitleText == "Upload failed")
  }

  @Test
  func testLocalVoicetrackSubtitleColorWhenCompletedReturnsGreen() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test"
    )

    #expect(voicetrack.subtitleColor == .green)
  }

  @Test
  func testLocalVoicetrackSubtitleColorWhenFailedReturnsRed() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .failed(error: "Error"),
      title: "Test"
    )

    #expect(voicetrack.subtitleColor == .playolaRed)
  }

  @Test
  func testLocalVoicetrackSubtitleColorWhenProcessingReturnsGray() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .uploading(progress: 0.5),
      title: "Test"
    )

    #expect(voicetrack.subtitleColor == .playolaGray)
  }

  @Test
  func testLocalVoicetrackAlbumImageUrlReturnsNil() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Test"
    )

    #expect(voicetrack.albumImageUrl == nil)
  }

  @Test
  func testLocalVoicetrackIconReturnsMicFill() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      title: "Test"
    )

    #expect(voicetrack.icon == "mic.fill")
  }

  @Test
  func testLocalVoicetrackIsReadyWhenCompletedReturnsTrue() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test",
      audioBlockId: "audio-block-123"
    )

    #expect(voicetrack.isReady)
  }

  @Test
  func testLocalVoicetrackIsReadyWhenProcessingReturnsFalse() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .uploading(progress: 0.5),
      title: "Test"
    )

    #expect(!voicetrack.isReady)
  }

  @Test
  func testLocalVoicetrackIsReadyWhenCompletedButNoAudioBlockIdReturnsFalse() {
    let voicetrack = LocalVoicetrack(
      originalURL: URL(fileURLWithPath: "/tmp/test.wav"),
      status: .completed,
      title: "Test",
      audioBlockId: nil
    )

    #expect(!voicetrack.isReady)
  }

  // MARK: - AudioBlock Conformance Tests

  @Test
  func testAudioBlockStagingIdReturnsId() {
    let audioBlock = AudioBlock.mockWith(id: "song-123")

    #expect(audioBlock.stagingId == "song-123")
  }

  @Test
  func testAudioBlockTitleTextReturnsTitle() {
    let audioBlock = AudioBlock.mockWith(title: "Blowin' in the Wind")

    #expect(audioBlock.titleText == "Blowin' in the Wind")
  }

  @Test
  func testAudioBlockSubtitleTextReturnsArtist() {
    let audioBlock = AudioBlock.mockWith(artist: "Bob Dylan")

    #expect(audioBlock.subtitleText == "Bob Dylan")
  }

  @Test
  func testAudioBlockSubtitleColorReturnsGray() {
    let audioBlock = AudioBlock.mockWith()

    #expect(audioBlock.subtitleColor == .playolaGray)
  }

  @Test
  func testAudioBlockAlbumImageUrlReturnsImageUrl() {
    let imageUrl = URL(string: "https://example.com/album.jpg")!
    let audioBlock = AudioBlock.mockWith(imageUrl: imageUrl)

    #expect(audioBlock.albumImageUrl == imageUrl)
  }

  @Test
  func testAudioBlockIconReturnsNil() {
    let audioBlock = AudioBlock.mockWith()

    #expect(audioBlock.icon == nil)
  }

  @Test
  func testAudioBlockAudioBlockIdReturnsId() {
    let audioBlock = AudioBlock.mockWith(id: "song-456")

    #expect(audioBlock.audioBlockId == "song-456")
  }

  @Test
  func testAudioBlockIsReadyReturnsTrue() {
    let audioBlock = AudioBlock.mockWith()

    #expect(audioBlock.isReady)
  }

  @Test
  func testAudioBlockIsProcessingReturnsFalse() {
    let audioBlock = AudioBlock.mockWith()

    #expect(!audioBlock.isProcessing)
  }
}
