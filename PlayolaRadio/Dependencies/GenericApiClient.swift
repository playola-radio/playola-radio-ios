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

  @Shared(.auth) var auth: Auth
}

extension GenericApiClient: DependencyKey {
  // MARK: - Private Helper Methods

  /// Perform a network request and decode the response using Alamofire's native async/await support
  /// - Parameters:
  ///   - urlString: The URL string for the API endpoint
  ///   - method: The HTTP method to use
  ///   - parameters: Optional query parameters
  ///   - encoding: Parameter encoding (defaults to URLEncoding.default)
  /// - Returns: Decoded object of specified type
  private static func performRequest<T: Decodable & Sendable>(
    urlString: String,
    method: HTTPMethod,
    parameters: Parameters? = nil,
    encoding: ParameterEncoding = URLEncoding.default
  ) async throws -> T {
    // Use Alamofire's native async API
    let decoder = JSONDecoderWithIsoFull()

    let response = try await AF.request(
      urlString,
      method: method,
      parameters: parameters,
      encoding: encoding
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
    }
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

extension DependencyValues {
  var genericApiClient: GenericApiClient {
    get { self[GenericApiClient.self] }
    set { self[GenericApiClient.self] = newValue }
  }
}
