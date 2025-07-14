//
//  APIMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//
import Foundation
import IdentifiedCollections
@testable import PlayolaRadio

class APIMock: API {
  enum MockError: Error {
    case runtimeError(String)
  }
  
  var getStationListsShouldSucceed = true
  var getStationListsCallCount = 0
  var beforeAssertions: (() -> Void)?
  
  init(getStationListsShouldSucceed: Bool = true) {
    self.getStationListsShouldSucceed = getStationListsShouldSucceed
  }
  
  override func getStations() async throws -> IdentifiedArrayOf<StationList> {
    beforeAssertions?()
    getStationListsCallCount += 1
    if getStationListsShouldSucceed {
      return StationList.mocks
    } else {
      throw MockError.runtimeError("Some API Error")
    }
  }
}
