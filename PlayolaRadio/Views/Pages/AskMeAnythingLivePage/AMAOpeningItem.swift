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
  @dynamicMemberLookup
  enum Content: Codable, Equatable {
    case intro(AudioBlock)
    case song(AudioBlock)
    case voicetrack(LocalVoicetrack, completedDurationMS: Int?)
    case questionAnswer(AMAQuestionAnswer)
  }
}

/// A fully-resolved listener question with its recorded answer and optional trailing
/// song. Doubles as the `addToShow` payload (live path) and the persisted opening-item
/// associated value (pre-show path). Only ever constructed once its answer is registered
/// server-side, so both audio blocks are always present.
struct AMAQuestionAnswer: Codable, Equatable {
  let questionId: String
  let listenerName: String
  let questionBlock: AudioBlock
  let answerBlock: AudioBlock
  var trailingBlock: AudioBlock?
}

extension AMAOpeningItem {
  /// The single block id required by ``StagingItem``. Derived from ``audioBlockIds`` so the
  /// per-`Content` mapping lives in one place: `nil` for a multi-block question-and-answer item,
  /// otherwise the item's one block id.
  var audioBlockId: String? { audioBlockIds.count == 1 ? audioBlockIds.first : nil }

  /// Ordered block ids this item contributes to the flat Start Show list.
  var audioBlockIds: [String] {
    switch content {
    case .intro(let block), .song(let block): return [block.id]
    case .voicetrack(let voicetrack, _): return voicetrack.audioBlockId.map { [$0] } ?? []
    case .questionAnswer(let qa):
      return [qa.questionBlock.id, qa.answerBlock.id] + (qa.trailingBlock.map { [$0.id] } ?? [])
    }
  }

  var isReady: Bool {
    switch content {
    case .intro, .song, .questionAnswer:
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
    case .questionAnswer(let qa):
      return qa.questionBlock.durationMS + qa.answerBlock.durationMS
        + (qa.trailingBlock?.durationMS ?? 0)
    }
  }
}
