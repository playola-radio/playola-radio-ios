//
//  WelcomeMessagePageModel.swift
//  PlayolaRadio
//
//  One-time welcome shown the first time an eligible user opens an artist station that has
//  a welcome-message recording. Plays the recording; progress and chip reveals are driven
//  by the recording's real duration. Then the station starts.
//

import Dependencies
import Foundation
import PlayolaPlayer
import Sharing
import SwiftUI

struct WelcomeMessageChip: Identifiable, Equatable {
  let id: String
  let systemImageName: String
  let text: String
  let revealAtFraction: Double
}

@MainActor
@Observable
class WelcomeMessagePageModel: ViewModel {

  // MARK: - Presentation Gate

  // Single gate shared by every play entry point (station list, home "For You").
  static func shouldPresent(
    for item: APIStationItem, eligible: Bool, alreadyShownThisSession: Bool
  ) -> Bool {
    guard eligible, !alreadyShownThisSession else { return false }
    guard item.welcomeMessageAudioBlockId != nil else { return false }
    if case .playola = item.anyStation { return true }
    return false
  }

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.audioPlayer) var audioPlayer
  @ObservationIgnored @Dependency(\.analytics) var analytics
  @ObservationIgnored @Dependency(\.stationPlayer) var stationPlayer

  // MARK: - Shared State

  @ObservationIgnored @Shared(.auth) var auth

  // MARK: - Initialization

  let station: AnyStation

  init(station: AnyStation) {
    self.station = station
    super.init()
  }

  // MARK: - Properties

  // Three chips spaced equidistant along the recording.
  let chips: [WelcomeMessageChip] = [
    WelcomeMessageChip(
      id: "songs", systemImageName: "music.note",
      text: "Hand-Picked Every Song", revealAtFraction: 0.25),
    WelcomeMessageChip(
      id: "stories", systemImageName: "mic.fill",
      text: "Recorded All the Stories", revealAtFraction: 0.5),
    WelcomeMessageChip(
      id: "live", systemImageName: "antenna.radiowaves.left.and.right",
      text: "Sometimes Broadcasts Live", revealAtFraction: 0.75),
  ]

  var playbackState: PlaybackState = .idle
  var isComplete = false
  var schedule: Schedule?
  @ObservationIgnored private var playbackSession: PlaybackSession?
  @ObservationIgnored private var hasStartedPlaying = false
  @ObservationIgnored private var isStartingStation = false

  // MARK: - User Actions

  func task() async {
    // Take over playback the moment the welcome appears. Stopping any station that's
    // already playing prevents its audio from overlapping the welcome recording, and
    // clears currentStation so the later startStation() play() isn't a no-op (which would
    // skip the .startingNewStation that dismisses this sheet).
    stationPlayer.stop()
    async let scheduleLoad: Void = loadSchedule()
    await playWelcomeRecording()
    await scheduleLoad
  }

  private func playWelcomeRecording() async {
    guard let jwt = auth.jwt else {
      await startStation()
      return
    }

    let downloadUrl: URL?
    do {
      downloadUrl = try await api.getStationWelcomeMessage(jwt, station.id)?.downloadUrl
    } catch {
      // Best-effort: a failed fetch falls back to starting the station directly. Log so an API
      // regression stays visible rather than silently dropping the error.
      print("WelcomeMessagePageModel: getStationWelcomeMessage failed — \(error)")
      downloadUrl = nil
    }

    // The user may have tapped Skip while the recording was being fetched — the station is
    // already starting, so don't begin welcome playback over it.
    guard !isStartingStation else { return }

    guard let downloadUrl else {
      await startStation()
      return
    }

    do {
      let session = try await audioPlayer.startPlayback(downloadUrl) { [weak self] state in
        self?.playbackStateChanged(state)
      }
      guard !isStartingStation else {
        await session.stop()
        session.cancel()
        return
      }
      playbackSession = session
      reportSeen(jwt: jwt)
    } catch {
      await startStation()
    }
  }

  func skipButtonTapped() async {
    await startStation()
  }

  func primaryButtonTapped() async {
    await startStation()
  }

  func viewDisappeared() {
    let session = playbackSession
    playbackSession = nil
    Task {
      await session?.stop()
      session?.cancel()
    }
  }

  // MARK: - View Helpers

  var curatorName: String { station.name }
  var personalDJLabel: String { "IS YOUR PERSONAL DJ" }
  var imageURL: URL? { station.imageUrl }

  var progress: Double { isComplete ? 1 : playbackState.progress }

  func isChipRevealed(_ chip: WelcomeMessageChip) -> Bool {
    progress >= chip.revealAtFraction
  }

  func chipOpacity(_ chip: WelcomeMessageChip) -> Double {
    isChipRevealed(chip) ? 1 : 0
  }

  func chipOffset(_ chip: WelcomeMessageChip) -> CGFloat {
    isChipRevealed(chip) ? 0 : 10
  }

  // Chips hand off to the "Now playing" card once the message wraps.
  var chipStackOpacity: Double { isComplete ? 0 : 1 }
  var nowPlayingCardOpacity: Double { isComplete ? 1 : 0 }
  var nowPlayingCardLabel: String { "NOW PLAYING" }

  // Best-effort preview of what's airing on the station now, derived live from the
  // fetched schedule + the current clock (the station itself isn't playing yet). Falls
  // back to the station/curator when there's no schedule or nothing is airing.
  var nowPlayingSpin: Spin? { schedule?.nowPlaying() }

  var nowPlayingCardTitle: String {
    guard let audioBlock = nowPlayingSpin?.audioBlock else { return station.stationName }
    if audioBlock.type == "commercial" { return "Playola Pays" }
    if audioBlock.type == "song" { return audioBlock.title }
    return nowPlayingSpin?.airing?.episode?.title ?? station.stationName
  }

  var nowPlayingCardSubtitle: String {
    guard let audioBlock = nowPlayingSpin?.audioBlock, audioBlock.type == "song" else {
      return "with \(station.name)"
    }
    return audioBlock.artist
  }

  var equalizerOpacity: Double { isComplete ? 0 : 1 }

  var skipButtonTitle: String { "Skip" }
  var skipButtonOpacity: Double { isComplete ? 0 : 1 }

  var primaryButtonTitle: String { "Start Listening" }
  var isPrimaryButtonEnabled: Bool { isComplete }
  var primaryButtonBackground: Color { isComplete ? .playolaRed : Color(hex: "#2A1313") }
  var primaryButtonForeground: Color { isComplete ? .white : .white.opacity(0.35) }
  var primaryButtonGlowOpacity: Double { isComplete ? 0.5 : 0 }

  // MARK: - Private Helpers

  private func loadSchedule() async {
    do {
      let spins = try await api.fetchSchedule(station.id, false)
      guard !isStartingStation else { return }
      schedule = Schedule(
        stationId: station.id, spins: spins, dateProvider: DependencyDateProvider())
    } catch {
      // Best-effort: the schedule only feeds the optional Now Playing card. Log so an API
      // regression stays visible rather than silently dropping the error.
      print("WelcomeMessagePageModel: loadSchedule failed — \(error)")
    }
  }

  private func playbackStateChanged(_ state: PlaybackState) {
    playbackState = state
    if state.isPlaying {
      hasStartedPlaying = true
    }
    // Completion needs near-the-end progress, not just isPlaying == false — a buffering
    // stall mid-recording also reports not-playing and must not end the welcome early.
    // While playing, only true end-of-file (>= 0.995) completes. Once playback stops, the
    // engine often halts a hair early, so a lower threshold (>= 0.97) still counts as done.
    guard hasStartedPlaying, !isComplete else { return }
    if state.progress >= 0.995 || (!state.isPlaying && state.progress >= 0.97) {
      isComplete = true
    }
  }

  // Server-stamps "seen" only once the recording is actually playing — a failed fetch or
  // playback fallback must NOT burn the user's one welcome. Unstructured Task so sheet
  // dismissal can't cancel the write mid-flight.
  private func reportSeen(jwt: String) {
    let api = api
    let stationId = station.id
    Task.detached {
      do {
        try await api.markWelcomeMessageSeen(jwt, stationId)
      } catch {
        // A failed write means the user may see the welcome again next session. Log so the
        // regression stays visible rather than silently dropping the error.
        print("WelcomeMessagePageModel: markWelcomeMessageSeen failed — \(error)")
      }
    }
  }

  private func startStation() async {
    guard !isStartingStation else { return }
    isStartingStation = true
    await playbackSession?.stop()
    playbackSession?.cancel()
    playbackSession = nil
    await analytics.track(
      .startedStation(station: StationInfo(from: station), entryPoint: "welcome_message"))
    await stationPlayer.play(station: station)
  }
}
