//
//  GenericApiClient.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Alamofire
import Foundation
import IdentifiedCollections
import Sharing

class GenericApiClient: Sendable {
  let stationsURL = URL(string: "\(Config.shared.baseUrl)/v1/developer/stationLists")!

  @Shared(.stationLists) var stationLists: IdentifiedArrayOf<StationList>
  @Shared(.stationListsLoaded) var stationListsLoaded: Bool
  @Shared(.auth) var auth: Auth
  @Shared(.currentUser) var currentUser: User?


  // Helper struct to get either local or remote JSON
  func getStations() async throws -> IdentifiedArrayOf<StationList> {
    // Create local copy to avoid repeated property access
    if stationListsLoaded {
      return stationLists
    }

    do {
      let stationLists = try await loadHttp()
      self.$stationLists.withLock { $0 = IdentifiedArrayOf(uniqueElements: stationLists) }
      self.$stationListsLoaded.withLock { $0 = true }
      return self.stationLists
    } catch {
      // Fall back to local
      let localStations = try await loadLocal()
      print("Error loading remote StationLists. Falling back to local version.")
      return IdentifiedArrayOf(uniqueElements: localStations)
    }
  }

  func signInViaApple(identityToken: String,
                      email: String,
                      authCode: String,
                      displayName: String?) async throws
  {
    var parameters: [String: any Any & Sendable] = [
      "identityToken": identityToken,
      "authCode": authCode,
      "email": email,
    ]
    if let displayName {
      parameters["displayName"] = displayName
    }

    let response = try await AF.request("\(Config.shared.baseUrl)/v1/auth/apple/mobile/signup",
                                      method: .post,
                                      parameters: parameters,
                                      encoding: JSONEncoding.default)
      .serializingDecodable(LoginResponse.self)
      .value

    self.$auth.withLock { $0 = Auth(jwtToken: response.playolaToken) }
  }

  func revokeAppleCredentials(appleUserId: String) async throws {
    let parameters: [String: any Any & Sendable] = ["appleUserId": appleUserId]

    _ = try await AF.request("\(Config.shared.baseUrl)/v1/auth/apple/revoke",
                            method: .put,
                            parameters: parameters,
                            encoding: JSONEncoding.default)
      .validate(statusCode: 200..<300)
      .serializingString()
      .value

    AuthService.shared.signOut()
    AuthService.shared.clearAppleUser()
  }

  func getUser(userId: String) async throws -> User {
    let baseUrl = Config.shared.baseUrl

    guard let token = auth.jwt else {
      throw APIError.invalidResponse
    }

    let headers: HTTPHeaders = [
      "Authorization": "Bearer \(token)"
    ]

    let response = try await AF.request("\(baseUrl)/v1/users/\(userId)",
                                        method: .get,
                                        headers: headers)
      .validate(statusCode: 200..<300)
      .serializingDecodable(User.self)
      .value

    return response
  }

  func signInViaGoogle(code: String) async throws {
    let parameters: [String: any Any & Sendable] = [
      "code": code,
      "originatesFromIOS": true,
    ]

    let response = try await AF.request("\(Config.shared.baseUrl)/v1/auth/google/signin",
                                      method: .post,
                                      parameters: parameters,
                                      encoding: JSONEncoding.default)
      .validate(statusCode: 200..<300)
      .serializingDecodable(LoginResponse.self)
      .value

    let newAuth = Auth(jwtToken: response.playolaToken)
    self.$auth.withLock { $0 = newAuth }
  }

  private func loadLocal() async throws -> [StationList] {
    let filePathURL = Bundle.main.url(forResource: "station_lists", withExtension: "json")
    guard let filePathURL else {
      throw DataError.fileNotFound
    }

    let data = try Data(contentsOf: filePathURL, options: .uncached)
    return try decodeStationLists(from: data)
  }

  private func loadHttp() async throws -> [StationList] {
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalCacheData

    let session = URLSession(configuration: config)

    let (data, response) = try await session.data(from: stationsURL)

    guard let httpResponse = response as? HTTPURLResponse,
          200 ... 299 ~= httpResponse.statusCode else {
      throw DataError.httpResponseNotValid
    }

    return try decodeStationLists(from: data)
  }

  private func decodeStationLists(from data: Data) throws -> [StationList] {
    let jsonDictionary = try JSONDecoder().decode([String: [StationList]].self, from: data)

    guard let stationLists = jsonDictionary["stationLists"] else {
      throw DataError.dataNotValid
    }

    return stationLists
  }

  enum DataError: Error {
    case urlNotValid, dataNotValid, dataNotFound, fileNotFound, httpResponseNotValid
  }

  enum APIError: Error {
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case serverError(Int)
  }

  struct LoginResponse: Decodable {
    let playolaToken: String
  }
}
