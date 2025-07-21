//
//  API.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import Alamofire
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import Sharing

// MARK: - API Dependency

@DependencyClient
struct APIClient {
  var getStations: () async throws -> IdentifiedArrayOf<StationList> = { [] }
  var signInViaApple: (String, String, String, String?) async throws -> String = { _, _, _, _ in ""
  }
  var revokeAppleCredentials: (String) async throws -> Void = { _ in }
  var signInViaGoogle: (String) async throws -> String = { _ in "" }
}

extension APIClient: DependencyKey {
  static let liveValue: Self = {
    return Self(
      getStations: {
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/developer/stationLists"
        let response = try await AF.request(url).serializingDecodable([String: [StationList]].self)
          .value
        guard let stationLists = response["stationLists"] else {
          throw APIError.dataNotValid
        }
        return IdentifiedArray(uniqueElements: stationLists)
      },
      signInViaApple: { identityToken, email, authCode, displayName in
        var parameters: [String: Any] = [
          "identityToken": identityToken,
          "authCode": authCode,
          "email": email,
        ]
        if let displayName {
          parameters["displayName"] = displayName
        }
        let response = try await AF.request(
          "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/mobile/signup",
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default
        ).serializingDecodable(LoginResponse.self).value

        return response.playolaToken
      },
      revokeAppleCredentials: { appleUserId in
        let parameters: [String: Any] = ["appleUserId": appleUserId]
        _ = try await AF.request(
          "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/revoke",
          method: .put,
          parameters: parameters,
          encoding: JSONEncoding.default
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        .value

        AuthService.shared.signOut()
        AuthService.shared.clearAppleUser()
      },
      signInViaGoogle: { code in
        let parameters: [String: Any] = [
          "code": code,
          "originatesFromIOS": true,
        ]

        let response = try await AF.request(
          "\(Config.shared.baseUrl.absoluteString)/v1/auth/google/signin",
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(LoginResponse.self).value

        return response.playolaToken
      }
    )
  }()
}

enum APIError: Error {
  case dataNotValid
}

extension DependencyValues {
  var api: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }
}

struct LoginResponse: Decodable {
  let playolaToken: String
}
