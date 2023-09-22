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
  case template, code
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
    tv.indentStrategy = .space(length: 4)

    return tv
  }

  static func createForSnippetEditing() -> TextView {
    return textView()
  }

  // TODO Language from Snippet information
  static func textView() -> TextView {
    let tv = TextView()
    tv.theme = PragmataProTheme(originalTheme: DefaultTheme())
    tv.backgroundColor = .clear
    tv.setLanguageMode(TreeSitterLanguageMode(language: .bash))
    
    tv.autocapitalizationType = .none
    tv.autocorrectionType = .no
    tv.inputAssistantItem.leadingBarButtonGroups = []
    tv.inputAssistantItem.trailingBarButtonGroups = []
    tv.smartDashesType = .no
    tv.smartQuotesType = .no
    tv.smartInsertDeleteType = .no
    tv.spellCheckingType = .no
    
    return tv
  }
}

public final class PragmataProTheme<T: Runestone.Theme>: Runestone.Theme {
  
  public var font = BlinkFonts.snippetEditContent
  
  public var textColor: UIColor {
    originalTheme.textColor
  }
  
  public var gutterBackgroundColor: UIColor {
    originalTheme.gutterBackgroundColor
  }
  
  public var gutterHairlineColor: UIColor {
    originalTheme.gutterHairlineColor
  }
  
  public var lineNumberColor: UIColor {
    originalTheme.lineNumberColor
  }
  
  public var lineNumberFont: UIFont {
    originalTheme.font
  }
  
  public var selectedLineBackgroundColor: UIColor {
    originalTheme.selectedLineBackgroundColor
  }
  
  public var selectedLinesLineNumberColor: UIColor {
    originalTheme.selectedLinesLineNumberColor
  }
  
  public var selectedLinesGutterBackgroundColor: UIColor {
    originalTheme.selectedLinesGutterBackgroundColor
  }
  
  public var invisibleCharactersColor: UIColor {
    originalTheme.invisibleCharactersColor
  }
  
  public var pageGuideHairlineColor: UIColor {
    originalTheme.pageGuideHairlineColor
  }
  
  public var pageGuideBackgroundColor: UIColor {
    originalTheme.pageGuideBackgroundColor
  }
  
  public var markedTextBackgroundColor: UIColor {
    originalTheme.markedTextBackgroundColor
  }
  
  public func textColor(for highlightName: String) -> UIColor? {
    originalTheme.textColor(for: highlightName)
  }
  
  var originalTheme: T
  
  init(originalTheme: T) {
    self.originalTheme = originalTheme
  }
}
 
