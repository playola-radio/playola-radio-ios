//
//  UpsideDownNotificationBannerModel.swift
//  PlayolaRadio
//

import Dependencies
import Foundation
import Observation

/// An in-app copy of a Playola notification, shown while the app is flipped upside down, where
/// the system banner would appear right-side up.
@MainActor
@Observable
final class UpsideDownNotificationBannerModel: ViewModel {
  struct Banner: Equatable, Identifiable {
    let id: UUID
    let title: String
    let body: String

    /// The system banner is announced to VoiceOver; the copy has to announce itself.
    var accessibilityAnnouncement: String { "\(title). \(body)" }
  }

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.uuid) var uuid

  // MARK: - Properties

  /// Notifications arriving while one is showing wait their turn, since their system banners
  /// were already suppressed.
  private var queue: [(banner: Banner, onTap: @MainActor () -> Void)] = []
  var banner: Banner? { queue.first?.banner }

  let displayDuration = Duration.seconds(5)
  private let dismissDragDistance: CGFloat = 20

  // MARK: - User Actions

  func bannerTapped() {
    guard let onTap = queue.first?.onTap else { return }
    dismissCurrentBanner()
    onTap()
  }

  func bannerDragEnded(verticalTranslation: CGFloat) {
    guard verticalTranslation < -dismissDragDistance else { return }
    dismissCurrentBanner()
  }

  func bannerAppeared() async {
    let shownBanner = banner
    do {
      try await clock.sleep(for: displayDuration)
    } catch {
      return
    }
    guard banner == shownBanner else { return }
    dismissCurrentBanner()
  }

  // MARK: - View Helpers

  var visibleBanners: [Banner] { banner.map { [$0] } ?? [] }

  // MARK: - Presentation

  func show(title: String, body: String, onTap: @escaping @MainActor () -> Void) {
    queue.append((Banner(id: uuid(), title: title, body: body), onTap))
  }

  func hideAll() {
    queue = []
  }

  // MARK: - Private Helpers

  private func dismissCurrentBanner() {
    guard !queue.isEmpty else { return }
    queue.removeFirst()
  }
}
