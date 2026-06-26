import Combine
import Dependencies
import Foundation
import IdentifiedCollections
import Sharing

/// Drives the live giveaway data path. Polls the cross-station feed, finds the now-playing
/// station's event, and reveals the tap button at the skew-corrected `opensAt` by publishing the
/// (open) event into `@Shared(.activeGiveaway)` — which the player overlay renders.
///
/// Owned and started by `MainContainerModel` (mirrors `LiveStationsPoller`), foreground-gated via
/// scene phase. Exact reveal timing only matters while foregrounded (the button only shows on the
/// player), so a backgrounded app simply reconciles on return — no background timer needed.
@MainActor
@Observable
final class GiveawayCoordinator {
  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.date.now) var now
  @ObservationIgnored @Shared(.auth) var auth
  @ObservationIgnored @Shared(.nowPlaying) var nowPlaying
  @ObservationIgnored @Shared(.activeGiveaway) var activeGiveaway
  @ObservationIgnored @Shared(.upcomingGiveaways) var upcomingGiveaways
  @ObservationIgnored @Shared(.giveawayParticipations) var participations

  @ObservationIgnored private var feedPollTask: Task<Void, Never>?
  @ObservationIgnored private var revealTask: Task<Void, Never>?
  @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
  @ObservationIgnored private var armedEventId: String?
  @ObservationIgnored private var hasObservedStation = false
  @ObservationIgnored private var lastObservedStationId: String?
  @ObservationIgnored private var inFlightTapIds: Set<String> = []
  /// Bumped whenever an arm is cancelled/replaced; a timer callback ignores itself if stale.
  @ObservationIgnored private var generation = 0

  static let feedPollInterval: Duration = .seconds(30)
  /// How far back a `.resolvedLost` participation is still re-checked for a last-tapper promotion on
  /// foreground. A contest closes minutes after a tap, so a few hours is generous without unbounded
  /// polling of stale losses.
  static let lossReconcileWindow: TimeInterval = 6 * 60 * 60

  // MARK: - Lifecycle

  func start() {
    guard GiveawayFeature.isLiveDataEnabled, feedPollTask == nil else {
      log(
        "start skipped (enabled=\(GiveawayFeature.isLiveDataEnabled), running=\(feedPollTask != nil))"
      )
      return
    }
    log("starting · env=\(Config.shared.environment.rawValue) · api=\(Config.shared.baseUrl)")
    observeStationChanges()
    feedPollTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        await self.reconcile()
        // Raw `Task.sleep` (like `LiveStationsPoller`) for the background poll cadence — the
        // testable `clock` dependency is reserved for the reveal arm, where exact timing matters.
        try? await Task.sleep(for: Self.feedPollInterval)
      }
    }
  }

  func stop() {
    feedPollTask?.cancel()
    feedPollTask = nil
    cancellables.removeAll()
    cancelArmedReveal()
  }

  /// Immediate reconcile (on foreground / now-playing change).
  func pollNow() async {
    guard GiveawayFeature.isLiveDataEnabled else { return }
    await reconcile()
    await reconcileRecentResolvedLosses()
  }

  // MARK: - Reconcile

  func reconcile() async {
    guard let jwt = auth.jwt else {
      // Auth loss: cancel the armed timer + clear the open event, AND clear the badges/banner —
      // without a jwt we can't refresh, so leaving them up would strand stale "coming up" state.
      log("reconcile: no auth jwt — clearing")
      clearActiveAndArm()
      $upcomingGiveaways.withLock { $0 = [] }
      return
    }
    let feed: [GiveawayEvent]
    do {
      feed = try await api.giveawayEventsFeed(jwt)
    } catch {
      log("reconcile: feed FETCH FAILED (\(error)) — keeping last state")
      return  // transient failure: keep last known state, retry next poll
    }
    // Publish the all-stations "coming up" projection unconditionally — the badges must show in the
    // station list / Home even when nothing is playing, so this runs ahead of the now-playing guard.
    publishUpcoming(from: feed)
    guard let stationId = currentPlayolaStationId else {
      // Not on a Playola station: tear down the open event + armed timer, but KEEP upcomingGiveaways
      // (that's what powers the list/Home badges while browsing without playback).
      log("reconcile: not on a Playola station — clearing active only")
      clearActiveAndArm()
      return
    }
    let stationEvents = feed.filter { $0.stationId == stationId }
    log(
      "reconcile: playing=\(stationId.prefix(8)) events="
        + "\(stationEvents.map { "\($0.status.rawValue)@\($0.opensAt?.description ?? "nil")" })")
    guard let item = Self.selectEvent(from: stationEvents) else {
      await handleNoFeedEvent(jwt: jwt, stationId: stationId)
      return
    }
    log(
      "reconcile: selected \(item.id) status=\(item.status.rawValue) opensAt=\(item.opensAt?.description ?? "nil")"
    )
    switch item.status {
    case .open:
      cancelArmedReveal()
      await revealEvent(jwt: jwt, eventId: item.id, expectedStationId: stationId)
    case .scheduled:
      if activeGiveaway?.id != item.id { $activeGiveaway.withLock { $0 = nil } }
      armRevealIfNeeded(jwt: jwt, item: item, stationId: stationId)
    case .closed, .canceled, .unknown:
      clearActiveAndArm()
    }
  }

  // MARK: - Tap

  /// Tap into a giveaway. The tap response carries the authoritative `isWinner`, so the outcome is
  /// resolved and persisted (keyed by the per-airing event id) the instant the POST returns — no
  /// wait for the contest to close. The durable write survives an app kill. One tap per event.
  /// Stays silent on the expected `.notOpenYet` race; rethrows any genuine failure for the caller.
  func tap(event: GiveawayEvent) async throws {
    guard let jwt = auth.jwt else { return }
    guard participations[event.id] == nil, !inFlightTapIds.contains(event.id) else { return }
    inFlightTapIds.insert(event.id)
    defer { inFlightTapIds.remove(event.id) }
    do {
      let response = try await api.tapGiveawayEvent(jwt, event.id)
      persistOutcome(event: event, response: response)
    } catch GiveawayTapError.notOpenYet {
      log("tap: not-open-yet for \(event.id) — silent (expected race)")
    } catch {
      log("tap: unexpected failure for \(event.id) — \(error)")
      throw error
    }
  }

  /// Resolve the tap immediately from the server's authoritative response. A non-winning tap is only
  /// *provisionally* lost — the last-tapper promotion at close can still flip it to a win (recovered
  /// by the poll-while-open backstop and the winner push).
  private func persistOutcome(event: GiveawayEvent, response: GiveawayTapResponse) {
    let status: GiveawayParticipationStatus =
      response.isWinner
      ? .resolvedWon(submissionCompleted: false)
      : .resolvedLost(toastShown: false)
    $participations.withLock {
      // A push or backstop may have crowned this event while the POST was in flight; never let a
      // (losing) tap response downgrade an already-recorded win.
      if case .resolvedWon = $0[event.id]?.status { return }
      $0[event.id] = GiveawayParticipation(
        id: event.id, stationId: event.stationId, prizeName: event.prizeName,
        prizeDescription: event.prizeDescription, prizeImageUrl: event.prizeImageUrl,
        winningNumber: event.winningNumber, tapNumber: response.tapNumber, status: status,
        tappedAt: now)
    }
  }

  // MARK: - Reveal

  /// GET the authoritative event (reconciles open on demand) and publish it for the overlay.
  func revealEvent(jwt: String, eventId: String, expectedStationId: String) async {
    do {
      let event = try await api.giveawayEvent(jwt, eventId)
      guard currentPlayolaStationId == expectedStationId else {
        log("reveal: station changed before publish — skipping \(eventId)")
        return
      }
      $activeGiveaway.withLock { $0 = event }
      removeUpcomingEntry(stationId: event.stationId, revealedEventId: event.id)
      log("REVEALED \(eventId) status=\(event.status.rawValue)")
    } catch {
      log("reveal: GET \(eventId) failed — \(error)")
    }
  }

  /// Handle the feed having no event for the current station — happens transiently at the open
  /// transition AND permanently when a contest closes (closed events leave the feed). Never cancels
  /// an in-flight arm (it self-validates via GET at opensAt). Drops a stale cross-station event;
  /// confirms a same-station published event via GET and clears it only once it's no longer open.
  private func handleNoFeedEvent(jwt: String, stationId: String) async {
    log("reconcile: no feed event for current station — keeping any armed reveal")
    guard let active = activeGiveaway else { return }
    if active.stationId != stationId {
      $activeGiveaway.withLock { $0 = nil }
    } else {
      await clearActiveIfNoLongerOpen(jwt: jwt, event: active, stationId: stationId)
    }
  }

  /// A published event has dropped out of the feed. Confirm via the authoritative GET: keep it if
  /// it's still open (a transient feed gap at the open transition), clear it once it has closed.
  /// A transient GET failure keeps it (the next poll retries). On close, run the loss backstop so a
  /// last-tapper promotion is caught for the in-app user without waiting on the push.
  func clearActiveIfNoLongerOpen(jwt: String, event: GiveawayEvent, stationId: String) async {
    guard let fresh = try? await api.giveawayEvent(jwt, event.id) else { return }
    guard currentPlayolaStationId == stationId else { return }
    if fresh.status != .open {
      $activeGiveaway.withLock { $0 = nil }
      log("active event \(event.id) is now \(fresh.status.rawValue) → cleared")
      await reconcileResolvedLoss(jwt: jwt, eventId: event.id)
    }
  }

  /// Backstop for the last-tapper promotion: when a contest the user provisionally lost has closed,
  /// re-check `my-result` once and flip `.resolvedLost → .resolvedWon` if the server promoted them.
  /// No-op on a still-open contest, a confirmed loss, or a transient failure.
  func reconcileResolvedLoss(jwt: String, eventId: String) async {
    guard case .resolvedLost = participations[eventId]?.status else { return }
    guard let result = try? await api.giveawayEventMyResult(jwt, eventId) else { return }
    guard result.isResolved, result.isWinner else { return }
    $participations.withLock {
      // Re-check inside the lock: a push or a claim may have changed the state during the GET, and we
      // must not reset a now-won/claimed participation back to an unsubmitted win.
      guard case .resolvedLost = $0[eventId]?.status else { return }
      $0[eventId]?.status = .resolvedWon(submissionCompleted: false)
      if let tapNumber = result.tapNumber { $0[eventId]?.tapNumber = tapNumber }
    }
    log("backstop: \(eventId) promoted loss→win")
  }

  /// Foreground safety net for the promoted last-tapper when the live close-detection path didn't run
  /// (app was killed, the station changed, or `activeGiveaway` was already cleared). Re-checks each
  /// recent `.resolvedLost` once. Bounded by `lossReconcileWindow` so old losses aren't polled forever.
  func reconcileRecentResolvedLosses() async {
    guard let jwt = auth.jwt else { return }
    let losses = participations.values.filter {
      if case .resolvedLost = $0.status { return true }
      return false
    }
    guard !losses.isEmpty else { return }
    let cutoff = now.addingTimeInterval(-Self.lossReconcileWindow)
    let recentLossIds = losses.compactMap { $0.tappedAt >= cutoff ? $0.id : nil }
    for eventId in recentLossIds {
      await reconcileResolvedLoss(jwt: jwt, eventId: eventId)
    }
  }

  /// Among a station's events, pick the relevant one: an open one (reveal now), otherwise the
  /// soonest-opening scheduled one. A station can have several scheduled events at once (one per
  /// upcoming airing of the episode), so the order the feed returns them in is not meaningful.
  static func selectEvent(from stationEvents: [GiveawayEvent]) -> GiveawayEvent? {
    stationEvents.first(where: { $0.status == .open })
      ?? stationEvents
      .filter { $0.status == .scheduled }
      .min(by: { ($0.opensAt ?? .distantFuture) < ($1.opensAt ?? .distantFuture) })
  }

  /// Delay from response time until the skew-corrected open moment. Uses the server's own
  /// `(opensAt - serverTime)` delta, so device-clock skew is irrelevant; RTT-corrected by half.
  static func revealDelay(opensAt: Date, serverTime: Date, rtt: Duration) -> Duration {
    let untilOpen = Duration.seconds(opensAt.timeIntervalSince(serverTime)) - rtt / 2
    return untilOpen > .zero ? untilOpen : .zero
  }

  // MARK: - Private Helpers

  /// Reconcile the instant the now-playing station settles on a new value (de-duped by station id,
  /// since nowPlaying also changes per song), so the overlay appears promptly on tune-in.
  private func observeStationChanges() {
    guard cancellables.isEmpty else { return }
    $nowPlaying.publisher
      .sink { [weak self] _ in self?.nowPlayingChanged() }
      .store(in: &cancellables)
  }

  private func nowPlayingChanged() {
    let stationId = currentPlayolaStationId
    guard !hasObservedStation || stationId != lastObservedStationId else { return }
    hasObservedStation = true
    lastObservedStationId = stationId
    Task { await reconcile() }
  }

  private func armRevealIfNeeded(jwt: String, item: GiveawayEvent, stationId: String) {
    guard armedEventId != item.id else { return }
    cancelArmedReveal()
    armedEventId = item.id
    generation += 1
    let gen = generation
    revealTask = Task { [weak self] in
      await self?.armAndReveal(
        jwt: jwt, eventId: item.id, stationId: stationId, generation: gen)
    }
  }

  private func armAndReveal(jwt: String, eventId: String, stationId: String, generation gen: Int)
    async
  {
    let rttClock = ContinuousClock()
    let start = rttClock.now
    let event: GiveawayEvent
    do {
      event = try await api.giveawayEvent(jwt, eventId)
    } catch {
      // Transient detail-fetch failure: release the arm so the next feed poll can retry.
      if gen == generation { armedEventId = nil }
      log("arm: \(eventId) GET failed (\(error)) — released for retry")
      return
    }
    guard gen == generation else { return }  // superseded by a newer arm
    guard currentPlayolaStationId == stationId else {
      armedEventId = nil
      return
    }
    // The GET may have already reconciled to open (e.g. opensAt just passed) → reveal now.
    if event.status == .open {
      $activeGiveaway.withLock { $0 = event }
      removeUpcomingEntry(stationId: event.stationId, revealedEventId: event.id)
      armedEventId = nil
      log("arm: \(eventId) already open on GET → revealed now")
      return
    }
    guard let opensAt = event.opensAt, let serverTime = event.serverTime else {
      armedEventId = nil
      log("arm: \(eventId) missing opensAt/serverTime — cannot arm")
      return
    }
    let delay = Self.revealDelay(
      opensAt: opensAt, serverTime: serverTime, rtt: rttClock.now - start)
    log("arm: \(eventId) revealing in \(delay)")
    try? await clock.sleep(for: delay)
    guard gen == generation, currentPlayolaStationId == stationId else {
      log("arm: \(eventId) stale after sleep (gen/station changed) — skipping")
      return
    }
    // Reveal the button the instant we reach opensAt, straight from the event we already hold — no
    // confirming GET, whose round-trip would push the button several seconds past opensAt. The tap
    // opens the contest on-demand server-side, and the next feed poll converges authoritative state.
    revealFromHeldEvent(event, expectedStationId: stationId)
    armedEventId = nil
  }

  /// Publish a giveaway we already hold (flipped to `.open`) so the overlay shows the tap button with
  /// no network round-trip.
  func revealFromHeldEvent(_ event: GiveawayEvent, expectedStationId: String) {
    guard currentPlayolaStationId == expectedStationId else {
      log("reveal: station changed before publish — skipping \(event.id)")
      return
    }
    $activeGiveaway.withLock { $0 = event.openedCopy() }
    removeUpcomingEntry(stationId: event.stationId, revealedEventId: event.id)
    log("REVEALED \(event.id) from held event (no refresh)")
  }

  private func cancelArmedReveal() {
    revealTask?.cancel()
    revealTask = nil
    armedEventId = nil
    generation += 1
  }

  private func clearActiveAndArm() {
    cancelArmedReveal()
    $activeGiveaway.withLock { $0 = nil }
  }

  /// Project the full feed into the per-station "coming up" set: only `.scheduled` events, one entry
  /// per station (the soonest by `opensAt`). An open event is excluded here — it's owned by the tap
  /// overlay — so publishing from a fresh feed also drops a station whose event just opened or closed.
  private func publishUpcoming(from feed: [GiveawayEvent]) {
    let scheduled = feed.filter { $0.status == .scheduled }
    let soonestPerStation = Dictionary(grouping: scheduled, by: \.stationId)
      .compactMap { stationId, events -> UpcomingGiveawayInfo? in
        events.min(by: { ($0.opensAt ?? .distantFuture) < ($1.opensAt ?? .distantFuture) })
          .map { UpcomingGiveawayInfo(stationId: stationId, event: $0) }
      }
    $upcomingGiveaways.withLock { $0 = IdentifiedArray(uniqueElements: soonestPerStation) }
  }

  /// Drop a station's "coming up" entry the instant its event is revealed (open), so the badge/banner
  /// disappears without waiting up to 30s for the next poll. Only removes the entry if it still names
  /// the revealed event — a later scheduled event for the same station is re-derived by the next poll.
  private func removeUpcomingEntry(stationId: String, revealedEventId: String) {
    $upcomingGiveaways.withLock { upcoming in
      if upcoming[id: stationId]?.event.id == revealedEventId {
        upcoming[id: stationId] = nil
      }
    }
  }

  private var currentPlayolaStationId: String? {
    guard let anyStation = nowPlaying?.currentStation,
      case .playola(let station) = anyStation
    else { return nil }
    return station.id
  }

  private func log(_ message: String) {
    #if DEBUG
      print("[Giveaway] \(message)")
    #endif
  }
}
