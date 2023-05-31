//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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
import Runestone
import TreeSitterBashRunestone

enum TextViewEditingMode {
  case template,
       code
}

enum OutputShellFormatter {
  case block,
       lineBySemicolon,
       beginEnd

  func format(_ text: String) -> String {
    switch self {
    case .block:
      return text.replacingOccurrences(of: "\n", with: "; ").wrapIn(prefix: "$(\n", suffix: "\n)")
    case .lineBySemicolon:
      return text.replacingOccurrences(of: "\n", with: "; ")
    case .beginEnd:
      return text.wrapIn(prefix: "begin\n", suffix: "\nend")
    }
  }
}

extension String {
  func wrapIn(prefix: String, suffix: String) -> String {
    return "\(prefix)\(self)\(suffix)"
  }
}

extension TextView {
  func textRange(from range: NSRange) -> UITextRange? {
    let start = self.position(from: self.beginningOfDocument, offset: range.location)!
    let end = self.position(from: start, offset: range.length)!
    return self.textRange(from: start, to: end)
  }
}

class TextViewBuilder {
  static func createForSnippetPreview() -> TextView {
    let tv = textView()
    tv.isEditable = false
    tv.isScrollEnabled = false
    tv.isSelectable = false

    return tv
  }

  static func createForSnippetEditing() -> TextView {
    return textView()
  }

  // TODO Language from Snippet information
  static func textView() -> TextView {
    let tv = TextView()
    tv.backgroundColor = .clear
    tv.setLanguageMode(TreeSitterLanguageMode(language: .bash))
    tv.autocorrectionType = .no
    tv.autocapitalizationType = .none
    tv.smartDashesType = .no
    tv.smartQuotesType = .no
    tv.spellCheckingType = .no
    
    return tv
  }
}
