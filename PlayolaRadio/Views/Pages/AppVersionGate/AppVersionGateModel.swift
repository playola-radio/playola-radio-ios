//
//  AppVersionGateModel.swift
//  PlayolaRadio
//
//  Owns the "Update Required" forced-upgrade gate: it decides whether the
//  running build is too old to continue, drives the blocking alert, and
//  instruments the gate so we can measure whether users update or abandon.
//

import Dependencies
import Foundation
import Sharing
import SwiftUI

@MainActor
@Observable
class AppVersionGateModel: ViewModel {

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.api) var api
  @ObservationIgnored @Dependency(\.analytics) var analytics

  // MARK: - Shared State

  @ObservationIgnored @Shared(.appVersionRequirements) var appVersionRequirements
  @ObservationIgnored @Shared(.isBroadcaster) var isBroadcaster

  // MARK: - Properties

  var requiresUpdate = false

  /// The versions the currently-shown gate was presented with, so the
  /// "Update Tapped" event reports the same required_version as its "Shown"
  /// event (rather than re-deriving it and mislabeling broadcaster gates).
  private var activeGate: (currentVersion: String, requiredVersion: String)?

  // MARK: - Display Text

  let alertTitle = "Update Required"
  let alertMessage = "A new version of Playola Radio is available. Please update to continue."
  let updateButtonTitle = "Update"
  let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id6480465361")!

  // MARK: - User Actions

  func checkVersionRequirements() async {
    do {
      let requirements = try await api.getAppVersionRequirements()
      $appVersionRequirements.withLock { $0 = requirements }

      guard let currentVersion = Bundle.main.releaseVersionNumber else { return }

      if isVersion(currentVersion, lessThan: requirements.minimumVersion) {
        await presentUpdateGate(
          currentVersion: currentVersion,
          requiredVersion: requirements.minimumVersion,
          trigger: .minimumVersion)
        return
      }

      if isBroadcaster,
        isVersion(currentVersion, lessThan: requirements.minimumBroadcasterVersion)
      {
        await presentUpdateGate(
          currentVersion: currentVersion,
          requiredVersion: requirements.minimumBroadcasterVersion,
          trigger: .broadcaster)
        return
      }
    } catch {
      // Network failure → fail open (allow app)
    }
  }

  /// Invoked when another part of the app discovers mid-session that the user is
  /// a broadcaster on a too-old build (via the `.requiresAppUpdate` notification).
  func broadcasterUpdateDiscovered() async {
    let currentVersion = Bundle.main.releaseVersionNumber ?? ""
    let requiredVersion = appVersionRequirements?.minimumBroadcasterVersion ?? currentVersion
    await presentUpdateGate(
      currentVersion: currentVersion,
      requiredVersion: requiredVersion,
      trigger: .broadcasterDiscovered)
  }

  /// Tracks the tap. The caller (the view) must `await` this before opening the
  /// App Store, so the event is enqueued before the app is backgrounded and lost.
  func updateButtonTapped() async {
    let currentVersion = activeGate?.currentVersion ?? Bundle.main.releaseVersionNumber ?? ""
    let requiredVersion =
      activeGate?.requiredVersion ?? appVersionRequirements?.minimumVersion ?? ""
    await analytics.track(
      .updateGateUpdateTapped(currentVersion: currentVersion, requiredVersion: requiredVersion))
  }

  // MARK: - Private Helpers

  private func presentUpdateGate(
    currentVersion: String,
    requiredVersion: String,
    trigger: UpdateGateTrigger
  ) async {
    // Only track on the false → true transition so repeated launches/notifications
    // for an already-shown gate don't inflate "shown" counts.
    guard !requiresUpdate else { return }
    requiresUpdate = true
    activeGate = (currentVersion, requiredVersion)
    await analytics.track(
      .updateGateShown(
        currentVersion: currentVersion,
        requiredVersion: requiredVersion,
        trigger: trigger))
  }
}
