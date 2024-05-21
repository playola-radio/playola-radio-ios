//
//  AirplayButton.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/15/24.
//

import SwiftUI
import UIKit
import Foundation
import AVKit

struct AirPlayView: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let routePickerView = AVRoutePickerView()
    routePickerView.backgroundColor = .clear
    routePickerView.activeTintColor = .white
    routePickerView.tintColor = .gray
    return routePickerView
  }
  
  func updateUIView(_ uiView: UIView, context: Context) {
  }
}
