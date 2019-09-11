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

import UIKit




class SmarterTermInput: TermInput {
  
  private var _kbView: KBView
  private var _langCharsMap: [String: String]
  private var kbView: KBView { _kbView }
  private var _previousKBFrame: CGRect = .zero
  private var _hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(
  forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    _kbView = KBView()
    
    _langCharsMap = [
      // Russian
      "й": "q",
      "ц": "w",
      "у": "e",
      "к": "r",
      "е": "t",
      "н": "y",
      "г": "u",
      "ш": "i",
      "щ": "o",
      "з": "p",
      "ф": "a",
      "ы": "s",
      "в": "d",
      "а": "f",
      "п": "g",
      "р": "h",
      "о": "j",
      "л": "k",
      "д": "l",
      "я": "z",
      "ч": "x",
      "с": "c",
      "м": "v",
      "и": "b",
      "т": "n",
      "ь": "m",
      // More?
    ]
    
    super.init(frame: frame, textContainer: textContainer)
    
    if traitCollection.userInterfaceIdiom == .pad {
      setupAssistantItem()
    } else {
      setupAccessoryView()
    }
    
    _kbView.keyInput = self
    _kbView.lang = textInputMode?.primaryLanguage ?? ""
    
    let nc = NotificationCenter.default
      
    nc.addObserver(
      self,
      selector: #selector(_inputModeChanged),
      name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
    
    nc.addObserver(self,
      selector: #selector(_keyboardWillChangeFrame(notification:)),
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    
    nc.addObserver(self, selector: #selector(_updateSettings), name: NSNotification.Name.BKUserConfigChanged, object: nil)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var softwareKB: Bool {
    get { !_kbView.traits.isHKBAttached }
    set { _kbView.traits.isHKBAttached = !newValue }
  }
  
  @objc func _updateSettings() {
    let hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(
    forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
    
    if hideSmartKeysWithHKB != _hideSmartKeysWithHKB {
      _hideSmartKeysWithHKB = hideSmartKeysWithHKB
      if traitCollection.userInterfaceIdiom == .pad {
        setupAssistantItem()
      } else {
        setupAccessoryView()
      }
      reloadInputViews()
    }
  }
  
  // overriding chain
  override var next: UIResponder? {
    guard let responder = device?.view?.superview
    else {
      return super.next
    }
    return responder
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard
      let window = window,
      let scene = window.windowScene
    else {
      return
    }
    if traitCollection.userInterfaceIdiom == .phone {
      _kbView.traits.isPortrait = scene.interfaceOrientation.isPortrait
    }
  }
  
  func _matchCommand(input: String, flags: UIKeyModifierFlags) -> (UIKeyCommand, UIResponder)? {
    var result: (UIKeyCommand, UIResponder)? = nil
    
    var iterator: UIResponder? = self
    
    while let responder = iterator {
      if let cmd = responder.keyCommands?.first(
        where: { $0.input == input && $0.modifierFlags == flags}),
        let action = cmd.action,
        responder.canPerformAction(action, withSender: self)
        {
        result = (cmd, responder)
      }
      iterator = responder.next
    }
    
    return result
  }
  
  override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
    super.setMarkedText(markedText, selectedRange: selectedRange)
    if let text = markedText {
      _kbView.traits.isIME = !text.isEmpty
    } else {
      _kbView.traits.isIME = false
    }
  }
  
  override func unmarkText() {
    super.unmarkText()
    _kbView.traits.isIME = false
  }
  
  @objc func _inputModeChanged() {
    DispatchQueue.main.async {
      self._kbView.lang = self.textInputMode?.primaryLanguage ?? ""
    }
  }
  
  override func becomeFirstResponder() -> Bool {
    let res = super.becomeFirstResponder()
    device?.focus()
    _kbView.isHidden = false
    
    if res && _hideSmartKeysWithHKB && _kbView.traits.isHKBAttached {
      let v = inputAccessoryView
      inputAccessoryView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
      _removeSmartKeys()
      DispatchQueue.main.async {
        self.reloadInputViews()
        self.inputAccessoryView = v
      }
    }
    return res
  }
  
  override func resignFirstResponder() -> Bool {
    let res = super.resignFirstResponder()
    device?.blur()
    _kbView.isHidden = true
    return res
  }
  
  override func insertText(_ text: String) {
    let traits = _kbView.traits
    if traits.contains(.cmdOn) && text.count == 1 {
      var flags = traits.modifierFlags
      var input = text.lowercased()
      if input != text {
        flags.insert(.shift)
      }
      input = _langCharsMap[input] ?? input
      
      if let (cmd, res) = _matchCommand(input: input, flags: flags),
        let action = cmd.action  {
        res.perform(action, with: cmd)
      } else {
        switch(input) {
        case "c": copy(self)
        case "x": cut(self)
        case "z": flags.contains(.shift) ? undoManager?.undo() : undoManager?.redo()
        case "v": paste(self)
        default: super.insertText(text);
        }
      }
      _kbView.turnOffUntracked()
    } else if traits.contains([.altOn, .ctrlOn]) {
      escCtrlSeq(withInput:text)
    } else if traits.contains(.altOn) {
      escSeq(withInput: text)
    } else if traits.contains(.ctrlOn) {
      ctrlSeq(withInput: text)
    } else {
      super.insertText(text)
    }
  }
  
  override func deviceWrite(_ input: String!) {
    super.deviceWrite(input)
    _kbView.turnOffUntracked()
  }
  
  func _removeSmartKeys() {
    inputAccessoryView?.isHidden = true
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = []
  }
  
  func setupAccessoryView() {
    if _hideSmartKeysWithHKB && _kbView.traits.isHKBAttached {
      _removeSmartKeys()
      return;
    }
    
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = []
    inputAccessoryView = KBAccessoryView(kbView: kbView)
  }
  
  func setupAssistantItem() {
    inputAccessoryView = nil
    
    if _hideSmartKeysWithHKB && _kbView.traits.isHKBAttached {
      _removeSmartKeys()
      return;
    }
    
    let proxy = KBProxy(kbView: kbView)
    let item = UIBarButtonItem(customView: proxy)
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = [UIBarButtonItemGroup(barButtonItems: [item], representativeItem: nil)]
  }
  
  
  @objc func _keyboardWillChangeFrame(notification: NSNotification) {
    guard
      let window = window,
      let scene = window.windowScene,
      scene.activationState == .foregroundActive,
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
//      let kbFrameBegin = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
      kbFrameEnd.size.height >= 0,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal ? _previousKBFrame != kbFrameEnd :  abs(_previousKBFrame.size.height - kbFrameEnd.size.height) > 6 // reduce reflows (local height 69, other - 72)!
      
    else {
      return
    }
    
    _previousKBFrame = kbFrameEnd
    
    // Only key window can change input props
    guard window.isKeyWindow == true
    else {
      return
    }
    
    var bottomInset: CGFloat = 0

    let viewMaxY = UIScreen.main.bounds.size.height
    
    let kbMaxY = kbFrameEnd.maxY
    let kbMinY = kbFrameEnd.minY
    
    var isFloatingKB = false
    var isSoftwareKB = kbFrameEnd.size.height > 140
    
    if kbMaxY >= viewMaxY {
      bottomInset = viewMaxY - kbMinY
    } else if kbMinY < viewMaxY && kbMaxY < viewMaxY {
      // Floating
      isFloatingKB = true
      isSoftwareKB = true
      
      if let accessoryView = inputAccessoryView {
        bottomInset = accessoryView.bounds.size.height
      }
    }

    defer {
      _kbView.setNeedsLayout()
      LayoutManager.updateMainWindowKBBottomInset(bottomInset);
    }
    
    kbView.traits.isFloatingKB = isFloatingKB
    
    var needToSetupAssistant = false
    
    if traitCollection.userInterfaceIdiom == .phone {
      if self.softwareKB != isSoftwareKB {
        self.softwareKB = isSoftwareKB
        if _hideSmartKeysWithHKB && !isSoftwareKB && inputAccessoryView != nil {
          inputAccessoryView = nil
          bottomInset = 0
        } else if _hideSmartKeysWithHKB && isSoftwareKB && inputAccessoryView == nil {
          setupAccessoryView()
        } else if !_hideSmartKeysWithHKB && inputAccessoryView == nil {
          setupAccessoryView()
        }
        DispatchQueue.main.async {
          self.inputAccessoryView?.invalidateIntrinsicContentSize()
          self.reloadInputViews()
        }
      }
      if !isSoftwareKB && _hideSmartKeysWithHKB {
        bottomInset = 0
      }
    } else if isFloatingKB && inputAccessoryView == nil {
      // put in iphone mode
      _kbView.kbDevice = .in6_5
      _kbView.traits.isPortrait = true
      self.softwareKB = isSoftwareKB
      setupAccessoryView()
      bottomInset = inputAccessoryView?.frame.height ?? 0
      reloadInputViews()
    } else if !isFloatingKB && inputAccessoryView != nil {
      _kbView.kbDevice = .detect()
      needToSetupAssistant = true
    } else if _hideSmartKeysWithHKB && !isSoftwareKB && inputAssistantItem.trailingBarButtonGroups.count >= 1 {
      needToSetupAssistant = true
    } else if _hideSmartKeysWithHKB && isSoftwareKB && inputAssistantItem.trailingBarButtonGroups.isEmpty {
      needToSetupAssistant = true
    }
    
    if needToSetupAssistant {
      _kbView.kbDevice = .detect()
      self.softwareKB = isSoftwareKB
      setupAssistantItem()
      reloadInputViews()
    }
  }
  
  static let shared = SmarterTermInput()
}

