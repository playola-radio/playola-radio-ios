import Alamofire
import Combine
import Dependencies
import Foundation
import Observation
import PlayolaPlayer
import Sharing

@MainActor
@Observable
final class ListeningHistoryPageModel: ViewModel {
  @ObservationIgnored @Dependency(\.api) private var api
  @ObservationIgnored @Dependency(\.date.now) private var now
  @ObservationIgnored @Dependency(\.toast) private var toast
  @ObservationIgnored @Dependency(\.errorReporting) private var errorReporting
  @ObservationIgnored @Dependency(\.likesManager) private var likesManager: LikesManager
  @ObservationIgnored @Shared(.auth) private var auth
  @ObservationIgnored @Shared(.activeTab) private var activeTab
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  private var navigationCoordinator

  enum PageState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case error
    case signedOut
  }

  struct Section: Identifiable {
    let id: Date
    let title: String
    var rows: [Row]
  }

  struct Row: Identifiable {
    let spin: ListeningHistorySpin
    let audioBlock: AudioBlock
    var id: String { spin.id }
  }

  struct StateContent {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String
  }

  private(set) var spins: [ListeningHistorySpin] = []
  private(set) var nextOffset = 0
  private(set) var hasMore = false
  private(set) var pageState: PageState = .idle
  private(set) var isLoadingMore = false
  private(set) var loadMoreFailed = false

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
    if pageState == .idle { return .loading }
    return pageState
  }

  @ObservationIgnored private var ownerUserID: String?
  @ObservationIgnored private var requestGeneration = 0
  @ObservationIgnored private var lastSuccessfulFetchAt: Date?
  @ObservationIgnored private var firstPageTask: Task<Void, Never>?
  @ObservationIgnored private var laterPageTask: Task<Void, Never>?
  @ObservationIgnored private var authCancellable: AnyCancellable?

  override init() {
    super.init()
    authCancellable = $auth.publisher.sink { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.resetIfAccountChanged()
      }
    }
  }

  var displaySpins: [ListeningHistorySpin] {
    guard ownerUserID == auth.currentUser?.id else { return [] }
    return spins
  }

  var sections: [Section] {
    let calendar = Calendar.current
    var result: [Section] = []
    for spin in displaySpins {
      guard let audioBlock = spin.audioBlock else { continue }
      let row = Row(spin: spin, audioBlock: audioBlock)
      let day = calendar.startOfDay(for: spin.airtime)
      if result.last?.id == day {
        result[result.count - 1].rows.append(row)
      } else {
        result.append(Section(id: day, title: title(for: spin.airtime), rows: [row]))
      }
    }
    return result
  }

  func isLiked(_ spin: ListeningHistorySpin) -> Bool {
    guard let audioBlock = spin.audioBlock else { return false }
    return likesManager.isLiked(audioBlock.id)
  }

  func heartSymbol(for spin: ListeningHistorySpin) -> String {
    isLiked(spin) ? "heart.fill" : "heart"
  }

  func heartButtonLabel(for spin: ListeningHistorySpin) -> String {
    isLiked(spin) ? "Remove from Favorites" : "Add to Favorites"
  }

  func heartButtonTapped(for spin: ListeningHistorySpin) {
    guard let audioBlock = spin.audioBlock else { return }
    likesManager.toggleLike(audioBlock, spinId: spin.id)
  }

  func subtitle(for spin: ListeningHistorySpin) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return "\(spin.station?.name ?? "") · \(formatter.string(from: spin.airtime))"
  }

  func libraryTabSelected() async {
    resetIfAccountChanged()
    if let firstPageTask {
      await firstPageTask.value
      return
    }
    await refresh(showFailureToast: false)
  }

  func detailAppeared() async {
    resetIfAccountChanged()
    if let firstPageTask {
      await firstPageTask.value
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

  func loadMoreIfNeeded(visibleSpinID: String) async {
    guard !loadMoreFailed else { return }
    guard displaySpins.suffix(5).contains(where: { $0.id == visibleSpinID }) else { return }
    await loadMore()
  }

  func loadMoreRetryButtonTapped() async {
    guard loadMoreFailed else { return }
    await loadMore()
  }

  private func refresh(showFailureToast: Bool) async {
    guard let userID = auth.currentUser?.id, let token = auth.jwt else {
      pageState = .signedOut
      return
    }
    requestGeneration += 1
    let generation = requestGeneration
    ownerUserID = userID
    laterPageTask = nil
    isLoadingMore = false
    loadMoreFailed = false
    if spins.isEmpty { pageState = .loading }

    let task = Task { [weak self] in
      guard let self else { return }
      do {
        let response = try await api.getListeningHistory(token, 0)
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        spins = response.displaySpins
        nextOffset = response.spins.count
        hasMore = response.pagination.hasMore
        lastSuccessfulFetchAt = now
        pageState = .loaded
      } catch {
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
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
      if requestGeneration == generation { firstPageTask = nil }
    }
    firstPageTask = task
    await task.value
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
      do {
        let response = try await api.getListeningHistory(token, offset)
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        let existingIDs = Set(spins.map(\.id))
        spins += response.displaySpins.filter { !existingIDs.contains($0.id) }
        nextOffset = offset + response.spins.count
        hasMore = response.pagination.hasMore
        isLoadingMore = false
      } catch {
        guard requestGeneration == generation, auth.currentUser?.id == userID else { return }
        isLoadingMore = false
        loadMoreFailed = true
        await reportLoadError(error)
      }
      if requestGeneration == generation { laterPageTask = nil }
    }
    laterPageTask = task
    await task.value
  }

  private func resetIfAccountChanged() {
    guard ownerUserID != auth.currentUser?.id else { return }
    requestGeneration += 1
    ownerUserID = auth.currentUser?.id
    spins = []
    nextOffset = 0
    hasMore = false
    lastSuccessfulFetchAt = nil
    firstPageTask = nil
    laterPageTask = nil
    isLoadingMore = false
    loadMoreFailed = false
    pageState = auth.currentUser == nil ? .signedOut : .idle
  }

  private func title(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDate(date, inSameDayAs: now) { return "Today" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
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
