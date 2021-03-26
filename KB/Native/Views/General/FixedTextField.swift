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

struct FixedTextField: UIViewRepresentable {
  class ViewWrapper: UIView, UITextFieldDelegate {
    let textField = UITextField()
    fileprivate let _id: String
    fileprivate let _nextId: String?
    fileprivate let _returnKeyType: UIReturnKeyType?
    fileprivate let _onReturn: (() -> ())?
    @Binding var text: String
    
    init(
      _ placeholder: String,
      text: Binding<String>,
      id: String = UUID().uuidString,
      nextId: String?,
      returnKeyType: UIReturnKeyType? = nil,
      onReturn: (() -> ())? = nil,
      secureTextEntry: Bool = false,
      keyboardType: UIKeyboardType,
      autocorrectionType: UITextAutocorrectionType = .default,
      autocapitalizationType: UITextAutocapitalizationType = .sentences
    ) {
      _id = id
      _text = text
      _nextId = nextId
      _returnKeyType = returnKeyType
      _onReturn = onReturn
      super.init(frame: .zero)
      textField.keyboardType = keyboardType
      textField.placeholder = placeholder
      textField.delegate = self
      textField.isSecureTextEntry = secureTextEntry
      
      textField.addTarget(
        self,
        action: #selector(ViewWrapper._changed(sender:)),
        for: UIControl.Event.editingChanged
      )
      
      textField.autocorrectionType = autocorrectionType
      textField.autocapitalizationType = autocapitalizationType
      
      self.addSubview(textField)
      if let returnKeyType = returnKeyType {
        textField.returnKeyType = returnKeyType
      } else if _nextId != nil {
        textField.returnKeyType = .next
      }
    }
    
    override func becomeFirstResponder() -> Bool {
      return textField.becomeFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
      if let onReturn = _onReturn {
        textField.resignFirstResponder()
        onReturn()
        return false
      }
      if let nextId = _nextId,
         let nextField = ViewWrapper.__map[nextId] {
        nextField.becomeFirstResponder()
      } else {
        textField.resignFirstResponder()
      }
      return false
    }
    
    override func didMoveToSuperview() {
      super.didMoveToSuperview()
      if superview == nil {
        ViewWrapper.__map.removeValue(forKey: _id)
      } else {
        ViewWrapper.__map[_id] = self
      }
    }
    
    @objc func _changed(sender: UITextField) {
      text = sender.text ?? ""
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
      super.layoutSubviews()
      textField.frame = bounds
    }
    
    static var __map:[String: UIView] = [:]
  }
  
  private let _placeholder: String
  @Binding private var text: String
  private let _id: String
  private let _nextId: String?
  private let _returnKeyType: UIReturnKeyType?
  private let _onReturn: (() -> ())?
  private let _keyboardType: UIKeyboardType
  private let _autocorrectionType: UITextAutocorrectionType
  private let _autocapitalizationType: UITextAutocapitalizationType
  private let _secureTextEntry: Bool
  
  init(
    _ placeholder: String,
    text: Binding<String>,
    id: String,
    nextId: String? = nil,
    returnKeyType: UIReturnKeyType? = nil,
    onReturn: (() -> ())? = nil,
    secureTextEntry: Bool = false,
    keyboardType: UIKeyboardType = .default,
    autocorrectionType: UITextAutocorrectionType = .default,
    autocapitalizationType: UITextAutocapitalizationType = .sentences
    
  ) {
    _placeholder = placeholder
    _text = text
    _id = id
    _nextId = nextId
    _returnKeyType = returnKeyType
    _onReturn = onReturn
    _secureTextEntry = secureTextEntry
    _keyboardType = keyboardType
    _autocorrectionType = autocorrectionType
    _autocapitalizationType = autocapitalizationType
  }
  
  func makeUIView(
    context: UIViewRepresentableContext<FixedTextField>
  ) -> ViewWrapper {
    ViewWrapper(
      _placeholder,
      text: _text,
      id: _id,
      nextId: _nextId,
      returnKeyType: _returnKeyType,
      onReturn: _onReturn,
      secureTextEntry: _secureTextEntry,
      keyboardType: _keyboardType,
      autocorrectionType: _autocorrectionType,
      autocapitalizationType: _autocapitalizationType
    )
  }
  
  static func dismantleUIView(_ uiView: ViewWrapper, coordinator: ()) {
    uiView.textField.removeTarget(
      nil, action: nil, for: UIControl.Event.editingChanged
    )
    uiView.textField.delegate = nil
  }
  
  func updateUIView(
    _ uiView: ViewWrapper,
    context: UIViewRepresentableContext<FixedTextField>
  ) {
    uiView.textField.placeholder = _placeholder
    uiView.textField.autocapitalizationType = _autocapitalizationType
    uiView.textField.autocorrectionType = _autocorrectionType
    uiView.textField.isSecureTextEntry = _secureTextEntry
    
    
    if !uiView.textField.isFirstResponder {
      uiView.textField.text = text
    }
  }
  
  static func becomeFirstReponder(id: String) {
    DispatchQueue.main.async() {
      ViewWrapper.__map[id]?.becomeFirstResponder()
    }
  }
}
