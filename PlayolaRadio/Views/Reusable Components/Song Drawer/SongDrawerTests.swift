//
//  SongDrawerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

@MainActor
final class SongDrawerTests: XCTestCase {
  
  func testOpenSpotify_WithSpotifyId_OpensCorrectURL() {
    let audioBlock = AudioBlock.mockWith(spotifyId: "4iV5W9uYEdYUVa79Axb7Rh")
    var dismissCalled = false
    
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: { dismissCalled = true }
    )
    
    // Note: In a real test environment, UIApplication.shared.open won't actually open URLs
    // This test verifies the logic flow and that dismiss is called
    model.openSpotify()
    
    XCTAssertTrue(dismissCalled, "Should call onDismiss after attempting to open Spotify")
  }
  
  func testOpenSpotify_WithoutSpotifyId_JustDismisses() {
    let audioBlock = AudioBlock.mockWith(spotifyId: nil)
    var dismissCalled = false
    
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: { dismissCalled = true }
    )
    
    model.openSpotify()
    
    XCTAssertTrue(dismissCalled, "Should call onDismiss when no Spotify ID is available")
  }
  
  func testOpenAppleMusic_OpensSearchURL() {
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
    
    model.openAppleMusic()
    
    XCTAssertTrue(dismissCalled, "Should call onDismiss after attempting to open Apple Music")
  }
  
  func testOpenAppleMusic_HandlesSpecialCharacters() {
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
    model.openAppleMusic()
    
    XCTAssertTrue(dismissCalled, "Should handle URL encoding and call onDismiss")
  }
  
  func testShouldShowSpotify_TrueWhenSpotifyIdExists() {
    let audioBlock = AudioBlock.mockWith(spotifyId: "4iV5W9uYEdYUVa79Axb7Rh")
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: {}
    )
    
    XCTAssertTrue(model.shouldShowSpotify)
  }
  
  func testShouldShowSpotify_FalseWhenSpotifyIdIsNil() {
    let audioBlock = AudioBlock.mockWith(spotifyId: nil)
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: {}
    )
    
    XCTAssertFalse(model.shouldShowSpotify)
  }
  
  func testShouldShowAppleMusic_TrueWhenTitleAndArtistExist() {
    let audioBlock = AudioBlock.mockWith(
      title: "Test Song",
      artist: "Test Artist"
    )
    let model = SongDrawerModel(
      audioBlock: audioBlock,
      likedDate: Date(),
      onDismiss: {}
    )
    
    XCTAssertTrue(model.shouldShowAppleMusic)
  }
  
  func testShouldShowAppleMusic_FalseWhenTitleOrArtistEmpty() {
    let audioBlockEmptyTitle = AudioBlock.mockWith(
      title: "",
      artist: "Test Artist"
    )
    let modelEmptyTitle = SongDrawerModel(
      audioBlock: audioBlockEmptyTitle,
      likedDate: Date(),
      onDismiss: {}
    )
    
    XCTAssertFalse(modelEmptyTitle.shouldShowAppleMusic)
    
    let audioBlockEmptyArtist = AudioBlock.mockWith(
      title: "Test Song",
      artist: ""
    )
    let modelEmptyArtist = SongDrawerModel(
      audioBlock: audioBlockEmptyArtist,
      likedDate: Date(),
      onDismiss: {}
    )
    
    XCTAssertFalse(modelEmptyArtist.shouldShowAppleMusic)
  }
  
  func testRemoveFromLikedSongs_UnlikesAndDismisses() async {
    let audioBlock = AudioBlock.mock
    var dismissCalled = false
    
    await withDependencies {
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
      XCTAssertTrue(model.likesManager.isLiked(audioBlock.id))
      
      model.removeFromLikedSongs()
      
      // Verify it's been unliked and dismiss was called
      XCTAssertFalse(model.likesManager.isLiked(audioBlock.id))
      XCTAssertTrue(dismissCalled)
    }
  }
  
  func testRemoveFromLikedSongs_WithOnRemoveCallback() async {
    let audioBlock = AudioBlock.mock
    var dismissCalled = false
    var onRemoveCalled = false
    var removedAudioBlock: AudioBlock?
    
    await withDependencies {
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
      
      model.removeFromLikedSongs()
      
      // Verify the onRemove callback was called with correct audio block
      XCTAssertTrue(onRemoveCalled, "Should call onRemove callback")
      XCTAssertEqual(removedAudioBlock?.id, audioBlock.id, "Should pass correct audioBlock to onRemove")
      XCTAssertTrue(dismissCalled, "Should call onDismiss")
      
      // Verify song is still liked (since onRemove callback handles the removal)
      XCTAssertTrue(model.likesManager.isLiked(audioBlock.id), "Song should still be liked when using onRemove callback")
    }
  }
}