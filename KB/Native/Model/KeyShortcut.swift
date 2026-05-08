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

extension UIKeyModifierFlags {
  func toSymbols() -> String {
    var res = ""
    if contains(.control) {
      res += KeyCode.controlLeft.symbol
    }
    if contains(.alternate) {
      res += KeyCode.optionLeft.symbol
    }
    if contains(.shift) {
      res += KeyCode.shiftLeft.symbol
    }
    if contains(.command) {
      res += KeyCode.commandLeft.symbol
    }
    if contains(.alphaShift) {
      res += KeyCode.capsLock.symbol
    }
    return res
  }
}

class KeyShortcut: ObservableObject, Codable, Identifiable {
  @Published var action: KeyBindingAction = .none
  @Published var modifiers: UIKeyModifierFlags = []
  @Published var input: String = ""
  
  var id: String { "\(action.id)-\(modifiers)-\(input)" }
  
  var title: String { action.title }
  
  var isCleared: Bool { input.isEmpty && modifiers.isEmpty }

  var isInDefaultCommandList: Bool {
    guard case .command(let cmd) = action else { return false }
    return KeyShortcut.defaultList.contains {
      if case .command(let defaultCmd) = $0.action { return defaultCmd == cmd }
      return false
    }
  }

  static func defaultFor(_ shortcut: KeyShortcut) -> KeyShortcut? {
    guard case .command(let cmd) = shortcut.action else { return nil }
    return defaultList.first {
      if case .command(let defaultCmd) = $0.action { return defaultCmd == cmd }
      return false
    }
  }

  var description: String {
    if isCleared { return "None" }

    var res = modifiers.toSymbols()
    
    switch input {
    case UIKeyCommand.inputRightArrow:
      res += KeyCode.right.symbol
    case UIKeyCommand.inputLeftArrow:
      res += KeyCode.left.symbol
    case UIKeyCommand.inputUpArrow:
      res += KeyCode.up.symbol
    case UIKeyCommand.inputDownArrow:
      res += KeyCode.down.symbol
    case UIKeyCommand.inputHome:
      res += KeyCode.home.symbol
    case UIKeyCommand.inputEnd:
      res += KeyCode.end.symbol
    case UIKeyCommand.inputPageUp:
      res += KeyCode.pageUp.symbol
    case UIKeyCommand.inputPageDown:
      res += KeyCode.pageDown.symbol
    case UIKeyCommand.inputEscape:
      res += KeyCode.escape.symbol
    case UIKeyCommand.f1:
      res += KeyCode.f1.symbol
    case UIKeyCommand.f2:
      res += KeyCode.f2.symbol
    case UIKeyCommand.f3:
      res += KeyCode.f3.symbol
    case UIKeyCommand.f4:
      res += KeyCode.f4.symbol
    case UIKeyCommand.f5:
      res += KeyCode.f5.symbol
    case UIKeyCommand.f6:
      res += KeyCode.f6.symbol
    case UIKeyCommand.f7:
      res += KeyCode.f7.symbol
    case UIKeyCommand.f8:
      res += KeyCode.f8.symbol
    case UIKeyCommand.f9:
      res += KeyCode.f9.symbol
    case UIKeyCommand.f10:
      res += KeyCode.f10.symbol
    case UIKeyCommand.f11:
      res += KeyCode.f11.symbol
    case UIKeyCommand.f12:
      res += KeyCode.f12.symbol
    case " ":
      res += KeyCode.space.symbol
    case "\r":
      res += KeyCode.return.symbol
    case "\u{8}":
      res += KeyCode.delete.symbol
    case "\t":
      res += KeyCode.tab.symbol
    default:
      res += input.uppercased()
    }
    
    return res
  }
  
  // - MARK: Codable
   
   enum Keys: CodingKey {
     case action
     case modifiers
     case input
   }
   
   func encode(to encoder: Encoder) throws {
     var c = encoder.container(keyedBy: Keys.self)
     try c.encode(action,             forKey: .action)
     try c.encode(modifiers.rawValue, forKey: .modifiers)
     try c.encode(input,              forKey: .input)
   }
   
   required convenience init(from decoder: Decoder) throws {
     let c = try decoder.container(keyedBy: Keys.self)
     
     let action        = try c.decode(KeyBindingAction.self, forKey: .action)
     let modifiers     = try c.decode(Int.self,              forKey: .modifiers)
     let input         = try c.decode(String.self,           forKey: .input)
     
     self.init(
       action: action,
       modifiers: UIKeyModifierFlags(rawValue: modifiers),
       input: input
     )
   }
  
  init(action: KeyBindingAction, modifiers: UIKeyModifierFlags, input: String) {
    self.action = action
    self.modifiers = modifiers
    self.input = input
  }
  
  convenience init(_ command: Command, _ modifiers: UIKeyModifierFlags, _ input: String) {
    let action = KeyBindingAction.command(command)
    self.init(action: action, modifiers: modifiers, input: input)
  }
  
  static var snippetsShowShortcut: KeyShortcut {
    KeyShortcut(.snippetsShow, [.command, .shift], ",")
  }

  static var scratchShowShortcut: KeyShortcut {
    KeyShortcut(.scratchShow, [.command, .shift], ".")
  }

  static var defaultList: [KeyShortcut] {
    [
      KeyShortcut(.clipboardCopy, .command, "c"),
      KeyShortcut(.clipboardCopyRaw, [.command, .shift], "c"),
      KeyShortcut(.clipboardPaste, .command, "v"),

      KeyShortcut(.windowNew, [.command, .shift], "t"),
      KeyShortcut(.windowClose, [.command, .shift], "w"),
      KeyShortcut(.windowFocusOther, [.command], "o"),

      KeyShortcut(.tabNew, .command, "t"),
      KeyShortcut(.tabClose, .command, "w"),
      KeyShortcut(.tabNext, [.command, .shift], "]"),
      KeyShortcut(.tabNext, [.command, .shift], UIKeyCommand.inputRightArrow),
      KeyShortcut(.tabPrev, [.command, .shift], "["),
      KeyShortcut(.tabPrev, [.command, .shift], UIKeyCommand.inputLeftArrow),

      KeyShortcut(.tabMoveToOtherWindow, [.command, .shift], "o"),

      KeyShortcut(.zoomIn, [.command, .shift], "="),
      KeyShortcut(.zoomOut, .command, "-"),
      KeyShortcut(.zoomReset, .command, "="),

      KeyShortcut(.scrollLineUp, .command, UIKeyCommand.inputUpArrow),
      KeyShortcut(.scrollLineDown, .command, UIKeyCommand.inputDownArrow),

      KeyShortcut(.configShow, .command, ","),
      Self.snippetsShowShortcut,
      Self.scratchShowShortcut
    ]
  }
}
