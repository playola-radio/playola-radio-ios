//
//  SongDrawerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

@MainActor
struct SongDrawerTests {

  @Test
  func testSpotifyTappedWithSpotifyIdOpensCorrectURL() {
    let audioBlock = AudioBlock.mockWith(spotifyId: "4iV5W9uYEdYUVa79Axb7Rh")
    var dismissCalled = false

    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: { dismissCalled = true }
    )

    // Note: In a real test environment, UIApplication.shared.open won't actually open URLs
    // This test verifies the logic flow and that dismiss is called
    model.spotifyTapped()

    #expect(dismissCalled, "Should call onDismiss after attempting to open Spotify")
  }

  @Test
  func testSpotifyTappedWithoutSpotifyIdJustDismisses() {
    let audioBlock = AudioBlock.mockWith(spotifyId: nil)
    var dismissCalled = false

    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: { dismissCalled = true }
    )

    model.spotifyTapped()

    #expect(dismissCalled, "Should call onDismiss when no Spotify ID is available")
  }

  @Test
  func testAppleMusicTappedOpensSearchURL() {
    let audioBlock = AudioBlock.mockWith(
      title: "Test Song",
      artist: "Test Artist"
    )
    var dismissCalled = false

    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: { dismissCalled = true }
    )

    model.appleMusicTapped()

    #expect(dismissCalled, "Should call onDismiss after attempting to open Apple Music")
  }

  @Test
  func testAppleMusicTappedHandlesSpecialCharacters() {
    let audioBlock = AudioBlock.mockWith(
      title: "Song & Title",
      artist: "Artist @ Name"
    )
    var dismissCalled = false

    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: { dismissCalled = true }
    )

    // Should not crash with special characters and should call dismiss
    model.appleMusicTapped()

    #expect(dismissCalled, "Should handle URL encoding and call onDismiss")
  }

  @Test
  func testShouldShowSpotifyTrueWhenSpotifyIdExists() {
    let audioBlock = AudioBlock.mockWith(spotifyId: "4iV5W9uYEdYUVa79Axb7Rh")
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: {}
    )

    #expect(model.shouldShowSpotify)
  }

  @Test
  func testShouldShowSpotifyFalseWhenSpotifyIdIsNil() {
    let audioBlock = AudioBlock.mockWith(spotifyId: nil)
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: {}
    )

    #expect(!model.shouldShowSpotify)
  }

  @Test
  func testShouldShowAppleMusicTrueWhenTitleAndArtistExist() {
    let audioBlock = AudioBlock.mockWith(
      title: "Test Song",
      artist: "Test Artist"
    )
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: {}
    )

    #expect(model.shouldShowAppleMusic)
  }

  @Test
  func testShouldShowAppleMusicFalseWhenTitleOrArtistEmpty() {
    let audioBlockEmptyTitle = AudioBlock.mockWith(
      title: "",
      artist: "Test Artist"
    )
    let modelEmptyTitle = SongDrawerModel(
      audioBlock: audioBlockEmptyTitle,
      likedDate: Date(),
      onDismiss: {}
    )

    #expect(!modelEmptyTitle.shouldShowAppleMusic)

    let audioBlockEmptyArtist = AudioBlock.mockWith(
      title: "Test Song",
      artist: ""
    )
    let modelEmptyArtist = SongDrawerModel(
      audioBlock: audioBlockEmptyArtist,
      likedDate: Date(),
      onDismiss: {}
    )

    #expect(!modelEmptyArtist.shouldShowAppleMusic)
  }

  @Test
  func testRemoveFromLikedSongsTappedUnlikesAndDismisses() async {
    let audioBlock = AudioBlock.mock
    var dismissCalled = false

    withDependencies {
      let likesManager = LikesManager()
      // Pre-like the song
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = SongDrawerModel(
        audioBlock: audioBlock,
        likedDate: Date(),
        onDismiss: { dismissCalled = true }
      )

      // Verify it's liked initially
      #expect(model.likesManager.isLiked(audioBlock.id))

      model.removeFromLikedSongsTapped()

      // Verify it's been unliked and dismiss was called
      #expect(!model.likesManager.isLiked(audioBlock.id))
      #expect(dismissCalled)
    }
  }

  @Test
  func testRemoveFromLikedSongsTappedWithOnRemoveCallback() async {
    let audioBlock = AudioBlock.mock
    var dismissCalled = false
    var onRemoveCalled = false
    var removedAudioBlock: AudioBlock?

    withDependencies {
      let likesManager = LikesManager()
      likesManager.like(audioBlock)
      $0.likesManager = likesManager
    } operation: {
      let model = SongDrawerModel(
        audioBlock: audioBlock,
        likedDate: Date(),
        onDismiss: { dismissCalled = true },
        onRemove: { audioBlock in
          onRemoveCalled = true
          removedAudioBlock = audioBlock
        }
      )

      model.removeFromLikedSongsTapped()

      // Verify the onRemove callback was called with correct audio block
      #expect(onRemoveCalled, "Should call onRemove callback")
      #expect(
        removedAudioBlock?.id == audioBlock.id, "Should pass correct audioBlock to onRemove")
      #expect(dismissCalled, "Should call onDismiss")

      // Verify song is still liked (since onRemove callback handles the removal)
      #expect(
        model.likesManager.isLiked(audioBlock.id),
        "Song should still be liked when using onRemove callback"
      )
    }
  }
}
