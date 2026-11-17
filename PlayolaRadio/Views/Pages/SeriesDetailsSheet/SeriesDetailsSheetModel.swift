//
//  SeriesDetailsSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

enum SeriesRepeatOption: String, CaseIterable, Identifiable, Hashable {
  case everyWeek
  case noSchedule

  var id: String { rawValue }

  var title: String {
    switch self {
    case .everyWeek: "Every week"
    case .noSchedule: "No schedule"
    }
  }
}

struct SeriesDayOption: Identifiable, Equatable {
  let id: Locale.Weekday
  let letter: String
  let isSelected: Bool
  let fillColor: Color
}

@MainActor
@Observable
class SeriesDetailsSheetModel: ViewModel, Identifiable {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.notificationCenter) var notificationCenter

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization

  init(stationId: String, timeZone: TimeZone) {
    self.stationId = stationId
    self.timeZone = timeZone
    super.init()
  }

  // MARK: - Properties

  static let defaultHour = 19

  let stationId: String
  let timeZone: TimeZone
  var name = ""
  var repeatOption: SeriesRepeatOption = .everyWeek
  var selectedDays: Set<Locale.Weekday> = []
  var hour = SeriesDetailsSheetModel.defaultHour
  var minute = 0
  var isSaving = false
  var presentedAlert: PlayolaAlert?
  @ObservationIgnored var onSaved: @MainActor (CuratorSeries) async -> Void = { _ in }
  @ObservationIgnored var onCancel: @MainActor () -> Void = {}

  var navigationTitle: String { "New Series" }
  var cancelButtonTitle: String { "Cancel" }
  var saveButtonTitle: String { "Save" }
  var nameHeader: String { "NAME" }
  var namePlaceholder: String { "Series name" }
  var repeatsHeader: String { "REPEATS" }
  var daysHeader: String { "DAYS" }
  var timeHeader: String { "TIME" }
  var startsAtLabel: String { "Starts at" }
  var note: String {
    "Pick the days your series airs. Open slots will show up on the series page \u{2014} "
      + "they\u{2019}re only suggestions."
  }
  var repeatOptions: [SeriesRepeatOption] { SeriesRepeatOption.allCases }

  // MARK: - User Actions

  func dayTapped(_ day: Locale.Weekday) {
    guard !isSaving else { return }
    if selectedDays.contains(day) {
      selectedDays.remove(day)
    } else {
      selectedDays.insert(day)
    }
  }

  func cancelButtonTapped() {
    guard !isSaving else { return }
    onCancel()
  }

  func saveButtonTapped() async {
    guard isSaveEnabled, let jwt = auth.jwt else { return }
    isSaving = true
    let created: CuratorSeries
    do {
      created = try await api.createSeries(jwt, stationId, trimmedName, rrule)
    } catch {
      isSaving = false
      await presentFailure(error)
      return
    }
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
    await onSaved(created)
  }

  // MARK: - View Helpers

  var isSaveEnabled: Bool {
    guard !isSaving, !trimmedName.isEmpty else { return false }
    return repeatOption == .noSchedule || !selectedDays.isEmpty
  }

  var saveButtonColor: Color { isSaveEnabled ? .playolaRed : .playolaTextTertiary }

  var saveTitleOpacity: Double { isSaving ? 0 : 1 }

  var savingSpinnerOpacity: Double { isSaving ? 1 : 0 }

  var isInteractiveDismissDisabled: Bool { isSaving }

  func repeatOptionFill(_ option: SeriesRepeatOption) -> Color {
    option == repeatOption ? .playolaSurfacePlaceholder : .playolaTransparent
  }

  func repeatOptionTapped(_ option: SeriesRepeatOption) {
    guard !isSaving else { return }
    repeatOption = option
  }

  var scheduleSections: [String] { repeatOption == .everyWeek ? ["schedule"] : [] }

  var dayOptions: [SeriesDayOption] {
    Self.sundayFirst.map { day, letter in
      let isSelected = selectedDays.contains(day)
      return SeriesDayOption(
        id: day, letter: letter, isSelected: isSelected,
        fillColor: isSelected ? .playolaRed : .playolaSurfaceControl)
    }
  }

  var startTime: Date {
    get {
      calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
    }
    set {
      let components = calendar.dateComponents([.hour, .minute], from: newValue)
      hour = components.hour ?? hour
      minute = components.minute ?? minute
    }
  }

  var rrule: String? {
    guard repeatOption == .everyWeek else { return nil }
    return SeriesSchedule(weekdays: selectedDays, hour: hour, minute: minute).rrule
  }

  // MARK: - Private Helpers

  private static let sundayFirst: [(Locale.Weekday, String)] = [
    (.sunday, "S"), (.monday, "M"), (.tuesday, "T"), (.wednesday, "W"), (.thursday, "T"),
    (.friday, "F"), (.saturday, "S"),
  ]

  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
  }

  private func presentFailure(_ error: Error) async {
    guard !(error is CancellationError), (error as? URLError)?.code != .cancelled else { return }
    if !NetworkErrorClassifier.isNetworkError(error) {
      var tags = NetworkErrorClassifier.errorTags(for: error)
      tags["endpoint"] = "createSeries"
      await errorReporting.reportError(error, tags)
    }
    presentedAlert = PlayolaAlert(
      title: "Couldn\u{2019}t Create Series", message: error.localizedDescription,
      dismissButton: .cancel(Text("OK")))
  }
}
