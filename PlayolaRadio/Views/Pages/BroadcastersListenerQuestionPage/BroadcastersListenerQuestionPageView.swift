//
//  BroadcastersListenerQuestionPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct BroadcastersListenerQuestionPageView: View {
  @Bindable var model: BroadcastersListenerQuestionPageModel

  var body: some View {
    ZStack {
      Color.background
        .edgesIgnoringSafeArea(.all)

      if model.isLoading {
        ProgressView()
          .tint(.textPrimary)
      } else if model.questions.isEmpty {
        emptyState
      } else {
        VStack(spacing: 0) {
          filterPills
          if model.filteredQuestions.isEmpty {
            filteredEmptyState
          } else {
            questionsList
          }
        }
      }
    }
    .navigationTitle("Listener Questions")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .onAppear {
      Task { await model.viewAppeared() }
    }
    .alert(item: $model.presentedAlert) { $0.alert }
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
              .background(
                model.selectedFilter == filter
                  ? Color.primary
                  : Color.elevatedSurface
              )
              .cornerRadius(20)
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

      Text("No Questions Yet")
        .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
        .foregroundColor(.textPrimary)

      Text("When listeners send you questions,\nthey'll appear here.")
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }

  private var filteredEmptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "line.3.horizontal.decrease.circle")
        .font(.system(size: 48))
        .foregroundColor(.textSecondary)

      Text(model.filteredEmptyStateTitle)
        .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
        .foregroundColor(.textPrimary)

      Text(model.filteredEmptyStateMessage)
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.textSecondary)
        .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxHeight: .infinity)
  }

  // MARK: - Questions List

  private var questionsList: some View {
    List {
      ForEach(model.filteredQuestions) { question in
        ListenerQuestionRow(
          question: question,
          isExpanded: model.isExpanded(question.id),
          isPlaying: model.isPlaying(question.id),
          onExpandTapped: { model.showMoreButtonTapped(question.id) },
          onPlayTapped: { Task { await model.playButtonTapped(question) } },
          onRowTapped: { Task { await model.questionRowTapped(question) } }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: model.canDecline(question)) {
          if model.canDecline(question) {
            Button(role: .destructive) {
              Task { await model.declineQuestionSwiped(question) }
            } label: {
              Label("Decline", systemImage: "xmark.circle")
            }
            .tint(Color.error)
          }
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .refreshable {
      await model.refreshPulledDown()
    }
  }
}

// MARK: - Listener Question Row

struct ListenerQuestionRow: View {
  let question: ListenerQuestion
  let isExpanded: Bool
  let isPlaying: Bool
  let onExpandTapped: () -> Void
  let onPlayTapped: () -> Void
  let onRowTapped: () -> Void

  private let collapsedLineLimit = 2

  private var transcription: String {
    question.transcription ?? "No transcription available"
  }

  private var listenerName: String {
    question.listener?.fullName ?? "Unknown Listener"
  }

  private var timeAgo: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: question.createdAt, relativeTo: Date())
  }

  private var durationString: String {
    guard let durationMS = question.durationMS else { return "" }
    let seconds = durationMS / 1000
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    if minutes > 0 {
      return "\(minutes):\(String(format: "%02d", remainingSeconds))"
    }
    return "0:\(String(format: "%02d", remainingSeconds))"
  }

  private var needsExpansion: Bool {
    transcription.count > 100
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header with listener info
      HStack(spacing: 12) {
        // Name and time
        VStack(alignment: .leading, spacing: 2) {
          Text(listenerName)
            .font(.custom(FontNames.Inter_600_SemiBold, size: 15))
            .foregroundColor(.textPrimary)

          Text(timeAgo)
            .font(.custom(FontNames.Inter_400_Regular, size: 12))
            .foregroundColor(.textSecondary)
        }

        Spacer()

        // Play button
        playButton

        // Chevron indicator
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.textSecondary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 12)

      // Transcription
      VStack(alignment: .leading, spacing: 8) {
        Text(transcription)
          .font(.custom(FontNames.Inter_400_Regular, size: 14))
          .foregroundColor(.textPrimary)
          .lineLimit(isExpanded ? nil : collapsedLineLimit)
          .animation(.easeInOut(duration: 0.2), value: isExpanded)

        HStack {
          if needsExpansion {
            Button {
              withAnimation(.easeInOut(duration: 0.25)) {
                onExpandTapped()
              }
            } label: {
              HStack(spacing: 4) {
                Text(isExpanded ? "Show less" : "Show more")
                  .font(.custom(FontNames.Inter_500_Medium, size: 13))
                  .foregroundColor(.primary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundColor(.primary)
              }
            }
          }

          Spacer()

          if question.status == .answered {
            statusBadge
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
    .background(Color.cardSurface)
    .cornerRadius(12)
    .contentShape(Rectangle())
    .onTapGesture {
      onRowTapped()
    }
  }

  // MARK: - Subviews

  private var playButton: some View {
    Button(action: onPlayTapped) {
      HStack(spacing: 6) {
        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
          .font(.system(size: 12))

        if !durationString.isEmpty {
          Text(durationString)
            .font(.custom(FontNames.Inter_500_Medium, size: 12))
        }
      }
      .foregroundColor(.textPrimary)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.primary)
      .cornerRadius(20)
    }
  }

  private var statusBadge: some View {
    Text("Answered")
      .font(.custom(FontNames.Inter_500_Medium, size: 11))
      .foregroundColor(.textPrimary)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color.success)
      .cornerRadius(10)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    BroadcastersListenerQuestionPageView(
      model: BroadcastersListenerQuestionPageModel(stationId: "preview-station")
    )
  }
  .preferredColorScheme(.dark)
}

#Preview("Empty State") {
  NavigationStack {
    BroadcastersListenerQuestionPageView(
      model: {
        let model = BroadcastersListenerQuestionPageModel(stationId: "preview-station")
        model.questions = []
        return model
      }()
    )
  }
  .preferredColorScheme(.dark)
}
