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

class FormView: UIView {
  var categoryTextField: UITextField
  var nameTextField: UITextField
  
  var categoryLeft: UILabel
  var nameLeft: UILabel
  
  var separator1View: UIView
  var separator2View: UIView
  
  override init(frame: CGRect) {
    categoryTextField = UITextField()
    nameTextField = UITextField()
    categoryLeft = UILabel()
    nameLeft = UILabel()
    separator1View = UIView()
    separator2View = UIView()
    super.init(frame: frame)
    self.addSubview(categoryTextField)
    self.addSubview(nameTextField)
    self.addSubview(separator1View)
    self.addSubview(separator2View)
    
    categoryLeft.text = "Category: "
    categoryLeft.textColor = .secondaryLabel
    nameLeft.text = "Name: "
    nameLeft.textColor = .secondaryLabel
    
    nameTextField.leftView = nameLeft
    nameTextField.leftViewMode = .always
    
    
    categoryTextField.leftView = categoryLeft
    categoryTextField.leftViewMode = .always
    
    separator1View.backgroundColor = .separator
    separator2View.backgroundColor = .separator
    
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let h = max(categoryTextField.intrinsicContentSize.height, 44);
    
    categoryTextField.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: h)
    separator1View.frame = CGRect(x: 0, y: h, width: self.bounds.width, height: 0.5)
    
    nameTextField.frame = CGRect(x: 0, y: separator1View.frame.maxY + 1, width: self.bounds.width, height: h)
    separator2View.frame = CGRect(x: 0, y: h * 2 + 1, width: self.bounds.width, height: 0.5)
  }
  
  override var intrinsicContentSize: CGSize {
    let h = max(categoryTextField.intrinsicContentSize.height, 44);
    return CGSize(width: self.bounds.width, height: h * 2 + 3 + 6)
  }
}


class NewSnippetViewController: UIViewController, TextViewDelegate, UINavigationItemRenameDelegate {
  
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
  }

  func textViewDidChangeSelection(_ textView: TextView) {
    // We could use this to trigger a search for underlying template.
    // But this would make the textview work unnecessarily.
    // We could also compare with the template ranges alone.
  }
  
  var textView: TextView
  var formView: FormView
  var model: SearchModel
  var templateTokenRanges: [NSRange]
  var acceptReplace: Bool
  
  var _keyCommands: [UIKeyCommand] = []
  
  init(textView: TextView, model: SearchModel) {
    self.textView = textView
    self.model = model
    self.templateTokenRanges =  [NSRange]()
    self.acceptReplace = false
    self.formView = FormView()
    super.init(nibName: nil, bundle: nil)
    self.textView.editorDelegate = self
    self.textView.addSubview(self.formView)
    
    self.textView.text = "# New snippet"
    
    _keyCommands = [
      UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(create)),
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
    
    self.navigationItem.rightBarButtonItem =
      UIBarButtonItem(
        title: "Create", style: .done, target: self, action: #selector(create)
      )
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel)
    self.navigationItem.leftBarButtonItem?.target = self
    self.navigationItem.leftBarButtonItem?.action = #selector(cancel)
    self.navigationItem.style = .editor
        
    self.formView.categoryTextField.addTarget(self, action: #selector(onFieldFocus), for: .editingDidBegin)
    
    self.formView.categoryTextField.addTarget(self, action: #selector(onFieldChange), for: .editingChanged)
    
    self.formView.categoryTextField.addTarget(self, action: #selector(onFieldBlur), for: .editingDidEnd)
    
    self.formView.nameTextField.addTarget(self, action: #selector(onFieldFocus), for: .editingDidBegin)
    self.formView.nameTextField.addTarget(self, action: #selector(onFieldBlur), for: .editingDidEnd)
    self.formView.nameTextField.addTarget(self, action: #selector(onFieldChange), for: .editingChanged)
    
    let query = self.model.fuzzyResults.query
    let parts = query.split(separator: "/", maxSplits: 1)
    
    if parts.count > 0 {
      self.formView.categoryTextField.text = String(parts[0])
    }
    
    if parts.count == 2 {
      self.formView.nameTextField.text = String(parts[1])
    }
    
    self.onFieldChange()
  }
  
  @objc func onFieldChange() {
    let category = model.cleanString(str: formView.categoryTextField.text)
    let name = model.cleanString(str: formView.nameTextField.text)
    
    if category.isEmpty || name.isEmpty {
      self.title = nil
      return
    }
    
    self.title = "\(category)/\(name)"
  }
  
  // workaround
  // if form fields is focused we disable scroll to prevent scrolling bug
  @objc func onFieldFocus() {
    self.textView.scrollRectToVisible(CGRect.init(x: 0, y: 0, width: 10, height: 1), animated: true)
    self.textView.isScrollEnabled = false
  }
  
  @objc func onFieldBlur() {
    self.textView.isScrollEnabled = true
  }
  
  @objc func cancel() {
    model.closeEditor()
  }
  
  @objc func create() {
    let category = model.cleanString(str: formView.categoryTextField.text)

    if category.isEmpty {
      self.showAlert(msg: "Category can't be empty.")
    }
    
    var name = model.cleanString(str: formView.nameTextField.text)
    
    if name.isEmpty {
      self.showAlert(msg: "Name can't be empty.")
    }
    
    name += ".sh"
    
    let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if content.isEmpty {
      self.showAlert(msg: "Content can't be empty.")
    }
    
    do {
      try model.snippetsLocations.saveSnippet(folder: category, name: name, content: content)
      model.updateWith(text: "")
    } catch  {
      self.showAlert(msg: error.localizedDescription)
      return
    }
   
    
    model.closeEditor()
  }
  
  func showAlert(msg: String) {
    let ctrl = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
    ctrl.addAction(UIAlertAction(title: "Ok", style: .default))
    self.present(ctrl, animated: true)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    let ins = self.systemMinimumLayoutMargins
    textView.frame = self.view.bounds.insetBy(dx: ins.leading, dy: ins.top)
    let size = formView.intrinsicContentSize;
    if textView.contentInset.top != size.height {
      textView.contentInset = UIEdgeInsets(top: size.height, left: 0, bottom: 0, right: 0)
    }
    formView.frame = CGRect(x: 0, y: -size.height, width: textView.bounds.width, height: size.height)
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if (formView.categoryTextField.text ?? "").isEmpty {
      _ = formView.categoryTextField.becomeFirstResponder()
    } else if (formView.nameTextField.text ?? "").isEmpty {
      _ = formView.nameTextField.becomeFirstResponder()
    } else {
      _ = textView.becomeFirstResponder()
    }
    
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    self.model.closeEditor()
  }
  
}
