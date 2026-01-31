//
//  APIClient+Live.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/17/25.
//

import Alamofire
import Dependencies
import Foundation
import IdentifiedCollections
import PlayolaPlayer

// MARK: - Request Parameters

private struct MoveSpinParameters: Encodable, Sendable {
  let placeAfterSpinId: String?
}

private struct CreateVoicetrackParameters: Encodable, Sendable {
  let s3Key: String
  let durationMS: Int
}

// MARK: - Request Helpers

private let sharedIsoDecoder = JSONDecoderWithIsoFull()

private func authenticatedGet<T: Decodable & Sendable>(
  path: String,
  token: String,
  queryParams: [String: String]? = nil
) async throws -> T {
  var url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  if let queryParams, !queryParams.isEmpty {
    let queryString = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
    url += "?\(queryString)"
  }
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  return try await AF.request(url, headers: headers)
    .validate(statusCode: 200..<300)
    .serializingDecodable(T.self, decoder: sharedIsoDecoder)
    .value
}

private func authenticatedPost<T: Decodable & Sendable>(
  path: String,
  token: String,
  parameters: [String: String] = [:]
) async throws -> T {
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  return try await AF.request(
    url,
    method: .post,
    parameters: parameters.isEmpty ? nil : parameters,
    encoding: JSONEncoding.default,
    headers: headers
  )
  .validate(statusCode: 200..<300)
  .serializingDecodable(T.self, decoder: sharedIsoDecoder)
  .value
}

private func authenticatedPostVoid(
  path: String,
  token: String,
  parameters: [String: String] = [:]
) async throws {
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  _ = try await AF.request(
    url,
    method: .post,
    parameters: parameters.isEmpty ? nil : parameters,
    encoding: JSONEncoding.default,
    headers: headers
  )
  .validate(statusCode: 200..<300)
  .serializingData()
  .value
}

private func authenticatedPut<T: Decodable & Sendable>(path: String, token: String) async throws
  -> T
{
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  return try await AF.request(url, method: .put, headers: headers)
    .validate(statusCode: 200..<300)
    .serializingDecodable(T.self, decoder: sharedIsoDecoder)
    .value
}

private func authenticatedPutVoid(path: String, token: String) async throws {
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  _ = try await AF.request(url, method: .put, headers: headers)
    .validate(statusCode: 200..<300)
    .serializingData()
    .value
}

private func authenticatedDelete(path: String, token: String) async throws {
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  _ = try await AF.request(url, method: .delete, headers: headers)
    .validate(statusCode: 200..<300)
    .serializingData()
    .value
}

extension APIClient: DependencyKey {
  static let liveValue: Self = {
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
        try await authenticatedGet(path: "/v1/rewards/users/me/profile", token: jwtToken)
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

        let dataResponse = await request.serializingDecodable(UpdateUserResponse.self).response
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
          if let data = dataResponse.value,
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errorObj = errorResponse["error"] as? [String: Any],
            let message = errorObj["message"] as? String
          {
            throw InvitationCodeError.invalidCode(message)
          }

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
          if let data = dataResponse.value,
            let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = errorResponse["message"] as? String
          {
            throw APIError.validationError(message)
          }

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
        var parameters: [String: String] = ["audioBlockId": songId]
        if let spinId { parameters["spinId"] = spinId }
        try await authenticatedPostVoid(
          path: "/v1/users/me/likes", token: jwtToken, parameters: parameters)
      },
      unlikeSong: { jwtToken, songId in
        try await authenticatedDelete(path: "/v1/users/me/likes/\(songId)", token: jwtToken)
      },
      getLikedSongs: { jwtToken in
        try await authenticatedGet(path: "/v1/users/me/likes", token: jwtToken)
      },
      getShows: { jwtToken, includeSegments, stationId in
        var queryParams: [String: String] = [:]
        if includeSegments { queryParams["includeSegments"] = "true" }
        if let stationId { queryParams["stationId"] = stationId }
        return try await authenticatedGet(
          path: "/v1/shows", token: jwtToken, queryParams: queryParams.isEmpty ? nil : queryParams
        )
      },
      getShowById: { jwtToken, showId, includeSegments in
        let queryParams = includeSegments ? nil : ["includeSegments": "false"]
        return try await authenticatedGet(
          path: "/v1/shows/\(showId)", token: jwtToken, queryParams: queryParams
        )
      },
      getAirings: { jwtToken, stationId in
        var queryParams: [String: String]?
        if let stationId { queryParams = ["stationId": stationId] }
        return try await authenticatedGet(
          path: "/v1/airings", token: jwtToken, queryParams: queryParams)
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
        try await authenticatedGet(path: "/v1/stations/\(stationId)", token: jwtToken)
      },
      fetchUserStations: { jwtToken in
        try await authenticatedGet(path: "/v1/users/me/stations", token: jwtToken)
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
        let parameters = MoveSpinParameters(placeAfterSpinId: placeAfterSpinId)

        let dataResponse = await AF.request(
          url,
          method: .put,
          parameters: parameters,
          encoder: JSONParameterEncoder.default,
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
        try await authenticatedPost(
          path: "/v1/stations/\(stationId)/voicetrack-presigned-url", token: jwtToken
        )
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
        let parameters = CreateVoicetrackParameters(s3Key: s3Key, durationMS: durationMS)

        let dataResponse = await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoder: JSONParameterEncoder.default,
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
      getVoicetrackStatus: { jwtToken, stationId, s3Key in
        var allowedCharacters = CharacterSet.urlPathAllowed
        allowedCharacters.remove("/")
        let encodedS3Key =
          s3Key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s3Key
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/voicetrack-status/\(encodedS3Key)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable(VoicetrackStatusResponse.self)
          .value

        return response
      },
      getListenerQuestions: { jwtToken, stationId in
        try await authenticatedGet(
          path: "/v1/stations/\(stationId)/listener-questions", token: jwtToken)
      },
      getListenerQuestionPresignedURL: { jwtToken, stationId in
        try await authenticatedPost(
          path: "/v1/listener-questions/presigned-url",
          token: jwtToken,
          parameters: ["stationId": stationId]
        )
      },
      createListenerQuestion: { jwtToken, stationId, audioBlockId in
        try await authenticatedPost(
          path: "/v1/listener-questions",
          token: jwtToken,
          parameters: ["stationId": stationId, "audioBlockId": audioBlockId]
        )
      },
      registerListenerQuestionAnswer: { jwtToken, stationId, questionId, answerAudioBlockId in
        try await authenticatedPost(
          path: "/v1/stations/\(stationId)/listener-questions/\(questionId)/answer",
          token: jwtToken,
          parameters: ["answerAudioBlockId": answerAudioBlockId]
        )
      },
      declineListenerQuestion: { jwtToken, stationId, questionId in
        try await authenticatedPost(
          path: "/v1/stations/\(stationId)/listener-questions/\(questionId)/decline",
          token: jwtToken
        )
      },
      getMyListenerQuestionAirings: { jwtToken in
        try await authenticatedGet(path: "/v1/users/me/listener-question-airings", token: jwtToken)
      },
      searchSongs: { jwtToken, keywords in
        let encoded =
          keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        return try await authenticatedGet(
          path: "/v1/songs/search", token: jwtToken, queryParams: ["keywords": encoded]
        )
      },
      searchSongRequests: { jwtToken, keywords in
        let encoded =
          keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        return try await authenticatedGet(
          path: "/v1/songs/search-song-seeds", token: jwtToken, queryParams: ["keywords": encoded]
        )
      },
      requestSong: { jwtToken, spotifyId in
        try await authenticatedPostVoid(
          path: "/v1/songs/requests", token: jwtToken, parameters: ["spotifyId": spotifyId]
        )
      },
      registerDevice: { jwtToken, deviceToken, platform, appVersion in
        try await authenticatedPost(
          path: "/v1/users/me/devices",
          token: jwtToken,
          parameters: ["deviceToken": deviceToken, "platform": platform, "appVersion": appVersion]
        )
      },
      unregisterDevice: { jwtToken, deviceId in
        try await authenticatedDelete(path: "/v1/users/me/devices/\(deviceId)", token: jwtToken)
      },
      sendStationNotification: { jwtToken, stationId, message in
        try await authenticatedPostVoid(
          path: "/v1/stations/\(stationId)/notifications", token: jwtToken,
          parameters: ["message": message]
        )
      },
      getPushNotificationSubscriptions: { jwtToken in
        try await authenticatedGet(
          path: "/v1/users/me/push-notification-subscriptions", token: jwtToken)
      },
      subscribeToStationNotifications: { jwtToken, stationId in
        try await authenticatedPost(
          path: "/v1/stations/\(stationId)/push-notification-subscription/subscribe",
          token: jwtToken
        )
      },
      unsubscribeFromStationNotifications: { jwtToken, stationId in
        try await authenticatedPost(
          path: "/v1/stations/\(stationId)/push-notification-subscription/unsubscribe",
          token: jwtToken
        )
      },
      fetchLiveStations: { jwtToken in
        try await authenticatedGet(path: "/v1/stations/live", token: jwtToken)
      },
      getSupportConversation: { jwtToken in
        try await authenticatedGet(path: "/v1/conversations/support", token: jwtToken)
      },
      getConversationMessages: { jwtToken, conversationId in
        try await authenticatedGet(
          path: "/v1/conversations/\(conversationId)/messages", token: jwtToken)
      },
      sendConversationMessage: { jwtToken, conversationId, message in
        try await authenticatedPost(
          path: "/v1/conversations/\(conversationId)/messages",
          token: jwtToken,
          parameters: ["message": message]
        )
      },
      markConversationRead: { jwtToken, conversationId in
        try await authenticatedPutVoid(
          path: "/v1/conversations/\(conversationId)/read", token: jwtToken)
      },
      getConversations: { jwtToken, status in
        var queryParams: [String: String]?
        if let status { queryParams = ["status": status] }
        return try await authenticatedGet(
          path: "/v1/conversations", token: jwtToken, queryParams: queryParams)
      },
      getOrCreateReferralCode: { jwtToken, expiresAt in
        try await authenticatedPost(
          path: "/v1/referral-codes/get-or-create",
          token: jwtToken,
          parameters: ["expiresAt": ISO8601DateFormatter().string(from: expiresAt)]
        )
      },
      getStationLibrary: { jwtToken, stationId in
        try await authenticatedGet(path: "/v1/stations/\(stationId)/library", token: jwtToken)
      },
      getStationLibraryRequests: { jwtToken, stationId, status in
        var queryParams: [String: String]?
        if let status { queryParams = ["status": status] }
        return try await authenticatedGet(
          path: "/v1/stations/\(stationId)/library-requests",
          token: jwtToken,
          queryParams: queryParams
        )
      },
      createAddLibraryRequest: { jwtToken, stationId, body in
        var parameters: [String: String] = [
          "spotifyId": body.spotifyId, "title": body.title, "artist": body.artist,
        ]
        if let album = body.album { parameters["album"] = album }
        if let imageUrl = body.imageUrl { parameters["imageUrl"] = imageUrl }
        return try await authenticatedPost(
          path: "/v1/stations/\(stationId)/library-requests/add",
          token: jwtToken,
          parameters: parameters
        )
      },
      createRemoveLibraryRequest: { jwtToken, stationId, audioBlockId in
        try await authenticatedPost(
          path: "/v1/stations/\(stationId)/library-requests/remove",
          token: jwtToken,
          parameters: ["audioBlockId": audioBlockId]
        )
      },
      dismissStationLibraryRequest: { jwtToken, stationId, requestId in
        try await authenticatedPut(
          path: "/v1/stations/\(stationId)/library-requests/\(requestId)/dismiss",
          token: jwtToken
        )
      },
      cancelStationLibraryRequest: { jwtToken, stationId, requestId in
        try await authenticatedDelete(
          path: "/v1/stations/\(stationId)/library-requests/\(requestId)",
          token: jwtToken
        )
      }
    )
  }()
}
