//
//  SongSearchPageView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/15/25.
//

import PlayolaPlayer
import SDWebImageSwiftUI
import SwiftUI

struct SongSearchPageView: View {
  @Bindable var model: SongSearchPageModel

  private var hasResults: Bool {
    !model.searchResults.isEmpty || !model.songRequestResults.isEmpty
  }

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack(spacing: 0) {
        if model.isSearching {
          Spacer()
          ProgressView()
            .tint(.white)
          Spacer()
        } else if model.searchText.isEmpty {
          Spacer()
          VStack(spacing: 12) {
            Image(systemName: "music.note.list")
              .font(.system(size: 48))
              .foregroundColor(.playolaGray)
            Text("Search for songs to add to your schedule")
              .font(.custom(FontNames.Inter_400_Regular, size: 16))
              .foregroundColor(.playolaGray)
              .multilineTextAlignment(.center)
          }
          .padding(.horizontal, 40)
          Spacer()
        } else if !hasResults {
          Spacer()
          VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
              .font(.system(size: 48))
              .foregroundColor(.playolaGray)
            Text("No songs found")
              .font(.custom(FontNames.Inter_400_Regular, size: 16))
              .foregroundColor(.playolaGray)
          }
          Spacer()
        } else {
          List {
            // Playola library results (only for libraryOnly or all modes)
            if model.searchMode != .seedsOnly && !model.searchResults.isEmpty {
              Section {
                ForEach(model.searchResults, id: \.id) { audioBlock in
                  SongSearchResultRow(audioBlock: audioBlock) {
                    model.onSelectSong(audioBlock)
                  }
                  .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                  .listRowSeparator(.hidden)
                  .listRowBackground(Color.clear)
                }
              } header: {
                Text("LIBRARY")
                  .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
                  .foregroundColor(.playolaGray)
              }
            }

            // Song seed results (only for seedsOnly or all modes)
            if model.searchMode != .libraryOnly && !model.songRequestResults.isEmpty {
              Section {
                ForEach(model.songRequestResults, id: \.id) { songRequest in
                  SongRequestResultRow(
                    songRequest: songRequest,
                    buttonText: model.isLibraryAddMode ? "ADD" : "REQUEST",
                    isProcessing: model.isProcessingAdd(for: songRequest)
                  ) {
                    Task {
                      if model.isLibraryAddMode {
                        await model.onAddSongToLibrary(songRequest)
                      } else {
                        await model.onRequestSong(songRequest)
                      }
                    }
                  }
                  .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                  .listRowSeparator(.hidden)
                  .listRowBackground(Color.clear)
                }
              } header: {
                Text(model.songSeedsSectionHeader)
                  .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
                  .foregroundColor(.playolaGray)
              }
            }
          }
          .listStyle(.plain)
          .scrollContentBackground(.hidden)
          .background(Color.black)
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      HStack(spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 16))
            .foregroundColor(.playolaGray)

          TextField("Search for songs", text: $model.searchText)
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(.white)
            .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#333333"))
        .cornerRadius(8)

        Button("Cancel") {
          model.onCancelTapped()
        }
        .font(.custom(FontNames.Inter_500_Medium, size: 16))
        .foregroundColor(.playolaRed)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color.black)
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

struct SongSearchResultRow: View {
  let audioBlock: AudioBlock
  let onSelect: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if let imageUrl = audioBlock.imageUrl {
        WebImage(url: imageUrl)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 45, height: 45)
          .clipped()
      } else {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(hex: "#666666"))
          .frame(width: 45, height: 45)
          .overlay(
            Image(systemName: "music.note")
              .foregroundColor(Color(hex: "#999999"))
          )
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(audioBlock.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(audioBlock.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
      }

      Spacer()

      Button(action: onSelect) {
        Text("SELECT")
          .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color.playolaRed)
          .cornerRadius(4)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(hex: "#333333"))
  }
}

struct SongRequestResultRow: View {
  let songRequest: SongRequest
  var buttonText: String = "REQUEST"
  var isProcessing: Bool = false
  let onRequest: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if let imageUrl = songRequest.imageUrl {
        WebImage(url: imageUrl)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 45, height: 45)
          .clipped()
      } else {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(hex: "#666666"))
          .frame(width: 45, height: 45)
          .overlay(
            Image(systemName: "music.note")
              .foregroundColor(Color(hex: "#999999"))
          )
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(songRequest.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(songRequest.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
      }

      Spacer()

      if isProcessing {
        ProgressView()
          .tint(.playolaGray)
      } else if let displayText = songRequest.requestStatus.displayText {
        Text(displayText)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
      } else {
        Button(action: onRequest) {
          Text(buttonText)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.playolaRed)
            .cornerRadius(4)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(hex: "#333333"))
  }
}

#Preview {
  SongSearchPageView(model: SongSearchPageModel())
    .preferredColorScheme(.dark)
}
