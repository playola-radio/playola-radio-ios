//
//  LibraryPageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
import SwiftUI

struct LibraryPageView: View {
  @Bindable var model: LibraryPageModel
  @State private var scrollPosition: String?

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      if model.isLoading && model.librarySongs.isEmpty {
        ProgressView()
          .tint(.white)
      } else if model.filteredSongs.isEmpty && model.searchText.isEmpty {
        emptyStateView
      } else {
        songListView
      }
    }
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .searchable(text: $model.searchText, prompt: model.searchPrompt)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          model.addSongButtonTapped()
        } label: {
          Image(systemName: "plus")
            .foregroundColor(.playolaRed)
        }
      }
    }
    .refreshable {
      await model.refreshPulledDown()
    }
    .task {
      await model.viewAppeared()
    }
    .playolaAlert($model.presentedAlert)
  }

  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "music.note.list")
        .font(.system(size: 48))
        .foregroundColor(.playolaGray)
      Text(model.emptyStateMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.playolaGray)
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 40)
  }

  private var songListView: some View {
    List {
      if !model.activeRequests.isEmpty {
        requestsSection
      }

      songsSection
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .background(Color.black)
    .scrollPosition(id: $scrollPosition)
  }

  private var requestsSection: some View {
    Section {
      ForEach(model.activeRequests) { request in
        LibraryRequestRow(
          request: request,
          typeLabel: model.requestTypeLabel(for: request),
          typeColor: model.requestTypeColor(for: request),
          statusLabel: model.requestStatusLabel(for: request),
          canDismiss: model.canDismissRequest(request),
          canCancel: model.canCancelRequest(request),
          dismissButtonText: model.dismissButtonText,
          cancelButtonText: model.cancelButtonText,
          onDismiss: {
            Task {
              await model.dismissRequestButtonTapped(request)
            }
          },
          onCancel: {
            Task {
              await model.cancelRequestButtonTapped(request)
            }
          }
        )
        .id("request-\(request.id)")
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
    } header: {
      SectionHeader(title: model.requestsSectionHeader)
    }
  }

  private var songsSection: some View {
    Section {
      ForEach(model.filteredSongs) { song in
        LibrarySongRow(
          song: song,
          isProcessing: model.isProcessingRemoval(for: song),
          hasPendingRequest: model.hasPendingRequest(for: song),
          pendingRemovalText: model.pendingRemovalText,
          cancelButtonText: model.cancelButtonText,
          removeButtonText: model.removeButtonText,
          onCancel: {
            if let request = model.pendingRequest(for: song) {
              Task {
                await model.cancelRequestButtonTapped(request)
              }
            }
          },
          onRemove: {
            Task {
              await model.removeSongButtonTapped(song)
            }
          }
        )
        .id("song-\(song.id)")
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
    } header: {
      SectionHeader(title: model.songsSectionHeader)
    }
  }
}

// MARK: - Section Header

struct SectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
      .foregroundColor(.playolaGray)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.black)
      .listRowInsets(EdgeInsets())
  }
}

// MARK: - Library Song Row

struct LibrarySongRow: View {
  let song: LibrarySong
  let isProcessing: Bool
  let hasPendingRequest: Bool
  let pendingRemovalText: String
  let cancelButtonText: String
  let removeButtonText: String
  let onCancel: () -> Void
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if let imageUrl = song.imageUrl {
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
        Text(song.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(song.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)
      }

      Spacer()

      if isProcessing {
        ProgressView()
          .tint(.playolaGray)
      } else if hasPendingRequest {
        HStack(spacing: 8) {
          Text(pendingRemovalText)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.playolaGray)

          Button(action: onCancel) {
            Text(cancelButtonText)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
              .foregroundColor(.playolaGray)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color(hex: "#444444"))
              .cornerRadius(4)
          }
          .buttonStyle(BorderlessButtonStyle())
        }
      } else {
        Button(action: onRemove) {
          Text(removeButtonText)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.playolaRed)
            .cornerRadius(4)
        }
        .buttonStyle(BorderlessButtonStyle())
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(hex: "#333333"))
  }
}

// MARK: - Library Request Row

struct LibraryRequestRow: View {
  let request: StationLibraryRequest
  let typeLabel: String
  let typeColor: Color
  let statusLabel: String
  let canDismiss: Bool
  let canCancel: Bool
  let dismissButtonText: String
  let cancelButtonText: String
  let onDismiss: () -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      if let imageUrl = request.imageUrl {
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
        Text(request.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(request.artist)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaGray)
          .lineLimit(1)

        HStack(spacing: 4) {
          Text(typeLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 10))
            .foregroundColor(typeColor)

          Text("•")
            .font(.custom(FontNames.Inter_400_Regular, size: 10))
            .foregroundColor(.playolaGray)

          Text(statusLabel)
            .font(.custom(FontNames.Inter_400_Regular, size: 10))
            .foregroundColor(.playolaGray)
        }
      }

      Spacer()

      if canDismiss {
        Button(action: onDismiss) {
          Text(dismissButtonText)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
            .foregroundColor(.playolaGray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#444444"))
            .cornerRadius(4)
        }
        .buttonStyle(BorderlessButtonStyle())
      } else if canCancel {
        Button(action: onCancel) {
          Text(cancelButtonText)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
            .foregroundColor(.playolaGray)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "#444444"))
            .cornerRadius(4)
        }
        .buttonStyle(BorderlessButtonStyle())
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(hex: "#333333"))
  }
}

#Preview {
  NavigationStack {
    LibraryPageView(model: LibraryPageModel(stationId: "preview-station"))
  }
  .preferredColorScheme(.dark)
}
