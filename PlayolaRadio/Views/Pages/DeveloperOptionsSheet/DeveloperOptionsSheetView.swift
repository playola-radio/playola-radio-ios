//
//  DeveloperOptionsSheetView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/20/26.
//

import Sharing
import SwiftUI

struct DeveloperOptionsSheetView: View {
  @Bindable var model: DeveloperOptionsSheetModel

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle(isOn: Binding(model.$sampleBufferRendererLocalOverride)) {
            VStack(alignment: .leading, spacing: 4) {
              Text(model.sampleBufferRendererTitle)
                .font(.custom(FontNames.Inter_500_Medium, size: 16))
                .foregroundColor(.white)
              Text(model.sampleBufferRendererDetail)
                .font(.custom(FontNames.Inter_400_Regular, size: 13))
                .foregroundColor(Color.textSecondary)
            }
          }
          .listRowBackground(Color.gray900)
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.black)
      .navigationTitle(model.navigationTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(model.doneButtonText) { model.doneButtonTapped() }
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}
