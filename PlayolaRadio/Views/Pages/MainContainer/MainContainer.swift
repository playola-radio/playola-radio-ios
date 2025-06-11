//
//  MainContainer.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/11/25.
//

import SwiftUI

struct MainContainer: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomePageView()
                .tabItem {
                    Image("HomeTabImage")
                    Text("Home")
                }
                .tag(0)
            
            HomePageView() // Temporarily using HomePageView
                .tabItem {
                    Image("RadioStationsTabImage")
                    Text("Radio Stations")
                }
                .tag(1)
            
            HomePageView() // Temporarily using HomePageView
                .tabItem {
                    Image("ProfileTabImage")
                    Text("Profile")
                }
                .tag(2)
        }
        .accentColor(.white) // Makes the selected tab icon white
        .onAppear {
            // Custom styling for TabView
            UITabBar.appearance().unselectedItemTintColor = UIColor(white: 0.7, alpha: 1.0)
            UITabBar.appearance().backgroundColor = .black
        }
    }
}

struct MainContainer_Previews: PreviewProvider {
    static var previews: some View {
        MainContainer()
            .preferredColorScheme(.dark)
    }
}
