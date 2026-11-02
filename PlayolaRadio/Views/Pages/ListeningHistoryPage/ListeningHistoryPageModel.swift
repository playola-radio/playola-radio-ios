import Alamofire
import Dependencies
import Foundation
import IdentifiedCollections
import Observation
import PlayolaPlayer
import Sharing
import UIKit

@MainActor
@Observable
final class ListeningHistoryPageModel: ViewModel {

  // MARK: - Dependencies
  @ObservationIgnored @Dependency(\.api) private var api
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.toast) private var toast
  @ObservationIgnored @Dependency(\.errorReporting) private var errorReporting
  @ObservationIgnored @Dependency(\.likesManager) private var likesManager: LikesManager

  // MARK: - Shared State
  @ObservationIgnored @Shared(.auth) private var auth
  @ObservationIgnored @Shared(.activeTab) private var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  private var navigationCoordinator

  // MARK: - Properties
  enum PageState: Equatable {
    case loading
    case loaded
    case empty
    case error
    case signedOut
  }

  struct Section: Identifiable {
    let id: Date
    let title: String
    var rows: IdentifiedArrayOf<Row>
  }

  struct Row: Identifiable {
    let spin: ListeningHistorySpin
    let audioBlock: AudioBlock
    let stationName: String
    var id: String { spin.id }
  }

  struct StateContent {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String
  }

  private struct FetchedPage {
    let spins: [ListeningHistorySpin]
    let nextOffset: Int
    let hasMore: Bool
  }

  private(set) var spins: IdentifiedArrayOf<ListeningHistorySpin> = []
  @ObservationIgnored private var nextOffset = 0
  private(set) var hasMore = false
  private(set) var pageState: PageState = .loading
  private(set) var isLoadingMore = false
  private(set) var loadMoreFailed = false
  private var displayDate: Date?

  @ObservationIgnored private var ownerUserID: String?
  @ObservationIgnored private var requestGeneration = 0
  @ObservationIgnored private var lastSuccessfulFetchAt: Date?
  @ObservationIgnored private var shouldCheckFreshnessOnAppearance = true
  @ObservationIgnored private var visibleSpinIDs: Set<String> = []
  @ObservationIgnored private var firstPageTask: Task<Void, Never>?
  @ObservationIgnored private var laterPageTask: Task<Void, Never>?

  // MARK: - User Actions
  func libraryTabSelected() async {
    resetIfAccountChanged()
    if let firstPageTask {
      await firstPageTask.value
      return
    }
    await refresh(showFailureToast: false)
  }

  func detailWillOpen() {
    displayDate = now
    shouldCheckFreshnessOnAppearance = true
  }

  func detailAppeared() async {
    resetIfAccountChanged()
    guard shouldCheckFreshnessOnAppearance else { return }
    shouldCheckFreshnessOnAppearance = false
    if let firstPageTask {
      await firstPageTask.value
      if pageState == .error { await refresh(showFailureToast: true) }
      return
    }
    if let lastSuccessfulFetchAt,
      now.timeIntervalSince(lastSuccessfulFetchAt) < 60,
      pageState == .loaded
    {
      return
    }
    await refresh(showFailureToast: true)
  }

  func backButtonTapped() {
    navigationCoordinator.pop()
  }

  func refreshRequested() async {
    resetIfAccountChanged()
    await refresh(showFailureToast: true)
  }

  func retryButtonTapped() async {
    await refreshRequested()
  }

  func exploreStationsButtonTapped() {
    navigationCoordinator.yourLibraryPath = []
    $activeTab.withLock { $0 = .stationsList }
  }

  func signInButtonTapped() async {
    await AuthService.shared.signOut()
  }

  func rowAppeared(_ row: Row) {
    visibleSpinIDs.insert(row.id)
  }

  func rowDisappeared(_ row: Row) {
    visibleSpinIDs.remove(row.id)
  }

  func loadMoreIfNeeded(visibleSpinID: String) async {
    guard !loadMoreFailed else { return }
    guard displaySpins.suffix(5).contains(where: { $0.id == visibleSpinID }) else { return }
    await loadMore()
  }

  func loadMoreRetryButtonTapped() async {
    await loadMore()
  }

  func observeDayChanges() async {
    async let dayChanges: Void = refreshDisplayDate(onEach: .NSCalendarDayChanged)
    async let foregrounds: Void = refreshDisplayDate(
      onEach: UIApplication.didBecomeActiveNotification)
    _ = await (dayChanges, foregrounds)
  }

  // MARK: - View Helpers
  var navigationTitle: String { "Listening History" }
  var backButtonLabel: String { "Back to Your Library" }
  var loadMoreErrorMessage: String { "Couldn’t load more songs." }
  var loadMoreRetryTitle: String { "Retry" }
  var emptyContent: StateContent {
    StateContent(
      symbol: "music.note",
      title: "No listening history yet",
      message: "Songs you hear on Playola channels will appear here.",
      buttonTitle: "Explore Stations"
    )
  }
  var errorContent: StateContent {
    StateContent(
      symbol: "wifi.slash",
      title: "Couldn’t load your history",
      message: "Check your connection and try again.",
      buttonTitle: "Try Again"
    )
  }
  var signedOutContent: StateContent {
    StateContent(
      symbol: "person.crop.circle",
      title: "Sign in to see your history",
      message: "Your listening history is tied to your account.",
      buttonTitle: "Sign In"
    )
  }

  var displayState: PageState {
    if ownerUserID != auth.currentUser?.id {
      return auth.currentUser == nil ? .signedOut : .loading
    }
    if pageState == .loaded && displaySpins.isEmpty { return .empty }
    return pageState
  }

  var displaySpins: IdentifiedArrayOf<ListeningHistorySpin> {
    guard ownerUserID == auth.currentUser?.id else { return [] }
    return spins
  }

  var sections: IdentifiedArrayOf<Section> {
    let calendar = Calendar.current
    var result: IdentifiedArrayOf<Section> = []
    for spin in displaySpins {
      guard let audioBlock = spin.audioBlock, let station = spin.station else { continue }
      let row = Row(spin: spin, audioBlock: audioBlock, stationName: station.name)
      let day = calendar.startOfDay(for: spin.airtime)
      if result[id: day] != nil {
        result[id: day]?.rows.append(row)
      } else {
        result.append(Section(id: day, title: title(for: spin.airtime), rows: [row]))
      }
    }
    return result
  }

  func isLiked(_ row: Row) -> Bool {
    likesManager.isLiked(row.audioBlock.id)
  }

  func heartSymbol(for row: Row) -> String {
    isLiked(row) ? "heart.fill" : "heart"
  }

  func heartButtonLabel(for row: Row) -> String {
    isLiked(row) ? "Remove from Favorites" : "Add to Favorites"
  }

  func heartButtonTapped(for row: Row) {
    likesManager.toggleLike(row.audioBlock, spinId: row.id)
  }

  func subtitle(for row: Row) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return "\(row.stationName) · \(formatter.string(from: row.spin.airtime))"
  }

  // MARK: - Private Helpers
  private func refresh(showFailureToast: Bool) async {
    guard let userID = auth.currentUser?.id, let token = auth.jwt else {
      pageState = .signedOut
      return
    }
    requestGeneration += 1
    firstPageTask?.cancel()
    laterPageTask?.cancel()
    let generation = requestGeneration
    ownerUserID = userID
    laterPageTask = nil
    isLoadingMore = false
    loadMoreFailed = false
    if spins.isEmpty { pageState = .loading }

    let task = Task { [weak self] in
      guard let self else { return }
      do {
        let page = try await fetchVisiblePage(token: token, startingAt: 0, excluding: [])
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        spins = IdentifiedArray(page.spins, uniquingIDsWith: { first, _ in first })
        nextOffset = page.nextOffset
        hasMore = page.hasMore
        lastSuccessfulFetchAt = now
        pageState = .loaded
      } catch {
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        await handleFirstPageError(error, showFailureToast: showFailureToast)
      }
      if requestGeneration == generation { firstPageTask = nil }
    }
    firstPageTask = task
    await task.value
    guard requestGeneration == generation else { return }
    await loadMoreIfVisibleTail()
  }

  private func refreshDisplayDate(onEach name: Notification.Name) async {
    for await _ in NotificationCenter.default.notifications(named: name).map({ _ in () }) {
      displayDate = now
    }
  }

  private func loadMoreIfVisibleTail() async {
    guard displaySpins.suffix(5).contains(where: { visibleSpinIDs.contains($0.id) }) else {
      return
    }
    await loadMore()
  }

  private func loadMore() async {
    guard hasMore, !isLoadingMore, firstPageTask == nil, laterPageTask == nil,
      let userID = auth.currentUser?.id, userID == ownerUserID, let token = auth.jwt
    else { return }
    let generation = requestGeneration
    let offset = nextOffset
    isLoadingMore = true
    loadMoreFailed = false
    let task = Task { [weak self] in
      guard let self else { return }
      defer {
        if requestGeneration == generation {
          isLoadingMore = false
          laterPageTask = nil
        }
      }
      do {
        let page = try await fetchVisiblePage(
          token: token, startingAt: offset, excluding: Set(spins.ids))
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        spins.append(contentsOf: page.spins)
        nextOffset = page.nextOffset
        hasMore = page.hasMore
      } catch {
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        if isUnauthorized(error) {
          spins = []
          hasMore = false
          pageState = .signedOut
        } else {
          loadMoreFailed = true
        }
        await reportLoadError(error)
      }
    }
    laterPageTask = task
    await task.value
  }

  private func fetchVisiblePage(
    token: String,
    startingAt offset: Int,
    excluding existingIDs: Set<String>
  ) async throws -> FetchedPage {
    var nextOffset = offset
    while true {
      try Task.checkCancellation()
      let response = try await api.getListeningHistory(token, nextOffset)
      let visible = response.displaySpins.filter { !existingIDs.contains($0.id) }
      nextOffset += response.spins.count
      let hasMore = response.pagination.hasMore && !response.spins.isEmpty
      if !visible.isEmpty || !hasMore {
        return FetchedPage(spins: visible, nextOffset: nextOffset, hasMore: hasMore)
      }
    }
  }

  private func handleFirstPageError(_ error: Error, showFailureToast: Bool) async {
    if isUnauthorized(error) {
      spins = []
      pageState = .signedOut
    } else if spins.isEmpty {
      pageState = .error
    } else {
      pageState = .loaded
      if showFailureToast {
        await toast.show(PlayolaToast(message: "History couldn't refresh.", buttonTitle: "OK"))
      }
    }
    await reportLoadError(error)
  }

  private func resetIfAccountChanged() {
    guard ownerUserID != auth.currentUser?.id else { return }
    requestGeneration += 1
    firstPageTask?.cancel()
    laterPageTask?.cancel()
    ownerUserID = auth.currentUser?.id
    spins = []
    nextOffset = 0
    hasMore = false
    lastSuccessfulFetchAt = nil
    shouldCheckFreshnessOnAppearance = true
    firstPageTask = nil
    laterPageTask = nil
    isLoadingMore = false
    loadMoreFailed = false
    pageState = auth.currentUser == nil ? .signedOut : .loading
  }

  private func title(for date: Date) -> String {
    let calendar = Calendar.current
    let today = displayDate ?? now
    if calendar.isDate(date, inSameDayAs: today) { return "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
      calendar.isDate(date, inSameDayAs: yesterday)
    {
      return "Yesterday"
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM d, yyyy"
    return formatter.string(from: date)
  }

  private func isUnauthorized(_ error: Error) -> Bool {
    guard let error = error as? AFError,
      case .responseValidationFailed(.unacceptableStatusCode(let code)) = error
    else { return false }
    return code == 401
  }

  private func reportLoadError(_ error: Error) async {
    guard !NetworkErrorClassifier.isNetworkError(error) else { return }
    await errorReporting.reportError(error, ["endpoint": "getListeningHistory"])
  }
}
