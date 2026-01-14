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

  /// Fetches airings (scheduled broadcasts of episodes)
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: Optional station ID to filter by specific station
  /// - Returns: Array of Airing objects with nested episode, show, and station data
  /// - Throws: APIError if the request fails
  var getAirings: (_ jwtToken: String, _ stationId: String?) async throws -> [Airing] =
    { _, _ in [] }

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
        PresignedURLResponse(
          presignedUrl: URL(string: "https://example.com")!,
          s3Key: "test.m4a",
          voicetrackUrl: URL(string: "https://example.com/test.m4a")!
        )
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

  /// Checks if a voicetrack file has been normalized and is ready in the voicetracks bucket
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID
  ///   - s3Key: The S3 key to check
  /// - Returns: VoicetrackStatusResponse indicating if the file is ready
  /// - Throws: APIError if the request fails
  var getVoicetrackStatus:
    (_ jwtToken: String, _ stationId: String, _ s3Key: String) async throws
      -> VoicetrackStatusResponse = { _, _, _ in
        VoicetrackStatusResponse(ready: true, s3Key: "test.m4a")
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

  /// Searches for song requests by keywords
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - keywords: The search keywords
  /// - Returns: Array of SongRequests matching the search
  /// - Throws: APIError if the request fails
  var searchSongRequests: (_ jwtToken: String, _ keywords: String) async throws -> [SongRequest] = {
    _, _ in
    []
  }

  /// Requests a song to be added to the library
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - spotifyId: The Spotify ID of the song to request
  /// - Throws: APIError if the request fails
  var requestSong: (_ jwtToken: String, _ spotifyId: String) async throws -> Void = { _, _ in }

  /// Registers a device for push notifications
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - deviceToken: The APNs device token as a hex string
  ///   - platform: The platform (ios or android)
  ///   - appVersion: The app version string
  /// - Returns: RegisteredDevice containing the device ID
  /// - Throws: APIError if the request fails
  var registerDevice:
    (_ jwtToken: String, _ deviceToken: String, _ platform: String, _ appVersion: String)
      async throws
      -> RegisteredDevice = { _, _, _, _ in
        RegisteredDevice(id: "", deviceToken: "", platform: "ios", isActive: true)
      }

  /// Unregisters a device from push notifications
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - deviceId: The device ID to unregister
  /// - Throws: APIError if the request fails
  var unregisterDevice: (_ jwtToken: String, _ deviceId: String) async throws -> Void = { _, _ in }

  /// Sends a push notification to all listeners of a station
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID to send notification for
  ///   - message: The notification message
  /// - Throws: APIError if the request fails
  var sendStationNotification:
    (_ jwtToken: String, _ stationId: String, _ message: String) async throws -> Void = { _, _, _ in
    }

  /// Fetches all push notification subscriptions for the current user
  /// - Parameter jwtToken: The JWT token for authentication
  /// - Returns: Array of PushNotificationSubscriptionWithStation objects
  /// - Throws: APIError if the request fails
  var getPushNotificationSubscriptions:
    (_ jwtToken: String) async throws -> [PushNotificationSubscriptionWithStation] = { _ in [] }

  /// Subscribes to push notifications for a station
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID to subscribe to
  /// - Returns: The updated PushNotificationSubscription
  /// - Throws: APIError if the request fails
  var subscribeToStationNotifications:
    (_ jwtToken: String, _ stationId: String) async throws -> PushNotificationSubscription = {
      _, _ in
      PushNotificationSubscription(
        id: "",
        userId: "",
        stationId: "",
        isSubscribed: true,
        optedOutAt: nil,
        autoSubscribedAt: nil,
        manualSubscribedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    }

  /// Unsubscribes from push notifications for a station
  /// - Parameters:
  ///   - jwtToken: The JWT token for authentication
  ///   - stationId: The station ID to unsubscribe from
  /// - Returns: The updated PushNotificationSubscription
  /// - Throws: APIError if the request fails
  var unsubscribeFromStationNotifications:
    (_ jwtToken: String, _ stationId: String) async throws -> PushNotificationSubscription = {
      _, _ in
      PushNotificationSubscription(
        id: "",
        userId: "",
        stationId: "",
        isSubscribed: false,
        optedOutAt: nil,
        autoSubscribedAt: nil,
        manualSubscribedAt: nil,
        createdAt: Date(),
        updatedAt: Date()
      )
    }

  /// Fetches currently live stations
  /// - Returns: Array of LiveStationInfo containing stations that are currently live
  /// - Throws: APIError if the request fails
  var fetchLiveStations: () async throws -> [LiveStationInfo] = { [] }
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

struct RegisteredDevice: Decodable, Equatable {
  let id: String
  let deviceToken: String
  let platform: String
  let isActive: Bool
}
