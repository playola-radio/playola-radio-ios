//
//  ScheduleShowSheetModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import IdentifiedCollections
import Sharing
import SwiftUI

struct ScheduleSlotRow: Identifiable, Equatable {
  let id: Date
  let monthText: String
  let dayText: String
  let title: String
  let subtitle: String
}

struct ScheduleLockNote: Identifiable, Equatable {
  var id: String { title }
  let title: String
  let body: String
}

@MainActor
@Observable
class ScheduleShowSheetModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.date.now) var now

  // MARK: - Shared State

  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(
    episode: CuratorEpisode,
    series: CuratorSeries?,
    settings: StationSchedulingSettings,
    occupiedIntervals: [DateInterval],
    initialTime: Date?,
    schedule: @escaping @MainActor (_ airtime: Date) async throws -> Void,
    dismissed: (@MainActor () -> Void)? = nil
  ) {
    self.episode = episode
    self.series = series
    self.settings = settings
    self.schedule = schedule
    self.dismissedAction = dismissed
    self.pickedTime = initialTime ?? .distantPast
    super.init()
    slotRows = makeSlotRows(occupiedIntervals: occupiedIntervals)
    pickedTime = Self.minuteStart(initialTime ?? slotRows.first?.id ?? defaultTime)
  }

  // MARK: - Properties

  let episode: CuratorEpisode
  let series: CuratorSeries?
  let settings: StationSchedulingSettings
  var pickedTime: Date
  private(set) var isSaving = false
  private(set) var slotRows: IdentifiedArrayOf<ScheduleSlotRow> = []
  private var failure: ScheduleFailure?
  @ObservationIgnored private let schedule: @MainActor (_ airtime: Date) async throws -> Void
  /// Runs once, after SwiftUI has finished dismissing this sheet (see MainContainer's bridge).
  @ObservationIgnored private var dismissedAction: (@MainActor () -> Void)?

  var cancelButtonTitle: String { "Cancel" }
  var whenLabel: String { "WHEN" }
  var dayRowLabel: String { "Day" }
  var timeRowLabel: String { "Time" }
  var lockNoteTitle: String { "Locks right away" }

  // MARK: - User Actions

  func slotTapped(_ slot: ScheduleSlotRow) {
    pickedTime = slot.id
  }

  func cancelButtonTapped() {
    guard !isSaving else { return }
    dismiss()
  }

  func scheduleButtonTapped() async {
    guard isScheduleEnabled else { return }
    isSaving = true
    defer { isSaving = false }
    let airtime = chosenTime
    do {
      try await schedule(airtime)
      dismiss()
    } catch is CancellationError {
      return
    } catch {
      failure = ScheduleFailure(
        time: airtime, message: error.localizedDescription, isRefusal: isTimeRefusal(error))
    }
  }

  /// Called once SwiftUI has finished dismissing the sheet.
  func dismissed() {
    let action = dismissedAction
    dismissedAction = nil
    action?()
  }

  // MARK: - View Helpers

  /// The sheet stays open until its schedule closure has finished.
  var isCancelEnabled: Bool { !isSaving }

  var isSwipeDismissDisabled: Bool { isSaving }

  var isChangingTime: Bool { episode.upcomingAiring(now: now) != nil }

  var navigationTitle: String {
    isChangingTime ? "Change Time" : "Schedule \(episode.title)"
  }

  var saveButtonTitle: String { isChangingTime ? "Save" : "Schedule" }

  var saveButtonColor: Color { isScheduleEnabled ? .playolaRed : .playolaTextFaint }

  var isScheduleEnabled: Bool { !isSaving && !(activeFailure?.isRefusal ?? false) }

  var slotsSubtitleLines: [String] {
    guard let series, !slotRows.isEmpty else { return [] }
    return ["Open slots in \(series.title)"]
  }

  var slotRowHeight: CGFloat { 68 }

  var slotListHeight: CGFloat { min(CGFloat(slotRows.count), 3) * slotRowHeight }

  var dayPillLabel: String {
    let isToday = stationCalendar.isDate(chosenTime, inSameDayAs: now)
    return formatted(chosenTime, isToday ? "'Today,' MMM d" : "EEE, MMM d")
  }

  var timePillLabel: String { formatted(chosenTime, "h:mm a") }

  var stationTimeZone: TimeZone { settings.timeZone }

  var stationCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = stationTimeZone
    return calendar
  }

  var airsAtLines: [String] {
    guard activeFailure == nil else { return [] }
    var text = "Airs at about \(formatted(chosenTime, "h:mm a"))"
    if episode.hasAudio {
      let end = chosenTime.addingTimeInterval(Double(episode.durationMS) / 1000)
      text += " \u{00B7} ends about \(formatted(Self.nearestMinute(end), "h:mm a"))"
    }
    return [text]
  }

  var errorLines: [String] {
    activeFailure.map { [$0.message] } ?? []
  }

  var lockNotes: IdentifiedArrayOf<ScheduleLockNote> {
    let lockEdge = now.addingTimeInterval(Double(settings.airingEditLockMS) / 1000)
    guard chosenTime <= lockEdge else { return [] }
    return IdentifiedArray(uniqueElements: [
      ScheduleLockNote(
        title: lockNoteTitle,
        body:
          "This is less than \(settings.airingEditLockText) away, so \(possessiveTitle) songs "
          + "and time lock as soon as it\u{2019}s scheduled. To change them later, "
          + "unschedule it first.")
    ])
  }

  // MARK: - Private Helpers

  private struct ScheduleFailure {
    let time: Date
    let message: String
    let isRefusal: Bool
  }

  private var chosenTime: Date { Self.minuteStart(pickedTime) }

  private var activeFailure: ScheduleFailure? {
    guard let failure, failure.time == chosenTime else { return nil }
    return failure
  }

  private func isTimeRefusal(_ error: Error) -> Bool {
    switch error {
    case APIError.recordedShowLocked:
      return true
    case APIError.serverError(let message):
      return message.hasPrefix("This overlaps ") || message == "No audio."
    default:
      return false
    }
  }

  private var possessiveTitle: String {
    episode.title.hasSuffix("s") ? "\(episode.title)\u{2019}" : "\(episode.title)\u{2019}s"
  }

  private var defaultTime: Date {
    let lockEdge = now.addingTimeInterval(Double(settings.airingEditLockMS) / 1000)
    return stationCalendar.nextDate(
      after: lockEdge, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime)
      ?? lockEdge
  }

  private func makeSlotRows(occupiedIntervals: [DateInterval]) -> IdentifiedArrayOf<
    ScheduleSlotRow
  > {
    guard let series, !series.isOneTime, let rrule = series.rrule,
      let weeklyRule = SeriesSchedule(rrule: rrule)
    else { return [] }
    let slots = weeklyRule.openSlots(
      after: now, in: stationTimeZone, occupiedIntervals: occupiedIntervals)
    return IdentifiedArray(
      uniqueElements: slots.map { slot in
        ScheduleSlotRow(
          id: slot,
          monthText: formatted(slot, "MMM").uppercased(),
          dayText: formatted(slot, "d"),
          title: "\(formatted(slot, "EEEE")) \u{00B7} \(formatted(slot, "h:mm a"))",
          subtitle: "Airs at about \(formatted(slot, "h:mm a"))")
      })
  }

  private func dismiss() {
    guard case .scheduleShow(let presented) = navigationCoordinator.presentedSheet,
      presented === self
    else { return }
    $navigationCoordinator.withLock { $0.presentedSheet = nil }
  }

  private func formatted(_ date: Date, _ format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = stationTimeZone
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  private static func minuteStart(_ date: Date) -> Date {
    Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
  }

  private static func nearestMinute(_ date: Date) -> Date {
    Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded() * 60)
  }
}
