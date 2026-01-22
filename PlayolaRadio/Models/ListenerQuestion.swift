//
//  ListenerQuestion.swift
//  PlayolaRadio
//

import Foundation
import PlayolaPlayer

enum ListenerQuestionStatus: String, Codable, Equatable {
  case pending
  case answered
  case declined
}

struct ListenerQuestion: Codable, Identifiable, Equatable {
  let id: String
  let listenerId: String
  let stationId: String
  let audioBlockId: String
  let status: ListenerQuestionStatus
  let answerAudioBlockId: String?
  let answerSpinId: String?
  let notificationSentAt: Date?
  let declinedAt: Date?
  let declinedReason: String?
  let createdAt: Date

  let listener: ListenerQuestionListener?
  let audioBlock: AudioBlock?
  let answerAudioBlock: AudioBlock?

  var transcription: String? { audioBlock?.transcription }
  var durationMS: Int? { audioBlock?.durationMS }
}

struct ListenerQuestionListener: Codable, Equatable {
  let id: String
  let firstName: String
  let lastName: String?
  let profileImageUrl: String?

  var fullName: String {
    if let lastName = lastName {
      return "\(firstName) \(lastName)"
    }
    return firstName
  }
}

// MARK: - Mock

extension ListenerQuestion {
  static var mock: ListenerQuestion {
    ListenerQuestion(
      id: "mock-question-id",
      listenerId: "mock-listener-id",
      stationId: "mock-station-id",
      audioBlockId: "mock-audio-block-id",
      status: .pending,
      answerAudioBlockId: nil,
      answerSpinId: nil,
      notificationSentAt: nil,
      declinedAt: nil,
      declinedReason: nil,
      createdAt: Date(),
      listener: ListenerQuestionListener(
        id: "mock-listener-id",
        firstName: "Test",
        lastName: "User",
        profileImageUrl: nil
      ),
      audioBlock: nil,
      answerAudioBlock: nil
    )
  }
}
