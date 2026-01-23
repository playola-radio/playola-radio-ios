//
//  BroadcastersListenerQuestionPageView.swift
//  PlayolaRadio
//

import SDWebImageSwiftUI
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
        questionsList
      }
    }
    .navigationTitle("Listener Questions")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.background, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .task {
      await model.viewAppeared()
    }
    .alert(item: $model.presentedAlert) { $0.alert }
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

  // MARK: - Questions List

  private var questionsList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        ForEach(model.questions) { question in
          ListenerQuestionRow(
            question: question,
            isExpanded: model.isExpanded(question.id),
            isPlaying: model.isPlaying(question.id),
            onExpandTapped: { model.toggleExpanded(question.id) },
            onPlayTapped: { Task { await model.onPlayTapped(question) } }
          )
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
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
        // Avatar
        listenerAvatar

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

        if needsExpansion {
          Button(action: onExpandTapped) {
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
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
    .background(Color.cardSurface)
    .cornerRadius(12)
  }

  // MARK: - Subviews

  private var listenerAvatar: some View {
    Group {
      if let imageUrlString = question.listener?.profileImageUrl,
        let imageUrl = URL(string: imageUrlString)
      {
        WebImage(url: imageUrl)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 44, height: 44)
          .clipShape(Circle())
      } else {
        Circle()
          .fill(Color.elevatedSurface)
          .frame(width: 44, height: 44)
          .overlay(
            Text(listenerInitials)
              .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
              .foregroundColor(.textSecondary)
          )
      }
    }
  }

  private var listenerInitials: String {
    guard let listener = question.listener else { return "?" }
    let first = listener.firstName.prefix(1)
    let last = listener.lastName?.prefix(1) ?? ""
    return "\(first)\(last)".uppercased()
  }

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
