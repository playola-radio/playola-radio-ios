//
//  SupportPageView.swift
//  PlayolaRadio
//
//  Created by Claude on 1/15/26.
//

import SwiftUI

struct SupportPageView: View {
  @Bindable var model: SupportPageModel
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if model.isLoading {
        ProgressView()
          .tint(.white)
      } else {
        ChatView(model: model)
      }
    }
    .navigationTitle("Contact Us")
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbarBackground(Color.black, for: .navigationBar)
    .toolbarColorScheme(.dark, for: .navigationBar)
    .task {
      await model.onViewAppeared()
    }
    .task {
      await model.observeRefreshNotifications()
    }
    .alert(item: $model.presentedAlert) { $0.alert }
    .onChange(of: scenePhase) { _, newPhase in
      Task { await model.handleScenePhaseChange(newPhase) }
    }
  }
}

// MARK: - Chat View

struct ChatView: View {
  @Bindable var model: SupportPageModel
  @FocusState private var isInputFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 12) {
            ForEach(model.messages) { message in
              MessageBubble(
                message: message,
                isFromCurrentUser: message.senderId == model.currentUserId
              )
              .id(message.id)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .onChange(of: model.messages.count) { _, _ in
          if let lastMessage = model.messages.last {
            withAnimation {
              proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
          }
        }
        .onAppear {
          if let lastMessage = model.messages.last {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
      .refreshable {
        await model.refreshMessages()
      }

      Divider()
        .background(Color(hex: "#333333"))

      HStack(spacing: 12) {
        TextField("Message", text: $model.newMessage, axis: .vertical)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(Color(hex: "#1A1A1A"))
          .cornerRadius(20)
          .lineLimit(1...5)
          .focused($isInputFocused)

        Button {
          Task {
            await model.sendMessage()
          }
        } label: {
          if model.isSending {
            ProgressView()
              .tint(.white)
              .frame(width: 36, height: 36)
          } else {
            Image(systemName: "arrow.up.circle.fill")
              .font(.system(size: 36))
              .foregroundColor(model.canSend ? .playolaRed : Color(hex: "#666666"))
          }
        }
        .disabled(!model.canSend)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color.black)
    }
  }
}

// MARK: - Message Bubble

struct MessageBubble: View {
  let message: Message
  let isFromCurrentUser: Bool

  var body: some View {
    HStack {
      if isFromCurrentUser {
        Spacer(minLength: 60)
      }

      VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
        // Show sender name for messages not from current user
        if !isFromCurrentUser, let senderName = message.sender?.displayName {
          Text(senderName)
            .font(.custom(FontNames.Inter_500_Medium, size: 12))
            .foregroundColor(Color(hex: "#AAAAAA"))
        }

        Text(message.message)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.white)
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(isFromCurrentUser ? Color.playolaRed : Color(hex: "#333333"))
          .cornerRadius(18)

        Text(formatTime(message.createdAt))
          .font(.custom(FontNames.Inter_400_Regular, size: 11))
          .foregroundColor(Color(hex: "#888888"))
      }

      if !isFromCurrentUser {
        Spacer(minLength: 60)
      }
    }
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

struct SupportPageView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationStack {
      SupportPageView(model: SupportPageModel())
    }
  }
}
