//
//  Date+Comparisons.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 12/19/24.
//

import Foundation

extension Date {
  init(dateString:String) {
    let dateStringFormatter = DateFormatter()
    dateStringFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    dateStringFormatter.locale = Locale(identifier: "en_US_POSIX")
    let d = dateStringFormatter.date(from: dateString)!
    self.init(timeInterval:0, since:d)
  }

  init?(isoString:String?) {
    if let isoString = isoString
    {
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

      if let newDate = dateFormatter.date(from: isoString)
      {
        self.init(timeInterval:0, since: newDate)
        return
      }
    }
    return nil
  }

  func isAfter(_ dateToCompare : Date) -> Bool {
    //Declare Variables
    var isGreater = false

    //Compare Values
    if self.compare(dateToCompare) == ComparisonResult.orderedDescending
    {
      isGreater = true
    }

    //Return Result
    return isGreater
  }

  func isBefore(_ dateToCompare : Date) -> Bool {
    //Declare Variables
    var isLess = false

    //Compare Values
    if self.compare(dateToCompare) == ComparisonResult.orderedAscending
    {
      isLess = true
    }

    //Return Result
    return isLess
  }

  func addDays(_ daysToAdd : Int) -> Date {
    let secondsInDays : TimeInterval = Double(daysToAdd) * 60 * 60 * 24
    let dateWithDaysAdded : Date = self.addingTimeInterval(secondsInDays)

    //Return Result
    return dateWithDaysAdded
  }

  func addHours(_ hoursToAdd : Int) -> Date {
    let secondsInHours : TimeInterval = Double(hoursToAdd) * 60 * 60
    let dateWithHoursAdded : Date = self.addingTimeInterval(secondsInHours)

    //Return Result
    return dateWithHoursAdded
  }

  func addMinutes(_ minutesToAdd : Int) -> Date {
    let secondsInMinutes : TimeInterval = Double(minutesToAdd) * 60
    let dateWithMinutesAdded : Date = self.addingTimeInterval(secondsInMinutes)

    //Return Result
    return dateWithMinutesAdded
  }

  func addSeconds(_ secondsToAdd : Int) -> Date {
    let secondsInSeconds : TimeInterval = Double(secondsToAdd)
    let dateWithSecondsAdded : Date = self.addingTimeInterval(secondsInSeconds)

    //Return Result
    return dateWithSecondsAdded
  }

  func addMilliseconds(_ msToAdd : Int) -> Date {
    let millisecondsInSeconds: TimeInterval = Double(msToAdd)/1000.0
    let dateWithMSAdded : Date = self.addingTimeInterval(millisecondsInSeconds)

    //Return Result
    return dateWithMSAdded
  }

  func toISOString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: self)
  }

  func toBeautifulString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm:ssa"
    return formatter.string(from: self).lowercased()
  }

  func toApiParamString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/MM/dd/HH/mm"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: self)
  }
}
