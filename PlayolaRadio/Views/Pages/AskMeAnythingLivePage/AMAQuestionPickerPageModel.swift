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
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting

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
  let declineButtonText = "Decline"

  var questions: IdentifiedArrayOf<ListenerQuestion> = []
  var selectedFilter: AMAQuestionFilter = .all
  var expandedQuestionIds: Set<String> = []
  var playingQuestionId: String?
  var isLoading = false
  var airingQuestionId: String?
  var decliningQuestionIds: Set<String> = []
  var presentedAlert: PlayolaAlert?
  private var hasLoadedQuestions = false
  @ObservationIgnored private var questionsVersion = 0
  @ObservationIgnored private var appliedQuestionsVersion = 0
  @ObservationIgnored private var isAppActive = true

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

  var filteredQuestions: IdentifiedArrayOf<ListenerQuestion> {
    let matching = questions.filter { question in
      switch selectedFilter {
      case .all: return question.status != .declined
      case .unanswered: return question.status == .pending
      case .answered: return question.status == .answered
      }
    }
    return IdentifiedArray(uniqueElements: matching)
  }

  var showsLoadingSpinner: Bool { isLoading && !hasLoadedQuestions }

  var showEmptyState: Bool { !showsLoadingSpinner && filteredQuestions.isEmpty }

  // MARK: - User Actions

  func task() async {
    await viewAppeared()
    while !Task.isCancelled {
      do {
        try await clock.sleep(for: .seconds(10))
      } catch {
        break
      }
      guard isAppActive, !isLoading else { continue }
      await fetchQuestions(isUserInitiated: false)
    }
  }

  func viewAppeared() async {
    airingQuestionId = nil
    await loadQuestions()
  }

  func viewDisappeared() async {
    await stopPlayback()
  }

  func refreshPulledDown() async {
    await loadQuestions()
  }

  func scenePhaseChanged(newPhase: ScenePhase) {
    isAppActive = newPhase == .active
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

  func declineQuestionSwiped(_ question: ListenerQuestion) async {
    guard
      let jwt = auth.jwt,
      canDecline(question),
      airingQuestionId == nil,
      decliningQuestionIds.insert(question.id).inserted
    else { return }
    defer { decliningQuestionIds.remove(question.id) }
    do {
      questions[id: question.id] = try await api.declineListenerQuestion(
        jwt, stationId, question.id)
      questionsVersion += 1
      appliedQuestionsVersion = questionsVersion
    } catch {
      presentedAlert = .declineQuestionError(error.localizedDescription)
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

  func canDecline(_ question: ListenerQuestion) -> Bool {
    question.status == .pending
  }

  func declineSwipeActions(_ question: ListenerQuestion) -> [ListenerQuestion] {
    canDecline(question) ? [question] : []
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
  var filterPillsVisible: Bool { hasFilterableQuestions && !showsLoadingSpinner }
  var filterPillsOpacity: Double { filterPillsVisible ? 1 : 0 }
  var filterPillsAccessibilityHidden: Bool { !filterPillsVisible }
  var loadingOpacity: Double { showsLoadingSpinner ? 1 : 0 }
  var emptyStateOpacity: Double { showEmptyState ? 1 : 0 }
  var emptyStateAccessibilityHidden: Bool { !showEmptyState }
  var contentOpacity: Double { showEmptyState || showsLoadingSpinner ? 0 : 1 }
  var contentAccessibilityHidden: Bool { showEmptyState || showsLoadingSpinner }

  func filterBackground(_ filter: AMAQuestionFilter) -> Color {
    selectedFilter == filter ? Color.playolaRed : Color.playolaSurfaceRaised
  }

  func rowOpacity(_ questionId: String) -> Double {
    rowInteractive(questionId) ? 1 : 0.5
  }

  func rowDisabled(_ questionId: String) -> Bool {
    !rowInteractive(questionId)
  }

  func badgeBackground(_ question: ListenerQuestion) -> Color {
    isAnswered(question) ? Color.playolaSuccessGreen.opacity(0.15) : Color.playolaSurfaceRaised
  }

  func badgeForeground(_ question: ListenerQuestion) -> Color {
    isAnswered(question) ? Color.playolaSuccessGreen : Color.playolaTextSecondary
  }

  func transcriptLineLimit(_ questionId: String) -> Int? {
    isExpanded(questionId) ? nil : 2
  }

  func expandChevronRotation(_ questionId: String) -> Double {
    isExpanded(questionId) ? 180 : 0
  }

  // MARK: - Private Helpers

  private func loadQuestions() async {
    guard !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    await fetchQuestions(isUserInitiated: true)
  }

  private func fetchQuestions(isUserInitiated: Bool) async {
    guard let jwt = auth.jwt else { return }
    questionsVersion += 1
    let version = questionsVersion
    do {
      let fetched = try await api.getListenerQuestions(jwt, stationId)
      guard version > appliedQuestionsVersion else { return }
      appliedQuestionsVersion = version
      mergeFetchedQuestions(fetched)
      if let playingQuestionId, questions[id: playingQuestionId]?.status ?? .declined == .declined {
        await stopPlayback()
      }
    } catch {
      guard !Task.isCancelled else { return }
      if !isUserInitiated {
        await reportPollFailure(error)
      } else {
        presentedAlert = .fetchQuestionsError(error.localizedDescription)
      }
    }
  }

  private func reportPollFailure(_ error: Error) async {
    guard !NetworkErrorClassifier.isNetworkError(error) else { return }
    var tags = NetworkErrorClassifier.errorTags(for: error)
    tags["endpoint"] = "getListenerQuestions"
    await errorReporting.reportError(error, tags)
  }

  private func mergeFetchedQuestions(_ fetched: [ListenerQuestion]) {
    guard hasLoadedQuestions else {
      questions = IdentifiedArray(
        uniqueElements: fetched.sorted { ($0.createdAt, $0.id) > ($1.createdAt, $1.id) })
      hasLoadedQuestions = true
      return
    }
    let latest = IdentifiedArray(uniqueElements: fetched)
    let arrivals =
      fetched
      .filter { questions[id: $0.id] == nil }
      .sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    withAnimation {
      questions = IdentifiedArray(
        uniqueElements: questions.compactMap { latest[id: $0.id] } + arrivals)
    }
  }

  private func stopPlayback() async {
    guard playingQuestionId != nil else { return }
    playingQuestionId = nil
    await audioPlayer.stop()
  }
}
