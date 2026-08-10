//
//  ContactPagePadView.swift
//  PlayolaRadio
//
//  iPad-only (regular horizontal size class) layout for the "Your Profile" screen.
//
//  QUARANTINED ON PURPOSE. iPad is not a maintained priority. This view is a dumb
//  layout over `ContactPageModel` — it holds zero business logic and wires every button
//  to the same model actions the compact layout uses. It deliberately duplicates the
//  small card / button styling rather than sharing components with the iPhone layout, so
//  future iPhone changes never have to account for iPad. Design drift is acceptable; this
//  whole file can be deleted without touching the iPhone path. See
//  docs/superpowers/specs/2026-08-06-ipad-profile-design.md.
//

import Sharing
import SwiftUI

struct ContactPagePadView: View {
  @Bindable var model: ContactPageModel
  @Shared(.unreadSupportCount) var unreadSupportCount

  private let contentMaxWidth: CGFloat = 720
  private let columns = [
    GridItem(.flexible(), spacing: 16),
    GridItem(.flexible(), spacing: 16),
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          profileCard
          modeButtons
          actionGrid
          logOutButton
        }
        .frame(maxWidth: contentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 40)
      }
    }
    .background(Color.black)
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      Text(model.navigationTitle)
        .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
        .foregroundColor(.white)
      Spacer()
    }
    .frame(maxWidth: contentMaxWidth)
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.horizontal, 32)
    .padding(.top, 20)
    .padding(.bottom, 24)
    .background(Color.black)
  }

  // MARK: - Profile card

  private var profileCard: some View {
    ZStack {
      VStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(Color.gray700)
            .frame(width: 112, height: 112)

          Image("empty-profile-avatar")
            .frame(width: 72, height: 72)
            .foregroundColor(Color.gray400)
        }

        VStack(spacing: 4) {
          Text(model.name)
            .font(.custom(FontNames.Inter_500_Medium, size: 20))
            .foregroundColor(.white)

          Text(verbatim: model.email)
            .font(.custom(FontNames.Inter_400_Regular, size: 14))
            .foregroundColor(Color.textSecondary)
        }
      }
      .padding(.vertical, 24)
      .frame(maxWidth: .infinity)
      .background(Color.gray900)
      .cornerRadius(6)

      VStack {
        HStack {
          Spacer()
          Button {
            model.onEditProfileTapped()
          } label: {
            Image("pencil")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white)
              .padding(8)
          }
          .padding(.trailing, 16)
          .padding(.top, 16)
        }
        Spacer()
      }
    }
  }

  // MARK: - Conditional mode buttons

  @ViewBuilder
  private var modeButtons: some View {
    if model.isInBroadcastMode {
      ProfilePadActionButton(
        icon: "headphones", label: model.switchToListeningModeLabel, background: Color.info
      ) {
        model.switchToListeningMode()
      }
    }
    if model.myStationButtonVisible {
      ProfilePadActionButton(
        icon: "antenna.radiowaves.left.and.right",
        label: model.switchToBroadcastingModeLabel, background: Color.info
      ) {
        Task { await model.onMyStationTapped() }
      }
    }
  }

  // MARK: - Action grid

  private var actionGrid: some View {
    LazyVGrid(columns: columns, spacing: 16) {
      if model.showRewardsButton {
        ProfilePadActionButton(
          icon: "gift.fill", label: model.rewardsLabel, background: .playolaRed
        ) {
          model.onRewardsTapped()
        }
      }

      ProfilePadActionButton(
        icon: "bell.fill", label: model.notificationsLabel, background: .playolaRed
      ) {
        model.onNotificationsTapped()
      }

      contactUsButton

      ProfilePadActionButton(
        icon: "mic.fill", label: model.askArtistLabel, background: .playolaRed
      ) {
        model.callIntoStationButtonTapped()
      }
    }
  }

  private var contactUsButton: some View {
    Button {
      Task { await model.onContactUsTapped() }
    } label: {
      HStack(spacing: 12) {
        contactUsIcon

        Text(model.contactUsLabel)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .foregroundColor(.white)
          .font(.system(size: 14))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .padding(.horizontal, 16)
      .background(Color.playolaRed)
      .cornerRadius(6)
    }
    .disabled(model.isCheckingSupport)
  }

  @ViewBuilder
  private var contactUsIcon: some View {
    if model.isCheckingSupport {
      ProgressView()
        .tint(.white)
        .frame(width: 16, height: 16)
    } else {
      ZStack(alignment: .topTrailing) {
        Image(systemName: "bubble.left.fill")
          .foregroundColor(.white)
          .font(.system(size: 16))

        if unreadSupportCount > 0 {
          Text("\(unreadSupportCount)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Color.playolaRed)
            .frame(minWidth: 16, minHeight: 16)
            .background(Circle().fill(Color.white))
            .offset(x: 8, y: -8)
        }
      }
    }
  }

  // MARK: - Log out

  private var logOutButton: some View {
    Button {
      Task { await model.onLogOutTapped() }
    } label: {
      HStack(spacing: 8) {
        Image("signout-icon")
          .renderingMode(.template)
          .foregroundColor(.white)

        Text(model.logOutLabel)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(Color.gray600, lineWidth: 1)
      )
    }
    .padding(.top, 4)
  }
}

// MARK: - Reusable colored action button (duplicated styling, quarantined)

private struct ProfilePadActionButton: View {
  let icon: String
  let label: String
  let background: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .foregroundColor(.white)
          .font(.system(size: 16))

        Text(label)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)

        Spacer(minLength: 8)

        Image(systemName: "chevron.right")
          .foregroundColor(.white)
          .font(.system(size: 14))
      }
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .padding(.horizontal, 16)
      .background(background)
      .cornerRadius(6)
    }
  }
}

#Preview(traits: .fixedLayout(width: 1024, height: 768)) {
  ContactPagePadView(model: ContactPageModel())
    .preferredColorScheme(.dark)
}
