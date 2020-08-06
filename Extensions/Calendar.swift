//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

import Foundation

extension Calendar {
  
  /**
   Given two dates return the number of days between them
   
   - Returns: `Int` value with the days between dates
   */
  static func daysBetweenDates(startDate: Date, endDate: Date) -> Int? {
    
    let calendar = Calendar.current
    
    let currentDate = calendar.startOfDay(for: startDate)
    let boughtDate = calendar.startOfDay(for: endDate)
    
    let components = calendar.dateComponents([.day], from: boughtDate, to: currentDate)
    
    guard let daysInUse = components.day else {
      return nil
    }
    
    return daysInUse
  }
  
  /**
   Given two dates return the number of days between them
   
   - Returns: `Int` value with the days between dates
   */
  static func dateIntervalBetweenDates(startDate: Date, endDate: Date) -> String? {

      let calendar = Calendar.current

      let components = calendar.dateComponents([.day, .hour, .minute], from: endDate, to: startDate)

      guard let daysInUse = components.day else {
          return nil
      }

      if daysInUse == 0 {
          guard let hours = components.hour else {
              return nil
          }

          if hours == 0 {
              guard let minutes = components.minute else {
                  return nil
              }

              return "\(minutes) minutes"

          }

          return "\(hours) hours"
      }

      return "\(daysInUse) days"
  }
}
