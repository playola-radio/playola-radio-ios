//
//  AnalyticsEvent.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/14/25.
//

import Foundation
import Mixpanel

// MARK: - Analytics Event

enum AnalyticsEvent: Equatable {
  // MARK: App Lifecycle
  case appOpened(source: AppOpenSource, isFirstOpen: Bool)
  case appBackgrounded
  case appForegrounded

  // MARK: Authentication
  case signInStarted(method: AuthMethod)
  case signInCompleted(method: AuthMethod, userId: String)
  case signInFailed(method: AuthMethod, error: String)
  case signedOut

  // MARK: Station Discovery
  case viewedStationList(listName: String, screen: String)
  case tappedStationCard(station: StationInfo, position: Int, totalStations: Int)
  case viewedStationDetail(station: StationInfo)

  // MARK: Playback
  case startedStation(station: StationInfo, entryPoint: String)
  case listeningSessionStarted(station: StationInfo)
  case listeningSessionEnded(station: StationInfo, sessionLengthSec: Int)
  case switchedStation(
    from: StationInfo, to: StationInfo, timeBeforeSwitchSec: Int, reason: SwitchReason)
  case playbackError(station: StationInfo, error: String)

  // MARK: Rewards
  case viewedRewardsScreen(currentHours: Double)
  case tappedRedeemRewards(currentHours: Double)
  case unlockedRewardTier(tierName: String, hoursRequired: Int)
  case navigatedToRewardsFromListeningTile

  // MARK: Profile
  case viewedProfile
  case updatedProfile(fields: [String])
  case uploadedProfilePhoto

  // MARK: Broadcasting
  case viewedBroadcastScreen(stationId: String, stationName: String, userName: String)
  case broadcastNotificationSent(
    stationId: String, stationName: String, userName: String, messageLength: Int)
  case broadcastVoicetrackRecorded(stationId: String, stationName: String, userName: String)
  case broadcastVoicetrackUploaded(stationId: String, stationName: String, userName: String)
  case broadcastSongSearchTapped(stationId: String, stationName: String, userName: String)
  case broadcastSongAdded(
    stationId: String, stationName: String, userName: String, songTitle: String, artistName: String)

  // MARK: Engagement
  case audioOutputChanged(outputTypes: [String])
  case carPlayInitialized
  case stationChanged(from: String?, to: String)
  case notifyMeRequested(showId: String, showName: String, stationName: String)

  // MARK: Errors
  case apiError(endpoint: String, error: String)

  // MARK: App Rating
  case ratingPromptEnjoying
  case ratingPromptNotEnjoying
  case ratingPromptDismissed
  case feedbackSheetPresented
}

// MARK: - Event Properties

extension AnalyticsEvent {
  var name: String {
    switch self {
    case .appOpened: return "App Opened"
    case .appBackgrounded: return "App Backgrounded"
    case .appForegrounded: return "App Foregrounded"
    case .signInStarted: return "Sign In Started"
    case .signInCompleted: return "Sign In Completed"
    case .signInFailed: return "Sign In Failed"
    case .signedOut: return "Signed Out"
    case .viewedStationList: return "Viewed Station List"
    case .tappedStationCard: return "Tapped Station Card"
    case .viewedStationDetail: return "Viewed Station Detail"
    case .startedStation: return "Started Station"
    case .listeningSessionStarted: return "Listening Session Started"
    case .listeningSessionEnded: return "Listening Session Ended"
    case .switchedStation: return "Switched Station"
    case .playbackError: return "Playback Error"
    case .viewedRewardsScreen: return "Viewed Rewards Screen"
    case .tappedRedeemRewards: return "Tapped Redeem Rewards"
    case .unlockedRewardTier: return "Unlocked Reward Tier"
    case .navigatedToRewardsFromListeningTile: return "Navigated To Rewards From Listening Tile"
    case .viewedProfile: return "Viewed Profile"
    case .updatedProfile: return "Updated Profile"
    case .uploadedProfilePhoto: return "Uploaded Profile Photo"
    case .viewedBroadcastScreen: return "Viewed Broadcast Screen"
    case .broadcastNotificationSent: return "Broadcast Notification Sent"
    case .broadcastVoicetrackRecorded: return "Broadcast Voicetrack Recorded"
    case .broadcastVoicetrackUploaded: return "Broadcast Voicetrack Uploaded"
    case .broadcastSongSearchTapped: return "Broadcast Song Search Tapped"
    case .broadcastSongAdded: return "Broadcast Song Added"
    case .audioOutputChanged: return "Audio Output Changed"
    case .carPlayInitialized: return "CarPlay Initialized"
    case .stationChanged: return "Station Changed"
    case .notifyMeRequested: return "Notify Me Requested"
    case .apiError: return "API Error"
    case .ratingPromptEnjoying: return "Rating Prompt Enjoying"
    case .ratingPromptNotEnjoying: return "Rating Prompt Not Enjoying"
    case .ratingPromptDismissed: return "Rating Prompt Dismissed"
    case .feedbackSheetPresented: return "Feedback Sheet Presented"
    }
  }

  var properties: [String: any MixpanelType] {
    switch self {
    case .appOpened(let source, let isFirstOpen):
      return [
        "source": source.rawValue,
        "is_first_open": isFirstOpen,
      ]

    case .appBackgrounded, .appForegrounded:
      return [:]

    case .signInStarted(let method):
      return ["method": method.rawValue]

    case .signInCompleted(let method, let userId):
      return [
        "method": method.rawValue,
        "user_id": userId,
      ]

    case .signInFailed(let method, let error):
      return [
        "method": method.rawValue,
        "error": error,
      ]

    case .signedOut:
      return [:]

    case .viewedStationList(let listName, let screen):
      return [
        "list_name": listName,
        "screen": screen,
      ]

    case .tappedStationCard(let station, let position, let totalStations):
      var props = station.properties
      props["station_position"] = position
      props["station_count"] = totalStations
      return props

    case .viewedStationDetail(let station):
      return station.properties

    case .startedStation(let station, let entryPoint):
      var props = station.properties
      props["entry_point"] = entryPoint
      return props

    case .listeningSessionStarted(let station):
      return station.properties

    case .listeningSessionEnded(let station, let sessionLengthSec):
      var props = station.properties
      props["session_length_sec"] = sessionLengthSec
      return props

    case .switchedStation(let from, let to, let timeBeforeSwitchSec, let reason):
      return [
        "from_station_id": from.id,
        "from_station_name": from.name,
        "from_station_type": from.type,
        "to_station_id": to.id,
        "to_station_name": to.name,
        "to_station_type": to.type,
        "time_listened_before_switch_sec": timeBeforeSwitchSec,
        "switch_reason": reason.rawValue,
      ]

    case .playbackError(let station, let error):
      var props = station.properties
      props["error"] = error
      return props

    case .viewedRewardsScreen(let currentHours):
      return ["current_hours": currentHours]

    case .tappedRedeemRewards(let currentHours):
      return ["current_hours": currentHours]

    case .unlockedRewardTier(let tierName, let hoursRequired):
      return [
        "tier_name": tierName,
        "hours_required": hoursRequired,
      ]

    case .navigatedToRewardsFromListeningTile:
      return [:]

    case .viewedProfile:
      return [:]

    case .updatedProfile(let fields):
      return ["updated_fields": fields.joined(separator: ",")]

    case .uploadedProfilePhoto:
      return [:]

    case .viewedBroadcastScreen(let stationId, let stationName, let userName):
      return [
        "station_id": stationId,
        "station_name": stationName,
        "user_name": userName,
      ]

    case .broadcastNotificationSent(let stationId, let stationName, let userName, let messageLength):
      return [
        "station_id": stationId,
        "station_name": stationName,
        "user_name": userName,
        "message_length": messageLength,
      ]

    case .broadcastVoicetrackRecorded(let stationId, let stationName, let userName):
      return [
        "station_id": stationId,
        "station_name": stationName,
        "user_name": userName,
      ]

    case .broadcastVoicetrackUploaded(let stationId, let stationName, let userName):
      return [
        "station_id": stationId,
        "station_name": stationName,
        "user_name": userName,
      ]

    case .broadcastSongSearchTapped(let stationId, let stationName, let userName):
      return [
        "station_id": stationId,
        "station_name": stationName,
        "user_name": userName,
      ]

    case .broadcastSongAdded(
      let stationId, let stationName, let userName, let songTitle, let artistName):
      return [
        "station_id": stationId,
        "station_name": stationName,
        "user_name": userName,
        "song_title": songTitle,
        "artist_name": artistName,
      ]

    case .audioOutputChanged(let outputTypes):
      return ["output_types": outputTypes]

    case .carPlayInitialized:
      return [:]

    case .stationChanged(let from, let to):
      var props: [String: any MixpanelType] = ["to": to]
      if let from = from {
        props["from"] = from
      }
      return props

    case .notifyMeRequested(let showId, let showName, let stationName):
      return [
        "show_id": showId,
        "show_name": showName,
        "station_name": stationName,
      ]

    case .apiError(let endpoint, let error):
      return [
        "endpoint": endpoint,
        "error": error,
      ]

    case .ratingPromptEnjoying, .ratingPromptNotEnjoying, .ratingPromptDismissed,
      .feedbackSheetPresented:
      return [:]
    }
  }
}

// MARK: - Supporting Types

enum AppOpenSource: String {
  case direct = "direct"
  case pushNotification = "push_notification"
  case sharedLink = "shared_link"
  case deepLink = "deep_link"
}

enum AuthMethod: String {
  case apple
  case google
}

enum StationListType: String {
  case all
  case artists
  case fm
  case featured
}

enum SwitchReason: String {
  case userInitiated = "user_initiated"
  case error
  case connectionLost = "connection_lost"
}

// MARK: - Station Info Helper

struct StationInfo: Equatable {
  let id: String
  let name: String
  let type: String

  var properties: [String: any MixpanelType] {
    return [
      "station_id": id,
      "station_name": name,
      "station_type": type,
    ]
  }

  init(from station: AnyStation) {
    self.id = station.id
    self.name = station.name
    switch station {
    case .playola:
      self.type = "artist"
    case .url:
      self.type = "fm"
    }
  }
}
