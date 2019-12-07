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

enum Command: String, Codable, CaseIterable {
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
  
  var title: String {
    switch self {
    case .windowNew:            return "New Window"
    case .windowClose:          return "Close Window"
    case .windowFocusOther:     return "Focus on other Window"
    case .tabNew:               return "New tab"
    case .tabClose:             return "Close tab"
    case .tabNext:              return "Next tab"
    case .tabPrev:              return "Previous tab"
    case .tab1:                 return "Switch to tab 1"
    case .tab2:                 return "Switch to tab 2"
    case .tab3:                 return "Switch to tab 3"
    case .tab4:                 return "Switch to tab 4"
    case .tab5:                 return "Switch to tab 5"
    case .tab6:                 return "Switch to tab 6"
    case .tab7:                 return "Switch to tab 7"
    case .tab8:                 return "Switch to tab 8"
    case .tab9:                 return "Switch to tab 9"
    case .tab10:                return "Switch to tab 10"
    case .tab11:                return "Switch to tab 11"
    case .tab12:                return "Switch to tab 12"
    case .tabMoveToOtherWindow: return "Move tab to other Window"
    case .zoomIn:               return "Zoom In"
    case .zoomOut:              return "Zoom Out"
    case .zoomReset:            return "Zoom Reset"
    case .clipboardCopy:        return "Copy"
    case .clipboardPaste:       return "Paste"
    case .configShow:           return "Show Config"
    }
  }
}

enum KeyBindingAction: Codable, Identifiable {
  case hex(String)
  case press(KeyCode, shift: Bool, ctrl: Bool, alt: Bool, meta: Bool)
  case command(Command)
  case none
  
  var id: String {
    switch self {
    case .hex(let str): return "hex-\(str)"
    case .press(let keyCode, let shift, let ctrl, let alt, let meta): return "press-\(keyCode.id)-\(shift)-\(ctrl)-\(alt)-\(meta)"
    case .command(let cmd): return "cmd-\(cmd)"
    case .none: return "none"
    }
  }
  
  static var pressList: [KeyBindingAction] {
    [
      KeyBindingAction.press(.escape, shift: false, ctrl: false, alt: false, meta: false),
      KeyBindingAction.press(.space, shift: false, ctrl: true, alt: false, meta: false),
      KeyBindingAction.press(.f11, shift: false, ctrl: false, alt: false, meta: false),
      KeyBindingAction.press(.f12, shift: false, ctrl: false, alt: false, meta: false),
    ]
  }
  
  static var commandList: [KeyBindingAction] {
    Command.allCases.map({KeyBindingAction.command($0) })
  }
  
  var title: String {
    switch self {
    case .hex(let str): return "Hex: (\(str))"
    case .press(let keyCode, let shift, let ctrl, let alt, let meta):
      var sym = ""
      if (shift) {
        sym += KeyCode.shiftLeft.symbol
      }
      if (ctrl) {
        sym += KeyCode.controlLeft.symbol
      }
      if (alt) {
        sym += KeyCode.optionLeft.symbol
      }
      if (meta) {
        sym += KeyCode.commandLeft.symbol
      }
      sym += keyCode.symbol

      return "Press \(sym)"
    case .command(let cmd): return cmd.title
    case .none: return "none"
    }
  }
  
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
