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
import CloudKit


private let NagTimer = "NagTimer"
private let NagTimerMax = 10

extension Notification.Name {
  public static let subscriptionNag = Notification.Name("SubscriptionNag")
}


class SubscriptionNag: NSObject {
  @objc static let shared = SubscriptionNag()
  var nagTimer = Timer()
  let defaults = UserDefaults.standard

  private override init() {}

  @objc func start() {
    
    let container = CKContainer(identifier: "iCloud.com.carloscabanero.blinkshell")
        container.fetchUserRecordID() {
            recordID, error in

            if let err = error {
                print(err.localizedDescription)
            }
            else if let recID = recordID {
                print("fetched ID \(recID.recordName ?? "NA")")
            }
        }
    
    let user = UserModel()
    if user.shellAccess.active {
      return
    }
    
    self.nagTimer = Timer.scheduledTimer(withTimeInterval: 1,
                                         repeats: true) { t in
      var count = self.defaults.integer(forKey: NagTimer)
      print("Nag \(count)")

      count += 1
      if count > NagTimerMax {
        self.stop()
        NotificationCenter.default.post(name: .subscriptionNag, object: nil)
        return
      }
      self.defaults.set(count, forKey: NagTimer)
    }
  }

  func restart() {
    self.defaults.set(0, forKey: NagTimer)
    start()
  }

  func stop () {
    nagTimer.invalidate()
  }
}

