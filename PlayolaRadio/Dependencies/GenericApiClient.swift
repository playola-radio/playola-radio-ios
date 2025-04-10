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
import PlayolaPlayer
import Dependencies

struct GenericApiClient : Sendable {
  var getStations: @Sendable () async throws -> IdentifiedArrayOf<StationList>
  var signInViaApple: @Sendable (_ identityToken: String,
                       _ email: String,
                       _ authCode: String,
                       _ displayName: String?) async throws -> Auth
  var revokeAppleCredentials: @Sendable (_ appleUserId: String) async throws -> Void
  var signInViaGoogle: @Sendable (_ code: String) async throws -> Auth
  var getUser: @Sendable (_ userId: String, _ auth: Auth) async throws -> User
  var fetchUserStations: @Sendable(_ userId: String, _ auth: Auth) async throws -> [PlayolaPlayer.Station]
  var fetchSchedule: @Sendable(_ stationId: String, _ extended: Bool, _ auth: Auth) async throws -> Schedule

  // Helper Functions
  static let playolaBaseUrl = "https://admin-api.playola.fm/v1"

  static private func mapToAPIError(_ error: Error) -> APIError {
    if let afError = error as? AFError {
      switch afError {
      case .sessionTaskFailed(let error):
        return .networkError(error)
      case .responseSerializationFailed(let reason):
        if case .decodingFailed(let error) = reason {
          return .decodingError(error)
        }
        return .decodingError(afError)
      case .responseValidationFailed(let reason):
        if case .unacceptableStatusCode(let code) = reason, code >= 400 {
          return .serverError(code)
        }
        return .invalidResponse
      default:
        return .other(afError)
      }
    }
    return .other(error)
  }

  static func headers(auth: Auth?) -> HTTPHeaders {
    var headers: HTTPHeaders = [
      "Content-Type": "application/json",
      "Accept": "application/json"
    ]
    if let jwt = auth?.jwt {
      headers.add(name: "Authorization", value: "Bearer \(jwt)")
    }
    return headers
  }
}

extension GenericApiClient: DependencyKey {
  // MARK: - Private Helper Methods

  /// Perform a network request and decode the response using Alamofire's native async/await support
  /// - Parameters:
  ///   - urlString: The URL string for the API endpoint
  ///   - method: The HTTP method to use
  ///   - parameters: Optional query parameters
  ///   - auth: Authentication details for the request
  ///   - encoding: Parameter encoding (defaults to URLEncoding.default)
  /// - Returns: Decoded object of specified type
  private static func performRequest<T: Decodable & Sendable>(
    urlString: String,
    method: HTTPMethod,
    parameters: Parameters? = nil,
    auth: Auth? = nil,
    encoding: ParameterEncoding = URLEncoding.default
  ) async throws -> T {
    // Use Alamofire's native async API
    let decoder = JSONDecoderWithIsoFull()

    let response = try await AF.request(
      urlString,
      method: method,
      parameters: parameters,
      encoding: encoding,
      headers: headers(auth: auth)
    )
      .validate(statusCode: 200..<300)
      .serializingDecodable(T.self, decoder: decoder)
      .value

    return response
  }

  static var liveValue: Self {
    let stationsUrlStr: String = "\(Config.shared.baseUrl)/v1/developer/stationLists"

    return Self {
      try await performRequest(urlString: stationsUrlStr, method: .get)
    } signInViaApple: { identityToken, email, authCode, displayName in
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
      return Auth(jwtToken: response.playolaToken)

    } revokeAppleCredentials: { appleUserId in
      let parameters: [String: any Any & Sendable] = ["appleUserId": appleUserId]

      _ = try await AF.request("\(Config.shared.baseUrl)/v1/auth/apple/revoke",
                               method: .put,
                               parameters: parameters,
                               encoding: JSONEncoding.default)
      .validate(statusCode: 200..<300)
      .serializingString()
      .value
    } signInViaGoogle: { code in
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

      return Auth(jwtToken: response.playolaToken)
    } getUser: { userId, auth in
      let baseUrl = Config.shared.baseUrl

      guard let token = auth.jwt else {
        throw APIError.invalidResponse
      }

      let headers: HTTPHeaders = [
        "Authorization": "Bearer \(token)"
      ]

      return try await AF.request("\(baseUrl)/v1/users/\(userId)",
                                  method: .get,
                                  headers: headers)
      .validate(statusCode: 200..<300)
      .serializingDecodable(User.self)
      .value
    } fetchUserStations: { userId, auth in
      guard let authToken = auth.jwt else {
          throw APIError.unauthorized
      }

      let urlString = "\(Self.playolaBaseUrl)/users/\(userId)/stations"

      do {
          // Make the network request
          return try await performRequest(
              urlString: urlString,
              method: .get,
              auth: auth
          )
      } catch {
          throw mapToAPIError(error)
      }
    } fetchSchedule: { stationId, extended, auth in
      let urlString = "\(Self.playolaBaseUrl)/stations/\(stationId)/schedule"
      let parameters: [String: Bool] = ["extended": extended]
      
      do {
        // Make the network request
        let spins: [Spin] = try await performRequest(
          urlString: urlString,
          method: .get,
          parameters: parameters,
          auth: auth
        )
        
        // Create and return the schedule
        return Schedule(stationId: stationId, spins: spins)
      } catch {
        throw mapToAPIError(error)
      }
    }
  }

  enum DataError: Error {
    case urlNotValid, dataNotValid, dataNotFound, fileNotFound, httpResponseNotValid
  }

  enum APIError: Error {
    case unauthorized
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case serverError(Int)
    case other(Error)
  }

  struct LoginResponse: Decodable {
    let playolaToken: String
  }
}

extension DependencyValues {
  var genericApiClient: GenericApiClient {
    get { self[GenericApiClient.self] }
    set { self[GenericApiClient.self] = newValue }
  }
}
