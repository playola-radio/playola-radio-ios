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
  }

  // MARK: - Dependencies

  @ObservationIgnored @Dependency(\.continuousClock) var clock
  @ObservationIgnored @Dependency(\.uuid) var uuid

  // MARK: - Properties

  var banner: Banner?
  @ObservationIgnored private var onTap: @MainActor () -> Void = {}

  let displayDuration = Duration.seconds(5)
  private let dismissDragDistance: CGFloat = 20

  // MARK: - User Actions

  func bannerTapped() {
    let onTap = onTap
    hide()
    onTap()
  }

  func bannerDragEnded(verticalTranslation: CGFloat) {
    guard verticalTranslation < -dismissDragDistance else { return }
    hide()
  }

  func bannerAppeared() async {
    let shownBanner = banner
    do {
      try await clock.sleep(for: displayDuration)
    } catch {
      return
    }
    guard banner == shownBanner else { return }
    hide()
  }

  // MARK: - View Helpers

  var visibleBanners: [Banner] { banner.map { [$0] } ?? [] }

  // MARK: - Presentation

  func show(title: String, body: String, onTap: @escaping @MainActor () -> Void) {
    banner = Banner(id: uuid(), title: title, body: body)
    self.onTap = onTap
  }

  func hide() {
    banner = nil
    onTap = {}
  }
}
