//
//  MyAiringsPageModel.swift
//  PlayolaRadio
//

import Dependencies
import Sharing
import SwiftUI

enum ClipRowState: Equatable {
  case upcoming
  case noClip
  case creating
  case ready(Clip)
  case failed(String?)
}

@MainActor
@Observable
class MyAiringsPageModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.pushNotifications) var pushNotifications

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator)
  var mainContainerNavigationCoordinator

  // MARK: - Properties

  var airings: [ListenerQuestionAiring] = []
  var clips: [String: Clip] = [:]
  var isLoading = false
  var presentedAlert: PlayolaAlert?
  var pollingAiringIds: Set<String> = []
  private var pollingTasks: [String: Task<Void, Never>] = [:]

  // MARK: - User Actions

  func viewAppeared() async {
    await loadData()
    await pushNotifications.scheduleAiringReminders(upcomingAirings)
  }

  func viewDisappeared() {
    for task in pollingTasks.values {
      task.cancel()
    }
    pollingTasks.removeAll()
  }

  func createClipTapped(_ airing: ListenerQuestionAiring) async {
    guard let jwt = auth.jwt else { return }
    guard !pollingAiringIds.contains(airing.id) else { return }

    pollingAiringIds.insert(airing.id)

    do {
      let spinsResponse = try await api.getAiringSpins(jwt, airing.id)
      let allSpins = spinsResponse.contextSpins + spinsResponse.airingSpins
      guard let firstSpin = allSpins.min(by: { $0.airtime < $1.airtime }),
        let lastSpin = allSpins.max(by: { $0.airtime < $1.airtime })
      else {
        pollingAiringIds.remove(airing.id)
        presentedAlert = .errorCreatingClip
        return
      }

      let clip = try await api.createClipForAiring(
        jwt, firstSpin.id, lastSpin.id, 0, 0)
      clips[airing.id] = clip

      if clip.status == .pending || clip.status == .processing {
        await pollForClipCompletion(clipId: clip.id, airingId: airing.id)
      } else if clip.status == .failed {
        pollingAiringIds.remove(airing.id)
        presentedAlert = .clipFailed
      }
    } catch {
      pollingAiringIds.remove(airing.id)
      presentedAlert = .errorCreatingClip
    }
  }

  func downloadTapped(_ airing: ListenerQuestionAiring) {
    guard let clip = clips[airing.id] else { return }
    guard let urlString = clip.url, let url = URL(string: urlString) else {
      presentedAlert = .errorDownloadingClip
      return
    }
    let shareModel = ShareSheetModel(items: [url])
    mainContainerNavigationCoordinator.presentedSheet = .share(shareModel)
  }

  func shareTapped(_ airing: ListenerQuestionAiring) {
    guard let clip = clips[airing.id] else { return }
    let shareUrl = "\(Config.shared.baseUrl.absoluteString)/clips/\(clip.id)/share"
    let shareModel = ShareSheetModel(items: [shareUrl])
    mainContainerNavigationCoordinator.presentedSheet = .share(shareModel)
  }

  func retryTapped(_ airing: ListenerQuestionAiring) async {
    clips.removeValue(forKey: airing.id)
    await createClipTapped(airing)
  }

  func browseStationsTapped() {
    mainContainerNavigationCoordinator.pop()
  }

  // MARK: - View Helpers

  var navigationTitle: String { "My Airings" }

  var upcomingAirings: [ListenerQuestionAiring] {
    airings.filter { $0.airtime > now }.sorted { $0.airtime < $1.airtime }
  }

  var pastAirings: [ListenerQuestionAiring] {
    airings.filter { $0.airtime <= now }.sorted { $0.airtime > $1.airtime }
  }

  var emptyStateMessage: String {
    "Your Q&A airings will appear here.\nAsk a question on your favorite station!"
  }
  var emptyStateButtonText: String { "Browse Stations" }
  var showEmptyState: Bool { !isLoading && airings.isEmpty }

  func stationName(for airing: ListenerQuestionAiring) -> String {
    airing.station?.curatorName ?? "Station"
  }

  func stationImageUrl(for airing: ListenerQuestionAiring) -> URL? {
    airing.station?.imageUrl
  }

  private static let dayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    return f
  }()
  private static let monthDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    return f
  }()
  private static let hourFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mma"
    return f
  }()

  func formattedAirtime(_ date: Date) -> String {
    let dayOfWeek = Self.dayFormatter.string(from: date)
    let dateStr = Self.monthDayFormatter.string(from: date)
    let hour = Self.hourFormatter.string(from: date).lowercased()
    return "\(dayOfWeek), \(dateStr) at \(hour)"
  }

  func clipState(for airing: ListenerQuestionAiring) -> ClipRowState {
    if airing.airtime > now { return .upcoming }

    if pollingAiringIds.contains(airing.id) { return .creating }

    guard let clip = clips[airing.id] else { return .noClip }

    switch clip.status {
    case .completed:
      return .ready(clip)
    case .pending, .processing:
      return .creating
    case .failed:
      return .failed(clip.errorMessage)
    }
  }

  // MARK: - Private Helpers

  private func loadData() async {
    guard let jwt = auth.jwt else { return }

    isLoading = true
    defer { isLoading = false }

    do {
      async let airingsResult = api.getMyListenerQuestionAirings(jwt)
      async let clipsResult = api.getUserClips(jwt)

      let fetchedAirings = try await airingsResult
      let fetchedClips = try await clipsResult

      airings = fetchedAirings
      matchClipsToAirings(fetchedClips)
    } catch {
      presentedAlert = .errorLoadingClips
    }
  }

  private func matchClipsToAirings(_ fetchedClips: [Clip]) {
    for clip in fetchedClips {
      guard let tracks = clip.tracks else { continue }
      for track in tracks {
        if let airingId = track.listenerQuestionAiringId {
          clips[airingId] = clip
        }
      }
    }
  }

  private func pollForClipCompletion(clipId: String, airingId: String) async {
    guard let jwt = auth.jwt else { return }

    let task = Task {
      for _ in 0..<60 {
        guard !Task.isCancelled else {
          pollingAiringIds.remove(airingId)
          return
        }

        try? await Task.sleep(for: .seconds(3))

        guard !Task.isCancelled else {
          pollingAiringIds.remove(airingId)
          return
        }

        do {
          let clip = try await api.getClip(jwt, clipId)
          clips[airingId] = clip

          if clip.status == .completed {
            pollingAiringIds.remove(airingId)
            pollingTasks.removeValue(forKey: airingId)
            return
          } else if clip.status == .failed {
            pollingAiringIds.remove(airingId)
            pollingTasks.removeValue(forKey: airingId)
            presentedAlert = .clipFailed
            return
          }
        } catch {
          pollingAiringIds.remove(airingId)
          pollingTasks.removeValue(forKey: airingId)
          return
        }
      }

      pollingAiringIds.remove(airingId)
      pollingTasks.removeValue(forKey: airingId)
      presentedAlert = .clipTimeout
    }
    pollingTasks[airingId] = task

    await task.value
  }
}

// MARK: - Alerts

extension PlayolaAlert {
  static var errorCreatingClip: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "There was an error creating your clip. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }

  static var errorLoadingClips: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Unable to load your airings. Please try again later.",
      dismissButton: .cancel(Text("OK")))
  }

  static var clipFailed: PlayolaAlert {
    PlayolaAlert(
      title: "Clip Failed",
      message: "There was an error processing your clip. You can try again.",
      dismissButton: .cancel(Text("OK")))
  }

  static var clipTimeout: PlayolaAlert {
    PlayolaAlert(
      title: "Still Processing",
      message:
        "Your clip is taking longer than expected. Check back in a few minutes.",
      dismissButton: .cancel(Text("OK")))
  }

  static var errorDownloadingClip: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "The clip file is not available. Please try again later.",
      dismissButton: .cancel(Text("OK")))
  }
}
