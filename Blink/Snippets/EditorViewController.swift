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

import Foundation
import UIKit

import SwiftUI
import Runestone
import TreeSitterBashRunestone


class EditorViewController: UIViewController, TextViewDelegate, UINavigationItemRenameDelegate {
  func navigationItem(_: UINavigationItem, didEndRenamingWith title: String) {
    
  }
  
  func navigationItemShouldBeginRenaming(_: UINavigationItem) -> Bool {
    true
  }
  
  func navigationItem(_: UINavigationItem, willBeginRenamingWith suggestedTitle: String, selectedRange: Range<String.Index>) -> (String, Range<String.Index>) {
    return (suggestedTitle, suggestedTitle.range(of: suggestedTitle)!)
  }
  
  func navigationItem(_: UINavigationItem, shouldEndRenamingWith title: String) -> Bool {
    true
  }
  
  
  func textViewDidBeginEditing(_ textView: TextView) {
    if model.editingMode == .template {
      self.setNextTemplateTokenRanges(textView: textView)
    }
  }

  func setNextTemplateTokenRanges(textView: TextView) {
    let text = textView.text
    let nextTokenRangeIndex: String.Index
    if let range = self.templateTokenRanges.first {
      nextTokenRangeIndex = Range(range, in: textView.text)!.upperBound
    } else {
      nextTokenRangeIndex = text.startIndex
    }

    if nextTokenRangeIndex < text.endIndex,
      let range = text[nextTokenRangeIndex...].range(of: #"\$\{([\w@\.-]+)\}"#, options: .regularExpression) {
      let token = String(text[range])
      let nextTokenRanges = text.ranges(of: token).map { NSRange($0, in: text) }
      self.templateTokenRanges = nextTokenRanges
      highlightTemplateTokenRanges(textView)
      let range = nextTokenRanges[0]
      textView.selectedTextRange =  textView.textRange(from: range)
    } else {
      didCompleteTemplates(textView)
    }
  }

  func didCompleteTemplates(_ textView: TextView) {
    textView.highlightedRanges = []
    model.editingMode = .code
  }

  func textViewDidChangeSelection(_ textView: TextView) {
    // We could use this to trigger a search for underlying template.
    // But this would make the textview work unnecessarily.
    // We could also compare with the template ranges alone.
  }

  func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    if self.acceptReplace || model.editingMode == .code {
      return true
    }

    // Check if a Tab or Enter was pressed, in which case, switch to "next token".
    if text == "\t" || text == "\n" {
      setNextTemplateTokenRanges(textView: textView)
      return false
    }

    guard let templateEditingRange = (templateTokenRanges.first {
      return $0.lowerBound <= range.lowerBound && $0.upperBound >= range.upperBound
    }) else {
      return false
    }

    // Replace all appearances in templateTokenRanges.
    // Move the templateTokenRanges to accommodate for the introduced text.
    var newTemplateTokenRanges: [NSRange] = []
    let editingLocationOffset  = range.lowerBound - templateEditingRange.lowerBound
    let newTokenRangeLength = templateEditingRange.length + text.count - range.length
    var accummulatedPositionOffset = 0

    self.acceptReplace = true
    defer {
      self.acceptReplace = false
    }
    templateTokenRanges.forEach {
      let replacementRange = NSRange(location: accummulatedPositionOffset + $0.location + editingLocationOffset, length: range.length)
      
      textView.replace(replacementRange, withText: text)

      // this will force rerendering of all highlights
      // textView.text = textView.text.replacingCharacters(in: Range(replacementRange, in: textView.text)!, with: text)
      let newTokenRange = NSRange(location: accummulatedPositionOffset + $0.location, length: newTokenRangeLength)
      newTemplateTokenRanges.append(newTokenRange)
      accummulatedPositionOffset += newTokenRangeLength - $0.length

      if templateEditingRange == $0 {
        textView.selectedRange = NSRange(location: newTokenRange.lowerBound + editingLocationOffset + text.count, length: 0)
      }
    }

    templateTokenRanges = newTemplateTokenRanges
    highlightTemplateTokenRanges(textView)
    textViewDidChange(textView)
    return false
  }

  func highlightTemplateTokenRanges(_ textView: TextView) {
    var num = 0

    let highlightedRanges = templateTokenRanges.map {
      num += 1
      return HighlightedRange(id: "templateToken-\(num)", range: $0, color: textView.theme.markedTextBackgroundColor)
    }

    textView.highlightedRanges = highlightedRanges
  }
  
  var textView: TextView
  var model: SearchModel
  var templateTokenRanges: [NSRange]
  var acceptReplace: Bool
  
  var _keyCommands: [UIKeyCommand] = []
  
  init(textView: TextView, model: SearchModel) {
    self.textView = textView
    self.model = model
    self.templateTokenRanges =  [NSRange]()
    self.acceptReplace = false
    super.init(nibName: nil, bundle: nil)
    self.textView.editorDelegate = self
    
    _keyCommands = [
      UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(send)),
      UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancel))
    ]
    for cmd in _keyCommands {
      cmd.wantsPriorityOverSystemBehavior = true
    }
  }
  
  override var keyCommands: [UIKeyCommand] {
    get {
      _keyCommands
    }
    
    set {
      _keyCommands = newValue
    }
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
   
    self.view.backgroundColor = UIColor.systemBackground
    self.view.addSubview(textView)
    if let snippet = model.editingSnippet,
       let content = try? snippet.content {
      textView.text = content
      self.title = snippet.fuzzyIndex
    } else {
      textView.text = ""
    }
    
    self.navigationItem.rightBarButtonItem =
      UIBarButtonItem(
        title: "Send", style: .done, target: self, action: #selector(send)
      )
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel)
    self.navigationItem.leftBarButtonItem?.target = self
    self.navigationItem.leftBarButtonItem?.action = #selector(cancel)
    self.navigationItem.style = .editor
    self.navigationItem.renameDelegate = self
  }
  
  @objc func cancel() {
    model.closeEditor()
  }
  
  @objc func send() {
    model.sendContentToReceiver(content: textView.text)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let ins = self.systemMinimumLayoutMargins
    textView.frame = self.view.bounds.insetBy(dx: ins.leading, dy: ins.top)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    _ = textView.becomeFirstResponder()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.model.closeEditor()
  }
  
}
