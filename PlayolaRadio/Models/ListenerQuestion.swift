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

// MARK: - Mock Data

extension ListenerQuestion {
  static var mockQuestions: [ListenerQuestion] {
    let now = Date()

    return [
      .mockWith(
        id: "question-1",
        listenerId: "listener-1",
        stationId: "station-1",
        audioBlockId: "audio-1",
        createdAt: now.addingTimeInterval(-3600),
        listener: .mockWith(
          id: "listener-1",
          firstName: "Sarah",
          lastName: "Johnson"
        ),
        audioBlock: AudioBlock.mockWith(
          id: "audio-1",
          title: "Question from Sarah",
          artist: "Listener",
          durationMS: 45000,
          transcription: """
            Hey! I love your station so much. I was wondering if you could play some more \
            80s music? I grew up listening to that era and it always brings back such great \
            memories. Thanks for all you do!
            """
        )
      ),
      .mockWith(
        id: "question-2",
        listenerId: "listener-2",
        stationId: "station-1",
        audioBlockId: "audio-2",
        createdAt: now.addingTimeInterval(-7200),
        listener: .mockWith(
          id: "listener-2",
          firstName: "Mike",
          lastName: "Chen"
        ),
        audioBlock: AudioBlock.mockWith(
          id: "audio-2",
          title: "Question from Mike",
          artist: "Listener",
          durationMS: 30000,
          transcription: "What's the name of that song you played earlier today?"
        )
      ),
      .mockWith(
        id: "question-3",
        listenerId: "listener-3",
        stationId: "station-1",
        audioBlockId: "audio-3",
        createdAt: now.addingTimeInterval(-14400),
        listener: .mockWith(
          id: "listener-3",
          firstName: "Emily",
          lastName: nil
        ),
        audioBlock: AudioBlock.mockWith(
          id: "audio-3",
          title: "Question from Emily",
          artist: "Listener",
          durationMS: 60000,
          transcription: """
            Hi there! I'm a huge fan of your station. I've been listening every day on my \
            commute to work and it really makes the drive so much better. I wanted to ask - \
            do you take song requests? I'd love to hear some indie rock if possible. Also, \
            where are you broadcasting from? Your station has such a unique vibe and I'm \
            curious about the person behind it. Keep up the amazing work!
            """
        )
      ),
      .mockWith(
        id: "question-4",
        listenerId: "listener-4",
        stationId: "station-1",
        audioBlockId: "audio-4",
        createdAt: now.addingTimeInterval(-21600),
        listener: .mockWith(
          id: "listener-4",
          firstName: "Alex",
          lastName: "Rivera"
        ),
        audioBlock: AudioBlock.mockWith(
          id: "audio-4",
          title: "Question from Alex",
          artist: "Listener",
          durationMS: 25000,
          transcription: "Love the station! Can you give a shoutout to my friend Jordan?"
        )
      ),
    ]
  }
}
