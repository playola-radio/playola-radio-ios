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
    Text("Hi")
  }
}

// MARK: - Preview
struct EditContactPageView_Previews: PreviewProvider {
  static var previews: some View {
    EditProfilePageView(model: EditProfilePageModel())
      .background(Color.black)
  }
}
