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


class SearchTextInput: UITextField, UITextFieldDelegate {
  override var keyCommands: [UIKeyCommand]? {
    return _keyCommands
  }

  var _keyCommands: [UIKeyCommand] = []
  
  override init(frame: CGRect) {
    let escape = UIKeyCommand(
      input: UIKeyCommand.inputEscape,
      modifierFlags: [],
      action: #selector(SearchTextInput.close))
    let ctrlN = UIKeyCommand(
      input: "n", modifierFlags: .control,
      action: #selector(SearchTextInput.nextSnippet)
    )
    let ctrlP = UIKeyCommand(
      input: "p", modifierFlags: .control,
      action: #selector(SearchTextInput.prevSnippet)
    )
    
    let ctrlDown = UIKeyCommand(
      input: UIKeyCommand.inputDownArrow, modifierFlags: .control,
      action: #selector(SearchTextInput.nextSnippet)
    )
    let ctrlUp = UIKeyCommand(
      input: UIKeyCommand.inputUpArrow, modifierFlags: .control,
      action: #selector(SearchTextInput.prevSnippet)
    )
    let up = UIKeyCommand(
      input: UIKeyCommand.inputDownArrow, modifierFlags:  [],
      action: #selector(SearchTextInput.nextSnippet)
    )
    let down = UIKeyCommand(
      input: UIKeyCommand.inputUpArrow, modifierFlags: [],
      action: #selector(SearchTextInput.prevSnippet)
    )
    let ctrlJ = UIKeyCommand(
      input: "j", modifierFlags: .control,
      action: #selector(SearchTextInput.nextSnippet)
    )
    let ctrlK = UIKeyCommand(
      input: "k", modifierFlags: .control,
      action: #selector(SearchTextInput.prevSnippet)
    )
    let tab = UIKeyCommand(
      input: "\t", modifierFlags: [],
      action: #selector(SearchTextInput.nextSnippet)
    )
    let shiftTab = UIKeyCommand(
      input: "\t", modifierFlags: .shift,
      action: #selector(SearchTextInput.prevSnippet)
    )
    let enter = UIKeyCommand(
      input: "\r", modifierFlags: [],
      action: #selector(SearchTextInput.enterEditMode)
    )
    let enter2 = UIKeyCommand(
      input: "\n", modifierFlags: [],
      action: #selector(SearchTextInput.enterEditMode)
    )
    
    self._keyCommands = [
      escape, ctrlN, ctrlJ, ctrlP, ctrlK, ctrlUp, ctrlDown, up, down, tab, shiftTab,
      enter, enter2
    ]
    
    super.init(frame: frame)
    
    self.addTarget(self, action: #selector(textChanged), for: UIControl.Event.editingChanged)
    
    for cmd in self._keyCommands {
      cmd.wantsPriorityOverSystemBehavior = true
    }
    
    self.font = UIFont.systemFont(ofSize: 24, weight: .bold)
    
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    label.font = self.font
    label.text = "<"
    
    
    self.leftView = label
    self.leftViewMode = .always
//    self.textContentType = .password
//    self.isSecureTextEntry = true
    

    self.delegate = self
    
    
    self.setNeedsLayout()
  }
  
  @objc func textChanged() {
    self.model.updateWith(text: self.text ?? "")
  }
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    true
  }
  
  func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    true
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  var model: SearchModel = SearchModel()  {
    didSet {
      if self.text != model.input {
        self.text = model.input
        self.setNeedsLayout()
      }
    }
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
  
  @objc func close() {
    model.close()
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
  
  func makeUIView(context: UIViewRepresentableContext<Self>) -> SearchTextInput {
    let view = SearchTextInput() //SearchTextView.create(model: model)
    model.inputView = view
    return view
  }
  
  func updateUIView(_ uiView: SearchTextInput, context: UIViewRepresentableContext<Self>) {
    uiView.model = self.model
  }
}
