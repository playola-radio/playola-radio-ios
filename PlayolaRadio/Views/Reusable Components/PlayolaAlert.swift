//
//  PlayolaAlert.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/16/25.
//

import SwiftUI

@MainActor
class PlayolaAlert: Equatable, Identifiable, Hashable {
  static func == (lhs: PlayolaAlert, rhs: PlayolaAlert) -> Bool {
    lhs.title == rhs.title && lhs.message == rhs.message
  }

  let title: String
  let message: String?
  let dismissButton: Alert.Button?
  let secondaryButton: Alert.Button?
  let primaryButtonText: String?
  let secondaryButtonText: String?
  let tertiaryButtonText: String?
  let primaryAction: (() async -> Void)?
  let secondaryAction: (() async -> Void)?
  let tertiaryAction: (() async -> Void)?

  init(
    title: String,
    message: String?,
    dismissButton: Alert.Button?,
    secondaryButton: Alert.Button? = nil
  ) {
    self.title = title
    self.message = message
    self.dismissButton = dismissButton
    self.secondaryButton = secondaryButton
    self.primaryButtonText = nil
    self.secondaryButtonText = nil
    self.tertiaryButtonText = nil
    self.primaryAction = nil
    self.secondaryAction = nil
    self.tertiaryAction = nil
  }

  init(
    title: String,
    message: String?,
    primaryButtonText: String,
    primaryAction: @escaping () async -> Void,
    secondaryButtonText: String,
    secondaryAction: (() async -> Void)? = nil
  ) {
    self.title = title
    self.message = message
    self.dismissButton = nil
    self.secondaryButton = nil
    self.primaryButtonText = primaryButtonText
    self.secondaryButtonText = secondaryButtonText
    self.tertiaryButtonText = nil
    self.primaryAction = primaryAction
    self.secondaryAction = secondaryAction
    self.tertiaryAction = nil
  }

  init(
    title: String,
    message: String?,
    primaryButtonText: String,
    primaryAction: @escaping () async -> Void,
    secondaryButtonText: String,
    secondaryAction: @escaping () async -> Void,
    tertiaryButtonText: String,
    tertiaryAction: @escaping () async -> Void
  ) {
    self.title = title
    self.message = message
    self.dismissButton = nil
    self.secondaryButton = nil
    self.primaryButtonText = primaryButtonText
    self.secondaryButtonText = secondaryButtonText
    self.tertiaryButtonText = tertiaryButtonText
    self.primaryAction = primaryAction
    self.secondaryAction = secondaryAction
    self.tertiaryAction = tertiaryAction
  }

  var hasThreeButtons: Bool {
    tertiaryButtonText != nil
  }

  var alert: Alert {
    var messageView: Text?
    if let message {
      messageView = Text(message)
    }

    if let primaryText = primaryButtonText, let secondaryText = secondaryButtonText {
      return Alert(
        title: Text(title),
        message: messageView,
        primaryButton: .default(Text(primaryText)) {
          Task { await self.primaryAction?() }
        },
        secondaryButton: .cancel(Text(secondaryText)) {
          Task { await self.secondaryAction?() }
        }
      )
    } else if let secondaryButton = secondaryButton, let dismissButton = dismissButton {
      return Alert(
        title: Text(title),
        message: messageView,
        primaryButton: dismissButton,
        secondaryButton: secondaryButton
      )
    } else {
      return Alert(title: Text(title), message: messageView, dismissButton: dismissButton)
    }
  }

  @ViewBuilder
  var alertButtons: some View {
    if let primaryText = primaryButtonText {
      Button(primaryText) {
        Task { await self.primaryAction?() }
      }
    }
    if let secondaryText = secondaryButtonText {
      Button(secondaryText) {
        Task { await self.secondaryAction?() }
      }
    }
    if let tertiaryText = tertiaryButtonText {
      Button(tertiaryText, role: .cancel) {
        Task { await self.tertiaryAction?() }
      }
    }
    let hasNoCustomButtons =
      primaryButtonText == nil && secondaryButtonText == nil && tertiaryButtonText == nil
    if dismissButton != nil || hasNoCustomButtons {
      Button("OK", role: .cancel) {}
    }
  }

  @ViewBuilder
  var alertMessage: some View {
    if let message {
      Text(message)
    }
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(title)
    hasher.combine(message)
  }
}

extension View {
  func playolaAlert(_ alert: Binding<PlayolaAlert?>) -> some View {
    self.alert(
      alert.wrappedValue?.title ?? "",
      isPresented: Binding(
        get: { alert.wrappedValue != nil },
        set: { if !$0 { alert.wrappedValue = nil } }
      ),
      presenting: alert.wrappedValue,
      actions: { $0.alertButtons },
      message: { $0.alertMessage }
    )
  }
}

extension PlayolaAlert {
  static var cannotOpenMailAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Error Opening Mail",
      message: "There was an error opening the email program",
      dismissButton: .cancel(Text("OK")))
  }

  static var secretStationsTurnedOnAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Congratulations",
      message: "Secret Stations Unlocked",
      dismissButton: .cancel(Text("OK")))
  }

  static var secretStationsHiddenAlert: PlayolaAlert {
    PlayolaAlert(
      title: "Secret Stations",
      message: "Secret Stations Hidden",
      dismissButton: .cancel(Text("OK")))
  }

  static var errorLoadingStation: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "Error loading station",
      dismissButton: .cancel(Text("OK")))
  }

  static var notificationsDisabled: PlayolaAlert {
    PlayolaAlert(
      title: "Notifications Disabled",
      message:
        "If you'd like to receive notifications for this, please turn on notifications in your settings.",
      dismissButton: .cancel(Text("OK")),
      secondaryButton: .default(
        Text("Settings"),
        action: {
          if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
          }
        })
    )
  }

  static var notificationScheduled: PlayolaAlert {
    PlayolaAlert(
      title: "Reminder Set",
      message: "You'll be notified when this show is about to start!",
      dismissButton: .cancel(Text("OK")))
  }

  static var errorSchedulingNotification: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "There was an error scheduling your notification. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }

  static func ratingPrompt(
    onEnjoying: @escaping () async -> Void,
    onNotEnjoying: @escaping () async -> Void,
    onNotNow: @escaping () async -> Void
  ) -> PlayolaAlert {
    PlayolaAlert(
      title: "Are you enjoying Playola Radio?",
      message: nil,
      primaryButtonText: "Yes!",
      primaryAction: onEnjoying,
      secondaryButtonText: "Not really",
      secondaryAction: onNotEnjoying,
      tertiaryButtonText: "Not now",
      tertiaryAction: onNotNow
    )
  }

  static var errorCreatingReferralCode: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "There was an error creating your invite link. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }

  static var errorRedeemingPrize: PlayolaAlert {
    PlayolaAlert(
      title: "Error",
      message: "There was an error redeeming your prize. Please try again.",
      dismissButton: .cancel(Text("OK")))
  }

  static var prizeRedeemed: PlayolaAlert {
    PlayolaAlert(
      title: "Prize Redeemed!",
      message: "We'll follow up via email to coordinate your reward.",
      dismissButton: .cancel(Text("OK")))
  }
}
