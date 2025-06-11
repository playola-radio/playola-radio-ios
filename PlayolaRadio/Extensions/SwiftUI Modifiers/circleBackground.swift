//
//  circleBackground.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

extension View {
    func circleBackground() -> some View {
        self.background(
          ZStack {
            Color.black
            ZStack() {
                Ellipse()
                    .foregroundColor(.clear)
                    .frame(width: 171, height: 171)
                    .overlay(
                        Ellipse()
                            .inset(by: 6)
                            .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                    )
                    .offset(x: 0.41, y: 0.41)
                Ellipse()
                    .foregroundColor(.clear)
                    .frame(width: 270.13, height: 270.13)
                    .overlay(
                        Ellipse()
                            .inset(by: 6)
                            .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                    )
                    .offset(x: 0.14, y: 0.14)
                Ellipse()
                    .foregroundColor(.clear)
                    .frame(width: 366.78, height: 366.78)
                    .overlay(
                        Ellipse()
                            .inset(by: 6)
                            .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                    )
                    .offset(x: -0.42, y: -0.42)
                Ellipse()
                    .foregroundColor(.clear)
                    .frame(width: 456, height: 456)
                    .overlay(
                        Ellipse()
                            .inset(by: 6)
                            .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: 6)
                    )
                    .offset(x: 0, y: 0)
            }
            .frame(width: 456, height: 200)
          }
        )
    }
}
