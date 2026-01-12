//
//  NewFeatureTile.swift
//  PlayolaRadio
//

import SwiftUI

struct NewFeatureTile: View {
  @Bindable var model: NewFeatureTileModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        if model.isSystemImage {
          Image(systemName: model.iconName)
            .foregroundColor(.white)
        } else {
          Image(model.iconName)
            .foregroundColor(.white)
        }

        Text(model.label)
          .font(.custom(FontNames.SpaceGrotesk_500_Medium, size: 16))
          .foregroundColor(.white)

        Spacer()
      }

      Text(model.content)
        .font(.custom(FontNames.Inter_700_Bold, size: 32))
        .foregroundColor(.white)

      if let paragraph = model.paragraph {
        Text(paragraph)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.gray)
      }

      if let buttonText = model.buttonText {
        Button(
          action: { Task { await model.onButtonTapped() } },
          label: {
            HStack {
              Spacer()
              Text(buttonText)
                .font(.custom(FontNames.Inter_500_Medium, size: 16))
                .foregroundColor(.white)
              Spacer()
            }
            .padding(.vertical, 16)
            .background(Color(red: 0.8, green: 0.4, blue: 0.4))
            .foregroundColor(.white)
            .cornerRadius(6)
          })
      }
    }
    .padding(20)
    .background(Color(white: 0.15))
    .cornerRadius(8)
  }
}

// MARK: - Preview
#Preview {
  VStack(spacing: 16) {
    NewFeatureTile(
      model: NewFeatureTileModel(
        label: "New Feature",
        content: "Coming Soon",
        buttonText: "Learn More"
      )
    )

    NewFeatureTile(
      model: NewFeatureTileModel(
        label: "New Feature",
        content: "Coming Soon",
        paragraph: "This is an optional paragraph to describe the feature in more detail.",
        buttonText: "Learn More"
      )
    )
  }
  .padding()
  .background(Color.black)
}
