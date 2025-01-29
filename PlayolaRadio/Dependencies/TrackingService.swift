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
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
        initializeTrackingLibraries()
    }

    @objc func handleRouteChange(notification _: Notification) {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        let outputTypes = currentRoute.outputs
            .map(\.portType.rawValue)

        reportEvent(.audioOutputChanged, properties: ["output_types": outputTypes])
    }

    public func initializeTrackingLibraries() {
        Mixpanel.initialize(token: Config.shared.mixpanelToken, trackAutomaticEvents: false)

//        Heap.shared.startRecording(Config.shared.heapToken)
//        Heap.iOSAutocaptureSource.register(isDefault: true)
    }

    func reportEvent(_ event: TrackingEvent, properties: [String: any MixpanelType]? = nil) {
        Mixpanel.mainInstance().track(event: event.rawValue, properties: properties)
    }
}
