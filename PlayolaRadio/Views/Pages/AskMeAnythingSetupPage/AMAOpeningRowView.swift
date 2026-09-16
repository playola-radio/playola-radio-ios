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
  let iconSystemName: String?
  let albumImageUrl: URL?
  let trailingText: String?
  let isProcessing: Bool
  let showsPin: Bool
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
    if let url = data.albumImageUrl {
      WebImage(
        url: url,
        context: RemoteArtwork.downsampleContext(
          CGSize(width: 45, height: 45), scale: displayScale)
      )
      .resizable()
      .scaledToFill()
      .frame(width: 45, height: 45)
      .clipShape(RoundedRectangle(cornerRadius: 4))
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color.playolaRed)
          .frame(width: 45, height: 45)
        Image(systemName: data.iconSystemName ?? "music.note")
          .font(.system(size: 20))
          .foregroundColor(.playolaTextPrimary)
      }
    }
  }

  @ViewBuilder private var trailing: some View {
    if data.isProcessing {
      ProgressView()
        .tint(.playolaTextPrimary)
        .scaleEffect(0.8)
    } else {
      HStack(spacing: 8) {
        Text(data.trailingText ?? "")
          .font(.custom(FontNames.Inter_400_Regular, size: 11))
          .foregroundColor(.playolaTextDisabled)
        Image(systemName: data.showsPin ? "pin" : "checkmark")
          .font(.system(size: 14))
          .foregroundColor(.playolaTextDisabled)
      }
    }
  }
}
