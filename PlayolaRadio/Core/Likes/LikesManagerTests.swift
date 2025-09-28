//
//  LikesManagerTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Dependencies
import PlayolaPlayer
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class LikesManagerTests: XCTestCase {
  // MARK: - Setup

  override func setUp() async throws {
    try await super.setUp()
    @Shared(.userLikes) var userLikes: [String: UserSongLike] = [:]
    @Shared(.pendingLikeOperations) var pendingOperations: [LikeOperation] = []
    $userLikes.withLock { $0 = [:] }
    $pendingOperations.withLock { $0 = [] }
  }

  // MARK: - Like Tests

  func testLike_AddsToUserLikes() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)

    XCTAssertTrue(manager.isLiked(audioBlock.id))
    XCTAssertEqual(manager.getLikedAudioBlock(audioBlock.id), audioBlock)
    XCTAssertEqual(manager.allLikedAudioBlocks.count, 1)
    XCTAssertEqual(manager.allLikedAudioBlocks.first, audioBlock)
  }

  func testLike_CreatesPendingOperation() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)

    XCTAssertEqual(manager.pendingOperations.count, 1)
    XCTAssertEqual(manager.pendingOperations.first?.audioBlock, audioBlock)
    XCTAssertEqual(manager.pendingOperations.first?.type, .like)
  }

  func testLike_CreatesUserSongLikeWithTimestamp() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock
    let beforeLike = Date()

    manager.like(audioBlock)

    let timestamp = manager.getLikedTimestamp(audioBlock.id)
    XCTAssertNotNil(timestamp)
    XCTAssertTrue(timestamp! >= beforeLike)
    XCTAssertTrue(timestamp! <= Date())
  }

  func testLike_DoesNotDuplicateIfAlreadyLiked() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)
    manager.like(audioBlock)  // Try to like again

    XCTAssertEqual(manager.allLikedAudioBlocks.count, 1)
    XCTAssertEqual(manager.pendingOperations.count, 1)
  }

  // MARK: - Unlike Tests

  func testUnlike_RemovesFromUserLikes() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)
    XCTAssertTrue(manager.isLiked(audioBlock.id))

    manager.unlike(audioBlock)

    XCTAssertFalse(manager.isLiked(audioBlock.id))
    XCTAssertNil(manager.getLikedAudioBlock(audioBlock.id))
    XCTAssertEqual(manager.allLikedAudioBlocks.count, 0)
  }

  func testUnlike_CreatesPendingOperation() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)

    manager.unlike(audioBlock)

    XCTAssertEqual(manager.pendingOperations.count, 2)
    XCTAssertEqual(manager.pendingOperations.last?.audioBlock, audioBlock)
    XCTAssertEqual(manager.pendingOperations.last?.type, .unlike)
  }

  func testUnlike_DoesNothingIfNotLiked() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.unlike(audioBlock)

    XCTAssertEqual(manager.pendingOperations.count, 0)
  }

  // MARK: - Toggle Tests

  func testToggleLike_LikesIfNotLiked() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.toggleLike(audioBlock)

    XCTAssertTrue(manager.isLiked(audioBlock.id))
  }

  func testToggleLike_UnlikesIfLiked() async {
    let manager = LikesManager()
    let audioBlock = AudioBlock.mock

    manager.like(audioBlock)
    XCTAssertTrue(manager.isLiked(audioBlock.id))

    manager.toggleLike(audioBlock)

    XCTAssertFalse(manager.isLiked(audioBlock.id))
  }

  // MARK: - Multiple Songs Tests

  func testMultipleLikes() async {
    let manager = LikesManager()
    let audioBlock1 = AudioBlock.mock
    let audioBlock2 = AudioBlock.mockWith(id: "different-id")
    let audioBlock3 = AudioBlock.mockWith(id: "another-id")

    manager.like(audioBlock1)
    manager.like(audioBlock2)
    manager.like(audioBlock3)

    XCTAssertEqual(manager.allLikedAudioBlocks.count, 3)
    XCTAssertTrue(manager.isLiked(audioBlock1.id))
    XCTAssertTrue(manager.isLiked(audioBlock2.id))
    XCTAssertTrue(manager.isLiked(audioBlock3.id))
  }

  // MARK: - Cleanup Tests

  func testCleanupExpiredOperations() async {
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

    XCTAssertEqual(manager.pendingOperations.count, 1)
    XCTAssertEqual(manager.pendingOperations.first, recentOp)
  }

  // MARK: - Persistence Tests

  func testPersistenceBetweenInstances() async {
    let audioBlock = AudioBlock.mock

    let manager1 = LikesManager()
    manager1.like(audioBlock)

    let manager2 = LikesManager()

    XCTAssertTrue(manager2.isLiked(audioBlock.id))
    XCTAssertEqual(manager2.allLikedAudioBlocks.count, 1)
    XCTAssertEqual(manager2.pendingOperations.count, 1)
  }
}
