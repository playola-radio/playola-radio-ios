//
//  NavigationCoordinator.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/21/25.
//
import SwiftUI

@Observable
class NavigationCoordinator {
    static let shared = NavigationCoordinator()
    var path: [Path] = []

    enum Path: Hashable {
        case stationListPage(StationListModel)
        case aboutPage(AboutPageModel)
        case nowPlayingPage(NowPlayingPageModel)
    }
}
