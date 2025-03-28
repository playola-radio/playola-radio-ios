//
//  Date+Formatting.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/28/25.
//
import Foundation

extension Date {
  func toBeautifulString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: self)
  }
}
