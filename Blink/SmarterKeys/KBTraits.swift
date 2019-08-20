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

import Foundation

struct KBTraits: OptionSet, Hashable, Codable {
  let rawValue: OptionBits
  
  // device orientation
  static let portrait          = Self(rawValue: 1 << 0)
  static let landscape         = Self(rawValue: 1 << 1)
  
  // keyboard type
  static let hkb               = Self(rawValue: 1 << 2)
  static let skb               = Self(rawValue: 1 << 3)
  
  // key modifiers
  static let escOn             = Self(rawValue: 1 << 4)
  static let escOff            = Self(rawValue: 1 << 5)
  static let altOn             = Self(rawValue: 1 << 6)
  static let altOff            = Self(rawValue: 1 << 7)
  static let ctrlOn            = Self(rawValue: 1 << 8)
  static let ctrlOff           = Self(rawValue: 1 << 9)
  static let cmdOn             = Self(rawValue: 1 << 10)
  static let cmdOff            = Self(rawValue: 1 << 11)
  
  // appearence
  static let dark              = Self(rawValue: 1 << 12)
  static let light             = Self(rawValue: 1 << 13)
  static let floatingKBOn      = Self(rawValue: 1 << 14)
  static let floatingKBOff     = Self(rawValue: 1 << 15)
  
  // floating cursor
  static let floatingCursorOn  = Self(rawValue: 1 << 16)
  static let floatingCursorOff = Self(rawValue: 1 << 17)
  
  // selection
  static let selectionOn  = Self(rawValue: 1 << 18)
  static let selectionOff = Self(rawValue: 1 << 19)
  
  // clipboard
  static let clipboardOn  = Self(rawValue: 1 << 20)
  static let clipboardOff = Self(rawValue: 1 << 21)
  
  // ime mode
  static let imeOff = Self(rawValue: 1 << 22)
  static let imeOn  = Self(rawValue: 1 << 23)
  
  static let suggestionsOff = Self(rawValue: 1 << 24)
  static let suggestionsOn  = Self(rawValue: 1 << 25)
  
  // shortcuts
  static let orientations:Self    = [.portrait, .landscape]
  static let kbs: Self            = [.hkb, .skb]
  
  static let esc: Self            = [.escOn, .escOff]
  static let alt: Self            = [.altOn, .altOff]
  static let ctrl: Self           = [.ctrlOn, .ctrlOff]
  static let cmd: Self            = [.cmdOn, .cmdOff]
  
  static let modifiers:Self       = [.esc, .alt, .ctrl, .cmd]
  static let styles: Self         = [.light, .dark]
  static let floatingKB: Self     = [.floatingKBOn, .floatingKBOn]
  static let floatingCursor: Self = [.floatingCursorOn, .floatingCursorOff]
  static let selection: Self      = [.selectionOn, .selectionOff]
  static let clipboard: Self      = [.clipboardOn, .clipboardOff]
  static let ime: Self            = [.imeOn, .imeOff]
  static let suggestions: Self    = [.suggestionsOn, .suggestionsOff]
  
  static let all:Self = [
    .orientations,
    .kbs,
    .modifiers,
    .styles,
    .floatingKB,
    .floatingCursor,
    .selection,
    .clipboard,
    .ime,
    .suggestions
  ]
  
  static let initial = Self.all - [
    .escOn, .cmdOn, .ctrlOn, .altOn,
    .floatingKBOn, .floatingCursorOn,
    .portrait, .hkb, .selectionOn, .clipboardOn,
    .imeOn, .suggestionsOn
  ]
  
  static let `default` = Self.all - [
    .suggestionsOn, .hkb, .floatingCursorOn, .floatingKBOn
  ]
  
  static var defaultSuggestionsOnly: Self {
    .default + .suggestionsOn - .suggestionsOff
  }
}

extension KBTraits {
  mutating func toggle(_ value: Bool, on: Self, off: Self) {
    if value {
      insert(on)
      remove(off)
    } else {
      insert(off)
      remove(on)
    }
  }
  
  var isHKBAttached: Bool {
    get { contains(.hkb) }
    set { toggle(newValue, on: .hkb, off: .skb) }
  }
  
  var isPortrait: Bool {
    get { contains(.portrait) }
    set { toggle(newValue, on: .portrait, off: .landscape) }
  }
  
  var isLandscape: Bool {
    get { contains(.landscape) }
    set { toggle(newValue, on: .landscape, off: .portrait) }
  }
  
  var isFloatingCursor: Bool {
    get { contains(.floatingCursorOn) }
    set { toggle(newValue, on: .floatingCursorOn, off: .floatingCursorOff) }
  }
  
  var hasSelection: Bool {
    get { contains(.selectionOn) }
    set { toggle(newValue, on: .selectionOn, off: .selectionOff) }
  }
  
  var hasClipboard: Bool {
    get { contains(.clipboardOn) }
    set { toggle(newValue, on: .clipboardOn, off: .clipboardOff) }
  }
  
  var hasSuggestions: Bool {
    get { contains(.suggestionsOn) }
    set { toggle(newValue, on: .suggestionsOn, off: .suggestionsOff) }
  }
  
  var isIME: Bool {
    get { contains(.imeOn) }
    set { toggle(newValue, on: .imeOn, off: .imeOff) }
  }
}

extension KBTraits {
  init?(cssSelector: String) {
    let cssMap:[String: Self] = [
      "all": .all,
      "orientations": .orientations,
      "kbs": .kbs,
      "esc": .esc,
      "alt": .alt,
      "ctrl": .ctrl,
      "cmd": .cmd,
      "modifiers": .modifiers,
      "styles": .styles,
      "floatingKB": .floatingKB,
      "floatingKBOn": .floatingKBOn,
      "floatingKBOff": .floatingKBOff,
      // TODO: fill the rest
    ]
    
    // aliases
//    cssMap["all"] = .always
    
    var result = Self(rawValue: 0)
    
    let parts = cssSelector.split(separator: ":")
    for var part in parts {
      var subtruct = false
      if part.hasPrefix("not(") && part.hasSuffix(")") {
        part = part["not(".endIndex..<part.endIndex]
        subtruct = true
      }

      let traits = part.split(separator: ".")
      for t in traits {
        guard let value = cssMap[String(t)] else {
          debugPrint("Unknown css class", t)
          return nil
        }
        if subtruct {
          result.subtract(value)
        } else {
          result.insert(value)
        }
      }
    }
    
    self = result
  }
}


extension KBTraits {
  static func - (lhs: KBTraits, rhs: KBTraits) -> KBTraits {
    lhs.subtracting(rhs)
  }
  
  static func + (lhs: KBTraits, rhs: KBTraits) -> KBTraits {
    lhs.union(rhs)
  }
}
