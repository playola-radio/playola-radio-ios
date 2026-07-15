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
import UIKit

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

  var presentedAlert: PlayolaAlert?

  private let alertTitle = "Update Required"
  private let alertMessage =
    "A new version of Playola Radio is available. Please update to continue."
  private let updateButtonTitle = "Update"
  private let appStoreURL = URL(string: "itms-apps://itunes.apple.com/app/id6480465361")!

  /// The versions the currently-shown gate was presented with, so the
  /// "Update Tapped" event reports the same required_version as its "Shown"
  /// event (rather than re-deriving it and mislabeling broadcaster gates).
  @ObservationIgnored private var activeGate: (currentVersion: String, requiredVersion: String)?

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
    // If requirements haven't loaded yet, report an empty (unknown) required
    // version rather than the current build, which would be a nonsensical
    // "required version" in the analytics.
    let requiredVersion = appVersionRequirements?.minimumBroadcasterVersion ?? ""
    await presentUpdateGate(
      currentVersion: currentVersion,
      requiredVersion: requiredVersion,
      trigger: .broadcasterDiscovered)
  }

  /// Re-presents the gate when the app returns to the foreground. Tapping "Update"
  /// dismisses the alert (SwiftUI clears `presentedAlert`) and opens the App Store, but
  /// `UIApplication.open` returns immediately rather than waiting for the user to come
  /// back, and `checkVersionRequirements()` only runs on cold launch. Without this, a
  /// user who taps "Update" and returns without updating could keep using an unsupported
  /// build. Reuses the existing `activeGate`, so it does not re-track a "shown" event.
  func scenePhaseChanged(newPhase: ScenePhase) {
    guard newPhase == .active, activeGate != nil, presentedAlert == nil else { return }
    presentedAlert = makeUpdateRequiredAlert()
  }

  /// Tracks the tap. Called from the alert action before opening the App Store,
  /// so the event is enqueued before the app is backgrounded and the event lost.
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
    // Only present/track on the not-shown → shown transition so repeated launches
    // or notifications for an already-shown gate don't inflate "shown" counts.
    guard presentedAlert == nil else { return }
    activeGate = (currentVersion, requiredVersion)
    presentedAlert = makeUpdateRequiredAlert()
    await analytics.track(
      .updateGateShown(
        currentVersion: currentVersion,
        requiredVersion: requiredVersion,
        trigger: trigger))
  }

  private func makeUpdateRequiredAlert() -> PlayolaAlert {
    PlayolaAlert(
      title: alertTitle,
      message: alertMessage,
      primaryButtonText: updateButtonTitle,
      primaryAction: { [weak self] in
        guard let self else { return }
        await self.updateButtonTapped()
        let opened = await UIApplication.shared.open(self.appStoreURL)
        // Normally the App Store foregrounds and `scenePhaseChanged` re-blocks on
        // return. If it fails to open there is no foreground transition to re-block on,
        // and the app is still active (no background race), so re-present immediately
        // rather than let a too-old build slip through the dismissed gate.
        if !opened {
          self.presentedAlert = self.makeUpdateRequiredAlert()
        }
      })
  }
}
