//
//  BroadcastersListenerQuestionPageModel.swift
//  PlayolaRadio
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

enum ListenerQuestionFilter: CaseIterable, Equatable {
  case pending
  case answered
  case all

  var displayText: String {
    switch self {
    case .pending: return "Pending"
    case .answered: return "Answered"
    case .all: return "All"
    }
  }
}

@MainActor
@Observable
class BroadcastersListenerQuestionPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Initialization

  init(stationId: String) {
    self.stationId = stationId
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let navigationTitle = "Questions from Listeners"
  let filterOptions: [ListenerQuestionFilter] = [.pending, .answered, .all]

  var questions: IdentifiedArrayOf<ListenerQuestion> = []
  var expandedQuestionIds: Set<String> = []
  var playingQuestionId: String?
  var isLoading = false
  var presentedAlert: PlayolaAlert?
  var selectedFilter: ListenerQuestionFilter = .pending

  var filteredQuestions: IdentifiedArrayOf<ListenerQuestion> {
    switch selectedFilter {
    case .pending:
      return questions.filter { $0.status == .pending }
    case .answered:
      return questions.filter { $0.status == .answered }
    case .all:
      return questions.filter { $0.status != .declined }
    }
  }

  var filteredEmptyStateTitle: String {
    switch selectedFilter {
    case .pending:
      return "All Caught Up!"
    case .answered:
      return "No Answered Questions"
    case .all:
      return "No Questions"
    }
  }

  var filteredEmptyStateMessage: String {
    switch selectedFilter {
    case .pending:
      return "You've responded to all your questions."
    case .answered:
      return "Questions you've answered will appear here."
    case .all:
      return "No questions to display."
    }
  }

  // MARK: - User Actions

  func viewAppeared() async {
    await fetchQuestions()
  }

  func refreshPulledDown() async {
    await fetchQuestions()
  }

  func filterSelected(_ filter: ListenerQuestionFilter) {
    selectedFilter = filter
  }

  func showMoreButtonTapped(_ questionId: String) {
    if expandedQuestionIds.contains(questionId) {
      expandedQuestionIds.remove(questionId)
    } else {
      expandedQuestionIds.insert(questionId)
    }
  }

  func playButtonTapped(_ question: ListenerQuestion) async {
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

  func questionRowTapped(_ question: ListenerQuestion) async {
    await stopPlayback()
    let detailModel = ListenerQuestionDetailPageModel(question: question)
    mainContainerNavigationCoordinator.push(.listenerQuestionDetailPage(detailModel))
  }

  func declineQuestionSwiped(_ question: ListenerQuestion) async {
    guard let jwt = auth.jwt else { return }

    do {
      let updatedQuestion = try await api.declineListenerQuestion(jwt, stationId, question.id)
      questions[id: question.id] = updatedQuestion
    } catch {
      presentedAlert = .declineQuestionError(error.localizedDescription)
    }
  }

  // MARK: - View Helpers

  func isExpanded(_ questionId: String) -> Bool {
    expandedQuestionIds.contains(questionId)
  }

  func isPlaying(_ questionId: String) -> Bool {
    playingQuestionId == questionId
  }

  func canDecline(_ question: ListenerQuestion) -> Bool {
    question.status == .pending
  }

  // MARK: - Private Helpers

  private func fetchQuestions() async {
    guard let jwt = auth.jwt else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      let fetchedQuestions = try await api.getListenerQuestions(jwt, stationId)
      questions = IdentifiedArray(uniqueElements: fetchedQuestions)
    } catch {
      presentedAlert = .fetchQuestionsError(error.localizedDescription)
    }
  }

  private func stopPlayback() async {
    await audioPlayer.stop()
    playingQuestionId = nil
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

  static func fetchQuestionsError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error Loading Questions",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }

  static func declineQuestionError(_ message: String) -> PlayolaAlert {
    PlayolaAlert(
      title: "Error Declining Question",
      message: message,
      dismissButton: .cancel(Text("OK"))
    )
  }
}
