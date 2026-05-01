//
//  ContactPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import Sharing
import SwiftUI

struct ContactPageView: View {
  @Bindable var model: ContactPageModel
  @Shared(.unreadSupportCount) var unreadSupportCount

  var body: some View {
    VStack(spacing: 0) {
      // Title
      HStack {
        Text("Your Profile")
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 24)
      .background(Color.black)

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Profile Card
          ZStack {
            VStack {
              // Profile Image and Info
              VStack(spacing: 16) {
                // Profile Image
                ZStack {
                  Circle()
                    .fill(Color.gray700)
                    .frame(width: 112, height: 112)

                  // Inner circle with person icon

                  Image("empty-profile-avatar")
                    .frame(width: 72, height: 72)
                    .foregroundColor(Color.gray400)
                }

                // Name and Email
                VStack(spacing: 4) {
                  Text(model.name)
                    .font(.custom(FontNames.Inter_500_Medium, size: 20))
                    .foregroundColor(.white)

                  Text(verbatim: model.email)
                    .font(.custom(FontNames.Inter_400_Regular, size: 14))
                    .foregroundColor(Color.textSecondary)

                }
              }
              .padding(.top, 20)
              .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .background(Color.gray900)
            .cornerRadius(6)

            // Edit icon in top right corner of the card
            VStack {
              HStack {
                Spacer()
                Button(
                  action: {
                    model.onEditProfileTapped()
                  },
                  label: {
                    Image("pencil")
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(.white)
                      .padding(8)
                  }
                )
                .padding(.trailing, 16)
                .padding(.top, 16)
              }
              Spacer()
            }
          }
          .padding(.horizontal, 20)

          // Switch to Listening Mode Button (only in broadcast mode)
          if model.isInBroadcastMode {
            Button(
              action: {
                model.switchToListeningMode()
              },
              label: {
                HStack(spacing: 12) {
                  Image(systemName: "headphones")
                    .foregroundColor(.white)
                    .font(.system(size: 16))

                  Text("Switch to Listening Mode")
                    .font(.custom(FontNames.Inter_500_Medium, size: 16))
                    .foregroundColor(.white)

                  Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .background(Color.info)
                .cornerRadius(6)
              }
            )
            .padding(.horizontal, 20)
          }

          // Switch to Broadcasting Mode Button (only in listening mode when user has stations)
          if model.myStationButtonVisible {
            Button(
              action: {
                Task {
                  await model.onMyStationTapped()
                }
              },
              label: {
                HStack(spacing: 12) {
                  Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.white)
                    .font(.system(size: 16))

                  Text("Switch to Broadcasting Mode")
                    .font(.custom(FontNames.Inter_500_Medium, size: 16))
                    .foregroundColor(.white)

                  Image(systemName: "chevron.right")
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .background(Color.info)
                .cornerRadius(6)
              }
            )
            .padding(.horizontal, 20)
          }

          // Liked Songs Button
          Button(
            action: {
              model.onLikedSongsTapped()
            },
            label: {
              HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                  .foregroundColor(.white)
                  .font(.system(size: 16))

                Text("Liked Songs")
                  .font(.custom(FontNames.Inter_500_Medium, size: 16))
                  .foregroundColor(.white)

                Image(systemName: "chevron.right")
                  .foregroundColor(.white)
                  .font(.system(size: 14))
              }
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .padding(.horizontal, 16)
              .background(Color.playolaRed)
              .cornerRadius(6)
            }
          )
          .padding(.horizontal, 20)

          // Notifications Button
          Button(
            action: {
              model.onNotificationsTapped()
            },
            label: {
              HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                  .foregroundColor(.white)
                  .font(.system(size: 16))

                Text("Notifications")
                  .font(.custom(FontNames.Inter_500_Medium, size: 16))
                  .foregroundColor(.white)

                Image(systemName: "chevron.right")
                  .foregroundColor(.white)
                  .font(.system(size: 14))
              }
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .padding(.horizontal, 16)
              .background(Color.playolaRed)
              .cornerRadius(6)
            }
          )
          .padding(.horizontal, 20)

          // Contact Us Button
          Button(
            action: {
              Task {
                await model.onContactUsTapped()
              }
            },
            label: {
              HStack(spacing: 12) {
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

                Text("Contact Us")
                  .font(.custom(FontNames.Inter_500_Medium, size: 16))
                  .foregroundColor(.white)

                Image(systemName: "chevron.right")
                  .foregroundColor(.white)
                  .font(.system(size: 14))
              }
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .padding(.horizontal, 16)
              .background(Color.playolaRed)
              .cornerRadius(6)
            }
          )
          .disabled(model.isCheckingSupport)
          .padding(.horizontal, 20)

          // Call In To Station Button
          Button(
            action: {
              model.callIntoStationButtonTapped()
            },
            label: {
              HStack(spacing: 12) {
                Image(systemName: "mic.fill")
                  .foregroundColor(.white)
                  .font(.system(size: 16))

                Text("Ask An Artist A Question")
                  .font(.custom(FontNames.Inter_500_Medium, size: 16))
                  .foregroundColor(.white)

                Image(systemName: "chevron.right")
                  .foregroundColor(.white)
                  .font(.system(size: 14))
              }
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .padding(.horizontal, 16)
              .background(Color.playolaRed)
              .cornerRadius(6)
            }
          )
          .padding(.horizontal, 20)

          // Log Out Button
          Button(
            action: {
              Task { await model.onLogOutTapped() }
            },
            label: {
              HStack(spacing: 8) {
                Image("signout-icon")
                  .renderingMode(.template)
                  .foregroundColor(.white)

                Text("Log out")
                  .font(.custom(FontNames.Inter_500_Medium, size: 16))
                  .foregroundColor(.white)
              }
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(Color.clear)
              .overlay(
                RoundedRectangle(cornerRadius: 6)
                  .stroke(Color.gray600, lineWidth: 1)
              )
            }
          )
          .padding(.horizontal, 20)
        }
        .padding(.bottom, 100)  // Account for tab bar
      }
    }
    .background(Color.black)
    .task {
      await model.onViewAppeared()
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

// MARK: - Preview
struct ContactPageView_Previews: PreviewProvider {
  static var previews: some View {
    ContactPageView(model: ContactPageModel())
      .background(Color.black)
  }
}
