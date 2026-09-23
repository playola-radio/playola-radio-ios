//
//  AMAQuestionPickerPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct AMAQuestionPickerPageView: View {
  let model: AMAQuestionPickerPageModel

  var body: some View {
    ZStack {
      Color.background
        .edgesIgnoringSafeArea(.all)

      ProgressView()
        .tint(.textPrimary)
        .opacity(model.loadingOpacity)

      emptyState
        .opacity(model.emptyStateOpacity)
        .accessibilityHidden(model.emptyStateAccessibilityHidden)

      VStack(spacing: 0) {
        filterPills
          .opacity(model.filterPillsOpacity)
          .accessibilityHidden(model.filterPillsAccessibilityHidden)
        questionsList
          .opacity(model.contentOpacity)
          .accessibilityHidden(model.contentAccessibilityHidden)
      }
    }
    .navigationTitle(model.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .onAppear {
      Task { await model.viewAppeared() }
    }
    .playolaAlert(presentedAlertBinding)
  }

  private var presentedAlertBinding: Binding<PlayolaAlert?> {
    Binding(get: { model.presentedAlert }, set: { model.presentedAlert = $0 })
  }

  // MARK: - Filter Pills

  private var filterPills: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(model.filterOptions, id: \.self) { filter in
          Button {
            model.filterSelected(filter)
          } label: {
            Text(filter.displayText)
              .font(.custom(FontNames.Inter_500_Medium, size: 14))
              .foregroundColor(.textPrimary)
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(model.filterBackground(filter))
              .cornerRadius(20)
              .frame(minHeight: 44)
              .contentShape(Rectangle())
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 48))
        .foregroundColor(.textSecondary)

      Text(model.emptyStateTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
        .foregroundColor(.textPrimary)

      Text(model.emptyStateMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }

  // MARK: - Questions List

  private var questionsList: some View {
    List {
      ForEach(model.filteredQuestions) { question in
        AMAQuestionRow(model: model, question: question)
          .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .refreshable {
      await model.refreshPulledDown()
    }
  }
}

// MARK: - Question Row

private struct AMAQuestionRow: View {
  let model: AMAQuestionPickerPageModel
  let question: ListenerQuestion

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      transcriptSection
    }
    .background(Color.cardSurface)
    .cornerRadius(12)
    .opacity(model.rowOpacity(question.id))
    .contentShape(Rectangle())
    .disabled(model.rowDisabled(question.id))
    .onTapGesture {
      Task { await model.questionRowTapped(question) }
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(model.listenerName(question))
          .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
          .foregroundColor(.textPrimary)

        Text(model.timeAgoText(question))
          .font(.custom(FontNames.Inter_400_Regular, size: 12))
          .foregroundColor(.textSecondary)
      }

      Spacer()

      badge

      playButton

      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.textSecondary)
    }
    .padding(.horizontal, 16)
    .padding(.top, 16)
    .padding(.bottom, 12)
  }

  private var badge: some View {
    Text(model.statusBadgeText(question))
      .font(.custom(FontNames.Inter_500_Medium, size: 11))
      .foregroundColor(.textPrimary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(model.badgeBackground(question))
      .cornerRadius(10)
  }

  private var playButton: some View {
    Button {
      Task { await model.playButtonTapped(question) }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: model.playButtonIcon(question.id))
          .font(.system(size: 12))

        Text(model.durationText(question))
          .font(.custom(FontNames.Inter_500_Medium, size: 12))
      }
      .foregroundColor(.textPrimary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.playolaRed)
      .cornerRadius(20)
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
  }

  private var transcriptSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(model.transcription(question))
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textPrimary)
        .lineLimit(model.transcriptLineLimit(question.id))
        .animation(.easeInOut(duration: 0.2), value: model.isExpanded(question.id))

      expandToggle
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }

  private var expandToggle: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.25)) {
        model.expandToggleTapped(question.id)
      }
    } label: {
      HStack(spacing: 4) {
        Text(model.expandToggleText(for: question.id))
          .font(.custom(FontNames.Inter_500_Medium, size: 13))
          .foregroundColor(.playolaRed)

        Image(systemName: "chevron.down")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.playolaRed)
          .rotationEffect(.degrees(model.expandChevronRotation(question.id)))
      }
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    AMAQuestionPickerPageView(
      model: AMAQuestionPickerPageModel(
        stationId: "preview-station",
        showStartedAt: nil,
        airQuestion: { _ in }
      )
    )
  }
  .preferredColorScheme(.dark)
}
