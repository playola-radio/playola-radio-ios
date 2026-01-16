//
//  ConversationListPageView.swift
//  PlayolaRadio
//

import SwiftUI

struct ConversationListPageView: View {
  @Bindable var model: ConversationListPageModel

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if model.isLoading {
        ProgressView()
          .tint(.white)
      } else if model.sortedConversations.isEmpty {
        emptyState
      } else {
        conversationList
      }
    }
    .navigationTitle("Support Conversations")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .task {
      await model.onViewAppeared()
    }
    .refreshable {
      await model.refresh()
    }
    .alert(item: $model.presentedAlert) { $0.alert }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "bubble.left.and.bubble.right")
        .font(.system(size: 48))
        .foregroundColor(Color(hex: "#666666"))

      Text("No conversations")
        .font(.custom(FontNames.Inter_500_Medium, size: 16))
        .foregroundColor(Color(hex: "#888888"))
    }
  }

  private var conversationList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(model.sortedConversations) { item in
          ConversationRow(item: item) {
            Task {
              await model.onConversationTapped(item)
            }
          }
          Divider()
            .background(Color(hex: "#333333"))
        }
      }
    }
  }
}

// MARK: - Conversation Row

struct ConversationRow: View {
  let item: AdminConversationResponse
  let onTap: () -> Void

  private var ownerName: String {
    item.conversation.ownerParticipant?.user?.fullName ?? "Unknown User"
  }

  private var ownerInitial: String {
    String(item.conversation.ownerParticipant?.user?.firstName.prefix(1) ?? "?")
  }

  private var hasUnread: Bool {
    item.unreadCountFromOwner > 0
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // Avatar with badge
        ZStack(alignment: .topTrailing) {
          Circle()
            .fill(Color(hex: "#444444"))
            .frame(width: 48, height: 48)
            .overlay(
              Text(ownerInitial)
                .font(.custom(FontNames.Inter_600_SemiBold, size: 18))
                .foregroundColor(.white)
            )

          if hasUnread {
            Text("\(item.unreadCountFromOwner)")
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(.white)
              .frame(minWidth: 18, minHeight: 18)
              .background(Circle().fill(Color.playolaRed))
              .offset(x: 4, y: -4)
          }
        }

        // Name and time
        VStack(alignment: .leading, spacing: 4) {
          Text(ownerName)
            .font(
              .custom(
                hasUnread ? FontNames.Inter_600_SemiBold : FontNames.Inter_500_Medium,
                size: 16
              )
            )
            .foregroundColor(.white)

          Text(formatTime(item.conversation.updatedAt))
            .font(.custom(FontNames.Inter_400_Regular, size: 13))
            .foregroundColor(Color(hex: "#888888"))
        }

        Spacer()

        // Status chip
        Text(item.conversation.status)
          .font(.custom(FontNames.Inter_500_Medium, size: 11))
          .foregroundColor(item.conversation.isOpen ? .green : Color(hex: "#888888"))
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(item.conversation.isOpen ? Color.green.opacity(0.2) : Color(hex: "#333333"))
          )

        Image(systemName: "chevron.right")
          .font(.system(size: 14))
          .foregroundColor(Color(hex: "#666666"))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
      formatter.dateFormat = "h:mm a"
    } else if calendar.isDateInYesterday(date) {
      return "Yesterday"
    } else {
      formatter.dateFormat = "MMM d"
    }

    return formatter.string(from: date)
  }
}

// MARK: - Preview

struct ConversationListPageView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      ConversationListPageView(model: ConversationListPageModel())
    }
  }
}
