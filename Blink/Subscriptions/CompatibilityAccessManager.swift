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


public struct EntitlementStatus {
  let active: Bool
  let since: Date?
  let until: Date?
  
  public init(active: Bool, since: Date? = nil, until: Date? = nil) {
    self.active = active
    self.since  = since
    self.until  = until
  }
  
  static var inactive: EntitlementStatus = .init(active: false)
}

public protocol EntitlementsSource {
  func status(of entitlement: CompatibilityAccessManager.Entitlement) -> AnyPublisher<EntitlementStatus, Never>
}

public class CompatibilityAccessManager {
  public struct Entitlement: Identifiable, Equatable {
    public let id: String
    public init(_ name: String) {
      self.id = name
    }
    
    var name: String { id }
  }

  public static let shared = CompatibilityAccessManager([AppStoreEntitlementsSource()])

  public let sources: [EntitlementsSource]
  
  private init(_ sources: [EntitlementsSource]) {
    self.sources = sources
  }
  
  public func status(of entitlement: CompatibilityAccessManager.Entitlement) -> AnyPublisher<EntitlementStatus, Never> {
    self.sources.publisher
      .print("checking access")
      .flatMap { $0.status(of: entitlement) }
      .first(where: \.active)
      .replaceEmpty(with: .inactive)
      .eraseToAnyPublisher()
  }
}
