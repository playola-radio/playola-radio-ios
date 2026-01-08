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
      },
      searchSongRequests: { jwtToken, keywords in
        let encodedKeywords =
          keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/songs/search-song-seeds?keywords=\(encodedKeywords)"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable([SongRequest].self, decoder: isoDecoder)
          .value

        return response
      },
      requestSong: { jwtToken, spotifyId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/songs/requests"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters = ["spotifyId": spotifyId]

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
      registerDevice: { jwtToken, deviceToken, platform, appVersion in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/devices"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters: [String: String] = [
          "deviceToken": deviceToken,
          "platform": platform,
          "appVersion": appVersion,
        ]

        let response = try await AF.request(
          url,
          method: .post,
          parameters: parameters,
          encoding: JSONEncoding.default,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(RegisteredDevice.self, decoder: JSONDecoderWithIsoFull())
        .value

        return response
      },
      unregisterDevice: { jwtToken, deviceId in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/users/me/devices/\(deviceId)"
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
      sendStationNotification: { jwtToken, stationId, message in
        let url = "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/notifications"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]
        let parameters: [String: String] = ["message": message]

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
      getPushNotificationSubscriptions: { jwtToken in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/users/me/push-notification-subscriptions"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(url, headers: headers)
          .validate(statusCode: 200..<300)
          .serializingDecodable(
            [PushNotificationSubscriptionWithStation].self, decoder: isoDecoder
          )
          .value

        return response
      },
      subscribeToStationNotifications: { jwtToken, stationId in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/push-notification-subscription/subscribe"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          method: .post,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(PushNotificationSubscription.self, decoder: isoDecoder)
        .value

        return response
      },
      unsubscribeFromStationNotifications: { jwtToken, stationId in
        let url =
          "\(Config.shared.baseUrl.absoluteString)/v1/stations/\(stationId)/push-notification-subscription/unsubscribe"
        let headers: HTTPHeaders = ["Authorization": "Bearer \(jwtToken)"]

        let response = try await AF.request(
          url,
          method: .post,
          headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(PushNotificationSubscription.self, decoder: isoDecoder)
        .value

        return response
      }
    )
  }()
}
