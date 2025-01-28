//
//  UIApplication+keyWindow.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/28/25.
//
import Foundation
import SwiftUI

extension UIApplication {
  public var keyWindow: UIWindow? {
    return Self
      .shared
      .connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .last { $0.isKeyWindow }
  }

  public var keyWindowPresentedController: UIViewController? {
    var viewController = self.keyWindow?.rootViewController

    if let presentedController = viewController as? UITabBarController {
      viewController = presentedController.selectedViewController
    }

    // Go deeper to find the last presented `UIViewController`
    while let presentedController = viewController?.presentedViewController {
      if let presentedController = presentedController as? UITabBarController {
        viewController = presentedController.selectedViewController
      } else {
        viewController = presentedController
      }
    }
    return viewController
  }
}
