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

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          PresetsCarousel(
            displays: model.presetsModel.displayPresets,
            sectionTitle: model.presetsModel.presetsSectionTitle,
            emptyStateText: model.presetsModel.presetsEmptyStateText,
            doneButtonText: model.presetsModel.presetsEditDoneButtonText,
            isEditing: model.presetsModel.isEditingPresets,
            isLoading: model.presetsModel.isLoadingPresets,
            hasLoadError: model.presetsModel.presetsLoadFailed,
            loadErrorText: model.presetsModel.presetsLoadErrorText,
            retryButtonText: model.presetsModel.presetsRetryButtonText,
            onTilePlay: { display in await model.presetTileTapped(display) },
            onTileLongPress: { display in model.presetsModel.presetTileLongPressed(display) },
            onTileRemove: { display in await model.presetsModel.presetRemoveTapped(display) },
            onMove: { presetId, to in
              await model.presetsModel.presetMoved(presetId: presetId, to: to)
            },
            onEditDoneTapped: { model.presetsModel.presetsEditDoneTapped() },
            onRetryTapped: { await model.presetsModel.retryLoadPresetsTapped() }
          )
        }
        .padding(.top, 8)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .task { await model.viewAppeared() }
    .playolaAlert(Bindable(model.presetsModel).presentedAlert)
  }
}

// MARK: - Preview
struct YourLibraryPageView_Previews: PreviewProvider {
  static var previews: some View {
    YourLibraryPageView(model: YourLibraryPageModel())
      .background(Color.black)
  }
}
