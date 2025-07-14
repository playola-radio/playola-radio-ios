//
//  Bundle+Misc.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/6/24.
//

import Foundation

extension Bundle {
  var appName: String {
    object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
    object(forInfoDictionaryKey: "CFBundleName") as? String ??
    ""
  }
  
  var releaseVersionNumber: String? {
    infoDictionary?["CFBundleShortVersionString"] as? String
  }
  
  var buildVersionNumber: String? {
    infoDictionary?["CFBundleVersion"] as? String
  }
}
