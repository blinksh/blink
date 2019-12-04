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


import SwiftUI

enum Command: String, Codable {
  case windowNew
  case windowClose
  case windowFocusOther
  case tabNew
  case tabClose
  case tabNext
  case tabPrev
  case tab1
  case tab2
  case tab3
  case tab4
  case tab5
  case tab6
  case tab7
  case tab8
  case tab9
  case tab10
  case tab11
  case tab12
  case tabMoveToOtherWindow
  case zoomIn
  case zoomOut
  case zoomReset
  case clipboardCopy
  case clipboardPaste
  case configShow
  
  var description: String {
    switch self {
    case .windowNew:        return "New Window"
    case .windowClose:      return "Close Window"
    case .windowFocusOther: return "Focus on other Window"
    case .tabNew:           return "New tab"
    case .tabClose:         return "Close tab"
    case .tabNext:          return "Next tab"
    case .tabPrev:          return "Prev tab"
    default: return self.rawValue
    }
  }
}

enum KeyBindingAction: Codable {
  case hex(String)
  case press(KeyCode, shift: Bool, ctrl: Bool, alt: Bool, meta: Bool)
  case command(Command)
  case none
  
  // - MARK: Codable
  
  enum Keys: CodingKey {
    case type
    case hex
    case value
    case key
    case press
    case command
    case none
    case alt
    case ctrl
    case meta
    case shift
  }
    
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    switch self {
    case .hex(let str):
      try c.encode(Keys.hex.stringValue, forKey: .type)
      try c.encode(str, forKey: .value)
    case .press(let keyCode, shift: let shift, ctrl: let ctrl, alt: let alt, meta: let meta):
      try c.encode(Keys.press.stringValue, forKey: .type)
      try c.encode(keyCode, forKey: .key)
      try c.encode(shift,   forKey: .shift)
      try c.encode(ctrl,    forKey: .ctrl)
      try c.encode(alt,     forKey: .alt)
      try c.encode(meta,    forKey: .meta)
    case .command(let cmd):
      try c.encode(Keys.command.stringValue, forKey: .type)
      try c.encode(cmd, forKey: .value)
    case .none:
      try c.encode(Keys.none.stringValue, forKey: .type)
    }
  }
  
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: Keys.self)
    let type = try c.decode(String.self, forKey: .type)
    let k = Keys(stringValue: type)
    
    switch k {
    case .hex:
      let hex = try c.decode(String.self, forKey: .value)
      self = .hex(hex)
    case .press:
      let keyCode = try c.decode(KeyCode.self, forKey: .key)
      let shift   = try c.decode(Bool.self, forKey: .shift)
      let ctrl    = try c.decode(Bool.self, forKey: .ctrl)
      let alt     = try c.decode(Bool.self, forKey: .alt)
      let meta    = try c.decode(Bool.self, forKey: .meta)
      self = .press(keyCode, shift: shift, ctrl: ctrl, alt: alt, meta: meta)
    case .command:
      let cmd = try c.decode(Command.self, forKey: .value)
      self = .command(cmd)
    default:
      self = .none
    }
  }
}
