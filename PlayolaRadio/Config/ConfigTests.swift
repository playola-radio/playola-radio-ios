//
//  ConfigTests.swift
//  PlayolaRadio
//

import Foundation
import Testing

@testable import PlayolaRadio

@Suite(.freshSharedState)
@MainActor
struct ConfigTests {
  @Test func localBaseUrlDefaultsToStandardLocalServerWhenBuildSettingIsUnset() {
    #expect(Config.localBaseUrl(override: nil) == URL(string: "http://localhost:10020")!)
  }

  @Test func localBaseUrlDefaultsToStandardLocalServerWhenBuildSettingIsEmpty() {
    #expect(Config.localBaseUrl(override: "") == URL(string: "http://localhost:10020")!)
  }

  @Test func localBaseUrlUsesBuildSettingWhenSet() {
    #expect(
      Config.localBaseUrl(override: "http://localhost:10070")
        == URL(string: "http://localhost:10070")!)
  }

  @Test func localBaseUrlIgnoresBuildSettingThatIsNotOnThisMachine() {
    #expect(
      Config.localBaseUrl(override: "https://admin-api.playola.fm")
        == URL(string: "http://localhost:10020")!)
  }
}
