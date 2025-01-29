//
//  APIClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import ComposableArchitecture
import Foundation

struct APIClient {
    var getStationLists: @Sendable () async throws -> [StationList] = { [] }
}

// extension APIClient: DependencyKey {
//  static let api = API()
//  static var liveValue: APIClient {
//    return APIClient {
//      return try await api.getStations()
//    }
//  }
//
//  static var previewValue: APIClient {
//    return Self {
//      return try await api.getStations()
//    }
//  }
//
//  static var testValue: APIClient {
//    return Self {
//      return StationList.mocks
//    }
//  }
// }
//
// extension DependencyValues {
//  var apiClient: APIClient {
//    get { self[APIClient.self] }
//    set { self [APIClient.self] = newValue }
//  }
// }
