//
//  NotificationsSettingsPageView.swift
//  PlayolaRadio
//
//  Created by Claude on 1/2/26.
//

import SwiftUI

struct NotificationsSettingsPageView: View {
  @Bindable var model: NotificationsSettingsPageModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      if model.isLoading && model.stationItems.isEmpty {
        Spacer()
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
        Spacer()
      } else if model.stationItems.isEmpty {
        emptyStateView
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            primaryToggleSection
            Divider()
              .background(Color(hex: "#333333"))
              .padding(.horizontal, 20)
            stationListSection
          }
          .padding(.top, 16)
        }
      }
    }
    .background(Color.black)
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button(
          action: {
            dismiss()
          },
          label: {
            Image(systemName: "chevron.left")
              .foregroundColor(.white)
              .font(.title2)
          })
      }
    }
    .onAppear {
      let appearance = UINavigationBarAppearance()
      appearance.configureWithOpaqueBackground()
      appearance.backgroundColor = UIColor.black
      appearance.titleTextAttributes = [
        .foregroundColor: UIColor.white,
        .font: UIFont.systemFont(ofSize: 18, weight: .medium),
      ]

      UINavigationBar.appearance().standardAppearance = appearance
      UINavigationBar.appearance().scrollEdgeAppearance = appearance
      UINavigationBar.appearance().compactAppearance = appearance
    }
    .task {
      await model.viewAppeared()
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "bell.slash")
        .font(.system(size: 48))
        .foregroundColor(Color(hex: "#666666"))
      Text("No stations available")
        .font(.custom(FontNames.Inter_500_Medium, size: 18))
        .foregroundColor(Color(hex: "#BABABA"))
      Text("No stations are currently available for notifications.")
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(Color(hex: "#666666"))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      Spacer()
    }
  }

  private var primaryToggleSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("All Notifications")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
          Text("Enable or disable all station notifications")
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(Color(hex: "#BABABA"))
        }
        Spacer()
        Toggle(
          "",
          isOn: Binding(
            get: { model.allNotificationsEnabled },
            set: { _ in
              Task { await model.toggleAllNotifications() }
            }
          )
        )
        .labelsHidden()
        .tint(Color(hex: "#EF6962"))
        .disabled(!model.togglingStationIds.isEmpty)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)
    }
  }

  private var stationListSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Stations")
        .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
        .foregroundColor(Color(hex: "#BABABA"))
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)

      ForEach(model.stationItems) { item in
        stationRow(item: item)
        if item.id != model.stationItems.last?.id {
          Divider()
            .background(Color(hex: "#333333"))
            .padding(.leading, 100)
        }
      }
    }
    .padding(.bottom, 100)
  }

  private func stationRow(item: StationNotificationItem) -> some View {
    HStack(spacing: 16) {
      AsyncImage(url: item.station.imageUrl) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
      } placeholder: {
        Color(white: 0.2)
      }
      .frame(width: 56, height: 56)
      .clipped()
      .cornerRadius(6)

      VStack(alignment: .leading, spacing: 2) {
        Text(item.station.curatorName)
          .font(.custom(FontNames.Inter_500_Medium, size: 16))
          .foregroundColor(.white)
          .lineLimit(1)

        Text(item.station.name)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(Color(hex: "#BABABA"))
          .lineLimit(1)

        Text(item.statusText)
          .font(.custom(FontNames.Inter_400_Regular, size: 11))
          .foregroundColor(item.statusColor)
      }

      Spacer()

      if model.isToggling(stationId: item.station.id) {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .white))
          .scaleEffect(0.8)
      } else {
        Toggle(
          "",
          isOn: Binding(
            get: { item.isSubscribed },
            set: { _ in
              Task { await model.toggleSubscription(for: item.station.id) }
            }
          )
        )
        .labelsHidden()
        .tint(Color(hex: "#EF6962"))
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }
}

// MARK: - Preview
struct NotificationsSettingsPageView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      NotificationsSettingsPageView(model: NotificationsSettingsPageModel())
    }
  }
}
