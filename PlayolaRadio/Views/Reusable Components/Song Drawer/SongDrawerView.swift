//
//  SongDrawerView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import PlayolaPlayer
import SwiftUI

struct SongDrawerView: View {
    @Bindable var model: SongDrawerModel

    var body: some View {
        VStack(spacing: 0) {
            // HEADER
            HStack(spacing: 16) {
                AsyncImage(url: model.audioBlock.imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#666666"))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(Color(hex: "#999999"))
                                .font(.system(size: 20))
                        )
                }
                .frame(width: 48, height: 48)
                .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.audioBlock.title)
                        .font(.custom(FontNames.Inter_500_Medium, size: 20))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(model.audioBlock.artist)
                        .font(.custom(FontNames.Inter_400_Regular, size: 14))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8) // small top inset; system handle sits above
            .padding(.bottom, 12)

            // thin divider under header (like the mock)
            Divider().overlay(Color(hex: "#565656"))

            // ACTIONS
            VStack(spacing: 0) {
                // Apple Music
                if model.shouldShowAppleMusic {
                    Button(
                        action: { model.openAppleMusic() },
                        label: {
                            HStack(spacing: 16) {
                                // Replace with your branded asset if you have it
                                Image("appleMusicIcon")
                                    .resizable()
                                    .frame(width: 32, height: 32)

                                Text("Listen on Apple Music")
                                    .font(.custom(FontNames.Inter_400_Regular, size: 16))
                                    .foregroundColor(.white)

                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                    )
                    .buttonStyle(.plain)
                }

                // Spotify
                if model.shouldShowSpotify {
                    Button(action: { model.openSpotify() }, label: {
                        HStack(spacing: 16) {
                            // Replace with a Spotify glyph asset for perfect branding
                            Image("spotifyIcon")
                                .resizable()
                                .frame(width: 32, height: 32)

                            Text("Listen on Spotify")
                                .font(.custom(FontNames.Inter_400_Regular, size: 16))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    })
                    .buttonStyle(.plain)
                }

                // Remove from liked songs
                Button(
                    action: { model.removeFromLikedSongs() },
                    label: {
                        HStack(spacing: 16) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)

                            Text("Remove from Liked Songs")
                                .font(.custom(FontNames.Inter_400_Regular, size: 16))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                )
                .buttonStyle(.plain)
            }
            .padding(.top, 8)
        }
        // NOTE: No custom .background / .clipShape / .ignoresSafeArea here.
        // Let the presenting .sheet control chrome via:
        //   .presentationBackground(.regularMaterial)
        //   .presentationCornerRadius(20)
        //   .presentationDetents([.height(280)])
        //   .presentationDragIndicator(.visible)
    }
}

#Preview {
    // Previewing the content only; in app it sits inside a .sheet with detents.
    SongDrawerView(
        model: SongDrawerModel(
            audioBlock: AudioBlock.mock,
            likedDate: Date(),
            onDismiss: {}
        )
    )
    .preferredColorScheme(.dark)
    .background(Color.black) // preview helper only
}
