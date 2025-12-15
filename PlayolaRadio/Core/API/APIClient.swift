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

  /// Fetches the schedule for a station
  /// - Parameters:
  ///   - stationId: The station ID to fetch the schedule for
  ///   - extended: Whether to fetch extended schedule (more spins)
  /// - Returns: Array of Spin objects representing the schedule
  /// - Throws: Error if the request fails
  var fetchSchedule: (_ stationId: String, _ extended: Bool) async throws -> [Spin] = { _, _ in [] }

  /// Fetches a station by ID
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID to fetch
  /// - Returns: Station object or nil if not found
  var fetchStation: (_ jwtToken: String, _ stationId: String) async throws -> Station? = { _, _ in
    nil
  }

  /// Fetches all stations for a user
  /// - Parameter jwtToken: The JWT token for authentication
  /// - Returns: Array of Station objects the user has access to
  var fetchUserStations: (_ jwtToken: String) async throws -> [Station] = { _ in [] }

  /// Deletes a spin from the station's schedule
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - spinId: The ID of the spin to delete
  /// - Returns: Updated array of Spin objects representing the new schedule
  /// - Throws: APIError if the request fails
  var deleteSpin: (_ jwtToken: String, _ spinId: String) async throws -> [Spin] = { _, _ in [] }

  /// Moves a spin to a new position in the playlist
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - spinId: The ID of the spin to move
  ///   - placeAfterSpinId: The ID of the spin after which to place the moved spin, or nil to place at the beginning
  /// - Returns: Updated array of Spin objects representing the new schedule
  /// - Throws: APIError if the request fails
  var moveSpin:
    (_ jwtToken: String, _ spinId: String, _ placeAfterSpinId: String?) async throws
      -> [Spin] = { _, _, _ in [] }
  /// Inserts a spin into the station's schedule
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - audioBlockId: The ID of the audio block to insert
  ///   - placeAfterSpinId: The ID of the spin to place the new spin after
  /// - Returns: Updated array of Spin objects representing the new schedule
  /// - Throws: APIError if the request fails
  var insertSpin:
    (_ jwtToken: String, _ audioBlockId: String, _ placeAfterSpinId: String) async throws -> [Spin] =
      { _, _, _ in [] }

  /// Gets a presigned URL for uploading a voicetrack to S3
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID to upload the voicetrack for
  /// - Returns: PresignedURLResponse containing the upload URL and S3 key
  /// - Throws: APIError if the request fails
  var getVoicetrackPresignedURL:
    (_ jwtToken: String, _ stationId: String) async throws
      -> PresignedURLResponse = { _, _ in
        PresignedURLResponse(presignedUrl: URL(string: "https://example.com")!, s3Key: "test.m4a")
      }

  /// Uploads a file to S3 using a presigned URL
  /// - Parameters:
  ///   - presignedURL: The presigned URL to upload to
  ///   - fileURL: The local file URL to upload
  ///   - contentType: The content type of the file
  ///   - onProgress: Callback for upload progress (0.0 to 1.0)
  /// - Throws: APIError if the upload fails
  var uploadToS3:
    (
      _ presignedURL: URL, _ fileURL: URL, _ contentType: String,
      _ onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> Void = { _, _, _, _ in }

  /// Creates a voicetrack AudioBlock after uploading to S3
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID to create the voicetrack for
  ///   - s3Key: The S3 key where the file was uploaded
  ///   - durationMS: The duration in milliseconds
  /// - Returns: The created AudioBlock
  /// - Throws: APIError if the request fails
  var createVoicetrack:
    (_ jwtToken: String, _ stationId: String, _ s3Key: String, _ durationMS: Int) async throws
      -> AudioBlock = { _, _, _, _ in
        AudioBlock.mockWith()
      }

  /// Searches for songs by keywords
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - keywords: The search keywords
  /// - Returns: Array of AudioBlocks matching the search
  /// - Throws: APIError if the request fails
  var searchSongs: (_ jwtToken: String, _ keywords: String) async throws -> [AudioBlock] = { _, _ in
    []
  }
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

        if statusCode >= 200, statusCode < 300 {
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
      },
      fetchSchedule: { stationId, extended in
        var url = "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/schedule"

        if extended {
          url += "?extended=true"
        }

        let response = try await AF.request(url)
          .validate(statusCode: 200..<300)
          .serializingDecodable([Spin].self, decoder: isoDecoder)
          .value

        return response
      },
      fetchStation: { jwtToken, stationId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable(Station.self, decoder: isoDecoder)
          .value

        return response
      },
      fetchUserStations: { jwtToken in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/stations"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable([Station].self, decoder: isoDecoder)
          .value

        return response
      },
      deleteSpin: { jwtToken, spinId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/spins/\(spinId)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let dataResponse = await AF.request(
          url,
          method: .delete,
          headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw APIError.dataNotValid
        }

        guard let data = dataResponse.value else {
          throw APIError.dataNotValid
        }

        if statusCode >= 200, statusCode < 300 {
          let spins = try isoDecoder.decode([Spin].self, from: data)
          return spins
        } else {
          let message = parsePlayolaErrorMessage(from: data) ?? "Failed to delete spin"
          throw APIError.validationError(message)
        }
      },
      moveSpin: { jwtToken, spinId, placeAfterSpinId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/spins/\(spinId)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters: [String: Any] = ["placeAfterSpinId": placeAfterSpinId as Any]

        let dataResponse = await AF.request(
          url,
          method: .put,
          parameters: parameters,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw APIError.dataNotValid
        }

        guard let data = dataResponse.value else {
          throw APIError.dataNotValid
        }

        if statusCode >= 200, statusCode < 300 {
          let spins = try isoDecoder.decode([Spin].self, from: data)
          return spins
        } else {
          if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errorObj = errorResponse["error"] as? [String: Any],
            let message = errorObj["message"] as? String
          {
            throw APIError.validationError(message)
          }
          throw APIError.validationError("Failed to move spin")
        }
      },
      insertSpin: { jwtToken, audioBlockId, placeAfterSpinId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/spins"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters: [String: String] = [
          "audioBlockId": audioBlockId,
          "placeAfterSpinId": placeAfterSpinId,
        ]

        let dataResponse = await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw APIError.dataNotValid
        }

        guard let data = dataResponse.value else {
          throw APIError.dataNotValid
        }

        if statusCode >= 200, statusCode < 300 {
          let spins = try isoDecoder.decode([Spin].self, from: data)
          return spins
        } else {
          let message = parsePlayolaErrorMessage(from: data) ?? "Failed to insert spin"
          throw APIError.validationError(message)
        }
      },
      getVoicetrackPresignedURL: { jwtToken, stationId in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/voicetrack-presigned-url"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          method: .post,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(PresignedURLResponse.self)
        .value

        return response
      },
      uploadToS3: { presignedURL, fileURL, contentType, onProgress in
        let headers: HTTPHeaders = [
          "Content-Type": contentType
        ]

        try await withCheckedThrowingContinuation {
          (continuation: CheckedContinuation<Void, Error>) in
          AF.upload(fileURL, to: presignedURL, method: .put, headers: headers)
            .uploadProgress { progress in
              onProgress(progress.fractionCompleted)
            }
            .response { response in
              if let error = response.error {
                continuation.resume(throwing: error)
              } else if let statusCode = response.response?.statusCode,
                statusCode >= 200, statusCode < 300
              {
                continuation.resume(returning: ())
              } else {
                continuation.resume(throwing: APIError.validationError("S3 upload failed"))
              }
            }
        }
      },
      createVoicetrack: { jwtToken, stationId, s3Key, durationMS in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/voicetracks"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters: [String: Any] = [
          "s3Key": s3Key,
          "durationMS": durationMS,
        ]

        let dataResponse = await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .serializingData()
        .response

        guard let statusCode = dataResponse.response?.statusCode else {
          throw APIError.dataNotValid
        }

        guard let data = dataResponse.value else {
          throw APIError.dataNotValid
        }

        if statusCode >= 200, statusCode < 300 {
          let audioBlock = try isoDecoder.decode(AudioBlock.self, from: data)
          return audioBlock
        } else {
          let message = parsePlayolaErrorMessage(from: data) ?? "Failed to create voicetrack"
          throw APIError.validationError(message)
        }
      },
      searchSongs: { jwtToken, keywords in
        let encodedKeywords =
          keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/songs/search?keywords=\(encodedKeywords)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable([AudioBlock].self, decoder: isoDecoder)
          .value

        return response
      }
    )
  }()
}

enum APIError: Error, LocalizedError {
  case dataNotValid
  case validationError(String)

  var errorDescription: String? {
    switch self {
    case .dataNotValid:
      return "Invalid data received from server"
    case .validationError(let message):
      return message
    }
  }
}

func parsePlayolaErrorMessage(from data: Data) -> String? {
  guard let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let errorObj = errorResponse["error"] as? [String: Any],
    let message = errorObj["message"] as? String
  else {
    return nil
  }
  return message
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
