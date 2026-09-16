//
//  AMAOpeningItem.swift
//  PlayolaRadio
//

import CasePaths
import Foundation
import PlayolaPlayer

struct AMAOpeningItem: Identifiable, Equatable {
  let id: UUID
  var content: Content

  @CasePathable
  enum Content: Equatable {
    case intro(AudioBlock)
    case song(AudioBlock)
    case voicetrack(LocalVoicetrack, completedDurationMS: Int?)
  }
}

extension AMAOpeningItem {
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
