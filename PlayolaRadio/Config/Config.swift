//
//  Config.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/19/25.
//
import Combine
import UIKit
import Foundation

class Config {
    public static let shared = Config()

    let environment: DevelopmentEnvironment
    let mixpanelToken: String
    let heapAppID: String

    var baseUrl: URL {
        switch environment {
        case .local:
          return URL(string: "http://localhost:10020")!
        case .development, .production:
          return URL(string: "https://admin-api.playola.fm")!
        }
    }

    private init() {
        self.environment = .init(rawValue: Config.get("DEV_ENVIRONMENT", varType: String.self))!
        self.mixpanelToken = Config.get("MIXPANEL_TOKEN", varType: String.self)
        self.heapAppID = Config.get("HEAP_APP_ID", varType: String.self)
    }

    static func get<T>(_ environmentVarName: String, varType _: T.Type) -> T {
        guard let token = Bundle.main.infoDictionary?[environmentVarName] as? T else {
            fatalError("Environment Variable \(environmentVarName) not initialized")
        }
        return token
    }
}

enum DevelopmentEnvironment: String {
    case local
    case development
    case production
}
