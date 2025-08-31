//
//  LikeOperation.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import Foundation
import PlayolaPlayer

/// Represents a pending like or unlike operation that needs to be synced with the server
struct LikeOperation: Codable, Equatable, Identifiable {
  /// The type of operation to perform
  enum OperationType: String, Codable, Equatable {
    case like
    case unlike
  }

  /// Unique identifier for this operation
  let id: UUID

  /// The audio block being liked or unliked
  let audioBlock: AudioBlock

  /// The type of operation (like or unlike)
  let type: OperationType

  /// When this operation was created
  let timestamp: Date

  /// Number of times we've tried to sync this operation
  var retryCount: Int

  /// Optional spin ID for context where the like occurred
  let spinId: String?

  /// Maximum number of retries before giving up
  static let maxRetries = 3

  init(
    id: UUID = UUID(),
    audioBlock: AudioBlock,
    type: OperationType,
    timestamp: Date = Date(),
    retryCount: Int = 0,
    spinId: String? = nil
  ) {
    self.id = id
    self.audioBlock = audioBlock
    self.type = type
    self.timestamp = timestamp
    self.retryCount = retryCount
    self.spinId = spinId
  }

  /// Creates a new operation with an incremented retry count
  func incrementingRetryCount() -> LikeOperation {
    LikeOperation(
      id: id,
      audioBlock: audioBlock,
      type: type,
      timestamp: timestamp,
      retryCount: retryCount + 1,
      spinId: spinId
    )
  }

  /// Whether this operation should be retried
  var shouldRetry: Bool {
    retryCount < Self.maxRetries
  }

  /// Whether this operation has expired (older than 7 days)
  var isExpired: Bool {
    Date().timeIntervalSince(timestamp) > 7 * 24 * 60 * 60
  }
}

// MARK: - Equatable

extension LikeOperation {
  static func == (lhs: LikeOperation, rhs: LikeOperation) -> Bool {
    lhs.id == rhs.id && lhs.audioBlock.id == rhs.audioBlock.id && lhs.type == rhs.type
      && lhs.timestamp == rhs.timestamp && lhs.retryCount == rhs.retryCount
  }
}
