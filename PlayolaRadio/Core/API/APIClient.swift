//
//  APIClient.swift
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
      _ identityToken: String, _ email: String?, _ authCode: String, _ firstName: String,
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

  /// Adds an email address to the waiting list
  /// - Parameter email: The email address to add to the waiting list
  /// - Throws: Error if the email is invalid or already exists
  var addToWaitingList: (_ email: String) async throws -> Void = { _ in }

  /// Likes a song for the authenticated user
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - songId: The ID of the song to like
  ///   - spinId: Optional ID of the spin context where the like occurred
  /// - Throws: APIError if the request fails
  var likeSong: (_ jwtToken: String, _ songId: String, _ spinId: String?) async throws -> Void = {
    _, _, _ in
  }

  /// Unlikes a song for the authenticated user
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - songId: The ID of the song to unlike
  /// - Throws: APIError if the request fails
  var unlikeSong: (_ jwtToken: String, _ songId: String) async throws -> Void = { _, _ in }

  /// Fetches all liked songs for the authenticated user
  /// - Parameter jwtToken: The JWT token for authentication
  /// - Returns: Array of UserSongLike objects containing AudioBlocks and timestamps
  /// - Throws: APIError if the request fails
  var getLikedSongs: (_ jwtToken: String) async throws -> [UserSongLike] = { _ in [] }

  /// Fetches all shows for the authenticated user
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - includeSegments: Whether to include show segments in the response
  ///   - stationId: Optional station ID to filter shows by station
  /// - Returns: Array of Show objects
  /// - Throws: APIError if the request fails
  var getShows:
    (_ jwtToken: String, _ includeSegments: Bool, _ stationId: String?) async throws -> [Show] = {
      _, _, _ in []
    }

  /// Fetches a single show by ID
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - showId: The ID of the show to fetch
  ///   - includeSegments: Whether to include show segments in the response (defaults to true)
  /// - Returns: Show object or nil if not found
  /// - Throws: APIError if the request fails
  var getShowById:
    (_ jwtToken: String, _ showId: String, _ includeSegments: Bool) async throws -> Show? = {
      _, _, _ in nil
    }

  /// Fetches scheduled shows
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - showId: Optional show ID to filter by specific show
  ///   - stationId: Optional station ID to filter by specific station
  /// - Returns: Array of ScheduledShow objects
  /// - Throws: APIError if the request fails
  var getScheduledShows:
    (_ jwtToken: String, _ showId: String?, _ stationId: String?) async throws -> [ScheduledShow] =
      { _, _, _ in [] }
}

extension APIClient: DependencyKey {
  static let liveValue: Self = {
    // Create a custom decoder for dates
    let isoDecoder = JSONDecoderWithIsoFull()

    return Self(
      getStations: {
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/station-lists"
        let response = try await AF.request(url)
          .serializingDecodable([StationList].self, decoder: JSONDecoderWithIsoFull())
          .value
        return IdentifiedArray(uniqueElements: response)
      },
      signInViaApple: { identityToken, email, authCode, firstName, lastName in
        var parameters: [String: String] = [
          "identityToken": identityToken,
          "authCode": authCode,
          "firstName": firstName,
        ]
        if let email {
          parameters["email"] = email
        }
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
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/invitation-codes/verify"
        let parameters = ["code": code]

        let dataResponse = await AF.request(
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
            valid
          {
            return
          }
          throw InvitationCodeError.invalidCode("Invalid invitation code")
        } else {
          // Try to parse server error message
          if let data = dataResponse.value,
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errorObj = errorResponse["error"] as? [String: Any],
            let message = errorObj["message"] as? String
          {
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
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/invitation-codes/register"
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
      },
      addToWaitingList: { email in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/waiting-list-entries"
        let parameters = ["email": email]

        let dataResponse = await AF.request(
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

        if statusCode >= 200 && statusCode < 300 {
          return
        } else {
          // Try to parse server error message
          if let data = dataResponse.value,
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = errorResponse["message"] as? String
          {
            throw APIError.validationError(message)
          }

          // Fall back to validation error
          let request = AF.request(
            url,
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default
          )
          _ = try await request.validate(statusCode: 200..<300).serializingData().value
        }
      },
      likeSong: { jwtToken, songId, spinId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/likes"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        var parameters: [String: String] = ["audioBlockId": songId]
        if let spinId = spinId {
          parameters["spinId"] = spinId
        }

        _ = try await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        .value
      },
      unlikeSong: { jwtToken, songId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/likes/\(songId)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        _ = try await AF.request(
          url,
          method: .delete,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        .value
      },
      getLikedSongs: { jwtToken in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/likes"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable([UserSongLike].self, decoder: isoDecoder)
        .value

        return response
      },
      getShows: { jwtToken, includeSegments, stationId in
        var url = "\(Config.shared.baseUrl.absoluteString)/v1/shows"
        var queryParams: [String] = []

        if includeSegments {
          queryParams.append("includeSegments=true")
        }
        if let stationId = stationId {
          queryParams.append("stationId=\(stationId)")
        }

        if !queryParams.isEmpty {
          url += "?" + queryParams.joined(separator: "&")
        }

        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable([Show].self, decoder: isoDecoder)
        .value

        return response
      },
      getShowById: { jwtToken, showId, includeSegments in
        var url = "\(Config.shared.baseUrl.absoluteString)/v1/shows/\(showId)"
        if !includeSegments {
          url += "?includeSegments=false"
        }
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(Show?.self, decoder: isoDecoder)
        .value

        return response
      },
      getScheduledShows: { jwtToken, showId, stationId in
        var url = "\(Config.shared.baseUrl.absoluteString)/v1/shows/schedule"
        var queryParams: [String] = []

        if let showId = showId {
          queryParams.append("showId=\(showId)")
        }
        if let stationId = stationId {
          queryParams.append("stationId=\(stationId)")
        }

        if !queryParams.isEmpty {
          url += "?" + queryParams.joined(separator: "&")
        }

        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable([ScheduledShow].self, decoder: isoDecoder)
        .value

        return response
      }
    )
  }()
}

enum APIError: Error {
  case dataNotValid
  case validationError(String)
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
