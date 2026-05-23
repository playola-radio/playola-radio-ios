//
//  LikeOperationTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Foundation
import PlayolaPlayer
import Testing

@testable import PlayolaRadio

struct LikeOperationTests {

  // MARK: - Test Data

  private let testAudioBlock = AudioBlock.mock

  // MARK: - Initialization Tests

  @Test
  func testInitDefaultValues() {
    let operation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like
    )

    #expect(operation.audioBlock.id == testAudioBlock.id)
    #expect(operation.type == .like)
    #expect(operation.retryCount == 0)
    #expect(abs(operation.timestamp.timeIntervalSinceNow) < 1)
  }

  @Test
  func testInitCustomValues() {
    let customId = UUID()
    let customDate = Date(timeIntervalSinceNow: -3600)

    let operation = LikeOperation(
      id: customId,
      audioBlock: testAudioBlock,
      type: .unlike,
      timestamp: customDate,
      retryCount: 2
    )

    #expect(operation.id == customId)
    #expect(operation.type == .unlike)
    #expect(operation.timestamp == customDate)
    #expect(operation.retryCount == 2)
  }

  // MARK: - Retry Logic Tests

  @Test
  func testIncrementingRetryCount() {
    let operation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      retryCount: 1
    )

    let incrementedOperation = operation.incrementingRetryCount()

    #expect(incrementedOperation.id == operation.id)
    #expect(incrementedOperation.audioBlock.id == operation.audioBlock.id)
    #expect(incrementedOperation.type == operation.type)
    #expect(incrementedOperation.timestamp == operation.timestamp)
    #expect(incrementedOperation.retryCount == 2)
  }

  @Test
  func testShouldRetry() {
    let operation0 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 0)
    let operation1 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 1)
    let operation2 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 2)
    let operation3 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 3)
    let operation4 = LikeOperation(audioBlock: testAudioBlock, type: .like, retryCount: 4)

    #expect(operation0.shouldRetry)
    #expect(operation1.shouldRetry)
    #expect(operation2.shouldRetry)
    #expect(!operation3.shouldRetry)
    #expect(!operation4.shouldRetry)
  }

  // MARK: - Expiration Tests

  @Test
  func testIsExpired() {
    let now = Date()
    let recentOperation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      timestamp: now
    )

    let oldOperation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      timestamp: now.addingTimeInterval(-8 * 24 * 60 * 60)
    )

    #expect(!recentOperation.isExpired(now: now))
    #expect(oldOperation.isExpired(now: now))
  }

  // MARK: - Equatable Tests

  @Test
  func testEquatableEqual() {
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

    #expect(operation1 == operation2)
  }

  @Test
  func testEquatableNotEqualDifferentId() {
    let operation1 = LikeOperation(audioBlock: testAudioBlock, type: .like)
    let operation2 = LikeOperation(audioBlock: testAudioBlock, type: .like)

    #expect(operation1 != operation2)
  }

  @Test
  func testEquatableNotEqualDifferentType() {
    let id = UUID()
    let operation1 = LikeOperation(id: id, audioBlock: testAudioBlock, type: .like)
    let operation2 = LikeOperation(id: id, audioBlock: testAudioBlock, type: .unlike)

    #expect(operation1 != operation2)
  }

  // MARK: - Codable Tests

  @Test
  func testCodable() throws {
    let operation = LikeOperation(
      audioBlock: testAudioBlock,
      type: .like,
      retryCount: 2
    )

    let encoder = JSONEncoder()
    let data = try encoder.encode(operation)

    let decoder = JSONDecoder()
    let decodedOperation = try decoder.decode(LikeOperation.self, from: data)

    #expect(decodedOperation.id == operation.id)
    #expect(decodedOperation.audioBlock.id == operation.audioBlock.id)
    #expect(decodedOperation.audioBlock.title == operation.audioBlock.title)
    #expect(decodedOperation.type == operation.type)
    #expect(decodedOperation.retryCount == operation.retryCount)
    #expect(
      abs(
        decodedOperation.timestamp.timeIntervalSince1970
          - operation.timestamp.timeIntervalSince1970
      ) < 0.001
    )
  }

  @Test
  func testOperationTypeRawValues() {
    #expect(LikeOperation.OperationType.like.rawValue == "like")
    #expect(LikeOperation.OperationType.unlike.rawValue == "unlike")
  }
}
