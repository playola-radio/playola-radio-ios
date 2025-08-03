//
//  ContactPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/23/25.
//

import SwiftUI

struct ContactPageView: View {
  @Bindable var model: ContactPageModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        // Title
        HStack {
          Text("Your Profile")
            .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
            .foregroundColor(.white)
          Spacer()
        }
        .padding(.horizontal, 20)

        // Profile Card
        ZStack {
          VStack {
            // Profile Image and Info
            VStack(spacing: 16) {
              // Profile Image
              ZStack {
                Circle()
                  .fill(Color(hex: "#565656"))
                  .frame(width: 112, height: 112)

                // Inner circle with person icon

                Image("empty-profile-avatar")
                  .frame(width: 72, height: 72)
                  .foregroundColor(Color(white: 0.7))
              }

              // Name and Email
              VStack(spacing: 4) {
                Text(model.name)
                  .font(.custom(FontNames.Inter_500_Medium, size: 20))
                  .foregroundColor(.white)

                Text(verbatim: model.email)
                  .font(.custom(FontNames.Inter_400_Regular, size: 14))
                  .foregroundColor(Color(hex: "#BABABA"))

              }
            }
            .padding(.top, 20)
            .padding(.bottom, 20)
          }
          .frame(maxWidth: .infinity)
          .background(Color(hex: "#333333"))
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

        // Log Out Button
        Button(
          action: {
            model.onLogOutTapped()
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
                .stroke(Color(hex: "#827876"), lineWidth: 1)
            )
          }
        )
        .padding(.horizontal, 20)
      }
      .padding(.top, 20)
      .padding(.bottom, 100)  // Account for tab bar
    }
    .background(Color.black)
    .task {
      await model.onViewAppeared()
    }
  }
}

// MARK: - Preview
struct ContactPageView_Previews: PreviewProvider {
  static var previews: some View {
    ContactPageView(model: ContactPageModel())
      .background(Color.black)
  }
}
