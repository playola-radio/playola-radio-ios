//
//  BroadcastersListenerQuestionPageModel.swift
//  PlayolaRadio
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class BroadcastersListenerQuestionPageModel: ViewModel {
  let stationId: String
  let navigationTitle = "Questions from Listeners"

  var questions: IdentifiedArrayOf<ListenerQuestion> = []
  var expandedQuestionIds: Set<String> = []
  var playingQuestionId: String?
  var isLoading = false
  var presentedAlert: PlayolaAlert?

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  init(stationId: String) {
    self.stationId = stationId
    super.init()
    loadMockData()
  }

  func viewAppeared() async {
    // For now, just use mock data
    // Later this will fetch from API
  }

  private func loadMockData() {
    questions = IdentifiedArray(uniqueElements: Self.mockQuestions)
  }

  func isExpanded(_ questionId: String) -> Bool {
    expandedQuestionIds.contains(questionId)
  }

  func toggleExpanded(_ questionId: String) {
    if expandedQuestionIds.contains(questionId) {
      expandedQuestionIds.remove(questionId)
    } else {
      expandedQuestionIds.insert(questionId)
    }
  }

  func isPlaying(_ questionId: String) -> Bool {
    playingQuestionId == questionId
  }

  func onPlayTapped(_ question: ListenerQuestion) async {
    guard let audioBlock = question.audioBlock,
      let downloadUrl = audioBlock.downloadUrl
    else { return }

    if playingQuestionId == question.id {
      await audioPlayer.stop()
      playingQuestionId = nil
    } else {
      do {
        if playingQuestionId != nil {
          await audioPlayer.stop()
        }
        try await audioPlayer.loadFile(downloadUrl)
        await audioPlayer.play()
        playingQuestionId = question.id
      } catch {
        presentedAlert = .audioPlaybackError(error.localizedDescription)
      }
    }
  }

  func stopPlayback() async {
    await audioPlayer.stop()
    playingQuestionId = nil
  }

  func questionRowTapped(_ question: ListenerQuestion) async {
    await stopPlayback()
    let detailModel = ListenerQuestionDetailPageModel(question: question)
    mainContainerNavigationCoordinator.push(.listenerQuestionDetailPage(detailModel))
  }
}

// MARK: - Mock Data

extension BroadcastersListenerQuestionPageModel {
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

// MARK: - Alerts

extension PlayolaAlert {
  static func audioPlaybackError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Playback Error",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
