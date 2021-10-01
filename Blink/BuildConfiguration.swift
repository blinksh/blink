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

// Feature flags definition
extension FeatureFlags {
  @objc static let fileProviders = _enabled(for: .developer, .testFlight)
  @objc static let blinkBuild    = _enabled(for: .developer, .testFlight)
}

struct PublishingOptions: OptionSet, CustomStringConvertible, CustomDebugStringConvertible {
  let rawValue: UInt8
  
  static let developer  = Self.init(rawValue: 1 << 0)
  static let testFlight = Self.init(rawValue: 1 << 1)
  static let appStore   = Self.init(rawValue: 1 << 2)
  
  static let all: Self = [.developer, .testFlight, .appStore]
  
  #if BLINK_PUBLISHING_OPTION_DEVELOPER
  static var current: Self  = .developer
  #elseif BLINK_PUBLISHING_OPTION_TESTFLIGHT
  static var current: Self  = .testFlight
  #else
  static var current: Self  = .appStore
  #endif
  
  var description: String {
    var result: [String] = []
    if self.contains(.developer) {
      result.append("Developer")
    }
    if self.contains(.testFlight) {
      result.append("Test Flight")
    }
    if self.contains(.testFlight) {
      result.append("App Store")
    }
    
    return "(" + result.joined(separator: ", ") + ")"
  }
  
  var debugDescription: String {
    var result: [String] = []
    if self.contains(.developer) {
      result.append("developer")
    }
    if self.contains(.testFlight) {
      result.append("testFlight")
    }
    if self.contains(.testFlight) {
      result.append("appStore")
    }
    
    return "[" + result.joined(separator: ", ") + "]"
  }
}

@objc class FeatureFlags: NSObject {
  
  @available(*, unavailable)
  override init() { }

  private static func _enabled(for options: PublishingOptions...) -> Bool {
    PublishingOptions(options).contains(.current)
  }
  
  @objc static func currentPublishingOptions() -> String {
    PublishingOptions.current.description
  }
}


