//
//  APIMock.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//
import Foundation
import IdentifiedCollections
@testable import PlayolaRadio

class APIMock {
    enum MockError: Error {
        case runtimeError(String)
    }

    var getStationListsShouldSucceed = true
    var beforeAssertions: (() -> Void)? = nil

    init(getStationListsShouldSucceed: Bool = true) {
        self.getStationListsShouldSucceed = getStationListsShouldSucceed
    }

    func getStations() async throws -> IdentifiedArrayOf<StationList> {
        beforeAssertions?()
        if getStationListsShouldSucceed {
            return StationList.mocks
        } else {
            throw MockError.runtimeError("Some API Error")
        }
    }
}
