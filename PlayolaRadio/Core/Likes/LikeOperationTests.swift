//
//  LikeOperationTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import PlayolaPlayer
import XCTest

@testable import PlayolaRadio

final class LikeOperationTests: XCTestCase {
  // MARK: - Test Data

  private let testAudioBlock = AudioBlock.mock

  // MARK: - Initialization Tests

  func testInit_DefaultValues() {
    let operation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like
    )

    XCTAssertNotNil(operation.id)
    XCTAssertEqual(operation.audioBlock.id, testAudioBlock.id)
    XCTAssertEqual(operation.type, .like)
    XCTAssertEqual(operation.retryCount, 0)
    XCTAssertTrue(abs(operation.timestamp.timeIntervalSinceNow) < 1)  // Recent timestamp
  }

  func testInit_CustomValues() {
    let customId = UUID()
    let customDate = Date(timeIntervalSinceNow: -3600)  // 1 hour ago

    let operation = LikeOperation(
      id: customId,
      audioBlock: testAudioBlock,
      type: .unlike,
      timestamp: customDate,
      retryCount: 2
    )

    XCTAssertEqual(operation.id, customId)
    XCTAssertEqual(operation.type, .unlike)
    XCTAssertEqual(operation.timestamp, customDate)
    XCTAssertEqual(operation.retryCount, 2)
  }

  // MARK: - Retry Logic Tests

  func testIncrementingRetryCount() {
    let operation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      retryCount: 1
    )

    let incrementedOperation = operation.incrementingRetryCount()

    XCTAssertEqual(incrementedOperation.id, operation.id)
    XCTAssertEqual(incrementedOperation.audioBlock.id, operation.audioBlock.id)
    XCTAssertEqual(incrementedOperation.type, operation.type)
    XCTAssertEqual(incrementedOperation.timestamp, operation.timestamp)
    XCTAssertEqual(incrementedOperation.retryCount, 2)
  }

  func testShouldRetry() {
    let operation0 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 0)
    let operation1 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 1)
    let operation2 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 2)
    let operation3 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 3)
    let operation4 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 4)

    XCTAssertTrue(operation0.shouldRetry)
    XCTAssertTrue(operation1.shouldRetry)
    XCTAssertTrue(operation2.shouldRetry)
    XCTAssertFalse(operation3.shouldRetry)  // Max retries = 3
    XCTAssertFalse(operation4.shouldRetry)
  }

  // MARK: - Expiration Tests

  func testIsExpired() {
    let recentOperation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      timestamp: Date()
    )

    let oldOperation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      timestamp: Date(timeIntervalSinceNow: -8 * 24 * 60 * 60)  // 8 days ago
    )

    XCTAssertFalse(recentOperation.isExpired)
    XCTAssertTrue(oldOperation.isExpired)
  }

  // MARK: - Equatable Tests

  func testEquatable_Equal() {
    let id = UUID()
    let date = Date()

    let operation1 = LikeOperation(
      id: id,
      audioBlock: testAudioBlock,
      type: .like,
      timestamp: date,
      retryCount: 1
    )

    let operation2 = LikeOperation(
      id: id,
      audioBlock: testAudioBlock,
      type: .like,
      timestamp: date,
      retryCount: 1
    )

    XCTAssertEqual(operation1, operation2)
  }

  func testEquatable_NotEqual_DifferentId() {
    let operation1 = LikeOperation(audioBlock: testAudioBlock, type: .like)
    let operation2 = LikeOperation(audioBlock: testAudioBlock, type: .like)

    XCTAssertNotEqual(operation1, operation2)  // Different IDs
  }

  func testEquatable_NotEqual_DifferentType() {
    let id = UUID()
    let operation1 = LikeOperation(id: id, audioBlock: testAudioBlock, type: .like)
    let operation2 = LikeOperation(id: id, audioBlock: testAudioBlock, type: .unlike)

    XCTAssertNotEqual(operation1, operation2)
  }

  // MARK: - Codable Tests

  func testCodable() throws {
    let operation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      retryCount: 2
    )

    // Encode
    let encoder = JSONEncoder()
    let data = try encoder.encode(operation)

    // Decode
    let decoder = JSONDecoder()
    let decodedOperation = try decoder.decode(LikeOperation.self, from: data)

    // Verify
    XCTAssertEqual(decodedOperation.id, operation.id)
    XCTAssertEqual(decodedOperation.audioBlock.id, operation.audioBlock.id)
    XCTAssertEqual(decodedOperation.audioBlock.title, operation.audioBlock.title)
    XCTAssertEqual(decodedOperation.type, operation.type)
    XCTAssertEqual(decodedOperation.retryCount, operation.retryCount)
    XCTAssertEqual(
      decodedOperation.timestamp.timeIntervalSince1970, operation.timestamp.timeIntervalSince1970,
      accuracy: 0.001
    )
  }

  func testOperationType_RawValues() {
    XCTAssertEqual(LikeOperation.OperationType.like.rawValue, "like")
    XCTAssertEqual(LikeOperation.OperationType.unlike.rawValue, "unlike")
  }
}
