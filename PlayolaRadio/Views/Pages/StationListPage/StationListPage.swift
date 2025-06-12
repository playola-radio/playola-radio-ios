//
//  StationListPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 5/21/24.
//

import SwiftUI

struct TempStation: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let imageUrl: String
    let isArtistStation: Bool
}

class StationListModel: ViewModel {}

struct StationListPage: View {
    @State private var selectedSegment = "All"
    let segments = ["All", "Artist Stations", "FM Stations"]

    // Sample Data
    let stations = [
        // Artist Stations
      TempStation(
            name: "Bri Bagwell's",
            subtitle: "Banned Radio",
            imageUrl: "https://playola-static.s3.amazonaws.com/bri_banned_logo.png",
            isArtistStation: true
        ),
      TempStation(
            name: "Jacob Stelly's",
            subtitle: "Moondog Radio",
            imageUrl: "https://playola-static.s3.amazonaws.com/station-images/Jacob-Stelly-1-116029.jpg",
            isArtistStation: true
        ),
      TempStation(
            name: "Sturgill Simpson's",
            subtitle: "Metamodern Radio",
            imageUrl: "https://example.com/sturgill.jpg",
            isArtistStation: true
        ),
        // FM Stations
      TempStation(
            name: "KOKE FM",
            subtitle: "Austin, TX",
            imageUrl: "https://example.com/koke.jpg",
            isArtistStation: false
        ),
      TempStation(
            name: "KOKE FM",
            subtitle: "Austin, TX",
            imageUrl: "https://example.com/koke.jpg",
            isArtistStation: false
        ),
      TempStation(
            name: "KOKE FM",
            subtitle: "Austin, TX",
            imageUrl: "https://example.com/koke.jpg",
            isArtistStation: false
        )
    ]

    var filteredStations: [TempStation] {
        switch selectedSegment {
        case "Artist Stations":
            return stations.filter { $0.isArtistStation }
        case "FM Stations":
            return stations.filter { !$0.isArtistStation }
        default:
            return stations
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Radio Stations")
                .font(.custom(FontNames.SpaceGrotesk_700_Bold, size: 34))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 24) // Specific spacing to bubbles

            // Custom Segment Control
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(segments, id: \.self) { segment in
                        Button(action: {
                            selectedSegment = segment
                        }) {
                            Text(segment)
                            .font(.custom(FontNames.Inter_500_Medium, size: 16))
                                .foregroundColor(Color.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedSegment == segment ?
                                    Color.playolaRed :
                                        Color(white: 0.2)
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)

            // Station List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Artist Stations Section
                    if selectedSegment != "FM Stations" {
                        stationSection(
                            title: "Artist Stations",
                            stations: stations.filter { $0.isArtistStation }
                        )
                    }

                    // FM Stations Section
                    if selectedSegment != "Artist Stations" {
                        stationSection(
                            title: "FM Stations",
                            stations: stations.filter { !$0.isArtistStation }
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black)
    }

    @ViewBuilder
    func stationSection(title: String, stations: [TempStation]) -> some View {
        if !stations.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                .font(.custom("Inter-Regular", size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                VStack(spacing: 1) {
                    ForEach(stations) { station in
                        StationRow(station: station)
                    }
                }
            }
        }
    }
}

struct StationRow: View {
    let station: TempStation

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                // Station Image
                AsyncImage(url: URL(string: station.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(white: 0.2)
                }
                .frame(width: 64, height: 64)
                .cornerRadius(6)

                // Station Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.name)
                    .font(.custom(FontNames.Inter_500_Medium, size: 22))
                        .foregroundColor(.white)

                    Text(station.subtitle)
                        .font(.custom(FontNames.Inter_400_Regular, size: 14))
                        .foregroundColor(.white)
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .onAppear {  listInstalledFonts() }
    }
}

#Preview {
    NavigationStack {
        StationListPage()
    }
    .preferredColorScheme(.dark)
}
