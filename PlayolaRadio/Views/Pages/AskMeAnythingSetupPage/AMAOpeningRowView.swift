//
//  AMAOpeningRowView.swift
//  PlayolaRadio
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct AMAOpeningRowData: Identifiable, Equatable {
  let id: UUID
  let title: String
  let subtitle: String
  let subtitleColor: Color
  let iconSystemName: String
  let albumImageUrl: URL?
  let leadingArtworkOpacity: Double
  let leadingFallbackOpacity: Double
  let trailingText: String
  let trailingIconSystemName: String
  let processingOpacity: Double
  let completedOpacity: Double
}

struct AMAOpeningRowView: View {
  @Environment(\.displayScale) private var displayScale
  let data: AMAOpeningRowData

  var body: some View {
    HStack(spacing: 12) {
      leading
      VStack(alignment: .leading, spacing: 2) {
        Text(data.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaTextPrimary)
          .lineLimit(1)
        Text(data.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(data.subtitleColor)
          .lineLimit(1)
      }
      Spacer()
      trailing
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity)
    .background(Color.playolaSurfaceRow)
  }

  @ViewBuilder private var leading: some View {
    ZStack {
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.playolaRed)
          .frame(width: 45, height: 45)
        Image(systemName: data.iconSystemName)
          .font(.system(size: 20))
          .foregroundColor(.playolaTextPrimary)
      }
      .opacity(data.leadingFallbackOpacity)
      WebImage(
        url: data.albumImageUrl,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 45, height: 45), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
      .frame(width: 45, height: 45)
      .clipShape(RoundedRectangle(cornerRadius: 4))
      .opacity(data.leadingArtworkOpacity)
    }
  }

  @ViewBuilder private var trailing: some View {
    ZStack {
      ProgressView()
        .tint(.playolaTextPrimary)
        .scaleEffect(0.8)
        .opacity(data.processingOpacity)
      HStack(spacing: 8) {
        Text(data.trailingText)
          .font(.custom(FontNames.Inter_400_Regular, size: 11))
          .foregroundColor(.playolaTextDisabled)
        Image(systemName: data.trailingIconSystemName)
          .font(.system(size: 14))
          .foregroundColor(.playolaTextDisabled)
      }
      .opacity(data.completedOpacity)
    }
  }
}
