//
//  StationCategory.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer

enum AudioBlockCategoryType: String, Codable, Sendable, Hashable, CaseIterable {
  case song
  case commercialblock
  case voicetrack
  case audioimage
  case productionpiece
  case commentary
  case unknown

  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    self = AudioBlockCategoryType(rawValue: raw) ?? .unknown
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  var displayName: String {
    switch self {
    case .song: return "Song"
    case .commercialblock: return "Commercial"
    case .voicetrack: return "Voicetrack"
    case .audioimage: return "Audio Image"
    case .productionpiece: return "Production Piece"
    case .commentary: return "Commentary"
    case .unknown: return "Other"
    }
  }

  var iconSystemName: String {
    switch self {
    case .song: return "music.note"
    case .commercialblock: return "dollarsign.circle"
    case .voicetrack: return "mic.fill"
    case .audioimage: return "waveform"
    case .productionpiece: return "slider.horizontal.3"
    case .commentary: return "text.bubble"
    case .unknown: return "square.stack"
    }
  }
}

struct StationCategory: Codable, Sendable, Identifiable, Hashable, Equatable {
  let id: String
  let name: String
  let audioBlockType: AudioBlockCategoryType
  let audioBlocks: [AudioBlock]
  let createdAt: Date
  let updatedAt: Date

  var isSong: Bool { audioBlockType == .song }

  enum CodingKeys: String, CodingKey {
    case id, name, audioBlockType, audioBlocks, createdAt, updatedAt
  }

  init(
    id: String,
    name: String,
    audioBlockType: AudioBlockCategoryType,
    audioBlocks: [AudioBlock] = [],
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.name = name
    self.audioBlockType = audioBlockType
    self.audioBlocks = audioBlocks
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    audioBlockType = try container.decode(AudioBlockCategoryType.self, forKey: .audioBlockType)
    audioBlocks = try container.decodeIfPresent([AudioBlock].self, forKey: .audioBlocks) ?? []
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }
}

extension StationCategory {
  static func mockWith(
    id: String = "mock-category-id",
    name: String = "Station IDs",
    audioBlockType: AudioBlockCategoryType = .audioimage,
    audioBlocks: [AudioBlock] = [],
    createdAt: Date = Date(timeIntervalSince1970: 1_000_000),
    updatedAt: Date = Date(timeIntervalSince1970: 1_000_000)
  ) -> StationCategory {
    StationCategory(
      id: id,
      name: name,
      audioBlockType: audioBlockType,
      audioBlocks: audioBlocks,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}
