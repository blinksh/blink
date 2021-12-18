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


public struct EntitlementInfo {
  let active: Bool
  let since: Date?
  let until: Date?
  
  public init(active: Bool, since: Date? = nil, until: Date? = nil) {
    self.active = active
    self.since  = since
    self.until  = until
  }
}

// Different guarantors allow to obtain entitlements from stored file tokens,
// appstore receipts, etc...
public protocol EntitlementGuarantor {
  func isActive(entitlement: CompatibilityAccessManager.Entitlement) -> Future<EntitlementInfo, Never>
}

public class CompatibilityAccessManager {
  public struct Entitlement: CustomStringConvertible {
    let name: String
    public init(_ name: String) {
      self.name = name
    }
    public var description: String { name }
  }

  public static let shared = CompatibilityAccessManager([AppStoreEntitlements()])

  public let guarantors: [EntitlementGuarantor]
  
  private init(_ guarantors: [EntitlementGuarantor]) {
    self.guarantors = guarantors
  }

  public func isActive(entitlement: CompatibilityAccessManager.Entitlement) -> Future<EntitlementInfo, Never> {
    print("Checking access to entitlement '\(entitlement)'")
    
    var isActive = false
    
    // Declared outside to retain the function until execution.
    var cancellable: AnyCancellable?
    return Future { promise in
      cancellable = self.guarantors
        .publisher
        .flatMap { $0.isActive(entitlement: entitlement) }
        .first { $0.active == true }
        .sink(receiveCompletion: { _ in
          if !isActive {
            promise(.success(EntitlementInfo(active: false)))
          }
        }, receiveValue: { val in
          isActive = true
          promise(.success(val))
        }
      )
    }
  }
}
