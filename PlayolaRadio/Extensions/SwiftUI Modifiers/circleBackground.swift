//
//  circleBackground.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

extension View {
  func circleBackground(offsetY: CGFloat = 0, lineWidth: CGFloat = 12) -> some View {
        self.background(
          GeometryReader { geometry in
            ZStack {
                Color.black
                ZStack {
                    Ellipse()
                        .foregroundColor(.clear)
                        .frame(width: 171 * 1.2, height: 171 * 1.2)
                        .overlay(
                            Ellipse()
                                .inset(by: 6)
                                .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: lineWidth)
                        )
                        .offset(x: 0.41, y: 0.41)
                    Ellipse()
                        .foregroundColor(.clear)
                        .frame(width: 270.13 * 1.2, height: 270.13 * 1.2)
                        .overlay(
                            Ellipse()
                                .inset(by: 6)
                                .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: lineWidth)
                        )
                        .offset(x: 0.14, y: 0.14)
                    Ellipse()
                        .foregroundColor(.clear)
                        .frame(width: 366.78 * 1.2, height: 366.78 * 1.2)
                        .overlay(
                            Ellipse()
                                .inset(by: 6)
                                .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: lineWidth)
                        )
                        .offset(x: -0.42, y: -0.42)
                    Ellipse()
                        .foregroundColor(.clear)
                        .frame(width: 456 * 1.2, height: 456 * 1.2)
                        .overlay(
                            Ellipse()
                                .inset(by: 6)
                                .stroke(Color(red: 0.12, green: 0.12, blue: 0.12), lineWidth: lineWidth)
                        )
                        .offset(x: 0, y: 0)
                }
                .offset(y: offsetY)
                .frame(width: geometry.size.width * 1.2, height: geometry.size.height * 1.2)
                .position(x: geometry.size.width/2, y: geometry.size.height/2)
            }
          }
        )
    }
}
