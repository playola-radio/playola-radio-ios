//
//  UserSongLike.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/31/25.
//

import Foundation
import PlayolaPlayer

/// Represents a user's like for a song as returned by the server
struct UserSongLike: Codable, Equatable, Identifiable {
  let id: String  // Auto-generated for local likes, provided by server for synced likes
  let userId: String
  let audioBlockId: String
  let spinId: String?
  let audioBlock: AudioBlock
  let spin: Spin?
  let createdAt: Date
  let updatedAt: Date?
  let isLocal: Bool  // true for local-only likes, false for server-synced likes

  init(
    id: String? = nil,
    userId: String,
    audioBlockId: String,
    spinId: String? = nil,
    audioBlock: AudioBlock,
    spin: Spin? = nil,
    createdAt: Date = Date(),
    updatedAt: Date? = nil,
    isLocal: Bool = true
  ) {
    self.id = id ?? UUID().uuidString  // Auto-generate if not provided
    self.userId = userId
    self.audioBlockId = audioBlockId
    self.spinId = spinId
    self.audioBlock = audioBlock
    self.spin = spin
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isLocal = isLocal
  }

  // Custom decoding to ensure isLocal is false when from server
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    userId = try container.decode(String.self, forKey: .userId)
    audioBlockId = try container.decode(String.self, forKey: .audioBlockId)
    spinId = try container.decodeIfPresent(String.self, forKey: .spinId)
    audioBlock = try container.decode(AudioBlock.self, forKey: .audioBlock)
    spin = try container.decodeIfPresent(Spin.self, forKey: .spin)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    isLocal = false  // Always false when decoded from server
  }

  enum CodingKeys: String, CodingKey {
    case id, userId, audioBlockId, spinId, audioBlock, spin, createdAt, updatedAt
    // Note: isLocal is not included in CodingKeys, so it won't be encoded/decoded
  }
}
