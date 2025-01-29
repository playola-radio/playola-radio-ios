//
//  UIApplication+keyWindow.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/28/25.
//
import Foundation
import SwiftUI

public extension UIApplication {
    var keyWindow: UIWindow? {
        Self
            .shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .last { $0.isKeyWindow }
    }

    var keyWindowPresentedController: UIViewController? {
        var viewController = keyWindow?.rootViewController

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
