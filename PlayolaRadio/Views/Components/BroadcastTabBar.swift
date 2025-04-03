//
//  BroadcastTabBar.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/28/25.
//
import SwiftUI

struct BroadcastTabBar: View {
  var selectedTab: NavigationCoordinator.BroadcastTabs
  var onTabSelected: (NavigationCoordinator.BroadcastTabs) -> Void
  
  var body: some View {
    HStack(spacing: 0) {
      BroadcastTabButton(
        title: "Schedule",
        systemImage: "calendar",
        isSelected: selectedTab == .schedule,
        action: { onTabSelected(.schedule) }
      )
      
      BroadcastTabButton(
        title: "Songs",
        systemImage: "music.note.list",
        isSelected: selectedTab == .songs,
        action: { onTabSelected(.songs) }
      )
    }
    .frame(height: 60)
    .background(Color(hex: "#1C1C1E"))
    .edgesIgnoringSafeArea(.bottom)
  }
}

struct BroadcastTabButton: View {
  var title: String
  var systemImage: String
  var isSelected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.system(size: 24))

        Text(title)
          .font(.system(size: 12))
      }
      .foregroundColor(isSelected ? .white : .gray)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
    }
    .background(
      isSelected ?
      Color.playolaLightPurple.opacity(0.2) :
        Color.clear
    )
  }
}
