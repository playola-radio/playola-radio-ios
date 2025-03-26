////
////  SelectStationsPage.swift
////  PlayolaRadio
////
////  Created by Brian D Keane on 3/26/25.
////
//
//import SwiftUI
//
//@MainActor
//struct MyStationPage: View {
//    @Bindable var model: MyStationPageModel
//
//    var body: some View {
//        ZStack {
//            // Background
//            Color.black.edgesIgnoringSafeArea(.all)
//
//            VStack(spacing: 0) {
//                // Main content area based on selected tab
//                if model.selectedTab == .schedule {
//                    ScheduleTabView()
//                } else {
//                    SongsTabView()
//                }
//
//                // Custom Tab Bar
//                CustomTabBar(selectedTab: model.selectedTab) { tab in
//                    model.selectTab(tab)
//                }
//            }
//        }
//        .alert(item: $model.presentedAlert) { alert in
//            alert.alert
//        }
//        .navigationTitle(model.station?.name ?? "My Station")
//        .navigationBarTitleDisplayMode(.inline)
//        .toolbar(content: {
//            ToolbarItem(placement: .topBarLeading) {
//                Image(systemName: "line.3.horizontal")
//                    .foregroundColor(.white)
//                    .onTapGesture {
//                        model.hamburgerButtonTapped()
//                    }
//            }
//        })
//        .onAppear {
//            Task {
//                await model.viewAppeared()
//            }
//        }
//    }
//}
//
//// MARK: - Tab Views
//// Simple placeholder tab views
//
//struct ScheduleTabView: View {
//    var body: some View {
//        VStack {
//            Spacer()
//            Text("Schedule Tab")
//                .font(.title)
//                .foregroundColor(.white)
//            Text("Station schedule placeholder")
//                .foregroundColor(.gray)
//                .padding()
//            Spacer()
//        }
//    }
//}
//
//struct SongsTabView: View {
//    var body: some View {
//        VStack {
//            Spacer()
//            Text("Songs Tab")
//                .font(.title)
//                .foregroundColor(.white)
//            Text("Station songs placeholder")
//                .foregroundColor(.gray)
//                .padding()
//            Spacer()
//        }
//    }
//}
//
//#Preview {
//    NavigationStack {
//        MyStationPage(model: MyStationPageModel())
//    }
//    .onAppear {
//        UINavigationBar.appearance().barStyle = .black
//        UINavigationBar.appearance().tintColor = .white
//    }
//}
