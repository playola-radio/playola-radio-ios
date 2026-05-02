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
import Sharing

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

// TEMPORARY: Global TLS 1.2 cap.
//
// On iOS 26, URLSession sends a TLS 1.3 ClientHello that includes the X25519MLKEM768
// post-quantum hybrid key share (~1.6 KB). Some users sit behind middleboxes
// (antivirus SSL inspection, parental-control routers, captive portals, etc.) that
// drop the larger ClientHello and surface as NSURLErrorSecureConnectionFailed (-1200),
// which makes every API request fail silently on those networks. PR #269 added a
// per-call TLS 1.2 fallback for sign-in, but follow-up testing showed the issue
// affects every endpoint — sign-in succeeds, then profile / listening-tracker /
// station fetches silently fail and the UI renders blank or stale data.
//
// As a stopgap, every Alamofire request in this file is routed through `apiSession`,
// which caps the URLSession to TLS 1.2 so the ClientHello stays small enough for
// these middleboxes to pass through.
//
// REVERT WHEN: Apple ships an iOS 26 fix (watch 26.5+ release notes) OR exposes a
// supported opt-out for the post-quantum hybrid key share so we can keep TLS 1.3.
// At that point, replace `apiSession` usages with bare `AF` again and consider
// restoring a per-call retry (the prior signInPostWithTLS12Fallback pattern) for
// defense in depth on networks that still misbehave.
private let apiSession: Alamofire.Session = {
  let configuration = URLSessionConfiguration.af.default
  configuration.tlsMaximumSupportedProtocolVersion = .TLSv12
  return Alamofire.Session(configuration: configuration)
}()

private func signInPost(
  authMethod: AuthMethod,
  endpointPath: String,
  parameters: Parameters
) async throws -> String {
  let dataResponse = await apiSession.request(
    "\(Config.shared.baseUrl.absoluteString)\(endpointPath)",
    method: .post,
    parameters: parameters,
    encoding: JSONEncoding.default
  )
  .validate(statusCode: 200..<300)
  .serializingDecodable(LoginResponse.self)
  .response

  switch dataResponse.result {
  case .success(let response):
    return response.playolaToken
  case .failure(let error):
    throw SignInAPIError(
      authMethod: authMethod,
      endpointPath: endpointPath,
      statusCode: dataResponse.response?.statusCode,
      responseBody: dataResponse.data.flatMap { String(data: $0, encoding: .utf8) },
      underlyingError: error)
  }
}

private func authenticatedGet<T: Decodable & Sendable>(
  path: String,
  token: String,
  queryParams: [String: String]? = nil
) async throws -> T {
  var url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  if let queryParams, !queryParams.isEmpty {
    var components = URLComponents(string: url)
    components?.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
    if let resolvedURL = components?.url {
      url = resolvedURL.absoluteString
    }
  }
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  return try await apiSession.request(url, headers: headers)
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
  return try await apiSession.request(
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
  _ = try await apiSession.request(
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
  return try await apiSession.request(url, method: .put, headers: headers)
    .validate(statusCode: 200..<300)
    .serializingDecodable(T.self, decoder: sharedIsoDecoder)
    .value
}

private func authenticatedPutVoid(path: String, token: String) async throws {
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  _ = try await apiSession.request(url, method: .put, headers: headers)
    .validate(statusCode: 200..<300)
    .serializingData()
    .value
}

private func authenticatedDelete(path: String, token: String) async throws {
  let url = "\(Config.shared.baseUrl.absoluteString)\(path)"
  let headers: HTTPHeaders = ["Authorization": "Bearer \(token)"]
  _ = try await apiSession.request(url, method: .delete, headers: headers)
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
        let response = try await apiSession.request(url)
          .serializingDecodable([StationList].self, decoder: JSONDecoderWithIsoFull())
          .value
        return IdentifiedArray(uniqueElements: response)
      },
      signInViaApple: { identityToken, email, authCode, firstName, lastName in
        var parameters: Parameters = [
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
        return try await signInPost(
          authMethod: .apple,
          endpointPath: "/v1/auth/apple/mobile/signup",
          parameters: parameters)
      },
      revokeAppleCredentials: { appleUserId in
        let parameters: [String: String] = ["appleUserId": appleUserId]
        _ = try await apiSession.request(
          "\(Config.shared.baseUrl.absoluteString)/v1/auth/apple/revoke",
          method: .put,
          parameters: parameters,
          encoding: JSONEncoding.default
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        .value

        await AuthService.shared.signOut()
      },
      signInViaGoogle: { code in
        let parameters: Parameters = [
          "code": code,
          "originatesFromIOS": true,
        ]

        return try await signInPost(
          authMethod: .google,
          endpointPath: "/v1/auth/google/signin",
          parameters: parameters)
      },
      getRewardsProfile: { jwtToken in
        try await authenticatedGet(path: "/v1/rewards/users/me/profile", token: jwtToken)
      },
      getPrizeTiers: {
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/rewards/tiers"

        let response = try await apiSession.request(url)
          .validate(statusCode: 200..<300)
          .serializingDecodable([PrizeTier].self, decoder: isoDecoder)
          .value

        return response
      },
      getUserPrizes: { jwtToken in
        try await authenticatedGet(path: "/v1/rewards/users/me/prizes", token: jwtToken)
      },
      redeemPrize: { jwtToken, prizeId, stationId in
        var params: [String: String] = [:]
        if let stationId { params["stationId"] = stationId }
        return try await authenticatedPost(
          path: "/v1/rewards/users/me/prizes/\(prizeId)/redeem",
          token: jwtToken,
          parameters: params
        )
      },
      updateUser: { jwtToken, firstName, lastName, verifiedEmail in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me"

        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        var params: [String: String] = ["firstName": firstName]
        if let lastName { params["lastName"] = lastName }
        if let verifiedEmail { params["verifiedEmail"] = verifiedEmail }

        let request = apiSession.request(
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
          verifiedEmail: body.verifiedEmail,
          profileImageUrl: body.profileImageUrl,
          role: body.role
        )

        return Auth(currentUser: updatedUser, jwt: newToken)
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

        let response = try await apiSession.request(url)
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
        @Shared(.registeredDeviceId) var registeredDeviceId
        var headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        if let deviceId = registeredDeviceId {
          headers.add(name: "X-Device-Id", value: deviceId)
        }

        let dataResponse = await apiSession.request(
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
        @Shared(.registeredDeviceId) var registeredDeviceId
        var headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        if let deviceId = registeredDeviceId {
          headers.add(name: "X-Device-Id", value: deviceId)
        }
        let parameters = MoveSpinParameters(placeAfterSpinId: placeAfterSpinId)

        let dataResponse = await apiSession.request(
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
        @Shared(.registeredDeviceId) var registeredDeviceId
        var headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        if let deviceId = registeredDeviceId {
          headers.add(name: "X-Device-Id", value: deviceId)
        }
        let parameters: [String: String] = [
          "audioBlockId": audioBlockId,
          "placeAfterSpinId": placeAfterSpinId,
        ]

        let dataResponse = await apiSession.request(
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
          apiSession.upload(fileURL, to: presignedURL, method: .put, headers: headers)
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

        let dataResponse = await apiSession.request(
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

        let response = try await apiSession.request(url, headers: headers)
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
        try await authenticatedGet(
          path: "/v1/songs/search", token: jwtToken, queryParams: ["keywords": keywords]
        )
      },
      searchSongRequests: { jwtToken, keywords in
        try await authenticatedGet(
          path: "/v1/songs/search-song-seeds", token: jwtToken, queryParams: ["keywords": keywords]
        )
      },
      requestSong: { jwtToken, songRequest in
        var parameters: [String: String] = [
          "title": songRequest.title,
          "artist": songRequest.artist,
          "album": songRequest.album,
          "appleId": songRequest.appleId,
          "durationMS": String(songRequest.durationMS),
          "releaseDate": songRequest.releaseDate,
        ]
        if let spotifyId = songRequest.spotifyId { parameters["spotifyId"] = spotifyId }
        if let isrc = songRequest.isrc { parameters["isrc"] = isrc }
        if let popularity = songRequest.popularity { parameters["popularity"] = String(popularity) }
        if let imageUrl = songRequest.imageUrl { parameters["imageUrl"] = imageUrl.absoluteString }
        try await authenticatedPostVoid(
          path: "/v1/songs/requests", token: jwtToken, parameters: parameters
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
      createSupportConversation: { jwtToken in
        try await authenticatedPost(path: "/v1/conversations/support", token: jwtToken)
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
      getIntroPresignedURL: { jwtToken, stationId, filename in
        let url =
          "\(Config.shared.productionBaseUrl.absoluteString)/v1/ios/stations/\(stationId)/source-tapes/presigned-url"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters = ["filename": filename]

        return try await apiSession.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(IntroPresignedURLResponse.self, decoder: isoDecoder)
        .value
      },
      createIntroSourceTape: { jwtToken, stationId, s3Key, name, durationMS, audioBlockId in
        let url =
          "\(Config.shared.productionBaseUrl.absoluteString)/v1/ios/stations/\(stationId)/source-tapes"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        var parameters: [String: any Sendable] = [
          "s3Key": s3Key,
          "name": name,
          "durationMS": durationMS,
        ]
        if let audioBlockId {
          parameters["audioBlockId"] = audioBlockId
        }

        _ = try await apiSession.request(
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
      getStationLibrary: { jwtToken, stationId in
        try await authenticatedGet(
          path: "/v1/stations/\(stationId)/library",
          token: jwtToken,
          queryParams: ["includeSongIntroIds": "true"]
        )
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
          "appleId": body.appleId, "title": body.title, "artist": body.artist,
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
      },
      getArtistRecordingAudioBlockIds: { jwtToken, stationId in
        let url =
          "\(Config.shared.productionBaseUrl.absoluteString)/v1/ios/stations/\(stationId)/source-tapes/audio-block-ids"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        return try await apiSession.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable([String].self)
          .value
      },
      getArtistSuggestions: { jwtToken, search in
        var queryParams: [String: String]?
        if let search, !search.isEmpty { queryParams = ["search": search] }
        return try await authenticatedGet(
          path: "/v1/artist-suggestions", token: jwtToken, queryParams: queryParams)
      },
      createArtistSuggestion: { jwtToken, artistName in
        try await authenticatedPost(
          path: "/v1/artist-suggestions", token: jwtToken,
          parameters: ["artistName": artistName])
      },
      voteForArtistSuggestion: { jwtToken, artistSuggestionId in
        try await authenticatedPostVoid(
          path: "/v1/artist-suggestions/\(artistSuggestionId)/vote", token: jwtToken)
      },
      removeArtistSuggestionVote: { jwtToken, artistSuggestionId in
        try await authenticatedDelete(
          path: "/v1/artist-suggestions/\(artistSuggestionId)/vote", token: jwtToken)
      },
      getAppVersionRequirements: {
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/app-version-requirements"
        return try await apiSession.request(url)
          .validate(statusCode: 200..<300)
          .serializingDecodable(AppVersionRequirements.self)
          .value
      }
    )
  }()
}
