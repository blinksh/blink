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


enum KeyModifier: String, Codable {
  case none       = ""
  case bit8       = "8-bit"
  case escape     = "Escape"
  case shift      = "Shift"
  case control    = "Control"
  case meta       = "Meta"
  
  var description: String { rawValue }
  
  var usageHint: String {
    switch self {
    case .none: return """
      A modifier is special state produced by pressing a modifier key. Modifiers don't do anything unless another key is pressed.
      An example is the shift modifier produced while you hold down a shift key.  Which keys produce which modifiers is controlled by the modifier mapping.
      """
    case .bit8: return "Add 128 to the unshifted character as in xterm."
    case .escape: return "Send an ESC prefix. Modern editors referes to this as ALT."
    case .shift: return ""
    case .control: return "Control sequence"
    case .meta: return "Add modifiers to control sequence"
    }
  }
}
