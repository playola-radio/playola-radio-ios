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
    .safeAreaInset(edge: .bottom) {
      searchBar
    }
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
    ScrollViewReader { proxy in
      List {
        if model.hasActiveRequests {
          requestsSection
        }

        songsSection
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color.black)
      .scrollPosition(id: $scrollPosition)
      .overlay(alignment: .trailing) {
        SectionIndexView(
          letters: model.availableSectionLetters,
          onSelectLetter: { letter in
            if let artist = model.firstArtist(forLetter: letter) {
              withAnimation {
                proxy.scrollTo("artist-\(artist)", anchor: .top)
              }
            }
          }
        )
        .padding(.trailing, 8)
      }
    }
  }

  private var requestsSection: some View {
    Section {
      if !model.pendingRequests.isEmpty {
        pendingRequestsSubsection
      }
      if !model.fulfilledRequests.isEmpty {
        fulfilledRequestsSubsection
      }
    } header: {
      SectionHeader(title: model.requestsSectionHeader)
    }
  }

  private var pendingRequestsSubsection: some View {
    requestsSubsection(
      header: model.pendingSubsectionHeader,
      requests: model.pendingRequests,
      showCheckmark: false,
      rowOpacity: 1.0
    )
  }

  private var fulfilledRequestsSubsection: some View {
    requestsSubsection(
      header: model.fulfilledSubsectionHeader,
      requests: model.fulfilledRequests,
      showCheckmark: true,
      rowOpacity: 0.7
    )
  }

  private func requestsSubsection(
    header: String,
    requests: [StationLibraryRequest],
    showCheckmark: Bool,
    rowOpacity: Double
  ) -> some View {
    Group {
      Text(header)
        .font(.custom(FontNames.Inter_500_Medium, size: 11))
        .foregroundColor(.playolaGray)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

      ForEach(requests) { request in
        LibraryRequestRow(
          request: request,
          typeLabel: model.requestTypeLabel(for: request),
          typeColor: model.requestTypeColor(for: request),
          statusLabel: model.requestStatusLabel(for: request),
          canDismiss: model.canDismissRequest(request),
          canCancel: model.canCancelRequest(request),
          showCheckmark: showCheckmark,
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
        .opacity(rowOpacity)
      }
    }
  }

  private var songsSection: some View {
    ForEach(model.songsByArtist, id: \.artist) { artistGroup in
      Section {
        ForEach(artistGroup.songs) { song in
          LibrarySongRow(
            song: song,
            isProcessing: model.isProcessingRemoval(for: song),
            hasPendingRequest: model.hasPendingRequest(for: song),
            hasSongIntro: model.hasSongIntro(for: song),
            pendingRemovalText: model.pendingRemovalText,
            cancelButtonText: model.cancelButtonText,
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
            },
            onRecordIntro: {
              model.recordIntroButtonTapped(song)
            }
          )
          .id("song-\(song.id)")
          .listRowInsets(EdgeInsets())
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
        }
      } header: {
        SectionHeader(title: artistGroup.artist)
          .id("artist-\(artistGroup.artist)")
      }
    }
  }

  private var searchBar: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16))
        .foregroundColor(.playolaGray)

      TextField(model.searchPrompt, text: $model.searchText)
        .font(.custom(FontNames.Inter_400_Regular, size: 16))
        .foregroundColor(.white)
        .autocorrectionDisabled()

      if !model.searchText.isEmpty {
        Button {
          model.searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16))
            .foregroundColor(.playolaGray)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(hex: "#333333"))
    .cornerRadius(8)
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.black)
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
  let hasSongIntro: Bool
  let pendingRemovalText: String
  let cancelButtonText: String
  let onCancel: () -> Void
  let onRemove: () -> Void
  let onRecordIntro: () -> Void

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
        HStack(spacing: 12) {
          if !hasSongIntro {
            Button(action: onRecordIntro) {
              Image(systemName: "mic")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.playolaGray)
                .frame(width: 32, height: 32)
                .background(Color(hex: "#444444"))
                .clipShape(Circle())
            }
            .buttonStyle(BorderlessButtonStyle())
          }

          Button(action: onRemove) {
            Image(systemName: "trash")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.playolaRed)
              .frame(width: 32, height: 32)
              .background(Color(hex: "#444444"))
              .clipShape(Circle())
          }
          .buttonStyle(BorderlessButtonStyle())
        }
      }
    }
    .padding(.leading, 12)
    .padding(.trailing, 28)
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
  var showCheckmark: Bool = false
  let dismissButtonText: String
  let cancelButtonText: String
  let onDismiss: () -> Void
  let onCancel: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      ZStack(alignment: .bottomTrailing) {
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

        if showCheckmark {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 14))
            .foregroundColor(.green)
            .background(Circle().fill(Color.black).frame(width: 16, height: 16))
            .offset(x: 2, y: 2)
        }
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

// MARK: - Section Index View

struct SectionIndexView: View {
  let letters: [String]
  let onSelectLetter: (String) -> Void

  @GestureState private var isDragging = false
  @State private var selectedLetter: String?

  var body: some View {
    VStack(spacing: 2) {
      ForEach(letters, id: \.self) { letter in
        Text(letter)
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(selectedLetter == letter ? .playolaRed : .playolaGray)
          .frame(width: 16, height: 14)
      }
    }
    .padding(.vertical, 4)
    .background(Color.black.opacity(0.3))
    .cornerRadius(8)
    .gesture(
      DragGesture(minimumDistance: 0)
        .updating($isDragging) { _, state, _ in
          state = true
        }
        .onChanged { value in
          let letterHeight: CGFloat = 16
          let index = Int(value.location.y / letterHeight)
          if index >= 0 && index < letters.count {
            let letter = letters[index]
            if selectedLetter != letter {
              selectedLetter = letter
              onSelectLetter(letter)
            }
          }
        }
        .onEnded { _ in
          selectedLetter = nil
        }
    )
  }
}

#Preview {
  NavigationStack {
    LibraryPageView(model: LibraryPageModel(stationId: "preview-station"))
  }
  .preferredColorScheme(.dark)
}
