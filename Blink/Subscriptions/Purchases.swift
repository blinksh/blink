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
import SystemConfiguration

import Purchases

public class AppStoreEntitlementsSource: EntitlementsSource {
  public init() {
    Purchases.logLevel = .debug
    let publicAPIKey = Bundle.main.object(forInfoDictionaryKey: "RevCatPublicKey") as! String
    Purchases.configure(withAPIKey: publicAPIKey)
    print("RevCat UserID is \(Purchases.shared.appUserID)")
  }
  
  public func status(of entitlement: CompatibilityAccessManager.Entitlement) -> AnyPublisher<EntitlementStatus, Never> {
    let pub = PassthroughSubject<EntitlementStatus, Never>()
    return pub.handleEvents(receiveRequest: { _ in
      Purchases.shared.purchaserInfo { info, error in
        pub.send(info?.status(of: entitlement) ?? .inactive)
        // TODO: handle error?
        pub.send(completion: .finished)
      }
    }).eraseToAnyPublisher()
  }
}


fileprivate extension Purchases.PurchaserInfo {
  func status(of entitlement: CompatibilityAccessManager.Entitlement) -> EntitlementStatus {
    let id = entitlement.id
    let since = purchaseDate(forEntitlement: id)
    let until = expirationDate(forEntitlement: id)
    let active = entitlements[id]?.isActive == true
    return EntitlementStatus(active: active, since: since, until: until)
  }
}


// TODO Assign on Sandbox?
public class PreconfiguredEntitlementsSource: EntitlementsSource {
  public init() {
    Purchases.logLevel = .debug
    let publicAPIKey = Bundle.main.object(forInfoDictionaryKey: "RevCatPublicKey") as! String
    Purchases.configure(withAPIKey: publicAPIKey)
    print("RevCat UserID is \(Purchases.shared.appUserID)")
  }
  
  public func status(of entitlement: CompatibilityAccessManager.Entitlement) -> AnyPublisher<EntitlementStatus, Never> {
    Just(.init(active: entitlement == .classic)).eraseToAnyPublisher()
  }
}

