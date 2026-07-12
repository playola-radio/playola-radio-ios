//
//  AppVersionGateModelTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import Dependencies
import Foundation
import Sharing
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct AppVersionGateModelTests {

  // A version far above any real build so the running bundle always compares as "too old".
  private let unreachableVersion = "999.0.0"
  // A version below any real build so the running bundle is always "up to date".
  private let ancientVersion = "0.0.1"

  private func gateShownEvents(_ events: [AnalyticsEvent]) -> [AnalyticsEvent] {
    events.filter { if case .updateGateShown = $0 { return true } else { return false } }
  }

  @Test
  func testShowsGateAndTracksWhenBelowMinimumVersion() async {
    @Shared(.isBroadcaster) var isBroadcaster = false
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.getAppVersionRequirements = { [unreachableVersion, ancientVersion] in
        AppVersionRequirements(
          minimumVersion: unreachableVersion, minimumBroadcasterVersion: ancientVersion)
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.checkVersionRequirements()

      #expect(model.presentedAlert != nil)
      let shown = gateShownEvents(captured.value)
      #expect(shown.count == 1)
      #expect(
        shown.first
          == .updateGateShown(
            currentVersion: Bundle.main.releaseVersionNumber ?? "",
            requiredVersion: unreachableVersion,
            trigger: .minimumVersion))
    }
  }

  @Test
  func testDoesNotShowGateWhenVersionIsCurrent() async {
    @Shared(.isBroadcaster) var isBroadcaster = true
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.getAppVersionRequirements = { [ancientVersion] in
        AppVersionRequirements(
          minimumVersion: ancientVersion, minimumBroadcasterVersion: ancientVersion)
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.checkVersionRequirements()

      #expect(model.presentedAlert == nil)
      #expect(gateShownEvents(captured.value).isEmpty)
    }
  }

  @Test
  func testShowsBroadcasterGateWhenBroadcasterIsBelowBroadcasterMinimum() async {
    @Shared(.isBroadcaster) var isBroadcaster = true
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.getAppVersionRequirements = { [ancientVersion, unreachableVersion] in
        AppVersionRequirements(
          minimumVersion: ancientVersion, minimumBroadcasterVersion: unreachableVersion)
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.checkVersionRequirements()

      #expect(model.presentedAlert != nil)
      let shown = gateShownEvents(captured.value)
      #expect(shown.count == 1)
      #expect(
        shown.first
          == .updateGateShown(
            currentVersion: Bundle.main.releaseVersionNumber ?? "",
            requiredVersion: unreachableVersion,
            trigger: .broadcaster))
    }
  }

  @Test
  func testNonBroadcasterIsNotGatedByBroadcasterMinimum() async {
    @Shared(.isBroadcaster) var isBroadcaster = false
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.getAppVersionRequirements = { [ancientVersion, unreachableVersion] in
        AppVersionRequirements(
          minimumVersion: ancientVersion, minimumBroadcasterVersion: unreachableVersion)
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.checkVersionRequirements()

      #expect(model.presentedAlert == nil)
      #expect(gateShownEvents(captured.value).isEmpty)
    }
  }

  @Test
  func testNetworkFailureFailsOpenAndTracksNothing() async {
    @Shared(.isBroadcaster) var isBroadcaster = true
    let captured = LockIsolated<[AnalyticsEvent]>([])

    struct RequirementsError: Error {}

    await withDependencies {
      $0.api.getAppVersionRequirements = { throw RequirementsError() }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.checkVersionRequirements()

      #expect(model.presentedAlert == nil)
      #expect(captured.value.isEmpty)
    }
  }

  @Test
  func testBroadcasterDiscoveredNotificationShowsGateAndTracks() async {
    @Shared(.appVersionRequirements) var appVersionRequirements = AppVersionRequirements(
      minimumVersion: "1.0.0", minimumBroadcasterVersion: "9.9.9")
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.broadcasterUpdateDiscovered()

      #expect(model.presentedAlert != nil)
      let shown = gateShownEvents(captured.value)
      #expect(shown.count == 1)
      #expect(
        shown.first
          == .updateGateShown(
            currentVersion: Bundle.main.releaseVersionNumber ?? "",
            requiredVersion: "9.9.9",
            trigger: .broadcasterDiscovered))
    }
  }

  @Test
  func testBroadcasterDiscoveredWithoutRequirementsReportsEmptyRequiredVersion() async {
    // Requirements not loaded (fresh empty store): the gate still blocks, but must
    // not masquerade the current build as the required version.
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.broadcasterUpdateDiscovered()

      #expect(model.presentedAlert != nil)
      #expect(
        gateShownEvents(captured.value).first
          == .updateGateShown(
            currentVersion: Bundle.main.releaseVersionNumber ?? "",
            requiredVersion: "",
            trigger: .broadcasterDiscovered))
    }
  }

  @Test
  func testUpdateTappedReusesShownGateRequiredVersion() async {
    // A broadcaster gate is shown with the broadcaster minimum; the tap event must
    // report that same required_version, not the general minimumVersion.
    @Shared(.isBroadcaster) var isBroadcaster = true
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.api.getAppVersionRequirements = { [ancientVersion, unreachableVersion] in
        AppVersionRequirements(
          minimumVersion: ancientVersion, minimumBroadcasterVersion: unreachableVersion)
      }
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.checkVersionRequirements()
      await model.updateButtonTapped()

      #expect(
        captured.value.contains(
          .updateGateUpdateTapped(
            currentVersion: Bundle.main.releaseVersionNumber ?? "",
            requiredVersion: unreachableVersion)))
    }
  }

  @Test
  func testDuplicatePresentDoesNotDoubleTrackShown() async {
    @Shared(.appVersionRequirements) var appVersionRequirements = AppVersionRequirements(
      minimumVersion: "1.0.0", minimumBroadcasterVersion: "9.9.9")
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.broadcasterUpdateDiscovered()
      await model.broadcasterUpdateDiscovered()

      #expect(model.presentedAlert != nil)
      #expect(gateShownEvents(captured.value).count == 1)
    }
  }

  @Test
  func testUpdateButtonTappedTracksEvent() async {
    @Shared(.appVersionRequirements) var appVersionRequirements = AppVersionRequirements(
      minimumVersion: "1.2.3", minimumBroadcasterVersion: "1.2.3")
    let captured = LockIsolated<[AnalyticsEvent]>([])

    await withDependencies {
      $0.analytics.track = { event in captured.withValue { $0.append(event) } }
    } operation: {
      let model = AppVersionGateModel()
      await model.updateButtonTapped()

      #expect(
        captured.value == [
          .updateGateUpdateTapped(
            currentVersion: Bundle.main.releaseVersionNumber ?? "",
            requiredVersion: "1.2.3")
        ])
    }
  }
}
