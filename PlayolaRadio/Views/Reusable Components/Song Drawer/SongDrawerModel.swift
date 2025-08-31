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
  let onRemove: ((AudioBlock) -> Void)?
  
  init(audioBlock: AudioBlock, likedDate: Date, onDismiss: @escaping () -> Void, onRemove: ((AudioBlock) -> Void)? = nil) {
    self.audioBlock = audioBlock
    self.likedDate = likedDate
    self.onDismiss = onDismiss
    self.onRemove = onRemove
  }
  
  var shouldShowSpotify: Bool {
    return audioBlock.spotifyId != nil && !(audioBlock.spotifyId?.isEmpty ?? true)
  }
  
  var shouldShowAppleMusic: Bool {
    return !audioBlock.title.isEmpty && !audioBlock.artist.isEmpty
  }
  
  func removeFromLikedSongs() {
    print("🗑️ removeFromLikedSongs called for: \(audioBlock.title)")
    if let onRemove = onRemove {
      // Use animated removal if callback is provided
      onRemove(audioBlock)
    } else {
      // Fallback to direct removal
      likesManager.unlike(audioBlock)
    }
    onDismiss()
  }
  
  func openAppleMusic() {
    // Apple Music deep linking can use search if no direct ID is available
    let artist = audioBlock.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let title = audioBlock.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    
    // Try Apple Music app first with search URL
    let appleMusicAppURL = URL(string: "music://music.apple.com/search?term=\(artist)+\(title)")
    let appleMusicWebURL = URL(string: "https://music.apple.com/search?term=\(artist)+\(title)")
    
    if let appleMusicAppURL = appleMusicAppURL, UIApplication.shared.canOpenURL(appleMusicAppURL) {
      // Open in Apple Music app if available
      UIApplication.shared.open(appleMusicAppURL)
    } else if let appleMusicWebURL = appleMusicWebURL {
      // Fallback to web version
      UIApplication.shared.open(appleMusicWebURL)
    }
    
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