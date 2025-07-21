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
  var signInViaApple: (String, String, String, String?) async -> Void = { _, _, _, _ in }
  var revokeAppleCredentials: (String) async -> Void = { _ in }
  var signInViaGoogle: (String) async -> Void = { _ in }
}

extension APIClient: DependencyKey {
  static let liveValue: Self = {
    let coordinator = APICoordinator.shared
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
        await coordinator.signInViaApple(
          identityToken: identityToken,
          email: email,
          authCode: authCode,
          displayName: displayName
        )
      },
      revokeAppleCredentials: { appleUserId in
        await coordinator.revokeAppleCredentials(appleUserId: appleUserId)
      },
      signInViaGoogle: { code in
        await coordinator.signInViaGoogle(code: code)
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

// MARK: - API Coordinator (Internal Implementation)

@MainActor
private class APICoordinator {
  static let shared = APICoordinator()

  @Shared(.auth) var auth: Auth

  func signInViaApple(
    identityToken: String,
    email: String,
    authCode: String,
    displayName: String?
  ) async {
    var parameters: [String: Any] = [
      "identityToken": identityToken,
      "authCode": authCode,
      "email": email,
    ]
    if let displayName {
      parameters["displayName"] = displayName
    }
    AF.request(
      "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/mobile/signup",
      method: .post,
      parameters: parameters,
      encoding: JSONEncoding.default
    ).responseDecodable(of: LoginResponse.self) { response in
      switch response.result {
      case let .success(loginResponse):
        self.$auth.withLock { $0 = Auth(jwtToken: loginResponse.playolaToken) }
      case let .failure(error):
        print("Failure to log in: \(error)")
      }
    }
  }

  func revokeAppleCredentials(appleUserId: String) async {
    let parameters: [String: Any] = ["appleUserId": appleUserId]
    AF.request(
      "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/revoke",
      method: .put,
      parameters: parameters,
      encoding: JSONEncoding.default
    )
    .validate(statusCode: 200..<300)
    .response { _ in
      AuthService.shared.signOut()
      AuthService.shared.clearAppleUser()
    }
  }

  func signInViaGoogle(code: String) async {
    let parameters: [String: Any] = [
      "code": code,
      "originatesFromIOS": true,
    ]

    AF.request(
      "\(Config.shared.baseUrl.absoluteString)/v1/auth/google/signin",
      method: .post,
      parameters: parameters,
      encoding: JSONEncoding.default
    )
    .validate(statusCode: 200..<300)
    .responseDecodable(of: LoginResponse.self) { response in
      switch response.result {
      case let .success(loginResponse):
        self.$auth.withLock { $0 = Auth(jwtToken: loginResponse.playolaToken) }
      case let .failure(error):
        print("Failure to log in: \(error)")
      }
    }
  }

}

struct LoginResponse: Decodable {
  let playolaToken: String
}
