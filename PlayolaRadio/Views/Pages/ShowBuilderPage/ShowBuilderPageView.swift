//
//  ShowBuilderPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct ShowBuilderPageView: View {
  @Bindable var model: ShowBuilderPageModel

  var body: some View {
    List {
      topSection
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      ForEach(model.rows) { row in
        AMAOpeningRowView(data: row.data)
          .moveDisabled(!model.canReorder)
          .swipeActions {
            Button(model.removeRowLabel, role: .destructive) {
              Task { await model.segmentDeleteTapped(row.id) }
            }
            .disabled(!row.data.isEditable)
          }
      }
      .onMove { source, destination in
        Task { await model.segmentsMoved(from: source, to: destination) }
      }
      .listRowInsets(EdgeInsets())
      .listRowSeparator(.hidden)
      .listRowBackground(Color.playolaSurfaceRow)
      addToShowCard
        .opacity(model.addCardOpacity)
        .allowsHitTesting(model.canEditContent)
        .padding(.top, 32)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    .listStyle(.plain)
    .environment(\.defaultMinListRowHeight, 0)
    .contentMargins(.all, 0, for: .scrollContent)
    .scrollContentBackground(.hidden)
    .overlay { loadingSpinner }
    .safeAreaInset(edge: .bottom) { bottomButtons }
    .background(Color.playolaSurfaceBase)
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(model.renameButtonTitle) { model.renameButtonTapped() }
          .foregroundColor(.playolaRed)
          .disabled(!model.canRename)
      }
    }
    .task { await model.viewAppeared() }
    .playolaAlert($model.presentedAlert)
    .alert(model.renameAlertTitle, isPresented: $model.isRenameAlertPresented) {
      TextField(model.renameFieldPlaceholder, text: $model.renameText)
      Button(model.renameCancelButtonTitle, role: .cancel) {}
      Button(model.renameSaveButtonTitle) {
        Task { await model.renameSaveButtonTapped() }
      }
    }
  }

  private var topSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(model.lockedBanners) { banner in
        lockedBanner(banner)
          .padding(.bottom, 24)
      }
      header
      Divider()
        .overlay(Color.playolaGlassHairline)
        .padding(.top, 16)
      seriesRow
        .padding(.top, 14)
      ForEach(model.lockLines, id: \.self) { line in
        noticeLine(icon: "lock.open", text: line)
      }
      ForEach(model.readOnlyNotices, id: \.self) { notice in
        noticeLine(icon: "globe", text: notice)
      }
      yourShowHeader
        .padding(.top, 24)
        .padding(.bottom, 10)
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      ForEach(model.draftBadges, id: \.self) { _ in
        DraftDateBadge()
      }
      ForEach(model.calendarBadges) { badge in
        CalendarDateBadge(date: badge.date, timeZone: badge.timeZone)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(model.headline)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
          .foregroundColor(model.headlineColor)
        Text(model.statusLine)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaTextSecondary)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      Spacer(minLength: 8)
      ForEach(model.changeTimeButtons, id: \.self) { title in
        Button {
          model.changeTimeButtonTapped()
        } label: {
          Text(title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.playolaRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.playolaRed, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var seriesRow: some View {
    Button {
      model.seriesRowTapped()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "square.stack.3d.up")
          .font(.system(size: 16))
          .foregroundColor(.playolaTextPrimary)
        Text(model.seriesTitle)
          .font(.custom(FontNames.Inter_500_Medium, size: 15))
          .foregroundColor(.playolaTextPrimary)
        Spacer()
        Text(model.seriesActionText)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
          .foregroundColor(model.seriesActionColor)
      }
      .padding(.horizontal, 16)
      .frame(height: 44)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.playolaGlassHairline, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!model.canChangeSeries)
  }

  private func noticeLine(icon: String, text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 13))
      Text(text)
        .font(.custom(FontNames.Inter_400_Regular, size: 13))
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(.playolaTextSecondary)
    .padding(.top, 14)
  }

  private func lockedBanner(_ banner: ShowBuilderBanner) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lock")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.playolaWarningAmber)
      VStack(alignment: .leading, spacing: 4) {
        Text(banner.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.playolaWarningAmber)
        Text(banner.message)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaTextSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .background(Color.playolaWarningAmber.opacity(0.12))
    .cornerRadius(12)
  }

  private var yourShowHeader: some View {
    HStack {
      Text(model.yourShowTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
        .tracking(1)
      Spacer()
      Text(model.totalDurationText)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
    }
    .foregroundColor(.playolaTextSecondary)
  }

  private var addToShowCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 7) {
        Image(systemName: "plus.circle")
          .font(.system(size: 18))
          .foregroundColor(.playolaRed)
        Text(model.addSectionTitle)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 19))
          .foregroundColor(.playolaTextPrimary)
      }
      Text(model.addSectionExplanation)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaTextSecondary)
      HStack(spacing: 12) {
        addAction(icon: "mic", label: model.voicetrackActionLabel) {
          model.voicetrackActionTapped()
        }
        addAction(icon: "music.note", label: model.songActionLabel) {
          model.songActionTapped()
        }
        addAction(icon: "bubble.left.and.bubble.right", label: model.qaActionLabel) {
          model.qaActionTapped()
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.playolaSurfaceSection)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.playolaGlassHairline, lineWidth: 1)
    )
  }

  private func addAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 10) {
        ZStack(alignment: .bottomTrailing) {
          ZStack {
            Circle()
              .fill(Color.playolaRed)
              .frame(width: 64, height: 64)
              .overlay(Circle().stroke(Color.playolaTextPrimary, lineWidth: 2))
            Image(systemName: icon)
              .font(.system(size: 24))
              .foregroundColor(.playolaTextPrimary)
          }
          ZStack {
            Circle()
              .fill(Color.playolaWarmSurface)
              .frame(width: 22, height: 22)
              .overlay(Circle().stroke(Color.playolaTextPrimary, lineWidth: 1.5))
            Image(systemName: "plus")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.playolaTextPrimary)
          }
        }
        Text(label)
          .font(.custom(FontNames.Inter_400_Regular, size: 13))
          .foregroundColor(.playolaTextPrimary)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
  }

  private var bottomButtons: some View {
    VStack(spacing: 0) {
      ForEach(model.scheduleButtons, id: \.self) { title in
        Button {
          model.scheduleButtonTapped()
        } label: {
          Label(title, systemImage: "calendar.badge.plus")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.playolaRed)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
      }
      ForEach(model.unscheduleButtons, id: \.self) { title in
        Button {
          model.unscheduleButtonTapped()
        } label: {
          Label(title, systemImage: "calendar.badge.minus")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 17))
            .foregroundColor(.playolaRed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
              RoundedRectangle(cornerRadius: 16)
                .stroke(Color.playolaRed, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color.playolaSurfaceBase)
  }

  private var loadingSpinner: some View {
    ProgressView()
      .tint(.white)
      .opacity(model.loadingOpacity)
  }
}

#Preview {
  NavigationStack {
    ShowBuilderPageView(
      model: ShowBuilderPageModel(
        stationId: "station-preview", episodeId: nil, seriesId: nil, slot: nil))
  }
  .preferredColorScheme(.dark)
}
