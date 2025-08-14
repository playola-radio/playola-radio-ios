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
  case viewedStationList(listType: StationListType, screen: String)
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

  // MARK: Engagement
  case audioOutputChanged(outputTypes: [String])
  case carPlayInitialized
  case stationChanged(from: String?, to: String)

  // MARK: Errors
  case apiError(endpoint: String, error: String)
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
    case .audioOutputChanged: return "Audio Output Changed"
    case .carPlayInitialized: return "CarPlay Initialized"
    case .stationChanged: return "Station Changed"
    case .apiError: return "API Error"
    }
  }

  var properties: [String: any MixpanelType] {
    switch self {
    case let .appOpened(source, isFirstOpen):
      return [
        "source": source.rawValue,
        "is_first_open": isFirstOpen,
      ]

    case .appBackgrounded, .appForegrounded:
      return [:]

    case let .signInStarted(method):
      return ["method": method.rawValue]

    case let .signInCompleted(method, userId):
      return [
        "method": method.rawValue,
        "user_id": userId,
      ]

    case let .signInFailed(method, error):
      return [
        "method": method.rawValue,
        "error": error,
      ]

    case .signedOut:
      return [:]

    case let .viewedStationList(listType, screen):
      return [
        "list_type": listType.rawValue,
        "screen": screen,
      ]

    case let .tappedStationCard(station, position, totalStations):
      var props = station.properties
      props["station_position"] = position
      props["station_count"] = totalStations
      return props

    case let .viewedStationDetail(station):
      return station.properties

    case let .startedStation(station, entryPoint):
      var props = station.properties
      props["entry_point"] = entryPoint
      return props

    case let .listeningSessionStarted(station):
      return station.properties

    case let .listeningSessionEnded(station, sessionLengthSec):
      var props = station.properties
      props["session_length_sec"] = sessionLengthSec
      return props

    case let .switchedStation(from, to, timeBeforeSwitchSec, reason):
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

    case let .playbackError(station, error):
      var props = station.properties
      props["error"] = error
      return props

    case let .viewedRewardsScreen(currentHours):
      return ["current_hours": currentHours]

    case let .tappedRedeemRewards(currentHours):
      return ["current_hours": currentHours]

    case let .unlockedRewardTier(tierName, hoursRequired):
      return [
        "tier_name": tierName,
        "hours_required": hoursRequired,
      ]

    case .navigatedToRewardsFromListeningTile:
      return [:]

    case .viewedProfile:
      return [:]

    case let .updatedProfile(fields):
      return ["updated_fields": fields.joined(separator: ",")]

    case .uploadedProfilePhoto:
      return [:]

    case let .audioOutputChanged(outputTypes):
      return ["output_types": outputTypes]

    case .carPlayInitialized:
      return [:]

    case let .stationChanged(from, to):
      var props: [String: any MixpanelType] = ["to": to]
      if let from = from {
        props["from"] = from
      }
      return props

    case let .apiError(endpoint, error):
      return [
        "endpoint": endpoint,
        "error": error,
      ]
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

  init(from station: RadioStation) {
    self.id = station.id
    self.name = station.name
    self.type = station.type.rawValue
  }
}
