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
    .mockWith()
  }

  static func mockWith(
    id: String = "mock-question-id",
    listenerId: String = "mock-listener-id",
    stationId: String = "mock-station-id",
    audioBlockId: String = "mock-audio-block-id",
    status: ListenerQuestionStatus = .pending,
    answerAudioBlockId: String? = nil,
    answerSpinId: String? = nil,
    notificationSentAt: Date? = nil,
    declinedAt: Date? = nil,
    declinedReason: String? = nil,
    createdAt: Date = Date(),
    listener: ListenerQuestionListener? = .mockWith(),
    audioBlock: AudioBlock? = nil,
    answerAudioBlock: AudioBlock? = nil
  ) -> ListenerQuestion {
    ListenerQuestion(
      id: id,
      listenerId: listenerId,
      stationId: stationId,
      audioBlockId: audioBlockId,
      status: status,
      answerAudioBlockId: answerAudioBlockId,
      answerSpinId: answerSpinId,
      notificationSentAt: notificationSentAt,
      declinedAt: declinedAt,
      declinedReason: declinedReason,
      createdAt: createdAt,
      listener: listener,
      audioBlock: audioBlock,
      answerAudioBlock: answerAudioBlock
    )
  }
}

extension ListenerQuestionListener {
  static func mockWith(
    id: String = "mock-listener-id",
    firstName: String = "Test",
    lastName: String? = "User",
    profileImageUrl: String? = nil
  ) -> ListenerQuestionListener {
    ListenerQuestionListener(
      id: id,
      firstName: firstName,
      lastName: lastName,
      profileImageUrl: profileImageUrl
    )
  }
}
