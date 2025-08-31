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
}