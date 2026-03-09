//
//  Color+Palette.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 1/23/26.
//

import SwiftUI

extension Color {
  // MARK: - Primary Colors

  static var primary: Color { Color(hex: "#EF6962") }
  static var primaryHover: Color { Color(hex: "#FF7E78") }
  static var primaryDeep: Color { Color(hex: "#C4514A") }

  // MARK: - Surfaces

  static var background: Color { Color(hex: "#130000") }
  static var cardSurface: Color { Color(hex: "#3A1212") }
  static var elevatedSurface: Color { Color(hex: "#471818") }

  // MARK: - Text

  static var textPrimary: Color { Color(hex: "#FFFFFF") }
  static var textSecondary: Color { Color(hex: "#D7BFBF") }
  static var disabled: Color { Color(hex: "#A68787") }

  // MARK: - Border

  static var border: Color { Color(hex: "#4D1C1C") }

  // MARK: - Semantic Colors

  static var success: Color { Color(hex: "#4CAF50") }
  static var warning: Color { Color(hex: "#FFC107") }
  static var error: Color { Color(hex: "#FF5252") }
  static var info: Color { Color(hex: "#6EC6FF") }

  // MARK: - Grays

  static var gray100: Color { Color(hex: "#F3F0EF") }
  static var gray200: Color { Color(hex: "#DDD7D5") }
  static var gray300: Color { Color(hex: "#C7BFBD") }
  static var gray400: Color { Color(hex: "#B0A7A5") }
  static var gray500: Color { Color(hex: "#998F8D") }
  static var gray600: Color { Color(hex: "#827876") }
  static var gray700: Color { Color(hex: "#6B6260") }
  static var gray800: Color { Color(hex: "#544C4A") }
  static var gray900: Color { Color(hex: "#3D3634") }
}
