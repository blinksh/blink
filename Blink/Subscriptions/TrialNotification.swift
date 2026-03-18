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
import UserNotifications

fileprivate let unc = UNUserNotificationCenter.current()
fileprivate let trialWillConvertID = "trial-will-convert"
fileprivate let trialSupportRequestID = "trial-support-request"

enum TrialProgressNotification {
  case OneWeek
  case TwoWeeks
  case OneMonth
}

extension TrialProgressNotification {
  // MARK: - Readiness (provisional-first)

  enum NotificationReadiness {
    case ready
    case needsSettings
    case unknown(String)
  }

  private enum NotificationAuthStatus { case notDetermined, authorized, provisional, denied, ephemeral }

  private static func currentAuthStatus() async -> NotificationAuthStatus {
    await withCheckedContinuation { cont in
      UNUserNotificationCenter.current().getNotificationSettings { s in
        let st: NotificationAuthStatus = switch s.authorizationStatus {
          case .notDetermined: .notDetermined
          case .denied:        .denied
          case .authorized:    .authorized
          case .provisional:   .provisional
          case .ephemeral:     .ephemeral
          @unknown default:    .denied
        }
        cont.resume(returning: st)
      }
    }
  }

  /// Preflight status
  static func ensureNotificationsReady() async -> NotificationReadiness {
    let status = await currentAuthStatus()
    switch status {
    case .authorized, .provisional, .ephemeral:
      return .ready

    case .notDetermined:
      do {
        let granted = try await UNUserNotificationCenter.current()
          .requestAuthorization(options: [.alert, .provisional])
        return granted ? .ready : .needsSettings
      } catch {
        return .unknown(error.localizedDescription)
      }

    case .denied:
      return .needsSettings
    }
  }

  func setup() async throws {
    try await scheduleTrialWillConvertNotification()
    try await scheduleTrialSupportRequestNotification()
  }

  private func scheduleTrialWillConvertNotification() async throws {
    let content = UNMutableNotificationContent()
    content.title = "Hope you are enjoying Blink."

    var notifyAfterDays: Int
    switch self {
    case .OneWeek:
      notifyAfterDays = 7 - 2
      content.body = "Your trial will convert in 2 days."
    case .TwoWeeks:
      notifyAfterDays = 14 - 3
      content.body = "Your trial will convert in 3 days."
    case .OneMonth:
      notifyAfterDays = 30 - 7
      content.body = "Your trial will convert in 7 days."
    }

    let targetDate = Calendar.current.date(byAdding: .day, value: notifyAfterDays, to: Date())!
    var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
    dateComponents.hour = 12
    dateComponents.minute = 0

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents,
                                                repeats: false)

    let request = UNNotificationRequest(identifier: trialWillConvertID,
                                        content: content,
                                        trigger: trigger)

    try await unc.add(request)
  }

  private func scheduleTrialSupportRequestNotification() async throws {
    let content = UNMutableNotificationContent()

    var notifyAfterDays: Int
    switch self {
    case .OneWeek:
      notifyAfterDays = 3
      content.title = "You are in day 3 of your trial..."
      content.body = "And we are here to help setting things up. Type `config` on the shell and ask!"
    case .TwoWeeks:
      notifyAfterDays = 5
      content.title = "You are in day 5 of your trial..."
      content.body = "And we are here to help setting things up. Type `config` on the shell and ask!"
    case .OneMonth:
      notifyAfterDays = 7
      content.title = "You are in day 7 of your trial..."
      content.body = "And we are here to help setting things up. Type `config` on the shell and ask!"
    }

    let targetDate = Calendar.current.date(byAdding: .day, value: notifyAfterDays, to: Date())!
    var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
    dateComponents.hour = 12
    dateComponents.minute = 0

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents,
                                                repeats: false)

    let request = UNNotificationRequest(identifier: trialSupportRequestID,
                                        content: content,
                                        trigger: trigger)

    try await unc.add(request)
  }
}
