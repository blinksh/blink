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
  case space        = "Space"
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
  case f1 = "F1"
  case f2 = "F2"
  case f3 = "F3"
  case f4 = "F4"
  case f5 = "F5"
  case f6 = "F6"
  case f7 = "F7"
  case f8 = "F8"
  case f9 = "F9"
  case f10 = "F10"
  case f11 = "F11"
  case f12 = "F12"
  case pageDown = "PageDown"
  case pageUp   = "PageUp"
  case home     = "Home"
  case end      = "End"
  case left     = "ArrowLeft"
  case right    = "ArrowRight"
  case up       = "ArrowUp"
  case down     = "ArrowDown"
  case backslash    = "Backslash"
  case bracketRight = "BracketRight"
  case bracketLeft  = "BracketLeft"
  case backquote    = "Backquote"
  case delete       = "Backspace"
  case `return`     = "Enter"
  case unidentified = "Unidentified"
  
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
    case .space: return "␣ Space"
    case .escape: return "⎋ Escape"
    case .capsLock: return "⇪ CapsLock"
    case .shiftLeft, .shiftRight: return "⇧ Shift"
    case .controlLeft, .controlRight: return "⌃ Control"
    case .optionLeft, .optionRight: return "⌥ Option"
    case .commandLeft, .commandRight: return "⌘ Command"
    case .pageUp: return "⇞ PageUp"
    case .pageDown: return "⇟ PageDown"
    case .home: return "↖︎ Home"
    case .end: return "↘︎ End"
    case .left: return "← Left"
    case .right: return "→ Right"
    case .up: return "↑ Up"
    case .down: return "↓ Up"
    case .backslash: return "\\"
    case .bracketRight: return "]"
    case .bracketLeft: return "["
    case .backquote: return "`"
    case .delete: return "⌫ Delete"
    case .return: return "↩︎ Return"
    case .unidentified: return "?"
    default: return rawValue
    }
  }
  
  var code: String { rawValue }
  
  var single: Bool {
    switch self {
    case .shiftLeft,
         .shiftRight,
         .controlLeft,
         .controlRight,
         .optionLeft,
         .optionRight,
         .commandLeft,
         .commandRight:
      return false
    default: return true
    }
  }
  
  var key: String {
    switch self {
    case .tab: return "Tab"
    case .space: return "Space"
    case .escape: return "Escape"
    case .capsLock: return "CapsLock"
    case .shiftLeft, .shiftRight: return "Shift"
    case .controlLeft, .controlRight: return "Control"
    case .optionLeft, .optionRight: return "Alt"
    case .commandLeft, .commandRight: return "Meta"
    case .delete: return "Backspace"
    default: return rawValue
    }
  }
  
  var keyCode: Int {
    switch self {
    case .unidentified: return 0
    case .tab: return 9
    case .space: return 32
    case .escape: return 27
    case .capsLock: return 20
    case .shiftLeft, .shiftRight: return 16
    case .controlLeft, .controlRight: return 17
    case .optionLeft, .optionRight: return 18
    case .commandLeft: return 91
    case .commandRight: return 93
    case .f1: return 112
    case .f2: return 113
    case .f3: return 114
    case .f4: return 115
    case .f5: return 116
    case .f6: return 117
    case .f7: return 118
    case .f8: return 119
    case .f9: return 120
    case .f10: return 121
    case .f11: return 122
    case .f12: return 123
    case .home: return 36
    case .pageUp: return 33
    case .pageDown: return 34
    case .end: return 35
    case .left: return 37
    case .right: return 39
    case .up: return 38
    case .down: return 40
    case .backslash: return 220
    case .bracketRight: return 221
    case .bracketLeft: return 219
    case .backquote:  return 192
    case .delete: return 8
    case .return: return 13
    }
  }
  
  var symbol: String {
    switch self {
    case .tab: return "⇥"
    case .space: return "␣"
    case .escape: return "⎋"
    case .capsLock: return "⇪"
    case .shiftLeft, .shiftRight: return "⇧"
    case .controlLeft, .controlRight: return "⌃"
    case .optionLeft, .optionRight: return "⌥"
    case .commandLeft, .commandRight: return "⌘"
    case .pageUp: return "⇞"
    case .pageDown: return "⇟"
    case .home: return "↖︎"
    case .end: return "↘︎"
    case .left: return "←"
    case .right: return "→"
    case .up: return "↑"
    case .down: return "↓"
    case .backslash: return "\\"
    case .bracketRight: return "]"
    case .bracketLeft: return "["
    case .backquote: return "`"
    case .delete: return "⌫"
    case .return: return "↩︎"
    case .unidentified: return ""
    default: return rawValue
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
    default: return 0
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
