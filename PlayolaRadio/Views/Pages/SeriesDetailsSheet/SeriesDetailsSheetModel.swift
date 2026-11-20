//
//  SeriesDetailsSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
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
  let accessibilityLabel: String
  let accessibilityTraits: AccessibilityTraits
  let fillColor: Color
}

@MainActor
@Observable
class SeriesDetailsSheetModel: ViewModel, Identifiable {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.errorReporting) var errorReporting
  @ObservationIgnored @Dependency(\.notificationCenter) var notificationCenter

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization

  /// New Series mode, or Edit Series mode when `editing` is given. Edit mode opens with the
  /// Series' name and, read from its rule, Every week with its days and time, No schedule for a nil
  /// rule, or the read-only Custom schedule for a rule the app can't read.
  init(stationId: String, timeZone: TimeZone, editing series: CuratorSeries? = nil) {
    self.stationId = stationId
    self.timeZone = timeZone
    self.editedSeries = series
    super.init()
    if let series {
      name = series.title
      if let rrule = series.rrule {
        if let schedule = SeriesSchedule(rrule: rrule) {
          selectedDays = schedule.weekdays
          hour = schedule.hour
          minute = schedule.minute
        } else {
          isCustomSchedule = true
        }
      } else {
        repeatOption = .noSchedule
      }
    }
  }

  // MARK: - Properties

  static let defaultHour = 19

  let stationId: String
  let timeZone: TimeZone
  let editedSeries: CuratorSeries?
  private(set) var isCustomSchedule = false
  var name = ""
  var repeatOption: SeriesRepeatOption = .everyWeek
  var selectedDays: Set<Locale.Weekday> = []
  var hour = SeriesDetailsSheetModel.defaultHour
  var minute = 0
  var isSaving = false
  var presentedAlert: PlayolaAlert?
  @ObservationIgnored var onSaved: @MainActor (CuratorSeries) async -> Void = { _ in }
  @ObservationIgnored var onCancel: @MainActor () -> Void = {}

  var navigationTitle: String { editedSeries == nil ? "New Series" : "Edit Series" }
  var cancelButtonTitle: String { "Cancel" }
  var saveButtonTitle: String { "Save" }
  var nameHeader: String { "NAME" }
  var namePlaceholder: String { "Series name" }
  var repeatsHeader: String { "REPEATS" }
  var daysHeader: String { "DAYS" }
  var timeHeader: String { "TIME" }
  var scheduleHeader: String { "SCHEDULE" }
  var startsAtLabel: String { "Starts at" }
  var note: String {
    guard editedSeries == nil else {
      return "Changing the schedule only changes your open slots. Shows that are already "
        + "scheduled keep their times."
    }
    return "Pick the days your series airs. Open slots will show up on the series page \u{2014} "
      + "they\u{2019}re only suggestions."
  }
  var repeatOptions: IdentifiedArrayOf<SeriesRepeatOption> {
    IdentifiedArray(uniqueElements: SeriesRepeatOption.allCases)
  }

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
    let saved: CuratorSeries
    do {
      if let editedSeries {
        // nil leaves a Custom schedule alone; `.some(nil)` clears the schedule.
        saved = try await api.updateSeries(
          jwt, editedSeries.id, trimmedName, isCustomSchedule ? nil : .some(rrule))
      } else {
        saved = try await api.createSeries(jwt, stationId, trimmedName, rrule)
      }
    } catch {
      isSaving = false
      await presentFailure(error)
      return
    }
    notificationCenter.post(
      name: .recordedShowsChanged, object: nil, userInfo: ["stationId": stationId])
    await onSaved(saved)
  }

  // MARK: - View Helpers

  var isSaveEnabled: Bool {
    guard !isSaving, !trimmedName.isEmpty else { return false }
    return isCustomSchedule || repeatOption == .noSchedule || !selectedDays.isEmpty
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

  var repeatsSections: [String] { isCustomSchedule ? [] : ["repeats"] }

  var scheduleSections: [String] {
    !isCustomSchedule && repeatOption == .everyWeek ? ["schedule"] : []
  }

  var customScheduleRows: [String] { isCustomSchedule ? ["Custom schedule"] : [] }

  var notes: [String] { isCustomSchedule ? [] : [note] }

  var dayOptions: IdentifiedArrayOf<SeriesDayOption> {
    IdentifiedArray(
      uniqueElements: Self.sundayFirst.map { day, name in
        let isSelected = selectedDays.contains(day)
        return SeriesDayOption(
          id: day, letter: String(name.prefix(1)), accessibilityLabel: name,
          accessibilityTraits: isSelected ? .isSelected : [],
          fillColor: isSelected ? .playolaRed : .playolaSurfaceControl)
      })
  }

  var startTime: Date {
    get {
      let wallClock = DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute)
      return calendar.date(from: wallClock) ?? .distantPast
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
    (.sunday, "Sunday"), (.monday, "Monday"), (.tuesday, "Tuesday"), (.wednesday, "Wednesday"),
    (.thursday, "Thursday"), (.friday, "Friday"), (.saturday, "Saturday"),
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
      tags["endpoint"] = editedSeries == nil ? "createSeries" : "updateSeries"
      await errorReporting.reportError(error, tags)
    }
    presentedAlert = PlayolaAlert(
      title: editedSeries == nil ? "Couldn\u{2019}t Create Series" : "Couldn\u{2019}t Save Series",
      message: error.localizedDescription,
      dismissButton: .cancel(Text("OK")))
  }
}
