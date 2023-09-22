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
  
  var description: String {
    
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
    case UIKeyCommand.inputEscape:
      res += KeyCode.escape.symbol
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
  
  static var defaultList: [KeyShortcut] {
    [
      KeyShortcut(.clipboardCopy, .command, "c"),
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
      
      KeyShortcut(.configShow, .command, ","),
      Self.snippetsShowShortcut
    ]
  }
}
