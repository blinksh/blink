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

import Purchases


struct SubscriptionInfo {
  let active: Bool
  let since: Date?
  let until: Date?
}

extension CompatibilityAccessManager.Entitlement {
  static let shell = CompatibilityAccessManager.Entitlement("shell")
}

class UserModel: ObservableObject {
  @Published var shellAccess = EntitlementInfo(active: false)
  @Published var plusAccess = EntitlementInfo(active: false)
  
  init() {
    update()
  }
  
  // Instead of recalculating, we could also gather the data all the time. Most values are cached and rarely used anyway.
  // TODO Issue is that we may not be able to have a Published value without a setter.
  // We could also potentially tie to a different value.
  func update() {
    CompatibilityAccessManager.shared.isActive(entitlement: .shell).assign(to: &$shellAccess)
    
    //      CompatibilityAccessManager.shared.isActive(entitlement: .shell, result: { (active, _) in
    //            self.shellIsActive = active
    //        })
    //        CompatibilityAccessManager.shared.isActive(entitlement: "plus", result: { (active, info) in
    //            if let info = info {
    //                self.plusAccess = SubscriptionInfo(active: active,
    //                                                   since: info.purchaseDate(forEntitlement: "plus"),
    //                                                   until: info.expirationDate(forEntitlement: "plus"))
    //            } else {
    //                self.plusAccess = SubscriptionInfo(active: active,
    //                                                   since: nil,
    //                                                   until: nil)
    //            }
    //
    //        })
  }
}
