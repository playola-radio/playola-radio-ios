//
//  ToastView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/30/25.
//

import SwiftUI

struct ToastView: View {
    let toast: PlayolaToast
    
    var body: some View {
        HStack(spacing: 0) {
            Text(toast.message)
                .font(.custom("Inter", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.vertical, 14)
                .padding(.leading, 16)
            
            Spacer()
            
            Button(action: {
                toast.action?()
            }, label: {
                Text(toast.buttonTitle)
                    .font(.custom("Inter", size: 16))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#EF6962"))
                    .padding(.vertical, 12)
                    .padding(.trailing, 16)
            })
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            ToastView(toast: PlayolaToast(
                message: "Added to Liked Songs",
                buttonTitle: "View all",
                action: { print("View all tapped") }
            ))
            
            ToastView(toast: PlayolaToast(
                message: "Song removed",
                buttonTitle: "Undo",
                action: { print("Undo tapped") }
            ))
            
            ToastView(toast: PlayolaToast(
                message: "Network error",
                buttonTitle: "Retry",
                action: { print("Retry tapped") }
            ))
        }
        .padding(.horizontal, 26)
    }
}
