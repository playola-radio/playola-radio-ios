//
//  TrackingService.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import AVFoundation
import Foundation
import Mixpanel

enum TrackingEvent: String {
  case audioOutputChanged = "audio_output_changed"
  case carplayInitialized = "carplay_initialized"
  case stationChanged = "station_changed"
}

class TrackingService {
  public static let shared = TrackingService()

  init() {
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(handleRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    initializeTrackingLibraries()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc func handleRouteChange(notification: Notification) {
    let session = AVAudioSession.sharedInstance()
    let currentRoute = session.currentRoute
    let outputTypes = currentRoute.outputs
      .map(\.portType.rawValue)

    reportEvent(.audioOutputChanged, properties: ["output_types": outputTypes])
  }

  /// Initializes tracking libraries for analytics
  public func initializeTrackingLibraries() {
    Mixpanel.initialize(token: Config.shared.mixpanelToken, trackAutomaticEvents: false)
  }

  /// Reports a tracking event with optional properties
  /// - Parameters:
  ///   - event: The tracking event to report
  ///   - properties: Optional properties dictionary for the event
  func reportEvent(_ event: TrackingEvent, properties: [String: any MixpanelType]? = nil) {
    Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
  }
}
