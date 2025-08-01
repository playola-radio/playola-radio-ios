//
//  EditProfilePage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 7/31/25.
//

import SwiftUI

struct EditProfilePageView: View {
  @Bindable var model: EditProfilePageModel

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Edit Profile")
          .font(.title2)
          .fontWeight(.medium)
          .foregroundColor(.white)

        Spacer()

        // Invisible spacer to center the title
        Image(systemName: "chevron.left")
          .opacity(0)
          .font(.title2)
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 30)

      // Form Content
      VStack(spacing: 16) {
        // First Name Section
        VStack(alignment: .leading) {
          Text("First Name")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.white)

          TextField("", text: .constant("Brian"))
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(hex: "#333333"))
            .cornerRadius(8)
            .foregroundColor(.white)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
        }

        // Last Name Section
        VStack(alignment: .leading) {
          Text("Last Name")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.white)

          TextField("", text: .constant("Keane"))
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(hex: "#333333"))
            .cornerRadius(8)
            .foregroundColor(.white)
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
        }

        // Email Section
        VStack(alignment: .leading) {
          Text("Email")
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .foregroundColor(.white)

          TextField("", text: .constant("briank@gmail.com"))
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(hex: "#333333"))
            .cornerRadius(8)
            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
            .font(.custom(FontNames.Inter_500_Medium, size: 16))
            .disabled(true)

          Text("This email is linked to your Google Account and can't be changed here.")
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(Color(hex: "#BABABA"))
            .padding(.top, 4)
        }

        // Save Button
        Button(
          action: {
            // Save action - will implement later
          },
          label: {
            Text("Save Profile")
              .font(.custom(FontNames.Inter_500_Medium, size: 16))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(Color(red: 0.9, green: 0.4, blue: 0.4))
              .cornerRadius(6)
          }
        )
        .padding(.top, 16)

        Spacer()

      }
      .padding(.horizontal, 20)
    }
    .background(Color.black)
  }
}

// MARK: - Preview
struct EditContactPageView_Previews: PreviewProvider {
  static var previews: some View {
    EditProfilePageView(model: EditProfilePageModel())
  }
}
