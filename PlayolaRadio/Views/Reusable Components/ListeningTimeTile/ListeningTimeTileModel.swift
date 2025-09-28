//
//  ListeningTimeTileModel.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Combine
import Dependencies
import Sharing
import SwiftUI

@MainActor
@Observable
class ListeningTimeTileModel: ViewModel {
    @ObservationIgnored @Shared(.listeningTracker) var listeningTracker: ListeningTracker?
    @ObservationIgnored @Dependency(\.continuousClock) var clock

    var totalListeningTime: Int = 0

    var buttonText: String?
    var buttonAction: (() async -> Void)?

    init(buttonText: String? = nil, buttonAction: (() async -> Void)? = nil) {
        self.buttonText = buttonText
        self.buttonAction = buttonAction
        super.init()
    }

    private var hourString: String {
        let totalSeconds = totalListeningTime / 1000
        let hours = totalSeconds / 3600
        return String(format: "%02d", hours)
    }

    private var minString: String {
        let totalSeconds = totalListeningTime / 1000
        let minutes = (totalSeconds % 3600) / 60
        return String(format: "%02d", minutes)
    }

    private var secString: String {
        let totalSeconds = totalListeningTime / 1000
        let seconds = totalSeconds % 60
        return String(format: "%02d", seconds)
    }

    var listeningTimeDisplayString: String {
        return "\(hourString)h \(minString)m \(secString)s"
    }

    private var refreshTask: Task<Void, Never>?

    func viewAppeared() {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                if let ms = listeningTracker?.totalListenTimeMS {
                    totalListeningTime = ms
                } else {
                    print("Tracker missing or zero")
                    totalListeningTime = 0
                }

                try? await clock.sleep(for: .seconds(1))
            }
        }
    }

    func onButtonTapped() async {
        await buttonAction?()
    }

    func viewDisappeared() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
