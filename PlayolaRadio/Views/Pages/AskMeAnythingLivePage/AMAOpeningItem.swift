//
//  AMAOpeningItem.swift
//  PlayolaRadio
//

import CasePaths
import Foundation
import PlayolaPlayer

struct AMAOpeningItem: Codable, Identifiable, Equatable {
  let id: UUID
  var content: Content

  @CasePathable
  enum Content: Codable, Equatable {
    case intro(AudioBlock)
    case song(AudioBlock)
    case voicetrack(LocalVoicetrack, completedDurationMS: Int?)
  }
}

extension AMAOpeningItem {
  var audioBlockId: String? {
    switch content {
    case .intro(let block), .song(let block): return block.id
    case .voicetrack(let voicetrack, _): return voicetrack.audioBlockId
    }
  }

  var isReady: Bool {
    switch content {
    case .intro, .song:
      return true
    case .voicetrack(let voicetrack, let completedDurationMS):
      return voicetrack.isComplete && voicetrack.audioBlockId != nil && completedDurationMS != nil
    }
  }

  var readyDurationMS: Int {
    guard isReady else { return 0 }
    switch content {
    case .intro(let block), .song(let block):
      return block.durationMS
    case .voicetrack(_, let completedDurationMS):
      return completedDurationMS ?? 0
    }
  }
}
