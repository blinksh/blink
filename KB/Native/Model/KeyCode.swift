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


enum KeyCode: String, Codable, CaseIterable, Identifiable {
  
  case tab          = "Tab"
  case escape       = "Escape"
  case capsLock     = "CapsLock"
  case shiftLeft    = "ShiftLeft"
  case shiftRight   = "ShiftRight"
  case controlLeft  = "ControlLeft"
  case controlRight = "ControlRight"
  case optionLeft   = "AltLeft"
  case optionRight  = "AltRight"
  case commandLeft  = "MetaLeft"
  case commandRight = "MetaRight"
  
  var isOption: Bool {
    switch self {
    case .optionLeft, .optionRight: return true
    case _: return false
    }
  }
  
  var hasAccents: Bool { isOption }
  
  var fullName: String {
    switch self {
    case .tab: return "⇥ Tab"
    case .escape: return "⎋ Escape"
    case .capsLock: return "⇪ CapsLock"
    case .shiftLeft, .shiftRight: return "⇧ Shift"
    case .controlLeft, .controlRight: return "⌃ Control"
    case .optionLeft, .optionRight: return "⌥ Option"
    case .commandLeft, .commandRight: return "⌘ Command"
    }
  }
  
  var code: String { rawValue }
  
  var single: Bool {
    switch self {
    case .tab, .escape, .capsLock: return true
    default: return false
    }
  }
  
  var key: String {
    switch self {
    case .tab: return "Tab"
    case .escape: return "Escape"
    case .capsLock: return "CapsLock"
    case .shiftLeft, .shiftRight: return "Shift"
    case .controlLeft, .controlRight: return "Control"
    case .optionLeft, .optionRight: return "Alt"
    case .commandLeft, .commandRight: return "Meta"
    }
  }
  
  var keyCode: Int {
    switch self {
    case .tab: return 9
    case .escape: return 27
    case .capsLock: return 20
    case .shiftLeft, .shiftRight: return 16
    case .controlLeft, .controlRight: return 17
    case .optionLeft, .optionRight: return 18
    case .commandLeft: return 91
    case .commandRight: return 93
    }
  }
  
  var symbol: String {
    switch self {
    case .tab: return "⇥"
    case .escape: return "⎋"
    case .capsLock: return "⇪"
    case .shiftLeft, .shiftRight: return "⇧"
    case .controlLeft, .controlRight: return "⌃"
    case .optionLeft, .optionRight: return "⌥"
    case .commandLeft, .commandRight: return "⌘"
    }
  }
  
  func symbol(loc: Int8) -> String {
    let sym = symbol
    if loc == 1 {
      return "L\(sym)"
    } else if loc == 2 {
      return "R\(sym)"
    }
    return sym
  }
  
  var location: Int {
    switch self {
    case .tab,
         .escape,
         .capsLock: return 0
    case .shiftLeft,
         .controlLeft,
         .optionLeft,
         .commandLeft: return 1
    case .shiftRight,
         .controlRight,
         .optionRight: return 2
    case .commandRight: return 0
    }
  }

  var id: String { "\(keyCode):\(location)" }
  
  init?(keyID: String) {
    for v in Self.allCases {
      if v.id == keyID {
        self = v
        return
      }
    }
    
    return nil
  }
  
  // - MARK: Codable
  
  enum Keys: CodingKey {
    case keyCode
    case code
    case key
    case id
  }
  
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    try c.encode(keyCode, forKey: .keyCode)
    try c.encode(code,    forKey: .code)
    try c.encode(key,     forKey: .key)
    try c.encode(id,      forKey: .id)
  }
  
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let code  = try c.decode(String.self, forKey: .code)
    self.init(rawValue: code)!
  }
}
