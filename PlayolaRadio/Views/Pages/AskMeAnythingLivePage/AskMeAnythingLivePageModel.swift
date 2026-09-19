//
//  AskMeAnythingLivePageModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

@MainActor
@Observable
class AskMeAnythingLivePageModel: ViewModel {

  enum Phase: Equatable { case loading, waiting, running, ending, ended, unavailable }

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.activeLiveShow) var activeLiveShow
  @ObservationIgnored @Shared(.mainContainerNavigationCoordinator) var navigationCoordinator

  // MARK: - Initialization

  init(stationId: String, liveShowId: String, scheduledStartsAt: Date) {
    self.stationId = stationId
    self.liveShowId = liveShowId
    self.scheduledStartsAt = scheduledStartsAt
    super.init()
  }

  // MARK: - Properties

  let stationId: String
  let liveShowId: String
  let scheduledStartsAt: Date

  private let targetMilliseconds = 600_000
  private let pollInterval: Duration = .seconds(10)
  private let contiguityToleranceSeconds: TimeInterval = 2

  private var schedule: Schedule?
  private(set) var listenerCount: Int?
  private(set) var hasConfirmedRunning = false
  private(set) var hasEnded = false
  private(set) var endOutcome: EndLiveShowResponse?
  private var pendingOutroBlock: AudioBlock?
  var presentedAlert: PlayolaAlert?

  // MARK: - Lifecycle (driven by the view's .task)

  func startMonitoring() async {
    await refreshNow()
    while !Task.isCancelled {
      do { try await clock.sleep(for: pollInterval) } catch { return }
      if Task.isCancelled { return }
      await refreshNow()
    }
  }

  func refreshNow() async {
    async let scheduleFetch = fetchScheduleSafely()
    async let listenerFetch = fetchListenerCountSafely()
    let newSchedule = await scheduleFetch
    let count = await listenerFetch

    if Task.isCancelled { return }

    if let newSchedule { schedule = newSchedule }
    if let count { listenerCount = count }

    if let np = schedule?.nowPlaying(), np.liveShowId == liveShowId {
      hasConfirmedRunning = true
    }
  }

  // MARK: - Phase

  var phase: Phase {
    // The server has told us the show is permanently gone (finished/replaced): latch terminal
    // immediately rather than trusting a stale cached schedule that may still show our spins.
    if hasEnded { return .ended }
    guard let schedule else { return endOutcome != nil ? .ending : .loading }

    if let np = schedule.nowPlaying(), np.liveShowId == liveShowId {
      return endOutcome != nil ? .ending : .running
    }

    if let endOutcome {
      let beforeEffectiveEnd = now < endOutcome.effectiveEndsAt
      return (beforeEffectiveEnd || hasShowSpinsRemaining(in: schedule)) ? .ending : .ended
    }

    if hasConfirmedRunning {
      return hasShowSpinsRemaining(in: schedule) ? .running : .ended
    }

    if hasUpcomingShowSpins(in: schedule) { return .waiting }

    return .unavailable
  }

  // MARK: - Now playing / queue

  var nowPlaying: Spin? { schedule?.nowPlaying() }

  var upcomingSpins: [Spin] {
    guard let schedule else { return [] }
    return schedule.current().filter { $0.airtime > now }
  }

  var nowPlayingProgress: Double {
    guard let spin = nowPlaying else { return 0 }
    return spin.progress(at: now)
  }

  // MARK: - Preparedness meter (spec §7.4 / D-A)

  var bufferedMilliseconds: Int {
    guard let schedule else { return 0 }
    let ordered = schedule.current().sorted { $0.airtime < $1.airtime }
    guard
      let startIdx = ordered.firstIndex(where: { $0.endtime > now && isShowSpin($0) })
    else { return 0 }

    var lastEnd = ordered[startIdx].endtime
    var idx = startIdx + 1
    while idx < ordered.count, isShowSpin(ordered[idx]) {
      guard ordered[idx].airtime <= lastEnd.addingTimeInterval(contiguityToleranceSeconds) else {
        break
      }
      lastEnd = ordered[idx].endtime
      idx += 1
    }

    let effectiveStart = max(now, ordered[startIdx].airtime)
    return max(0, Int(lastEnd.timeIntervalSince(effectiveStart) * 1000))
  }

  var bufferedMeterFraction: Double {
    min(1, Double(bufferedMilliseconds) / Double(targetMilliseconds))
  }

  private func isShowSpin(_ spin: Spin) -> Bool {
    spin.liveShowId == liveShowId && spin.isFiller != true
  }

  private func hasUpcomingShowSpins(in schedule: Schedule) -> Bool {
    schedule.current().contains { $0.liveShowId == liveShowId && $0.airtime > now }
  }

  private func hasShowSpinsRemaining(in schedule: Schedule) -> Bool {
    schedule.current().contains { $0.liveShowId == liveShowId && $0.endtime > now }
  }

  // MARK: - End Show flow (spec §9)

  func endShowButtonTapped() {
    let recorder = RecordWithMultiStepPromptModel.askMeAnythingOutro(stationId: stationId)
    recorder.onCompleted = { [weak self] outroBlock in
      await self?.submitEnd(outroAudioBlock: outroBlock)
    }
    navigationCoordinator.push(.recordWithMultiStepPromptPage(recorder))
  }

  func submitEnd(outroAudioBlock: AudioBlock) async {
    pendingOutroBlock = outroAudioBlock
    guard let jwt = auth.jwt else {
      presentedAlert = .liveShowEndFailed { [weak self] in await self?.retryEndButtonTapped() }
      return
    }
    do {
      let outcome = try await api.endLiveShow(jwt, stationId, liveShowId, outroAudioBlock.id)
      endOutcome = outcome
      await refreshNow()
    } catch APIError.liveShowFinished {
      // The show already wrapped (natural exhaustion / race). Treat as ended; discard the outro.
      endOutcome = nil
      pendingOutroBlock = nil
      hasEnded = true
      presentedAlert = .liveShowAlreadyEnded
    } catch APIError.liveShowReplaced {
      // Another show/edit superseded this one. It is no longer endable; discard the outro and
      // land in the terminal state rather than offering an unwinnable Retry.
      endOutcome = nil
      pendingOutroBlock = nil
      hasEnded = true
      presentedAlert = .liveShowAlreadyEnded
    } catch {
      presentedAlert = .liveShowEndFailed { [weak self] in await self?.retryEndButtonTapped() }
    }
  }

  func retryEndButtonTapped() async {
    guard let block = pendingOutroBlock else { return }
    await submitEnd(outroAudioBlock: block)
  }

  func doneButtonTapped() {
    $activeLiveShow.withLock { $0 = nil }
    navigationCoordinator.switchToBroadcastMode(stationId: stationId)
  }

  // MARK: - View Helpers

  var navigationTitle: String { "Ask Me Anything" }
  var listenerCountLabel: String { "\(listenerCount ?? 0) listening" }

  var nowPlayingTitle: String { nowPlaying?.audioBlock.title ?? "" }
  var nowPlayingArtist: String { nowPlaying?.audioBlock.artist ?? "" }
  var liveNowLabel: String { "LIVE NOW" }

  var bufferedMeterLabel: String { "\(durationLabel(bufferedMilliseconds)) buffered" }
  var bufferedPercentLabel: String {
    "\(Int((bufferedMeterFraction * 100).rounded()))% of 10 min"
  }

  var waitingCountdownLabel: String {
    let target = firstShowSpinAirtime ?? scheduledStartsAt
    let remaining = max(0, Int(target.timeIntervalSince(now)))
    return "Your Show Starts in \(durationLabel(remaining * 1000))"
  }

  var waitingSubtitleLabel: String {
    let target = firstShowSpinAirtime ?? scheduledStartsAt
    guard let np = nowPlaying else { return "Starts \(airtimeLabel(for: target))" }
    return "After \(np.audioBlock.title) finishes \u{00B7} \(timeString(for: target))"
  }

  var waitingFooterLabel: String { "Show starts automatically" }

  var addToShowTitle: String { "Add to Show" }
  var isAddToShowEnabled: Bool { false }  // PR2 wires this; rendered disabled in PR1.

  var endShowButtonTitle: String { "End Show" }
  var endingButtonTitle: String { "Ending\u{2026}" }
  var doneButtonTitle: String { "Done" }
  var unavailableMessage: String {
    "This show is no longer live. Your station is back to its regular schedule."
  }

  var waitingBannerOpacity: Double { phase == .waiting ? 1 : 0 }
  var runningMonitorOpacity: Double { (phase == .running || phase == .ending) ? 1 : 0 }
  var isEndShowEnabled: Bool { phase == .running }
  var endShowButtonOpacity: Double { (phase == .running || phase == .ending) ? 1 : 0 }
  var endShowButtonDisplayTitle: String {
    phase == .ending ? endingButtonTitle : endShowButtonTitle
  }
  var doneButtonOpacity: Double { (phase == .ended || phase == .unavailable) ? 1 : 0 }

  func airtimeLabel(for date: Date) -> String { "at \(timeString(for: date))" }

  func pinOpacity(for spin: Spin) -> Double { upcomingSpins.first?.id == spin.id ? 1 : 0 }

  // MARK: - Private Helpers

  private var firstShowSpinAirtime: Date? {
    schedule?.current()
      .filter { $0.liveShowId == liveShowId }
      .map(\.airtime)
      .min()
  }

  private func fetchScheduleSafely() async -> Schedule? {
    do {
      let spins = try await api.fetchSchedule(stationId, true)
      return Schedule(stationId: stationId, spins: spins, dateProvider: DependencyDateProvider())
    } catch {
      return nil
    }
  }

  private func fetchListenerCountSafely() async -> Int? {
    guard let jwt = auth.jwt else { return nil }
    do {
      let response = try await api.getActiveListeningSessions(jwt, stationId, now, nil)
      return response.summary.uniqueUsers
    } catch {
      return nil
    }
  }

  private func durationLabel(_ milliseconds: Int) -> String {
    let total = max(0, milliseconds) / 1000
    return String(format: "%d:%02d", total / 60, total % 60)
  }

  private func timeString(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
  }
}
