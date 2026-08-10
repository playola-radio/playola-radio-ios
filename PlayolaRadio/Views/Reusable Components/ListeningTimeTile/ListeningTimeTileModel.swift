//
//  ListeningTimeTileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Combine
import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class ListeningTimeTileModel: ViewModel {
  @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
  @ObservationIgnored @Dependency(\.continuousClock) var clock

  var totalListeningTime: Int = 0

  var buttonText: String?
  var buttonAction: (() async -> Void)?

  init(buttonText: String? = nil, buttonAction: (() async -> Void)? = nil) {
    self.buttonText = buttonText
    self.buttonAction = buttonAction
    super.init()
  }

  private var hourString: String {
    let totalSeconds = totalListeningTime / 1000
    let hours = totalSeconds / 3600
    return String(format: "%02d", hours)
  }

  private var minString: String {
    let totalSeconds = totalListeningTime / 1000
    let minutes = (totalSeconds % 3600) / 60
    return String(format: "%02d", minutes)
  }

  private var secString: String {
    let totalSeconds = totalListeningTime / 1000
    let seconds = totalSeconds % 60
    return String(format: "%02d", seconds)
  }

  var listeningTimeDisplayString: String {
    return "\(hourString)h \(minString)m \(secString)s"
  }

  var titleText: String { "Listening Time" }

  /// Non-nil only for the koozie-only cohort. When present, the tile renders the koozie
  /// sections instead of the legacy "Redeem Your Rewards!" button.
  private(set) var koozieTileModel: KoozieTileModel?

  /// Legacy button shows only when there is no koozie tile and a button was configured.
  var showsLegacyButton: Bool { koozieTileModel == nil && buttonText != nil }

  /// Creates or tears down the koozie sub-model to match the current cohort. Cheap and
  /// idempotent — safe to call on appear and each refresh tick.
  func refreshFromTracker() {
    let isKoozie = listeningTracker?.rewardsProfile.rewardsExperienceType == .koozieOnly
    if isKoozie, koozieTileModel == nil {
      koozieTileModel = KoozieTileModel()
    } else if !isKoozie, koozieTileModel != nil {
      koozieTileModel = nil
    }
  }

  private var refreshTask: Task<Void, Never>?

  func viewAppeared() {
    refreshFromTracker()
    refreshTask?.cancel()
    refreshTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        let ms = self.listeningTracker?.totalListenTimeMS ?? 0
        self.totalListeningTime = ms
        self.refreshFromTracker()
        if let koozie = self.koozieTileModel {
          koozie.liveTotalMS = ms
          koozie.startTiersLoadIfNeeded()  // one-shot, decoupled — never stalls this counter
        }
        try? await self.clock.sleep(for: .seconds(1))
      }
    }
  }

  func onButtonTapped() async {
    await buttonAction?()
  }

  func viewDisappeared() {
    refreshTask?.cancel()
    refreshTask = nil
  }
}
