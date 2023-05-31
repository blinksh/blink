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

class SearchTextViewDelegate: NSObject, UITextViewDelegate {
  
  var prevMode = SearchMode.general
  
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    var result = true
    if text == "\n" || text == "\t" {
      guard
        let textView = textView as? SearchTextView,
        let text = textView.text
      else {
        return false
      }
      textView.enterEditMode()
      result = false
    }
    return result
  }
  
  func textViewDidChange(_ textView: UITextView) {
    guard
          let textView = textView as? SearchTextView,
          let text = textView.text//,
// if marker has transparent bg we should hide first symbol
//          let tlm = textView.textLayoutManager
    else {
      return
    }
   
    textView.model.updateWith(text: text)
    
    if prevMode == textView.model.mode {
      // todo... fix kern
      let textLen = text.count

      if prevMode == .general {
        let range = NSRange(location: 0, length: textLen)
        textView.textStorage.beginEditing()
        textView.textStorage.removeAttribute(.kern, range: range)
        textView.textStorage.endEditing()
      } else {
        let range = NSRange(location: 1, length: textLen - 1)
        if textLen == 0 {
          textView.textStorage.removeAttribute(.kern, range: NSRange(location: 0, length: 0))
        } else if textLen > 1 {
          textView.textStorage.beginEditing()
          textView.textStorage.removeAttribute(.kern, range: range)
          textView.textStorage.endEditing()
        }
      }
      return
    }
    
    textView.textStorage.beginEditing()
    
    defer {
      prevMode = textView.model.mode
      textView.textStorage.endEditing()
      textView.setNeedsLayout()
    }
    
    // specific -> general
    if textView.model.mode == .general {
      // we need remove attributes
      
      textView.textStorage.removeAttribute(.kern, range: NSRange(location: 0, length: text.count))
//      tlm.removeRenderingAttribute(.foregroundColor, for: tlm.documentRange)
      return
    }
    
    if prevMode != .general {
      // set specific spacing
      textView.textStorage.addAttribute(.kern, value: NSNumber(value: 10), range: NSRange(location: 0, length: 1))
      return
    }
    
    // .general -> specific
    
    textView.textStorage.addAttribute(.kern, value: NSNumber(value: 10), range: NSRange(location: 0, length: 1))
    
//    let start = tlm.documentRange.location
//    let end = tlm.location(start, offsetBy: 1)
//    tlm.addRenderingAttribute(.foregroundColor, value: UIColor.clear, for: NSTextRange(location: start, end: end)!)
  }
}



class SearchTextView: UITextView {
  
  var markerView: MarkerView!
  fileprivate var _delegate: SearchTextViewDelegate!
  
  var model: SearchModel = SearchModel()  {
    didSet {
      if self.text != model.input {
        self.text = model.input
        self.setNeedsLayout()
      }
    }
  }
  
  override var keyCommands: [UIKeyCommand]? {
    return _keyCommands
  }
  
  var _keyCommands: [UIKeyCommand] = []
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    if model.mode == .general {
      self.markerView.removeFromSuperview()
      return
    }
    let containerView = self.subviews[1];
    containerView.layer.addSublayer(self.markerView.layer)
    
    self.markerView.label.font = self.font
    self.markerView.frame = CGRect(x: 0, y: 5.5, width: 28, height: 34)
    self.markerView.backgroundColor = .systemGroupedBackground
    self.markerView.layer.cornerRadius = 3
    self.markerView.label.textAlignment = .center
    
    self.markerView.label.text = model.mode.toSymbol()
  }
  
  static func create(model: SearchModel) -> Self {
    
    let view = Self(usingTextLayoutManager: true)
    view.model = model
    view.isEditable = true
    view.isSelectable = true
    view.allowsEditingTextAttributes = false
    view._delegate = SearchTextViewDelegate()
    view.delegate = view._delegate
    view.font = UIFont.systemFont(ofSize: 24, weight: .bold)
    view.markerView = MarkerView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    view.autocapitalizationType = .none
    view.autocorrectionType = .no
    view.smartDashesType = .no
    view.smartQuotesType = .no
    view.smartInsertDeleteType = .no
    view.spellCheckingType = .no
    view.backgroundColor = .clear
    view.returnKeyType = .continue
    
    view.text = model.input
    
    let ctrlN = UIKeyCommand(
      input: "n", modifierFlags: .control,
      action: #selector(SearchTextView.nextSnippet)
    )
    let ctrlP = UIKeyCommand(
      input: "p", modifierFlags: .control,
      action: #selector(SearchTextView.prevSnippet)
    )
    
    let ctrlDown = UIKeyCommand(
      input: UIKeyCommand.inputDownArrow, modifierFlags: .control,
      action: #selector(SearchTextView.nextSnippet)
    )
    let ctrlUp = UIKeyCommand(
      input: UIKeyCommand.inputUpArrow, modifierFlags: .control,
      action: #selector(SearchTextView.prevSnippet)
    )
    let up = UIKeyCommand(
      input: UIKeyCommand.inputDownArrow, modifierFlags:  [],
      action: #selector(SearchTextView.nextSnippet)
    )
    let down = UIKeyCommand(
      input: UIKeyCommand.inputUpArrow, modifierFlags: [],
      action: #selector(SearchTextView.prevSnippet)
    )
    let ctrlJ = UIKeyCommand(
      input: "j", modifierFlags: .control,
      action: #selector(SearchTextView.nextSnippet)
    )
    let ctrlK = UIKeyCommand(
      input: "k", modifierFlags: .control,
      action: #selector(SearchTextView.prevSnippet)
    )
    let tab = UIKeyCommand(
      input: "\t", modifierFlags: [],
      action: #selector(SearchTextView.nextSnippet)
    )
    let shiftTab = UIKeyCommand(
      input: "\t", modifierFlags: .shift,
      action: #selector(SearchTextView.prevSnippet)
    )
    let enter = UIKeyCommand(
      input: "\r", modifierFlags: [],
      action: #selector(SearchTextView.enterEditMode)
    )
    let enter2 = UIKeyCommand(
      input: "\n", modifierFlags: [],
      action: #selector(SearchTextView.enterEditMode)
    )
    
    view._keyCommands = [
      ctrlN, ctrlJ, ctrlP, ctrlK, ctrlUp, ctrlDown, up, down, tab, shiftTab,
      enter, enter2
    ]
    
    for cmd in view._keyCommands {
      cmd.wantsPriorityOverSystemBehavior = true
    }
    return view
  }
  
  @objc func nextSnippet() {
    model.selectNextSnippet()
  }
  
  @objc func prevSnippet() {
    model.selectPrevSnippet()
  }
  
  @objc func enterEditMode() {
    model.editCurrentSelection()
  }
  
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if action == #selector(UIResponderStandardEditActions.pasteAndMatchStyle(_:)) {
      return false
    }
    return super.canPerformAction(action, withSender: sender)
  }
}

struct SearchView: UIViewRepresentable {
  @ObservedObject var model: SearchModel
  
  func makeUIView(context: UIViewRepresentableContext<Self>) -> SearchTextView {
    let view = SearchTextView.create(model: model)
    model.inputView = view
    return view
  }
  
  func updateUIView(_ uiView: SearchTextView, context: UIViewRepresentableContext<Self>) {
    uiView.model = self.model
  }
}
