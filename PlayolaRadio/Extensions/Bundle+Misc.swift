//
//  Bundle+Misc.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/6/24.
//

import Foundation
import UIKit

extension Bundle {
  var appName: String {
    object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
    object(forInfoDictionaryKey: "CFBundleName") as? String ??
    ""
  }

  var releaseVersionNumber: String? {
    return infoDictionary?["CFBundleShortVersionString"] as? String
  }

  var buildVersionNumber: String? {
    return infoDictionary?["CFBundleVersion"] as? String
  }
  
  public var appIconLarge: UIImage? {
    if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
       let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
       let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
       let lastIcon = iconFiles.last {
      return UIImage(named: lastIcon)
    }
    return nil
  }
}
