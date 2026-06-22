import Combine
import Dependencies
import Foundation
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

  #if DEBUG
    /// Event id the player's debug injector uses; tapping it flips to standby locally (no POST).
    static let debugInjectedEventId = "debug-event"
  #endif

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
        try? await self.clock.sleep(for: Self.feedPollInterval)
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
  }

  // MARK: - Reconcile

  func reconcile() async {
    guard let jwt = auth.jwt else {
      log("reconcile: no auth jwt — clearing")
      clearActiveAndArm()
      return
    }
    guard let stationId = currentPlayolaStationId else {
      log("reconcile: not on a Playola station — clearing")
      clearActiveAndArm()
      return
    }
    let feed: [GiveawayEvent]
    do {
      feed = try await api.giveawayEventsFeed(jwt)
    } catch {
      log("reconcile: feed FETCH FAILED (\(error)) — keeping last state")
      return  // transient failure: keep last known state, retry next poll
    }
    log(
      "reconcile: feed=\(feed.map { "\($0.stationId.prefix(8)):\($0.status.rawValue)" }) "
        + "playing=\(stationId.prefix(8))")
    guard currentPlayolaStationId == stationId else { return }
    guard let item = feed.first(where: { $0.stationId == stationId }) else {
      log("reconcile: no feed event for current station — clearing")
      clearActiveAndArm()
      return
    }
    log(
      "reconcile: matched \(item.id) status=\(item.status.rawValue) opensAt=\(item.opensAt?.description ?? "nil")"
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

  /// Tap into a giveaway. Persists a standby participation (keyed by the per-airing event id) the
  /// instant the POST returns, so the reveal survives an app kill. One tap per event.
  func tap(event: GiveawayEvent) async {
    guard let jwt = auth.jwt else { return }
    guard participations[event.id] == nil, !inFlightTapIds.contains(event.id) else { return }
    inFlightTapIds.insert(event.id)
    defer { inFlightTapIds.remove(event.id) }
    #if DEBUG
      if event.id == Self.debugInjectedEventId {
        persistStandby(event: event, tapNumber: 7)
        return
      }
    #endif
    do {
      let response = try await api.tapGiveawayEvent(jwt, event.id)
      persistStandby(event: event, tapNumber: response.tapNumber)
    } catch {
      // 400 (not open yet) / network: no participation written; the user can tap again.
    }
  }

  private func persistStandby(event: GiveawayEvent, tapNumber: Int) {
    $participations.withLock {
      $0[event.id] = GiveawayParticipation(
        id: event.id, stationId: event.stationId, prizeName: event.prizeName,
        prizeDescription: event.prizeDescription, prizeImageUrl: event.prizeImageUrl,
        winningNumber: event.winningNumber, tapNumber: tapNumber, status: .tappedStandby,
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
      log("REVEALED \(eventId) status=\(event.status.rawValue)")
    } catch {
      log("reveal: GET \(eventId) failed — \(error)")
    }
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
      return
    }
    guard gen == generation, currentPlayolaStationId == stationId else { return }
    // The GET may have already reconciled to open (e.g. opensAt just passed) → reveal now.
    if event.status == .open {
      $activeGiveaway.withLock { $0 = event }
      armedEventId = nil
      log("arm: \(eventId) already open on GET → revealed now")
      return
    }
    guard let opensAt = event.opensAt, let serverTime = event.serverTime else {
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
    await revealEvent(jwt: jwt, eventId: eventId, expectedStationId: stationId)
    armedEventId = nil
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
