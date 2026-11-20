//
//  UnscheduleShowSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

@MainActor
@Observable
class UnscheduleShowSheetModel: ViewModel {

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(
    episode: CuratorEpisode,
    airing: CuratorAiring,
    series: CuratorSeries?,
    settings: StationSchedulingSettings,
    unschedule: @escaping @MainActor () async throws -> Void
  ) {
    self.episode = episode
    self.airing = airing
    self.series = series
    self.settings = settings
    self.unschedule = unschedule
    super.init()
  }

  // MARK: - Properties

  let episode: CuratorEpisode
  let airing: CuratorAiring
  let series: CuratorSeries?
  let settings: StationSchedulingSettings
  private(set) var isSaving = false
  private(set) var failureMessage: String?
  @ObservationIgnored private let unschedule: @MainActor () async throws -> Void

  var unscheduleButtonTitle: String { "Unschedule" }
  var keepScheduledButtonTitle: String { "Keep it scheduled" }

  // MARK: - User Actions

  func unscheduleConfirmed() async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    failureMessage = nil
    do {
      try await unschedule()
      dismiss()
    } catch is CancellationError {
      return
    } catch {
      failureMessage = error.localizedDescription
    }
  }

  func keepScheduledTapped() {
    dismiss()
  }

  // MARK: - View Helpers

  var title: String { "Unschedule \(episode.title)?" }

  var subtitle: String {
    guard let series, !series.isOneTime else { return "It goes back to your drafts." }
    return "It goes back to your drafts, and \(slotText) opens up again in \(series.title)."
  }

  var errorLines: [String] {
    failureMessage.map { [$0] } ?? []
  }

  // MARK: - Private Helpers

  private var slotText: String {
    "\(formatted("EEEE, MMM d")) at \(formatted("h:mm a"))"
  }

  private func dismiss() {
    guard case .unscheduleShow(let presented) = navigationCoordinator.presentedSheet,
      presented === self
    else { return }
    $navigationCoordinator.withLock { $0.presentedSheet = nil }
  }

  private func formatted(_ format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = settings.timeZone
    formatter.dateFormat = format
    return formatter.string(from: airing.airtime)
  }
}
