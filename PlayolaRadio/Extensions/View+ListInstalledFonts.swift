//
//  View+ListFontFamilies.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 6/10/25.
//
import SwiftUI

public extension View {
  func listInstalledFonts() {
          let fontFamilies = UIFont.familyNames.sorted()
          for family in fontFamilies {
              print(family)
              for font in UIFont.fontNames(forFamilyName: family).sorted() {
                  print("\t\(font)")
              }
          }
      }
}
