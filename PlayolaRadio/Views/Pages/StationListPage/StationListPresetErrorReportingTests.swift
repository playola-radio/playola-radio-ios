//
//  StationListPresetErrorReportingTests.swift
//  PlayolaRadio
//

import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer
import Sharing
import Testing

@testable import PlayolaRadio

@MainActor
struct StationListPresetErrorReportingTests {

  @Test
  func testStarTappedAddNetworkErrorIsNotReportedToSentry() async {
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = []

    let item = makePresetVisibleItem()
    let reportCount = LockIsolated(0)

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        throw NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
      }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, _ in reportCount.setValue(reportCount.value + 1) }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(reportCount.value == 0)
    #expect(pending.isEmpty)
    #expect(presets.isEmpty)
    #expect(model.presentedAlert == .errorSavingPreset(nil))
  }

  @Test
  func testStarTappedAddTagsReportedErrorWithDomainAndCode() async {
    @Shared(.auth) var auth = signedInAuth()
    @Shared(.presets) var presets: IdentifiedArrayOf<Preset> = []
    @Shared(.pendingPresetStationIds) var pending: Set<String> = []

    let item = makePresetVisibleItem()
    let reportedTags = LockIsolated<[String: String]>([:])

    let model = withDependencies {
      $0.api.createPreset = { _, _, _ in
        throw NSError(domain: "TestDomain", code: 42)
      }
      $0.analytics.track = { _ in }
      $0.errorReporting.reportError = { _, tags in reportedTags.setValue(tags) }
    } operation: {
      StationListModel()
    }

    await model.starTapped(for: item)

    #expect(reportedTags.value["endpoint"] == "POST /v1/presets")
    #expect(reportedTags.value["error_domain"] == "TestDomain")
    #expect(reportedTags.value["error_code"] == "42")
    #expect(reportedTags.value["station_id"] == item.anyStation.id)
  }
}
