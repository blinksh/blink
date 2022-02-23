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

import Combine
import Foundation
import UIKit

let UnlimitedScreenTimeEntitlementID = "unlimited_screen_time"
let ProductBlinkShellPlusID = "blink_shell_plus_1y_1999"
let ProductBlinkShellClassicID = "blink_shell_classic_unlimited_0"


// Decoupled from RevCat Entitlement
public struct Entitlement: Identifiable, Equatable, Hashable {
  public let id: String
  public var active: Bool
  public var unlockProductID: String?
  
  public static var inactiveUnlimitedScreenTime = Self(id: UnlimitedScreenTimeEntitlementID, active: false, unlockProductID: nil)
}

public protocol EntitlementsSourceDelegate: AnyObject {
  func didUpdateEntitlements(
    source: EntitlementsSource,
    entitlements :Dictionary<String, Entitlement>,
    activeSubscriptions: Set<String>,
    nonSubscriptionTransactions: Set<String>
  )
}

public protocol EntitlementsSource: AnyObject {
  var delegate: EntitlementsSourceDelegate? { get set }
  func startUpdates()
}


public class EntitlementsManager: ObservableObject, EntitlementsSourceDelegate {
  
  public static let shared = EntitlementsManager([AppStoreEntitlementsSource()])
  
  @Published var unlimitedTimeAccess: Entitlement = .inactiveUnlimitedScreenTime
  @Published var activeSubscriptions: Set<String> = .init()
  @Published var nonSubscriptionTransactions: Set<String> = .init()
  @Published var isUnknownState: Bool = true

  private let _sources: [EntitlementsSource]
  
  private init(_ sources: [EntitlementsSource]) {
    _sources = sources
    for s in sources {
      s.delegate = self
    }
  }
  
  public func startUpdates() {
    for s in _sources {
      s.startUpdates()
    }
  }
  
  public func didUpdateEntitlements(
    source: EntitlementsSource,
    entitlements: Dictionary<String, Entitlement>,
    activeSubscriptions: Set<String>,
    nonSubscriptionTransactions: Set<String>
  ) {
    
    defer {
      self.isUnknownState = false
    }

    // TODO: merge stategy from multiple sources
    self.activeSubscriptions = activeSubscriptions
    self.nonSubscriptionTransactions = nonSubscriptionTransactions
    
    let oldValue = self.unlimitedTimeAccess;
    if let newValue = entitlements[UnlimitedScreenTimeEntitlementID] {
      self.unlimitedTimeAccess = newValue
    }
    
    if isUnknownState {
      _updateSubscriptionNag()
    } else {
      if oldValue.active != self.unlimitedTimeAccess.active {
        _updateSubscriptionNag()
      }
    }

  }
  
  private func _updateSubscriptionNag() {
    if ProcessInfo().isMacCatalystApp || FeatureFlags.noSubscriptionNag {
      SubscriptionNag.shared.terminate()
      return
    }
    if self.unlimitedTimeAccess.active {
      SubscriptionNag.shared.terminate()
    } else {
      SubscriptionNag.shared.start()
    }
  }
  
  public func currentPlanName() -> String {
    if activeSubscriptions.contains(ProductBlinkShellPlusID) {
      return "Blink+ Plan"
    }
    if nonSubscriptionTransactions.contains(ProductBlinkShellClassicID) {
      return "Blink Classic Plan"
    }
    return "Free Plan"
  }
  
}
