//
//  AMAQuestionPickerPageModel.swift
//  PlayolaRadio
//

import Dependencies
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import SwiftUI

enum AMAQuestionFilter: CaseIterable, Equatable {
  case all
  case unanswered
  case answered

  var displayText: String {
    switch self {
    case .all: return "All"
    case .unanswered: return "Unanswered"
    case .answered: return "Answered"
    }
  }
}

@MainActor
@Observable
class AMAQuestionPickerPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(
    stationId: String,
    showStartedAt: Date?,
    addToShow: @escaping @MainActor (AMAQuestionAnswer) async throws -> Void
  ) {
    self.stationId = stationId
    self.showStartedAt = showStartedAt
    self.addToShow = addToShow
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let showStartedAt: Date?
  @ObservationIgnored let addToShow: @MainActor (AMAQuestionAnswer) async throws -> Void

  let navigationTitle = "Questions"
  let filterOptions: [AMAQuestionFilter] = [.all, .unanswered, .answered]
  let expandTranscriptText = "Expand transcript"
  let collapseTranscriptText = "Collapse transcript"
  let answeredBadgeText = "Answered"
  let unansweredBadgeText = "Unanswered"
  let newThisShowText = "New this show"
  let missingTranscriptionText = "No transcription available"
  let unknownListenerText = "Listener"

  var questions: IdentifiedArrayOf<ListenerQuestion> = []
  var selectedFilter: AMAQuestionFilter = .all
  var expandedQuestionIds: Set<String> = []
  var playingQuestionId: String?
  var isLoading = false
  var airingQuestionId: String?
  var presentedAlert: PlayolaAlert?

  var emptyStateTitle: String {
    switch selectedFilter {
    case .all: return "No Questions Yet"
    case .unanswered: return "All Caught Up!"
    case .answered: return "No Answered Questions"
    }
  }

  var emptyStateMessage: String {
    switch selectedFilter {
    case .all: return "When listeners send you questions,\nthey'll appear here."
    case .unanswered: return "You've answered every question so far."
    case .answered: return "Questions you've answered will appear here."
    }
  }

  var filteredQuestions: [ListenerQuestion] {
    let matching = questions.filter { question in
      switch selectedFilter {
      case .all: return question.status != .declined
      case .unanswered: return question.status == .pending
      case .answered: return question.status == .answered
      }
    }
    return matching.sorted { $0.createdAt > $1.createdAt }
  }

  var showEmptyState: Bool { !isLoading && filteredQuestions.isEmpty }

  // MARK: - User Actions

  func viewAppeared() async {
    airingQuestionId = nil
    await fetchQuestions()
  }

  func refreshPulledDown() async {
    await fetchQuestions()
  }

  func filterSelected(_ filter: AMAQuestionFilter) {
    selectedFilter = filter
  }

  func expandToggleTapped(_ questionId: String) {
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
        if playingQuestionId != nil { await audioPlayer.stop() }
        try await audioPlayer.loadFile(downloadUrl)
        await audioPlayer.play()
        playingQuestionId = question.id
      } catch {
        presentedAlert = .audioPlaybackError(error.localizedDescription)
      }
    }
  }

  func questionRowTapped(_ question: ListenerQuestion) async {
    guard airingQuestionId == nil else { return }
    airingQuestionId = question.id
    await stopPlayback()
    // Keep the row lock held across the push so a second queued tap can't open a duplicate
    // page; `viewAppeared` clears it when the picker reappears.
    if question.status == .answered {
      guard question.answerAudioBlock != nil else {
        airingQuestionId = nil
        presentedAlert = PlayolaAlert(
          title: "Answer Not Ready",
          message: "This answer is still processing. Try again in a moment.",
          dismissButton: .cancel(Text("OK")))
        return
      }
      let reviewModel = AMAAnswerQuestionPageModel(
        answeredQuestion: question, addToShow: addToShow)
      navigationCoordinator.push(.amaAnswerQuestionPage(reviewModel))
    } else {
      let answerModel = AMAAnswerQuestionPageModel(question: question, addToShow: addToShow)
      navigationCoordinator.push(.amaAnswerQuestionPage(answerModel))
    }
  }

  // MARK: - View Helpers

  func isExpanded(_ questionId: String) -> Bool {
    expandedQuestionIds.contains(questionId)
  }

  func expandToggleText(for questionId: String) -> String {
    isExpanded(questionId) ? collapseTranscriptText : expandTranscriptText
  }

  func isPlaying(_ questionId: String) -> Bool {
    playingQuestionId == questionId
  }

  func rowInteractive(_ questionId: String) -> Bool {
    airingQuestionId == nil
  }

  func statusBadgeText(_ question: ListenerQuestion) -> String {
    question.status == .answered ? answeredBadgeText : unansweredBadgeText
  }

  func isAnswered(_ question: ListenerQuestion) -> Bool {
    question.status == .answered
  }

  func isNewThisShow(_ question: ListenerQuestion) -> Bool {
    guard let showStartedAt else { return false }
    return question.createdAt >= showStartedAt
  }

  func listenerName(_ question: ListenerQuestion) -> String {
    question.listener?.fullName ?? unknownListenerText
  }

  func transcription(_ question: ListenerQuestion) -> String {
    question.transcription ?? missingTranscriptionText
  }

  func timeAgoText(_ question: ListenerQuestion) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    let relative = formatter.localizedString(for: question.createdAt, relativeTo: now)
    return isNewThisShow(question) ? "\(relative) · \(newThisShowText)" : relative
  }

  func durationText(_ question: ListenerQuestion) -> String {
    guard let durationMS = question.durationMS else { return "" }
    let total = max(0, durationMS) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  func playButtonIcon(_ questionId: String) -> String {
    isPlaying(questionId) ? "stop.fill" : "play.fill"
  }

  // MARK: - View Styling

  var hasFilterableQuestions: Bool { questions.contains { $0.status != .declined } }
  var filterPillsVisible: Bool { hasFilterableQuestions && !isLoading }
  var filterPillsOpacity: Double { filterPillsVisible ? 1 : 0 }
  var filterPillsAccessibilityHidden: Bool { !filterPillsVisible }
  var loadingOpacity: Double { isLoading ? 1 : 0 }
  var emptyStateOpacity: Double { showEmptyState ? 1 : 0 }
  var emptyStateAccessibilityHidden: Bool { !showEmptyState }
  var contentOpacity: Double { showEmptyState || isLoading ? 0 : 1 }
  var contentAccessibilityHidden: Bool { showEmptyState || isLoading }

  func filterBackground(_ filter: AMAQuestionFilter) -> Color {
    selectedFilter == filter ? Color.playolaRed : Color.elevatedSurface
  }

  func rowOpacity(_ questionId: String) -> Double {
    rowInteractive(questionId) ? 1 : 0.5
  }

  func rowDisabled(_ questionId: String) -> Bool {
    !rowInteractive(questionId)
  }

  func badgeBackground(_ question: ListenerQuestion) -> Color {
    isAnswered(question) ? Color.success : Color.elevatedSurface
  }

  func transcriptLineLimit(_ questionId: String) -> Int? {
    isExpanded(questionId) ? nil : 2
  }

  func expandChevronRotation(_ questionId: String) -> Double {
    isExpanded(questionId) ? 180 : 0
  }

  // MARK: - Private Helpers

  private func fetchQuestions() async {
    guard let jwt = auth.jwt else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let fetched = try await api.getListenerQuestions(jwt, stationId)
      questions = IdentifiedArray(uniqueElements: fetched)
    } catch {
      presentedAlert = .fetchQuestionsError(error.localizedDescription)
    }
  }

  private func stopPlayback() async {
    guard playingQuestionId != nil else { return }
    await audioPlayer.stop()
    playingQuestionId = nil
  }
}
