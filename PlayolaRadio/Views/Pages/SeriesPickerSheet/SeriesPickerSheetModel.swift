//
//  SeriesPickerSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import SwiftUI

struct SeriesPickerRow: Identifiable, Equatable {
  let id: String
  let title: String
  let subtitle: String
  let accessoryIcon: String
  let accessoryColor: Color
}

struct SeriesPickerNewSeriesRow: Identifiable, Equatable {
  var id: String { title }
  let title: String
  let subtitle: String
}

@MainActor
@Observable
class SeriesPickerSheetModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.toast) var toast

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String, showTitle: String, currentSeries: CuratorSeries?, timeZone: TimeZone) {
    self.stationId = stationId
    self.showTitle = showTitle
    self.currentSeries = currentSeries.flatMap { $0.isOneTime ? nil : $0 }
    self.timeZone = timeZone
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let showTitle: String
  let currentSeries: CuratorSeries?
  let timeZone: TimeZone
  var series: [CuratorSeries] = []
  var isLoading = true
  var seriesDetails: SeriesDetailsSheetModel?
  @ObservationIgnored var onSeriesChange: @MainActor (SeriesChange) async -> Void = { _ in }
  @ObservationIgnored var onDismissed: @MainActor () -> Void = {}
  @ObservationIgnored private var hasCommitted = false
  @ObservationIgnored private var hasNotifiedDismissal = false

  var title: String { currentSeries == nil ? "Add to a series" : "Series" }

  var subtitle: String {
    guard currentSeries != nil else { return "\(showTitle) will show up on the series page." }
    return "Changing the series doesn\u{2019}t change when \(showTitle) airs."
  }

  var loadErrorMessage: String { "The series couldn\u{2019}t load." }

  // MARK: - User Actions

  func viewAppeared() async {
    guard let jwt = auth.jwt else {
      isLoading = false
      return
    }
    defer { isLoading = false }
    do {
      series = try await api.getCuratorSeries(jwt, stationId).filter { !$0.isOneTime }
    } catch {
      guard !isCancellation(error) else { return }
      if !NetworkErrorClassifier.isNetworkError(error) {
        var tags = NetworkErrorClassifier.errorTags(for: error)
        tags["endpoint"] = "getCuratorSeries"
        await errorReporting.reportError(error, tags)
      }
      await toast.show(PlayolaToast(message: loadErrorMessage, buttonTitle: "OK"))
    }
  }

  func seriesRowTapped(_ seriesId: String) async {
    guard seriesId != currentSeries?.id else {
      dismissSheets()
      return
    }
    await commit(.join(seriesId))
  }

  func removeButtonTapped() async {
    guard currentSeries != nil else { return }
    await commit(.makeStandalone)
  }

  func newSeriesRowTapped() {
    guard !hasCommitted else { return }
    let details = withDependencies(from: self) {
      SeriesDetailsSheetModel(stationId: stationId, timeZone: timeZone)
    }
    details.onSaved = { [weak self] created in await self?.seriesCreated(created) }
    details.onCancel = { [weak self] in self?.seriesDetails = nil }
    seriesDetails = details
  }

  func dismissed() {
    guard !hasNotifiedDismissal else { return }
    hasNotifiedDismissal = true
    onDismissed()
  }

  // MARK: - View Helpers

  var rows: IdentifiedArrayOf<SeriesPickerRow> {
    guard !isLoading else { return [] }
    return IdentifiedArray(uniqueElements: series.map(row(for:)))
  }

  var loadingSpinners: [String] { isLoading ? ["loading"] : [] }

  var newSeriesRows: [SeriesPickerNewSeriesRow] {
    guard !isLoading else { return [] }
    return [
      SeriesPickerNewSeriesRow(title: "New Series", subtitle: "Name it and choose when it repeats")
    ]
  }

  var removeButtons: [String] {
    guard !isLoading, let currentSeries else { return [] }
    return ["Remove from \(currentSeries.title)"]
  }

  // MARK: - Private Helpers

  private func seriesCreated(_ created: CuratorSeries) async {
    guard !hasCommitted else { return }
    hasCommitted = true
    await onSeriesChange(.join(created.id))
    dismissSheets()
  }

  private func commit(_ change: SeriesChange) async {
    guard !hasCommitted else { return }
    hasCommitted = true
    dismissSheets()
    await onSeriesChange(change)
  }

  private func dismissSheets() {
    seriesDetails = nil
    guard case .seriesPicker(let presented) = navigationCoordinator.presentedSheet,
      presented === self
    else { return }
    $navigationCoordinator.withLock { $0.presentedSheet = nil }
  }

  private func row(for series: CuratorSeries) -> SeriesPickerRow {
    let isChecked = series.id == currentSeries?.id
    return SeriesPickerRow(
      id: series.id, title: series.title, subtitle: Self.scheduleText(series.rrule),
      accessoryIcon: isChecked ? "checkmark" : "chevron.right",
      accessoryColor: isChecked ? .playolaRed : .playolaTextTertiary)
  }

  private static func scheduleText(_ rrule: String?) -> String {
    guard let rrule else { return "No schedule" }
    return SeriesSchedule(rrule: rrule)?.text ?? "Custom schedule"
  }

  private func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
  }
}
