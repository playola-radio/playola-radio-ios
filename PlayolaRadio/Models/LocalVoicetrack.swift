//
//  LocalVoicetrack.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/13/25.
//

import Foundation

enum LocalVoicetrackStatus: Equatable {
  case converting
  case uploading(progress: Double)
  case normalizing
  case finalizing
  case completed
  case failed(error: String)
}

struct LocalVoicetrack: Identifiable, Equatable {
  let id: UUID
  let originalURL: URL
  var convertedURL: URL?
  var status: LocalVoicetrackStatus
  let createdAt: Date
  var title: String
  var audioBlockId: String?

  init(
    id: UUID = UUID(),
    originalURL: URL,
    convertedURL: URL? = nil,
    status: LocalVoicetrackStatus = .converting,
    createdAt: Date = Date(),
    title: String,
    audioBlockId: String? = nil
  ) {
    self.id = id
    self.originalURL = originalURL
    self.convertedURL = convertedURL
    self.status = status
    self.createdAt = createdAt
    self.title = title
    self.audioBlockId = audioBlockId
  }
}

// MARK: - Computed Properties

extension LocalVoicetrack {
  var isProcessing: Bool {
    switch status {
    case .converting, .uploading, .normalizing, .finalizing:
      return true
    case .completed, .failed:
      return false
    }
  }

  var isComplete: Bool {
    status == .completed
  }

  var isFailed: Bool {
    if case .failed = status {
      return true
    }
    return false
  }
}
