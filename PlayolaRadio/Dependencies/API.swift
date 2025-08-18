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
import PlayolaPlayer
import Sharing

// MARK: - API Dependency

@DependencyClient
struct APIClient: Sendable {
  /// Fetches all available radio station lists
  var getStations: () async throws -> IdentifiedArrayOf<StationList> = { [] }

  /// Signs in user via Apple authentication
  /// - Parameters:
  ///   - identityToken: The Apple identity token
  ///   - email: User's email address
  ///   - authCode: Apple authorization code
  ///   - firstName: User's first name
  ///   - lastName: Optional last name for the user
  /// - Returns: JWT token string
  var signInViaApple:
    (
      _ identityToken: String, _ email: String, _ authCode: String, _ firstName: String,
      _ lastName: String?
    )
      async throws -> String = { _, _, _, _, _ in ""
      }

  /// Revokes Apple credentials for the user
  /// - Parameter appleUserId: The Apple user ID to revoke
  var revokeAppleCredentials: (_ appleUserId: String) async throws -> Void = { _ in }

  /// Signs in user via Google authentication
  /// - Parameter code: Google authentication code
  /// - Returns: JWT token string
  var signInViaGoogle: (_ code: String) async throws -> String = { _ in "" }

  /// Fetches the rewards profile for the authenticated user
  /// - Parameter jwtToken: The JWT token for authentication
  /// - Returns: RewardsProfile containing listening time and rewards data
  var getRewardsProfile: (_ jwtToken: String) async throws -> RewardsProfile = { _ in
    RewardsProfile(totalTimeListenedMS: 0, totalMSAvailableForRewards: 0, accurateAsOfTime: Date())
  }

  /// Fetches all available prize tiers from the rewards system
  /// - Returns: Array of PrizeTier objects containing tiers and their associated prizes
  var getPrizeTiers: () async throws -> [PrizeTier] = { [] }

  ///   - jwtToken: Current JWT
  ///   - firstName: New first name
  ///   - lastName: New last name (optional, "" treated as nil)
  /// - Returns: Updated `Auth` containing fresh token & user
  var updateUser:
    (_ jwtToken: String, _ firstName: String, _ lastName: String?) async throws -> Auth = {
      _, _, _ in Auth()
    }

  /// Verifies if an invitation code is valid
  /// - Parameter code: The invitation code to verify
  /// - Throws: InvitationCodeError if the code is invalid, expired, or at max uses
  var verifyInvitationCode: (_ code: String) async throws -> Void = { _ in }

  /// Registers a user with an invitation code
  /// - Parameters:
  ///   - userId: The user ID to register
  ///   - code: The invitation code to use for registration
  /// - Throws: InvitationCodeError if the registration fails
  var registerInvitationCode: (_ userId: String, _ code: String) async throws -> Void = { _, _ in }
}

extension APIClient: DependencyKey {
  static let liveValue: Self = {
    // Create a custom decoder for dates
    let isoDecoder = JSONDecoderWithIsoFull()

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
      signInViaApple: { identityToken, email, authCode, firstName, lastName in
        var parameters: [String: String] = [
          "identityToken": identityToken,
          "authCode": authCode,
          "email": email,
          "firstName": firstName,
        ]
        if let lastName {
          parameters["lastName"] = lastName
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
        let parameters: [String: String] = ["appleUserId": appleUserId]
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
        let parameters: [String: Sendable] = [
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
      },
      getRewardsProfile: { jwtToken in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/rewards/users/me/profile"
        let headers: HTTPHeaders = [
          "Authorization": "Bearer \(jwtToken)"
        ]

        let response = try await AF.request(
          url,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(RewardsProfile.self, decoder: JSONDecoderWithIsoFull())
        .value

        return response
      },
      getPrizeTiers: {
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/rewards/tiers"

        let response = try await AF.request(url)
          .validate(statusCode: 200..<300)
          .serializingDecodable([PrizeTier].self, decoder: isoDecoder)
          .value

        return response
      },
      updateUser: { jwtToken, firstName, lastName in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me"

        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        var params: [String: String] = ["firstName": firstName]
        if let lastName { params["lastName"] = lastName }

        let request = AF.request(
          url,
          method: .put,
          parameters: params,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .validate(statusCode: 200..<300)

        // Capture decoded body *and* the HTTPURLResponse
        let dataResponse = try await request.serializingDecodable(UpdateUserResponse.self).response
        guard
          let body = dataResponse.value
        else {
          throw APIError.dataNotValid
        }

        let newToken = dataResponse.response?.headers["X-New-Access-Token"] ?? jwtToken
        let updatedUser = LoggedInUser(
          id: body.id,
          firstName: body.firstName,
          lastName: body.lastName,
          email: body.email,
          profileImageUrl: body.profileImageUrl,
          role: body.role
        )

        return Auth(currentUser: updatedUser, jwt: newToken)
      },
      verifyInvitationCode: { code in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/invitationCode/verify"
        let parameters = ["code": code]
        
        let dataResponse = try await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default
        )
        .serializingData()
        .response
        
        guard let statusCode = dataResponse.response?.statusCode else {
          throw APIError.dataNotValid
        }
        
        if statusCode == 200 {
          if let data = dataResponse.value,
             let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
             let valid = jsonResponse["valid"] as? Bool,
             valid {
            return
          }
          throw InvitationCodeError.invalidCode("Invalid invitation code")
        } else {
          // Try to parse server error message
          if let data = dataResponse.value,
             let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
             let errorObj = errorResponse["error"] as? [String: Any],
             let message = errorObj["message"] as? String {
            throw InvitationCodeError.invalidCode(message)
          }
          
          // Fall back to standard validation error
          let request = AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
          )
          _ = try await request.validate(statusCode: 200..<300).serializingData().value
        }
      },
      registerInvitationCode: { userId, code in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/invitationCode/register"
        let parameters = ["userId": userId, "code": code]
        
        let response = try await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable([String: Bool].self)
        .value
        
        guard response["success"] == true else {
          throw InvitationCodeError.registrationFailed("Failed to register with invitation code")
        }
      }
    )
  }()
}

enum APIError: Error {
  case dataNotValid
}

enum InvitationCodeError: Error {
  case invalidCode(String)
  case registrationFailed(String)
  
  var localizedDescription: String {
    switch self {
    case .invalidCode(let message),
         .registrationFailed(let message):
      return message
    }
  }
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
struct UpdateUserResponse: Decodable {
  let id: String
  let firstName: String
  let lastName: String?
  let email: String
  let profileImageUrl: String?
  let role: String
}
