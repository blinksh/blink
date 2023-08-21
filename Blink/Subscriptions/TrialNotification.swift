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

fileprivate let unc = UNUserNotificationCenter.current()
fileprivate let trialWillConvertID = "trial-will-convert"
fileprivate let trialSupportRequestID = "trial-support-request"

enum TrialProgressNotification {
  case OneWeek
  case OneMonth
}

extension TrialProgressNotification {
  func setup() async throws -> Bool {
    if !(try await unc.requestAuthorization(options: .alert)) {
      return false
    }

    try await scheduleTrialWillConvertNotification()
    try await scheduleTrialSupportRequestNotification()
    return true
  }

  private func scheduleTrialWillConvertNotification() async throws {
    let content = UNMutableNotificationContent()
    content.title = "Hope you are enjoying Blink."

    var dateComponents = DateComponents()
    switch self {
    case .OneWeek:
      dateComponents.day = 5
      content.body = "Your trial will convert in 2 days."
    case .OneMonth:
      dateComponents.day = 23
      content.body = "Your trial will convert in 7 days."
    }
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents,
                                                repeats: false)

    let request = UNNotificationRequest(identifier: trialWillConvertID,
                                        content: content,
                                        trigger: trigger)

    try await unc.add(request)
  }

  private func scheduleTrialSupportRequestNotification() async throws {
    let content = UNMutableNotificationContent()

    var dateComponents = DateComponents()
    switch self {
    case .OneWeek:
      dateComponents.day = 3
      content.title = "You are in day 3 of your trial..."
      content.body = "And we are here to help setting things up. Type `config` on the shell and ask us!"
    case .OneMonth:
      dateComponents.day = 7
      content.title = "You are in day 7 of your trial..."
      content.body = "And we are here to help setting things up. Type `config` on the shell and ask us!"
    }
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents,
                                                repeats: false)

    let request = UNNotificationRequest(identifier: trialSupportRequestID,
                                        content: content,
                                        trigger: trigger)

    try await unc.add(request)

  }
}
