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
        .padding(.top, 4)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      ForEach(model.rows) { row in
        segmentRow(row)
          .moveDisabled(!model.canReorder)
          .swipeActions {
            Button(model.removeRowLabel, role: .destructive) {
              Task { await model.rowDeleteTapped(row.id) }
            }
            .disabled(!row.isEditable)
          }
      }
      .onMove { source, destination in
        Task { await model.rowsMoved(from: source, to: destination) }
      }
      .listRowInsets(EdgeInsets())
      .listRowSeparator(.hidden)
      .listRowBackground(Color.playolaSurfaceRow)
      addToShowCard
        .opacity(model.addCardOpacity)
        .allowsHitTesting(model.canEditContent)
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
  }

  private var topSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(model.lockedBanners) { banner in
        lockedBanner(banner)
          .padding(.bottom, 12)
      }
      header
        .frame(height: 68)
      Rectangle()
        .fill(Color.playolaDividerSubtle)
        .frame(height: 1)
      seriesRow
        .padding(.top, 14)
      ForEach(model.lockLines, id: \.self) { line in
        noticeLine(Image("RecordedShows-lock-open").resizable(), text: line)
      }
      ForEach(model.readOnlyNotices, id: \.self) { notice in
        noticeLine(Image(systemName: "globe").resizable(), text: notice)
      }
      yourShowHeader
        .padding(.top, 22)
        .padding(.bottom, 8)
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
      VStack(alignment: .leading, spacing: 3) {
        Text(model.headline)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(model.headlineColor)
        Text(model.statusLine)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextTertiary)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      Spacer(minLength: 8)
      ForEach(model.changeTimeButtons, id: \.self) { title in
        Button {
          model.changeTimeButtonTapped()
        } label: {
          Text(title)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 13))
            .foregroundColor(.playolaRed)
            .padding(.horizontal, 10)
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
      HStack(spacing: 10) {
        Image("RecordedShows-layers")
          .resizable()
          .scaledToFit()
          .frame(width: 16, height: 16)
          .foregroundColor(.playolaTextSecondary)
        Text(model.seriesTitle)
          .font(.custom(FontNames.Inter_500_Medium, size: 14))
          .foregroundColor(model.seriesTitleColor)
        Spacer()
        Text(model.seriesActionText)
          .font(.custom(model.seriesActionFontName, size: 12))
          .foregroundColor(model.seriesActionColor)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(model.seriesRowOutlineColor, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!model.canChangeSeries)
  }

  private func noticeLine(_ icon: Image, text: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
      icon
        .scaledToFit()
        .frame(width: 13, height: 13)
      Text(text)
        .font(.custom(FontNames.Inter_400_Regular, size: 12))
        .fixedSize(horizontal: false, vertical: true)
    }
    .foregroundColor(.playolaTextTertiary)
    .padding(.top, 12)
  }

  private func lockedBanner(_ banner: ShowBuilderBanner) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image("RecordedShows-lock")
        .resizable()
        .scaledToFit()
        .frame(width: 16, height: 16)
        .foregroundColor(.playolaWarningAmber)
      VStack(alignment: .leading, spacing: 3) {
        Text(banner.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundColor(.playolaWarningAmber)
        Text(banner.message)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(Color.playolaWarningAmber.opacity(0.1))
    .cornerRadius(10)
  }

  private var yourShowHeader: some View {
    HStack {
      Text(model.yourShowTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
        .tracking(0.6)
      Spacer()
      Text(model.totalDurationText)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 12))
    }
    .foregroundColor(.playolaTextTertiary)
  }

  private func segmentRow(_ row: ShowBuilderSegmentRow) -> some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 4)
        .fill(row.tileColor)
        .overlay(
          Image(row.icon).resizable().scaledToFit().frame(width: 20, height: 20)
            .foregroundStyle(Color.playolaTextPrimary)
        )
        .frame(width: 45, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 4))
      VStack(alignment: .leading, spacing: 2) {
        Text(row.title)
          .font(.custom(FontNames.Inter_600_SemiBold, size: 14))
          .foregroundStyle(Color.playolaTextPrimary)
        Text(row.subtitle)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundStyle(Color.playolaTextDisabled)
      }
      .lineLimit(1)
      Spacer(minLength: 0)
      Text(row.durationText)
        .font(.custom(FontNames.Inter_400_Regular, size: 11))
        .foregroundStyle(Color.playolaTextDisabled)
      ForEach(row.handleIcons, id: \.self) { icon in
        Image(icon).resizable().scaledToFit().frame(width: 14, height: 14)
          .foregroundStyle(Color.playolaTextDisabled)
          .padding(.leading, 8)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var addToShowCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 7) {
          Image("AMA-circle-plus")
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .foregroundColor(.playolaRed)
          Text(model.addSectionTitle)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.playolaTextPrimary)
        }
        Text(model.addSectionExplanation)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.playolaTextSecondary)
      }
      HStack(spacing: 8) {
        addAction(icon: "AMA-mic", label: model.voicetrackActionLabel) {
          model.voicetrackActionTapped()
        }
        addAction(icon: "AMA-music-2", label: model.songActionLabel) {
          model.songActionTapped()
        }
        addAction(icon: "AMA-messages-square", label: model.qaActionLabel) {
          model.qaActionTapped()
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(16)
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
      VStack(spacing: 8) {
        ZStack(alignment: .bottomTrailing) {
          ZStack {
            Circle()
              .fill(Color.playolaRed)
              .frame(width: 64, height: 64)
              .overlay(Circle().stroke(Color.playolaTextPrimary, lineWidth: 2))
            Image(icon)
              .resizable()
              .scaledToFit()
              .frame(width: 28, height: 28)
              .offset(x: -1, y: -2)
              .foregroundColor(.playolaTextPrimary)
          }
          ZStack {
            Circle()
              .fill(Color.playolaWarmSurface)
              .frame(width: 22, height: 22)
              .overlay(Circle().stroke(Color.playolaTextPrimary, lineWidth: 1.5))
            Image("AMA-plus")
              .resizable()
              .scaledToFit()
              .frame(width: 14, height: 14)
              .foregroundColor(.playolaTextPrimary)
          }
        }
        Text(label)
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
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
          bottomButtonLabel(title, icon: "RecordedShows-calendar-clock")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.playolaRed)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
      }
      ForEach(model.unscheduleButtons, id: \.self) { title in
        Button {
          model.unscheduleButtonTapped()
        } label: {
          bottomButtonLabel(title, icon: "RecordedShows-calendar-x")
            .foregroundColor(.playolaRed)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
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

  private func bottomButtonLabel(_ title: String, icon: String) -> some View {
    HStack(spacing: 8) {
      Image(icon).resizable().scaledToFit().frame(width: 18, height: 18)
      Text(title)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
    }
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
