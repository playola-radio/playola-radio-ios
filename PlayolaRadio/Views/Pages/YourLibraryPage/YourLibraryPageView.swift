//
//  YourLibraryPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct YourLibraryPageView: View {
  @Bindable var model: YourLibraryPageModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(model.navigationTitle)
          .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 32))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 24)
      .background(Color.black)

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }
}

// MARK: - Preview
struct YourLibraryPageView_Previews: PreviewProvider {
  static var previews: some View {
    YourLibraryPageView(model: YourLibraryPageModel())
      .background(Color.black)
  }
}
