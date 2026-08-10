//
//  KoozieTileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/10/26.
//

import Dependencies
import Foundation
import Observation
import Sharing

/// The koozie-only listening-tile states. Legacy (full-tiers) users never reach these —
/// `ListeningTimeTileModel` only builds a `KoozieTileModel` for the koozie cohort.
enum KoozieTileMode: Equatable {
  case inProgress
  case claimable
  case addressForm
  case congrats
  case earned
}

@MainActor
@Observable
final class KoozieTileModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

  /// Koozie prize id + threshold, loaded once from `/tiers`. Nil until loaded.
  var kooziePrizeInfo: KooziePrizeInfo?
  /// Live listening total (ms), fed each second by the parent tile model's refresh loop.
  var liveTotalMS: Int = 0
  var addressForm = KoozieAddressFormModel()

  private var isShowingAddressForm = false
  private var congratsDismissedLocally = false
  /// The single in-flight/completed tiers-load task. Kept non-nil once started so the tile's
  /// 1s loop can call `startTiersLoadIfNeeded()` every tick without launching duplicates.
  private(set) var tiersLoadTask: Task<Void, Never>?

  // MARK: - Copy

  var progressTitle: String { "Playola Koozie" }
  var claimableTitle: String { "You earned a koozie!" }
  var claimableSubtitle: String { "Claim it and we'll get one out to you." }
  var redeemButtonText: String { "Redeem your koozie" }
  var earnedText: String { "Koozie redeemed — check your email" }
  var congratsMessage: String {
    "You've earned a \(kooziePrizeInfo?.prizeName ?? "koozie")! Thanks for listening!"
  }

  // MARK: - Derived state

  private var profile: RewardsProfile? { listeningTracker?.rewardsProfile }

  var mode: KoozieTileMode {
    if profile?.koozieEarned == true {
      if profile?.shouldShowKoozieCongrats == true, !congratsDismissedLocally {
        return .congrats
      }
      return .earned
    }
    if isShowingAddressForm { return .addressForm }
    if let info = kooziePrizeInfo, liveTotalMS >= info.requiredHours * 3_600_000 {
      return .claimable
    }
    return .inProgress
  }

  var progressFraction: Double {
    guard let info = kooziePrizeInfo, info.requiredHours > 0 else { return 0 }
    return min(1.0, Double(liveTotalMS) / Double(info.requiredHours * 3_600_000))
  }

  var progressPercentLabel: String { "\(Int(progressFraction * 100))%" }

  var hoursToGoLabel: String {
    guard let info = kooziePrizeInfo else { return "" }
    let remainingMS = max(0, info.requiredHours * 3_600_000 - liveTotalMS)
    let totalMinutes = remainingMS / 60_000
    return "\(totalMinutes / 60)h \(totalMinutes % 60)m of listening to go"
  }

  // MARK: - Actions

  /// Launches the tiers load once, decoupled from the tile's 1s counter loop (so a slow
  /// `/tiers` never stalls the live counter) and retrying with capped backoff on network
  /// failure (so one transient failure doesn't permanently strand a claimable user in
  /// `.inProgress`). Safe to call every tick — guarded to a single task.
  func startTiersLoadIfNeeded() {
    guard tiersLoadTask == nil, kooziePrizeInfo == nil else { return }
    tiersLoadTask = Task { [weak self] in
      guard let self else { return }
      var delay: Duration = .seconds(2)
      while !Task.isCancelled {
        if await self.loadTiersOnce() { return }  // stop on any successful fetch
        try? await self.clock.sleep(for: delay)
        delay = min(delay * 2, .seconds(30))
      }
    }
  }

  /// Cancels the tiers backoff task (breaking the strong self-retain it holds while looping)
  /// and clears it so the load can restart if the tile reappears. Called on tile disappear
  /// and when the koozie model is torn down.
  func cancelTiersLoad() {
    tiersLoadTask?.cancel()
    tiersLoadTask = nil
  }

  /// A single tiers fetch attempt. Returns true when the fetch succeeded (whether or not a
  /// koozie prize was present); false only on a thrown/transport error.
  func loadTiersOnce() async -> Bool {
    do {
      let tiers = try await api.getPrizeTiers()
      kooziePrizeInfo = tiers.kooziePrizeInfo
      return true
    } catch {
      return false
    }
  }

  func redeemTapped() {
    addressForm.serverError = nil
    isShowingAddressForm = true
  }

  func backTapped() {
    isShowingAddressForm = false
  }

  func sendMyKoozieTapped() async {
    guard addressForm.canSubmit, let jwt = auth.jwt, let info = kooziePrizeInfo else { return }
    addressForm.serverError = nil
    addressForm.isSubmitting = true
    defer { addressForm.isSubmitting = false }
    do {
      try await api.redeemKooziePrize(jwt, info.prizeId, addressForm.trimmedAddress())
      isShowingAddressForm = false
      await refreshProfile()
    } catch {
      addressForm.serverError =
        (error as? APIError)?.errorDescription ?? "Could not claim your koozie. Please try again."
    }
  }

  func dismissCongratsTapped() async {
    congratsDismissedLocally = true  // optimistic → .earned
    guard let jwt = auth.jwt else { return }
    try? await api.markKoozieCongratsSeen(jwt)
    await refreshProfile()
  }

  private func refreshProfile() async {
    guard let jwt = auth.jwt else { return }
    guard let refreshed = try? await api.getRewardsProfile(jwt) else { return }
    $listeningTracker.withLock { tracker in
      guard let current = tracker else {
        tracker = ListeningTracker(rewardsProfile: refreshed)
        return
      }
      // Adopt ONLY the koozie/earned flags. Keep the existing time totals + local sessions so
      // the live counter neither jumps backward nor double-counts local listening the refreshed
      // server total may already include. The full total re-syncs on the next app launch.
      var merged = current.rewardsProfile
      merged.rewardsExperience = refreshed.rewardsExperience
      merged.koozieEarned = refreshed.koozieEarned
      merged.shouldShowKoozieCongrats = refreshed.shouldShowKoozieCongrats
      tracker = current.replacingRewardsProfile(merged)
    }
  }
}
