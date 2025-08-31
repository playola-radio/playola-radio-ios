//
//  LikesManager.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing

/// Manages user likes for audio blocks with local persistence and server sync
@MainActor
final class LikesManager: ObservableObject {
  // MARK: - Shared State

  /// Dictionary of liked audio blocks keyed by their ID
  @Shared(.likedAudioBlocks) var likedAudioBlocks: [String: AudioBlock] = [:]

  /// Queue of pending operations to sync with server
  @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

  // MARK: - Dependencies

  @Dependency(\.api) private var api

  // MARK: - Public Interface

  /// Checks if an audio block is liked
  /// - Parameter audioBlockId: The ID of the audio block to check
  /// - Returns: True if the audio block is liked, false otherwise
  func isLiked(_ audioBlockId: String) -> Bool {
    likedAudioBlocks[audioBlockId] != nil
  }

  /// Gets a liked audio block by ID
  /// - Parameter audioBlockId: The ID of the audio block to retrieve
  /// - Returns: The audio block if it's liked, nil otherwise
  func getLikedAudioBlock(_ audioBlockId: String) -> AudioBlock? {
    likedAudioBlocks[audioBlockId]
  }

  /// Gets all liked audio blocks
  /// - Returns: Array of all liked audio blocks
  var allLikedAudioBlocks: [AudioBlock] {
    Array(likedAudioBlocks.values)
  }

  /// Gets the timestamp when an audio block was liked
  /// - Parameter audioBlockId: The ID of the audio block
  /// - Returns: The timestamp when it was liked, or nil if not liked
  func getLikedTimestamp(_ audioBlockId: String) -> Date? {
    // Find the most recent like operation for this audio block
    return
      pendingOperations
      .filter { $0.audioBlock.id == audioBlockId && $0.type == .like }
      .max(by: { $0.timestamp < $1.timestamp })?
      .timestamp
  }

  /// Gets all liked audio blocks with their like timestamps
  /// - Returns: Array of tuples containing audio blocks and their like timestamps
  var allLikedAudioBlocksWithTimestamps: [(AudioBlock, Date)] {
    return likedAudioBlocks.values.compactMap { audioBlock in
      if let likedTimestamp = getLikedTimestamp(audioBlock.id) {
        return (audioBlock, likedTimestamp)
      }
      return nil
    }
  }

  /// Toggles the like status of an audio block
  /// - Parameter audioBlock: The audio block to like or unlike
  func toggleLike(_ audioBlock: AudioBlock) {
    if isLiked(audioBlock.id) {
      unlike(audioBlock)
    } else {
      like(audioBlock)
    }
  }

  /// Likes an audio block
  /// - Parameter audioBlock: The audio block to like
  func like(_ audioBlock: AudioBlock) {
    guard !isLiked(audioBlock.id) else { return }

    $likedAudioBlocks.withLock {
      $0[audioBlock.id] = audioBlock
    }

    let operation = LikeOperation(
      audioBlock: audioBlock,
      type: .like
    )
    $pendingOperations.withLock {
      $0.append(operation)
    }

    // TODO: Trigger sync
  }

  /// Unlikes an audio block
  /// - Parameter audioBlock: The audio block to unlike
  func unlike(_ audioBlock: AudioBlock) {
    guard isLiked(audioBlock.id) else { return }

    $likedAudioBlocks.withLock {
      $0[audioBlock.id] = nil
    }

    let operation = LikeOperation(
      audioBlock: audioBlock,
      type: .unlike
    )
    $pendingOperations.withLock {
      $0.append(operation)
    }

    // TODO: Trigger sync
  }

  /// Clears expired operations from the pending queue
  func cleanupExpiredOperations() {
    $pendingOperations.withLock {
      $0.removeAll { $0.isExpired }
    }
  }
}

// MARK: - Dependency

extension LikesManager: DependencyKey {
  static let liveValue = LikesManager()
}

extension DependencyValues {
  var likesManager: LikesManager {
    get { self[LikesManager.self] }
    set { self[LikesManager.self] = newValue }
  }
}
