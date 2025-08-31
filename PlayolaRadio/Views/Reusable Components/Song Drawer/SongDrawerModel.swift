//
//  SongDrawerModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import SwiftUI
import UIKit

@MainActor
@Observable
class SongDrawerModel: ViewModel {
  @ObservationIgnored @Dependency(\.likesManager) var likesManager: LikesManager
  
  let audioBlock: AudioBlock
  let likedDate: Date
  let onDismiss: () -> Void
  
  init(audioBlock: AudioBlock, likedDate: Date, onDismiss: @escaping () -> Void) {
    self.audioBlock = audioBlock
    self.likedDate = likedDate
    self.onDismiss = onDismiss
  }
  
  func removeFromLikedSongs() {
    likesManager.unlike(audioBlock)
    onDismiss()
  }
  
  func openAppleMusic() {
    // TODO: Implement Apple Music deep link
    onDismiss()
  }
  
  func openSpotify() {
    guard let spotifyId = audioBlock.spotifyId else {
      // No Spotify ID available, just dismiss
      onDismiss()
      return
    }
    
    // Construct Spotify deep link URL
    let spotifyURL = URL(string: "spotify:track:\(spotifyId)")
    let webURL = URL(string: "https://open.spotify.com/track/\(spotifyId)")
    
    if let spotifyURL = spotifyURL, UIApplication.shared.canOpenURL(spotifyURL) {
      // Open in Spotify app if available
      UIApplication.shared.open(spotifyURL)
    } else if let webURL = webURL {
      // Fallback to web version
      UIApplication.shared.open(webURL)
    }
    
    onDismiss()
  }
}