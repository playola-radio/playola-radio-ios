//
//  ConfigTests.swift
//  PlayolaRadio
//

import CustomDump
import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ConfigTests {
  @Test func localBaseUrlDefaultsToStandardLocalServerWhenBuildSettingIsUnset() {
    expectNoDifference(Config.localBaseUrl(override: nil), URL(string: "http://localhost:10020")!)
  }

  @Test func localBaseUrlDefaultsToStandardLocalServerWhenBuildSettingIsEmpty() {
    expectNoDifference(Config.localBaseUrl(override: ""), URL(string: "http://localhost:10020")!)
  }

  @Test func localBaseUrlUsesBuildSettingWhenSet() {
    expectNoDifference(
      Config.localBaseUrl(override: "http://localhost:10070"),
      URL(string: "http://localhost:10070")!)
  }

  @Test func localBaseUrlIgnoresBuildSettingThatIsNotOnThisMachine() {
    expectNoDifference(
      Config.localBaseUrl(override: "https://admin-api.playola.fm"),
      URL(string: "http://localhost:10020")!)
  }
}
