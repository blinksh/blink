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
import AVFoundation

struct KBLayout {
  let left:   [KBKey]
  let middle: [KBKey]
  let right:  [KBKey]
  
  init(_ left: [KBKey], _ middle: [KBKey], _ right: [KBKey]) {
    self.left   = left
    self.middle = middle
    self.right  = right
  }
}

extension KBLayout {
  
  // MARK: iPhones
  
  static func iPhone(lang: String) -> Self {
    return Self([
      .key(.esc,  traits: .default - .landscape),
      .wideKey(.esc,  traits: .default - .portrait),
      .key(.ctrl, traits: .default),
      .key(.alt,  traits: .default),
      .arrows(traits: .default - .cmdOff),
    ], [
      .key(.tab,  traits: .default - .cmdOn),
      .vertical2("`", "~",  traits: .default - .cmdOn),
      .vertical2("@", "#",  traits: .default - .cmdOn),
      .vertical2("$", "^",  traits: .default - .cmdOn),
      
      .vertical2("-", "_",  traits: .default - .cmdOn),
      .vertical2("=", "+",  traits: .default - .cmdOn),
      
      .vertical2("[", "{",  traits: .default - .cmdOn),
      .vertical2("]", "}",  traits: .default - .cmdOn),
      
      .vertical2("\\", "|",  traits: .default - .cmdOn),
      
      .vertical2("<", "*",  traits: .default - .cmdOn),
      .vertical2(">", "\"",  traits: .default - .cmdOn),
      .vertical2("/", "?",  traits: .default - .cmdOn),
    
      .vertical2(".", "!",  traits: .default - .cmdOff),
          
      .vertical2(",", "%",  traits: .default - .cmdOff),
      .vertical2(";", ":",  traits: .default - .cmdOff),
      .vertical2("&", "'",  traits: .default - .cmdOff),
      
      .vertical2(.f(value: 1), .f(value: 7),  traits: .default - .cmdOff),
      .vertical2(.f(value: 2), .f(value: 8),  traits: .default - .cmdOff),
      .vertical2(.f(value: 3), .f(value: 9),  traits: .default - .cmdOff),
      .vertical2(.f(value: 4), .f(value: 10),  traits: .default - .cmdOff),
      .vertical2(.f(value: 5), .f(value: 11),  traits: .default - .cmdOff),
      .vertical2(.f(value: 6), .f(value: 12),  traits: .default - .cmdOff),
    
    ],
    [
      .arrows(traits: .default - .cmdOn),
      .wideKey(.cmd, traits: .default),
    ])
  }
  
  // MARK: iPad 9.7"
  
  static func _iPad_9_7_middle(lang: String) -> [KBKey] {
    if lang.hasPrefix("ru-") ||  lang.hasPrefix("fr-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "/>",  traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("de-"){
      return [
        .vertical2("~", "_",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "/>",  traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("es-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "/>",  traits: .default - .cmdOn),
      ]
    }
    
    return [
      .vertical2("`", "~",  traits: .default - .cmdOn),
      .vertical2("^", "_",  traits: .default - .cmdOn),
      .vertical2("\\", "|", traits: .default - .cmdOn),
      .vertical2("[", "{",  traits: .default - .cmdOn),
      .vertical2("]", "}",  traits: .default - .cmdOn),
      .vertical2("<", "</",  traits: .default - .cmdOn),
      .vertical2(">", "/>",  traits: .default - .cmdOn),
    ]
  }
  
  static func iPad_9_7(lang: String) -> Self {
    return Self([
     .wideKey(.esc,  traits: .default),
     .wideKey(.ctrl, traits: .default),
     .key(    .alt,  traits: .default),

     .icon(.esc,   traits: .defaultSuggestionsOnly),
     .icon(.ctrl,  traits: .defaultSuggestionsOnly),
     .icon(.alt,   traits: .defaultSuggestionsOnly),
     .icon(.tab,   traits: .defaultSuggestionsOnly),
     .arrows(traits: .default - .cmdOff),
   ], [
     .key(.tab,  traits: .default - .cmdOn),
     ] + _iPad_9_7_middle(lang: lang) + [
     //
     .vertical2("F1", "F8",   traits: .default - .cmdOff + .hkb + .suggestionsOn),
     .vertical2("F2", "F9",   traits: .default - .cmdOff + .hkb + .suggestionsOn),
     .vertical2("F3", "F10",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
     .vertical2("F4", "F11",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
     .vertical2("F5", "F12",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
     .vertical2("F6", "F13",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
     .vertical2("F7", "F14",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      //
     .flexKey(.esc,  traits: .default - .cmdOn - .skb + .hkb + .suggestionsOn),
   ], [
     .icon(   .copy,  traits: .all - .selectionOff - .skb),
     .icon(   .paste, traits: .all - .clipboardOff - .skb),
     .arrows(traits: .default - .cmdOn),
     .wideKey(    .cmd,   traits: .default + .hkb),
     .icon(   .cmd,   traits: .defaultSuggestionsOnly + .hkb),
   ])
  }
  
  // MARK: iPad 10.5"
  
  static func _iPad_10_5_middle(lang: String) -> [KBKey] {
    if lang.hasPrefix("ru-") ||  lang.hasPrefix("fr-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "/>",  traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("de-"){
      return [
        .vertical2("~", "_",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "/>",  traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("es-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "/>",  traits: .default - .cmdOn),
      ]
    }
    
    return [
      .vertical2("`", "~",  traits: .default - .cmdOn),
      .vertical2("^", "_",  traits: .default - .cmdOn),
      .vertical2("\\", "|", traits: .default - .cmdOn),
      .vertical2("[", "{",  traits: .default - .cmdOn),
      .vertical2("]", "}",  traits: .default - .cmdOn),
      .vertical2("<", "</",  traits: .default - .cmdOn),
      .vertical2(">", "/>",  traits: .default - .cmdOn),
    ]
  }
  
  static func iPad_10_5(lang: String) -> Self {
    
    return Self([
      .wideKey(.esc,  traits: .default),
      .wideKey(.ctrl, traits: .default),
      .key(    .alt,  traits: .default),

      .icon(.esc,   traits: .defaultSuggestionsOnly),
      .icon(.ctrl,  traits: .defaultSuggestionsOnly),
      .icon(.alt,   traits: .defaultSuggestionsOnly),
      .icon(.tab,   traits: .defaultSuggestionsOnly),
      .arrows(traits: .default - .cmdOff),
    ], [
      .key(.tab,  traits: .default - .cmdOn),
      ] + _iPad_10_5_middle(lang: lang) + [
      //
      .vertical2("F1", "F8",   traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F2", "F9",   traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F3", "F10",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F4", "F11",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F5", "F12",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F6", "F13",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F7", "F14",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
       //
      .flexKey(    .esc     ,  traits: .default - .cmdOn - .skb + .hkb + .suggestionsOn),
    ], [
      .icon(.copy,  traits: .all - .selectionOff - .skb),
      .icon(.paste, traits: .all - .clipboardOff - .skb),
      .arrows(traits: .default - .cmdOn),
      .wideKey(    .cmd,   traits: .default + .hkb),
      .icon(.cmd,    traits: .defaultSuggestionsOnly + .hkb),
    ])
  }
  
  // MARK: iPad 11"
  
  static func _iPad_11_middle(lang: String) -> [KBKey] {
    if lang.hasPrefix("ru-") ||  lang.hasPrefix("fr-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("<", "</",  traits: .default - .cmdOn),
        .vertical2(">", "'", traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("de-") {
      return [
        .vertical2("~", "_",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("<", "</", traits: .default - .cmdOn),
        .vertical2(">", "'",  traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("es-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("<", "</", traits: .default - .cmdOn),
        .vertical2(">", "'",  traits: .default - .cmdOn),
      ]
    }
    
    return [
      .vertical2("`", "~",  traits: .default - .cmdOn),
      .vertical2("^", "_",  traits: .default - .cmdOn),
      .vertical2("[", "{",  traits: .default - .cmdOn),
      .vertical2("]", "}",  traits: .default - .cmdOn),
      .vertical2("\\", "|", traits: .default - .cmdOn),
      .vertical2("<", "</", traits: .default - .cmdOn),
      .vertical2(">", "'",  traits: .default - .cmdOn),
    ]
  }
  
  static func iPad_11(lang: String) -> Self {
    return Self([
      .wideKey(.esc,  traits: .default),
      .wideKey(.ctrl, traits: .default),
      .wideKey(.alt,  traits: .default),

      .key(   .esc,  traits: .defaultSuggestionsOnly),
      .key(  .ctrl,  traits: .defaultSuggestionsOnly),
      .icon(  .alt,  traits: .defaultSuggestionsOnly),
      .arrows(traits: .default - .cmdOff),
    ], _iPad_11_middle(lang: lang) + [
      //
      .vertical2("F1", "F7",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F2", "F8",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F3", "F9",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F4", "F10", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F5", "F11", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F6", "F12", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      //
      .flexKey(.esc, traits: .default - .cmdOn - .skb + .hkb + .suggestionsOn),
    ], [
      .icon(   .copy,  traits: .all - .selectionOff - .skb),
      .icon(   .paste, traits: .all - .clipboardOff - .skb),
//      .key(    .left,  traits: .default),
//      .key(    .down,  traits: .default),
//      .key(    .up,    traits: .default),
//      .key(    .right, traits: .default),
      .arrows(traits: .default - .cmdOn),

      .wideKey(.cmd,   traits: .default),
      .key(    .cmd,   traits: .default + .hkb - .skb),
      .icon(   .cmd,   traits: .defaultSuggestionsOnly + .hkb),
    ])
  }
  
  // MARK: iPad 12.9"
  
  static func _iPad_12_9_middle(lang: String) -> [KBKey] {
    if lang.hasPrefix("ru-") {
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
        .vertical2("<", "</", traits: .default - .cmdOn),
        .vertical2(">", "'",  traits: .default - .cmdOn),
      ]
    }
    
    if lang.hasPrefix("fr-") {
       return [
         .vertical2("~", "'",  traits: .default - .cmdOn),
         .vertical2("$", "^",  traits: .default - .cmdOn),
         .vertical2("[", "{",  traits: .default - .cmdOn),
         .vertical2("]", "}",  traits: .default - .cmdOn),
         .vertical2("\\", "|", traits: .default - .cmdOn),
       ]
     }
    
    if lang.hasPrefix("de-"){
      return [
        .vertical2("~", "'",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
      ]
    }
    if lang.hasPrefix("es-"){
      return [
        .vertical2("`", "~",  traits: .default - .cmdOn),
        .vertical2("$", "^",  traits: .default - .cmdOn),
        .vertical2("[", "{",  traits: .default - .cmdOn),
        .vertical2("]", "}",  traits: .default - .cmdOn),
        .vertical2("\\", "|", traits: .default - .cmdOn),
      ]
    }
    return []
  }
  
  static func iPad_12_9(lang: String) -> Self {
    
    return Self([
      .wideKey(.esc,  traits: .default),
      .wideKey(.ctrl, traits: .default),
      .wideKey(.alt,  traits: .default),

      .wideKey(.esc,  traits: .defaultSuggestionsOnly),
      .wideKey(.ctrl, traits: .defaultSuggestionsOnly),
      .wideKey(.alt,  traits: .defaultSuggestionsOnly),
    ], _iPad_12_9_middle(lang: lang) + [
      // -
      .vertical2("F1", "F8",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F2", "F9",  traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F3", "F10", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F4", "F11", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F5", "F12", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F6", "F13", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      .vertical2("F7", "F14", traits: .default - .cmdOff + .hkb + .suggestionsOn),
      // -
      .flexKey(.esc,  traits: .default - .cmdOn - .skb + .hkb + .suggestionsOn),
    ], [
      .icon(.copy,  traits: .all - .selectionOff - .skb),
      .icon(.paste, traits: .all - .clipboardOff - .skb),
      .key(.left,   traits: .default),
      .key(.down,   traits: .default),
      .key(.up,     traits: .default),
      .key(.right,  traits: .default),

      .wideKey(.cmd, traits: .default - .portrait),
      .key(    .cmd, traits: .default - .landscape),
      .key(    .cmd, traits: .default + .hkb - .skb),
      .wideKey(.cmd, traits: .defaultSuggestionsOnly + .hkb),
    ])
  }
}
