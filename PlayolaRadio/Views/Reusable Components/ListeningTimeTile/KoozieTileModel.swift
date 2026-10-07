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
  case earned
}

@MainActor
@Observable
final class KoozieTileModel: ViewModel {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?

  override init() { super.init() }

  /// Koozie prize id + threshold, loaded once from `/tiers`. Nil until loaded.
  var kooziePrizeInfo: KooziePrizeInfo?
  /// Live listening total (ms), fed each second by the parent tile model's refresh loop.
  var liveTotalMS: Int = 0

  /// Set by `markClaimed()` once the claim sheet reports success. Keeps the tile out of
  /// `.claimable` even if the follow-up profile refresh fails or lags. Keyed by user id so a
  /// claim never carries over to another account signed in on the same model.
  private var locallyClaimedUserKeys: Set<String> = []
  private var currentUserKey: String { auth.currentUser?.id ?? "" }
  private var hasClaimedLocally: Bool { locallyClaimedUserKeys.contains(currentUserKey) }
  /// The single in-flight/completed tiers-load task. Kept non-nil once started so the tile's
  /// 1s loop can call `startTiersLoadIfNeeded()` every tick without launching duplicates.
  private(set) var tiersLoadTask: Task<Void, Never>?

  // MARK: - Copy

  var progressTitle: String { "Playola Koozie" }
  var claimableTitle: String { "You earned a koozie!" }
  var claimableSubtitle: String { "Claim it from your prize tile above." }
  var earnedText: String { "Koozie claimed — thanks for listening!" }

  // MARK: - Derived state

  private var profile: RewardsProfile? { listeningTracker?.rewardsProfile }

  var mode: KoozieTileMode {
    if profile?.koozieEarned == true || hasClaimedLocally { return .earned }
    if isClaimable { return .claimable }
    return .inProgress
  }

  var isClaimable: Bool {
    guard profile?.koozieEarned != true, !hasClaimedLocally, let info = kooziePrizeInfo else {
      return false
    }
    return liveTotalMS >= info.requiredHours * 3_600_000
  }

  var rewardClaim: RewardClaim? {
    guard isClaimable, let info = kooziePrizeInfo else { return nil }
    return RewardClaim(
      prizeId: info.prizeId, prizeSlug: "koozie", prizeTitle: info.prizeName,
      prizeImageUrl: nil, requiredHours: info.requiredHours)
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

  func markClaimed() {
    locallyClaimedUserKeys.insert(currentUserKey)
    Task { [weak self] in await self?.refreshProfile() }
  }

  func refreshProfile() async {
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
      tracker = current.replacingRewardsProfile(merged)
    }
  }
}
