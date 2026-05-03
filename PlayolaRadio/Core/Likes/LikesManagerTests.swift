//
//  LikesManagerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct LikesManagerTests {

  // MARK: - Like Tests

  @Test
  func testLikeAddsToUserLikes() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      return manager
    }

    #expect(manager.isLiked(audioBlock.id))
    #expect(manager.getLikedAudioBlock(audioBlock.id) == audioBlock)
    #expect(manager.allLikedAudioBlocks.count == 1)
    #expect(manager.allLikedAudioBlocks.first == audioBlock)
  }

  @Test
  func testLikeCreatesPendingOperation() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      return manager
    }

    #expect(manager.pendingOperations.count == 1)
    #expect(manager.pendingOperations.first?.audioBlock == audioBlock)
    #expect(manager.pendingOperations.first?.type == .like)
  }

  @Test
  func testLikeCreatesUserSongLikeWithTimestamp() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock
    let beforeLike = Date()

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      return manager
    }

    let timestamp = manager.getLikedTimestamp(audioBlock.id)
    #expect(timestamp != nil)
    #expect(timestamp! >= beforeLike)
    #expect(timestamp! <= Date())
  }

  @Test
  func testLikeDoesNotDuplicateIfAlreadyLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      manager.like(audioBlock)  // Try to like again
      return manager
    }

    #expect(manager.allLikedAudioBlocks.count == 1)
    #expect(manager.pendingOperations.count == 1)
  }

  // MARK: - Unlike Tests

  @Test
  func testUnlikeRemovesFromUserLikes() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      #expect(manager.isLiked(audioBlock.id))

      manager.unlike(audioBlock)
      return manager
    }

    #expect(!manager.isLiked(audioBlock.id))
    #expect(manager.getLikedAudioBlock(audioBlock.id) == nil)
    #expect(manager.allLikedAudioBlocks.count == 0)
  }

  @Test
  func testUnlikeCreatesPendingOperation() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      manager.unlike(audioBlock)
      return manager
    }

    #expect(manager.pendingOperations.count == 2)
    #expect(manager.pendingOperations.last?.audioBlock == audioBlock)
    #expect(manager.pendingOperations.last?.type == .unlike)
  }

  @Test
  func testUnlikeDoesNothingIfNotLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.unlike(audioBlock)
      return manager
    }

    #expect(manager.pendingOperations.count == 0)
  }

  // MARK: - Toggle Tests

  @Test
  func testToggleLikeLikesIfNotLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.toggleLike(audioBlock)
      return manager
    }

    #expect(manager.isLiked(audioBlock.id))
  }

  @Test
  func testToggleLikeUnlikesIfLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock)
      #expect(manager.isLiked(audioBlock.id))

      manager.toggleLike(audioBlock)
      return manager
    }

    #expect(!manager.isLiked(audioBlock.id))
  }

  // MARK: - Multiple Songs Tests

  @Test
  func testMultipleLikes() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock1 = AudioBlock.mock
    let audioBlock2 = AudioBlock.mockWith(id: "different-id")
    let audioBlock3 = AudioBlock.mockWith(id: "another-id")

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.like(audioBlock1)
      manager.like(audioBlock2)
      manager.like(audioBlock3)
      return manager
    }

    #expect(manager.allLikedAudioBlocks.count == 3)
    #expect(manager.isLiked(audioBlock1.id))
    #expect(manager.isLiked(audioBlock2.id))
    #expect(manager.isLiked(audioBlock3.id))
  }

  // MARK: - Cleanup Tests

  @Test
  func testCleanupExpiredOperations() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let recentOp = LikeOperation(
      audioBlock: audioBlock,
      type: .like,
      timestamp: Date()
    )

    let expiredOp = LikeOperation(
      audioBlock: audioBlock,
      type: .unlike,
      timestamp: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)
    )

    let manager = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager = LikesManager()
      manager.$pendingOperations.withLock {
        $0 = [recentOp, expiredOp]
      }
      manager.cleanupExpiredOperations()
      return manager
    }

    #expect(manager.pendingOperations.count == 1)
    #expect(manager.pendingOperations.first == recentOp)
  }

  // MARK: - Persistence Tests

  @Test
  func testPersistenceBetweenInstances() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager2 = withDependencies {
      $0.date = .constant(Date())
      $0.uuid = .incrementing
    } operation: {
      let manager1 = LikesManager()
      manager1.like(audioBlock)

      return LikesManager()
    }

    #expect(manager2.isLiked(audioBlock.id))
    #expect(manager2.allLikedAudioBlocks.count == 1)
    #expect(manager2.pendingOperations.count == 1)
  }
}
