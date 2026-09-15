//
//  Color+Hex.swift
//  Playola Radio
//
//  Created by Brian D Keane on 5/6/24.
//

import Foundation
import SwiftUI

extension Color {
  // swiftlint:disable identifier_name
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a: UInt64
    let r: UInt64
    let g: UInt64
    let b: UInt64
    switch hex.count {
    case 3:  // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6:  // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8:  // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (1, 1, 1, 0)
    }

    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
  // swiftlint:enable identifier_name

  static var playolaRed: Color {
    Color(hex: "#EF6962")
  }

  static var playolaLightPurple: Color {
    Color(hex: "#6962EF")
  }

  static var playolaGray: Color {
    Color(hex: "#868686")
  }

  // MARK: - Playola Design Tokens

  private static func playolaColor(_ hex: String, alpha: UInt8) -> Color {
    Color(hex: hex).opacity(Double(alpha) / 255)
  }

  // Brand
  static var playolaBrandPrimary: Color { playolaRed }
  static var playolaBrandSecondary: Color { playolaLightPurple }
  static var playolaCTADustyRed: Color { Color(hex: "#CC6666") }

  // Neutral surfaces
  static var playolaSurfaceBase: Color { Color(hex: "#000000") }
  static var playolaSurfaceDeep: Color { Color(hex: "#101010") }
  static var playolaSurfaceTrueBlack: Color { Color(hex: "#050505") }
  static var playolaSurfaceSection: Color { Color(hex: "#1A1A1A") }
  static var playolaSurfaceRaised: Color { Color(hex: "#2A2A2A") }
  static var playolaSurfaceTile: Color { Color(hex: "#262626") }
  static var playolaSurfaceRow: Color { Color(hex: "#333333") }
  static var playolaSurfaceControl: Color { Color(hex: "#444444") }
  static var playolaSurfaceMuted: Color { Color(hex: "#4A4A4A") }
  static var playolaSurfacePlaceholder: Color { Color(hex: "#666666") }
  static var playolaSurfaceArtPlaceholder: Color { Color(hex: "#4D4D4D") }
  static var playolaRingStroke: Color { Color(hex: "#1F1F1F") }
  static var playolaDividerStrong: Color { Color(hex: "#303030") }

  // Warm surfaces
  static var playolaWarmBase: Color { Color(hex: "#130000") }
  static var playolaWarmSurface: Color { Color(hex: "#3A1212") }
  static var playolaWarmSurfaceRaised: Color { Color(hex: "#471818") }
  static var playolaWarmControlDisabled: Color { Color(hex: "#2A1313") }
  static var playolaWarmGray900: Color { Color(hex: "#3D3634") }
  static var playolaWarmGray700: Color { Color(hex: "#6B6260") }
  static var playolaWarmGray600: Color { Color(hex: "#827876") }
  static var playolaWarmGray400: Color { Color(hex: "#B0A7A5") }

  // Question and playback surfaces
  static var playolaQuestionControlInk: Color { Color(hex: "#190605") }
  static var playolaQuestionBadgeSurface: Color { Color(hex: "#562321") }
  static var playolaQuestionNextSurface: Color { Color(hex: "#221010") }
  static var playolaQuestionPendingSurface: Color { Color(hex: "#171010") }
  static var playolaQuestionTraySurface: Color { Color(hex: "#190909") }
  static var playolaLockedSegment: Color { Color(hex: "#696969") }
  static var playolaLockedSegmentLight: Color { Color(hex: "#858585") }
  static var playolaProgressTrack: Color { Color(hex: "#5E5F5F") }

  // Text and icons
  static var playolaTextPrimary: Color { Color(hex: "#FFFFFF") }
  static var playolaTextSecondary: Color { Color(hex: "#C7C7C7") }
  static var playolaTextTertiary: Color { Color(hex: "#999999") }
  static var playolaTextQuaternary: Color { Color(hex: "#888888") }
  static var playolaTextMuted: Color { Color(hex: "#AAAAAA") }
  static var playolaTextDisabled: Color { playolaGray }
  static var playolaWarmTextSecondary: Color { Color(hex: "#D7BFBF") }
  static var playolaIconInactive: Color { Color(hex: "#BABABA") }
  static var playolaSystemGray: Color { Color(hex: "#8E8E93") }

  // Status and data
  static var playolaSuccessGreen: Color { Color(hex: "#34C759") }
  static var playolaLiveOnAir: Color { playolaSuccessGreen }
  static var playolaSuccessMaterial: Color { Color(hex: "#4CAF50") }
  static var playolaCommercialGreen: Color { Color(hex: "#2E7D32") }
  static var playolaWarningAmber: Color { Color(hex: "#FFC107") }
  static var playolaBufferAmber: Color { Color(hex: "#E9B85B") }
  static var playolaSystemRed: Color { Color(hex: "#FF3B30") }
  static var playolaInfoBlue: Color { Color(hex: "#6EC6FF") }
  static var playolaGiveawayPurple: Color { Color(hex: "#AF52DE") }
  static var playolaStarActive: Color { Color(hex: "#FFD24A") }
  static var playolaStarInactive: Color { playolaTextQuaternary }

  // Glass and overlays. Pen stores these as RRGGBBAA; use an exact alpha here
  // because Color(hex:) intentionally preserves its existing AARRGGBB contract.
  static var playolaTransparent: Color { Color.clear }
  static var playolaWarmTransparent: Color { playolaWarmBase.opacity(0) }
  static var playolaOverlayScrim70: Color { playolaColor("#000000", alpha: 0xB3) }
  static var playolaOverlayScrim85: Color { playolaColor("#000000", alpha: 0xD9) }
  static var playolaOverlayBlack40: Color { playolaColor("#000000", alpha: 0x66) }
  static var playolaOverlayBlack45: Color { playolaColor("#000000", alpha: 0x73) }
  static var playolaGlassFill: Color { playolaColor("#2C2C2E", alpha: 0xCC) }
  static var playolaGlassHairline: Color { playolaColor("#FFFFFF", alpha: 0x26) }
  static var playolaOverlayWhite7: Color { playolaColor("#FFFFFF", alpha: 0x12) }
  static var playolaDividerSubtle: Color { playolaOverlayWhite7 }
  static var playolaOverlayWhite12: Color { playolaColor("#FFFFFF", alpha: 0x1F) }
  static var playolaOverlayWhite14: Color { playolaColor("#FFFFFF", alpha: 0x24) }
  static var playolaOverlayWhite35: Color { playolaColor("#FFFFFF", alpha: 0x59) }
  static var playolaOverlayWhite50: Color { playolaColor("#FFFFFF", alpha: 0x80) }
  static var playolaOverlayWhite85: Color { playolaColor("#FFFFFF", alpha: 0xD9) }

  // Tinted states
  static var playolaBrandSoft10: Color { playolaColor("#EF6962", alpha: 0x1A) }
  static var playolaBrandSoft16: Color { playolaColor("#EF6962", alpha: 0x29) }
  static var playolaBrandSoft18: Color { playolaColor("#EF6962", alpha: 0x2E) }
  static var playolaBrandSoft30: Color { playolaColor("#EF6962", alpha: 0x4D) }
  static var playolaBrandSoft40: Color { playolaColor("#EF6962", alpha: 0x66) }
  static var playolaInfoSoft10: Color { playolaColor("#6EC6FF", alpha: 0x1A) }
  static var playolaInfoSoft40: Color { playolaColor("#6EC6FF", alpha: 0x66) }
  static var playolaAMASoft: Color { playolaColor("#FF5A5F", alpha: 0x22) }

  // Semantic aliases used by specific components
  static var playolaBorderDashed: Color { playolaSurfaceArtPlaceholder }
  static var playolaScheduleRow: Color { playolaSurfaceRow }
  static var playolaScheduleRowLocked: Color { playolaSurfaceControl }
  static var playolaDisabledFill: Color { playolaSurfacePlaceholder }
  static var playolaDisabledStroke: Color { playolaTextQuaternary }
}
