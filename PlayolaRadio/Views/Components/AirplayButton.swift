//
//  AirplayButton.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/15/24.
//

import AVKit
import Foundation
import SwiftUI
import UIKit

struct AirPlayView: UIViewRepresentable {
    func makeUIView(context _: Context) -> UIView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.activeTintColor = .white
        routePickerView.tintColor = .gray
        return routePickerView
    }

    func updateUIView(_: UIView, context _: Context) {}
}
