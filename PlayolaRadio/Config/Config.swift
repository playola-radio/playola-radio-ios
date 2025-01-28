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

  let environment: DevelopmentEnvironment = DevelopmentEnvironment(rawValue: Config.get("DEV_ENVIRONMENT", varType: String.self))!
  let mixpanelToken: String = Config.get("MIXPANEL_TOKEN", varType: String.self)
  let heapAppID: String = Config.get("HEAP_APP_ID", varType: String.self)

  var baseUrl: String {
    switch environment {
    case .local:
      return "http://localhost:10020"
    case .development, .production:
      return "https://admin-api.playola.fm"
    }
  }

  static func get<T>(_ environmentVarName: String, varType: T.Type) -> T {
    guard let token = Bundle.main.infoDictionary?[environmentVarName] as? T else {
      fatalError("Environment Variable \(environmentVarName) not initialized")
    }
    return token
  }
}

enum DevelopmentEnvironment: String {
  case local = "local"
  case development = "development"
  case production = "production"
}
