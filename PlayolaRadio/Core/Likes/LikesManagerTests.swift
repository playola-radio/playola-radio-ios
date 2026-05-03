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

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)

    #expect(manager.isLiked(audioBlock.id))
    #expect(manager.getLikedAudioBlock(audioBlock.id) == audioBlock)
    #expect(manager.allLikedAudioBlocks.count == 1)
    #expect(manager.allLikedAudioBlocks.first == audioBlock)
  }

  @Test
  func testLikeCreatesPendingOperation() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)

    #expect(manager.pendingOperations.count == 1)
    #expect(manager.pendingOperations.first?.audioBlock == audioBlock)
    #expect(manager.pendingOperations.first?.type == .like)
  }

  @Test
  func testLikeCreatesUserSongLikeWithTimestamp() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock
    let beforeLike = Date()

    manager.like(audioBlock)

    let timestamp = manager.getLikedTimestamp(audioBlock.id)
    #expect(timestamp != nil)
    #expect(timestamp! >= beforeLike)
    #expect(timestamp! <= Date())
  }

  @Test
  func testLikeDoesNotDuplicateIfAlreadyLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)
    manager.like(audioBlock)  // Try to like again

    #expect(manager.allLikedAudioBlocks.count == 1)
    #expect(manager.pendingOperations.count == 1)
  }

  // MARK: - Unlike Tests

  @Test
  func testUnlikeRemovesFromUserLikes() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)
    #expect(manager.isLiked(audioBlock.id))

    manager.unlike(audioBlock)

    #expect(!manager.isLiked(audioBlock.id))
    #expect(manager.getLikedAudioBlock(audioBlock.id) == nil)
    #expect(manager.allLikedAudioBlocks.count == 0)
  }

  @Test
  func testUnlikeCreatesPendingOperation() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)

    manager.unlike(audioBlock)

    #expect(manager.pendingOperations.count == 2)
    #expect(manager.pendingOperations.last?.audioBlock == audioBlock)
    #expect(manager.pendingOperations.last?.type == .unlike)
  }

  @Test
  func testUnlikeDoesNothingIfNotLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.unlike(audioBlock)

    #expect(manager.pendingOperations.count == 0)
  }

  // MARK: - Toggle Tests

  @Test
  func testToggleLikeLikesIfNotLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.toggleLike(audioBlock)

    #expect(manager.isLiked(audioBlock.id))
  }

  @Test
  func testToggleLikeUnlikesIfLiked() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)
    #expect(manager.isLiked(audioBlock.id))

    manager.toggleLike(audioBlock)

    #expect(!manager.isLiked(audioBlock.id))
  }

  // MARK: - Multiple Songs Tests

  @Test
  func testMultipleLikes() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let manager = LikesManager()
    let audioBlock1 = AudioBlock.mock
    let audioBlock2 = AudioBlock.mockWith(id: "different-id")
    let audioBlock3 = AudioBlock.mockWith(id: "another-id")

    manager.like(audioBlock1)
    manager.like(audioBlock2)
    manager.like(audioBlock3)

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

    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    let recentOp = LikeOperation(audioBlock: audioBlock, type: .like)

    let expiredOp = LikeOperation(
      audioBlock: audioBlock,
      type: .unlike,
      timestamp: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)
    )

    manager.$pendingOperations.withLock {
      $0 = [recentOp, expiredOp]
    }

    manager.cleanupExpiredOperations()

    #expect(manager.pendingOperations.count == 1)
    #expect(manager.pendingOperations.first == recentOp)
  }

  // MARK: - Persistence Tests

  @Test
  func testPersistenceBetweenInstances() async {
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []

    let audioBlock = AudioBlock.mock

    let manager1 = LikesManager()
    manager1.like(audioBlock)

    let manager2 = LikesManager()

    #expect(manager2.isLiked(audioBlock.id))
    #expect(manager2.allLikedAudioBlocks.count == 1)
    #expect(manager2.pendingOperations.count == 1)
  }
}
