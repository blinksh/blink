////////////////////////////////////////////////////////////////////////////////
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
import BlinkConfig


private let NagTimer       = "NagTimer"
private let NagTimestamp   = "NagTimestamp"
private let NagNumDisplays = "NagNumDisplays"
private let NagTimerMax = 2 * 60
private let NagInterval: TimeInterval = 10

extension Notification.Name {
  public static let subscriptionNag = Notification.Name("SubscriptionNag")
  public static let openMigration = Notification.Name("openMigration")
  public static let closeMigration = Notification.Name("closeMigration")
}

class SubscriptionNag: NSObject {
  @objc static let shared = SubscriptionNag()

  private override init() {}

  @objc func start() {
    let entitlements = EntitlementsManager.shared
    guard entitlements.unlimitedTimeAccess.active == false
    else {
      return
    }
    
    
      if self.doShowPaywall() {
        NotificationCenter.default.post(name: .subscriptionNag, object: nil)
        return
      }
  }
  
  func didShowNags() -> Bool {
    UserDefaults.standard.object(forKey: NagTimestamp) != nil
  }
  
  func doShowPaywall() -> Bool {
    // TODO: Bring back
//    if ProcessInfo().isMacCatalystApp || FeatureFlags.noSubscriptionNag {
//      return false
//    }
    return !EntitlementsManager.shared.unlimitedTimeAccess.active
//    return _nagCount() > NagTimerMax
  }
  
//  private func _nagCount() -> Int {
//    UserDefaults.standard.integer(forKey: NagTimer)
//  }
//
//  private func _nagNumDisplays() -> Int {
//    UserDefaults.standard.integer(forKey: NagNumDisplays)
//  }
//
//  private func _nagDate() -> Date {
//    Date(timeIntervalSince1970: TimeInterval(UserDefaults.standard.integer(forKey: NagTimestamp)))
//  }
//
//  func restart() {
//    if _nagNumDisplays() < 3 {
//      UserDefaults.standard.set(0, forKey: NagTimer)
//      NotificationCenter.default.post(name: .subscriptionNag, object: nil)
//      start()
//    } else {
//      terminate()
//    }
//  }
//
//  func stop() {
//    nagTimer.invalidate()
//  }
//
  func terminate() {
    NotificationCenter.default.post(name: .subscriptionNag, object: nil)
  }
}

