//
//  Config.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import Combine
import UIKit

class Config: ObservableObject {
    public static let shared = Config()

    var debugLog = true

    let mixpanelToken: String = {
        guard let token = Bundle.main.infoDictionary?["MIXPANEL_TOKEN"] as? String,
              !token.isEmpty else {
            fatalError("Environment Variable MIXPANEL_TOKEN not initialized")
        }
        return token
    }()

    let heapAppID: String = {
        guard let token = Bundle.main.infoDictionary?["HEAP_APP_ID"] as? String,
              !token.isEmpty else {
            fatalError("Environment Variable HEAP_APP_ID not initialized")
        }
        return token
    }()

//    // unused but leaving as an example of how to use future config
//    @Published public var showInDevelopmentStations:Bool! = UserDefaults.standard.bool(forKey: Config.developmentStationsKey) {
//        didSet {
//            UserDefaults.standard.setValue(showInDevelopmentStations, forKey: Config.developmentStationsKey)
//            StationsManager.shared.loadStations()
//        }
//    }

    init(debugLog: Bool = true) {
        self.debugLog = debugLog
    }
}
