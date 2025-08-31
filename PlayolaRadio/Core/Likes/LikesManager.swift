//
//  LikesManager.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Combine
import Dependencies
import Foundation
import PlayolaPlayer
import Sharing

/// Manages user likes for audio blocks with local persistence and server sync
@MainActor
final class LikesManager: ObservableObject {
  // MARK: - Shared State

  /// Dictionary of user likes keyed by audio block ID
  @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]

  /// Queue of pending operations to sync with server
  @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

  // MARK: - Dependencies

  @Dependency(\.api) private var api
  @Shared(.auth) private var auth

  private var authCancellable: AnyCancellable?
  private var lastJWT: String?

  init() {
    setupAuthObserver()
  }

  private func setupAuthObserver() {
    authCancellable = $auth.publisher
      .sink { [weak self] newAuth in
        Task { @MainActor [weak self] in
          await self?.handleAuthChange(newAuth)
        }
      }
  }

  private func handleAuthChange(_ newAuth: Auth) async {
    if let jwt = newAuth.jwt {
      if jwt != lastJWT {
        lastJWT = jwt
        await syncFromServer()
        await syncPendingOperations()
      }
    } else {
      lastJWT = nil
      $userLikes.withLock { $0.removeAll() }
      $pendingOperations.withLock { $0.removeAll() }
    }
  }

  // MARK: - Public Interface

  /// Checks if an audio block is liked
  /// - Parameter audioBlockId: The ID of the audio block to check
  /// - Returns: True if the audio block is liked, false otherwise
  func isLiked(_ audioBlockId: String) -> Bool {
    userLikes[audioBlockId] != nil
  }

  /// Gets a liked audio block by ID
  /// - Parameter audioBlockId: The ID of the audio block to retrieve
  /// - Returns: The audio block if it's liked, nil otherwise
  func getLikedAudioBlock(_ audioBlockId: String) -> AudioBlock? {
    userLikes[audioBlockId]?.audioBlock
  }

  /// Gets all liked audio blocks
  /// - Returns: Array of all liked audio blocks
  var allLikedAudioBlocks: [AudioBlock] {
    userLikes.values.map { $0.audioBlock }
  }

  /// Gets the timestamp when an audio block was liked
  /// - Parameter audioBlockId: The ID of the audio block
  /// - Returns: The timestamp when it was liked, or nil if not liked
  func getLikedTimestamp(_ audioBlockId: String) -> Date? {
    return userLikes[audioBlockId]?.createdAt
  }

  /// Gets all liked audio blocks with their like timestamps
  /// - Returns: Array of tuples containing audio blocks and their like timestamps
  var allLikedAudioBlocksWithTimestamps: [(AudioBlock, Date)] {
    let result = userLikes.values.map { ($0.audioBlock, $0.createdAt) }
    print("🔍 allLikedAudioBlocksWithTimestamps - userLikes keys: \(Array(userLikes.keys))")
    print("🔍 allLikedAudioBlocksWithTimestamps - audioBlock IDs: \(result.map { $0.0.id })")
    return result
  }

  /// Toggles the like status of an audio block
  /// - Parameters:
  ///   - audioBlock: The audio block to like or unlike
  ///   - spinId: Optional ID of the spin context where the like occurred
  func toggleLike(_ audioBlock: AudioBlock, spinId: String? = nil) {
    if isLiked(audioBlock.id) {
      unlike(audioBlock)
    } else {
      like(audioBlock, spinId: spinId)
    }
  }

  /// Likes an audio block
  /// - Parameters:
  ///   - audioBlock: The audio block to like
  ///   - spinId: Optional ID of the spin context where the like occurred
  func like(_ audioBlock: AudioBlock, spinId: String? = nil) {
    guard !isLiked(audioBlock.id) else { return }

    // Create a local UserSongLike for optimistic update
    let userSongLike = UserSongLike(
      userId: auth.currentUser?.id ?? "",
      audioBlockId: audioBlock.id,
      spinId: spinId,
      audioBlock: audioBlock
    )
    $userLikes.withLock {
      $0[audioBlock.id] = userSongLike
    }

    let operation = LikeOperation(
      audioBlock: audioBlock,
      type: .like,
      spinId: spinId
    )
    $pendingOperations.withLock {
      $0.append(operation)
    }

    Task {
      await syncPendingOperations()
    }
  }

  /// Unlikes an audio block
  /// - Parameter audioBlock: The audio block to unlike
  func unlike(_ audioBlock: AudioBlock) {
    print("🔍 Unlike attempt for: \(audioBlock.title), ID: \(audioBlock.id)")
    print("🔍 Is liked check: \(isLiked(audioBlock.id))")
    print("🔍 UserLikes keys: \(Array(userLikes.keys))")

    guard isLiked(audioBlock.id) else {
      print("❌ Unlike failed - not in liked songs")
      return
    }

    print("🔄 Unlike called for: \(audioBlock.title)")

    $userLikes.withLock {
      $0[audioBlock.id] = nil
    }

    let operation = LikeOperation(
      audioBlock: audioBlock,
      type: .unlike
    )
    $pendingOperations.withLock {
      $0.append(operation)
    }

    print("🔄 Pending unlike operations: \(pendingOperations.count)")

    Task {
      await syncPendingOperations()
    }
  }

  /// Clears expired operations from the pending queue
  func cleanupExpiredOperations() {
    $pendingOperations.withLock {
      $0.removeAll { $0.isExpired }
    }
  }

  /// Fetches liked songs from server and syncs with local state
  func syncFromServer() async {
    guard let jwt = auth.jwt else { return }

    do {
      let serverLikes = try await api.getLikedSongs(jwt)

      $userLikes.withLock { likesDict in
        likesDict.removeAll()
        for userSongLike in serverLikes {
          likesDict[userSongLike.audioBlockId] = userSongLike
        }
      }
    } catch {
      print("Failed to sync likes from server: \(error)")
    }
  }

  /// Syncs pending operations with the server
  func syncPendingOperations() async {
    guard let jwt = auth.jwt else { return }

    let operations = pendingOperations

    for operation in operations {
      do {
        switch operation.type {
        case .like:
          try await api.likeSong(jwt, operation.audioBlock.id, operation.spinId)
        case .unlike:
          print("🔄 Syncing unlike for: \(operation.audioBlock.title)")
          try await api.unlikeSong(jwt, operation.audioBlock.id)
        }

        $pendingOperations.withLock {
          $0.removeAll { $0.id == operation.id }
        }
      } catch {
        let updatedOperation = operation.incrementingRetryCount()
        if updatedOperation.shouldRetry {
          $pendingOperations.withLock {
            if let index = $0.firstIndex(where: { $0.id == operation.id }) {
              $0[index] = updatedOperation
            }
          }
        } else {
          $pendingOperations.withLock {
            $0.removeAll { $0.id == operation.id }
          }
        }
      }
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
