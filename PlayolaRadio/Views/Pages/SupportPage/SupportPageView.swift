//
//  SupportPageView.swift
//  PlayolaRadio
//
//  Created by Claude on 1/15/26.
//

import SwiftUI

struct SupportPageView: View {
  @Bindable var model: SupportPageModel

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if model.isLoading {
        ProgressView()
          .tint(.white)
      } else if model.hasExistingMessages {
        ChatView(model: model)
      } else {
        FeedbackFormView(model: model)
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
    .alert(item: $model.presentedAlert) { $0.alert }
  }
}

// MARK: - Feedback Form (First-time users)

struct FeedbackFormView: View {
  @Bindable var model: SupportPageModel
  @FocusState private var isTextFieldFocused: Bool

  private let placeholderText = """
      Tell us about a bug?
      Have an idea for a new feature?
      Just want to say hi to the team?
      
      We would LOVE to hear from you for any reason at all...
    """

  var body: some View {
    VStack(spacing: 20) {
      Text("Send us a message and we'll get back to you as soon as we can!")
        .font(.custom(FontNames.Inter_400_Regular, size: 14))
        .foregroundColor(.playolaGray)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      ZStack(alignment: .topLeading) {
        if model.newMessage.isEmpty {
          Text(placeholderText)
            .font(.custom(FontNames.Inter_400_Regular, size: 16))
            .foregroundColor(Color(hex: "#666666"))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }

        TextEditor(text: $model.newMessage)
          .font(.custom(FontNames.Inter_400_Regular, size: 16))
          .foregroundColor(.white)
          .scrollContentBackground(.hidden)
          .padding(8)
          .focused($isTextFieldFocused)
      }
      .frame(height: 180)
      .background(Color(hex: "#1A1A1A"))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color(hex: "#333333"), lineWidth: 1)
      )
      .padding(.horizontal)

      Spacer()

      Button {
        Task {
          await model.sendMessage()
        }
      } label: {
        if model.isSending {
          ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        } else {
          Text("Send Message")
            .font(.custom(FontNames.Inter_600_SemiBold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
      }
      .background(model.canSend ? Color.playolaRed : Color(hex: "#666666"))
      .cornerRadius(8)
      .disabled(!model.canSend)
      .padding(.horizontal)
      .padding(.bottom)
    }
    .padding(.top, 20)
    .onAppear {
      isTextFieldFocused = true
    }
  }
}

// MARK: - Chat View (Returning users)

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
