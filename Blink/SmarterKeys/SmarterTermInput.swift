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

class SmarterTermInput: KBWebView {
  
  private var _kbView: KBView
  private var kbView: KBView { _kbView }
  private var _hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(
  forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
  private var _inputAccessoryView: UIView? = nil
  
  var device: TermDevice? = nil
  
  override init(frame: CGRect, configuration: WKWebViewConfiguration) {
    _kbView = KBView()
    
    super.init(frame: frame, configuration: configuration)
    
    self.tintColor = .cyan
    
    if traitCollection.userInterfaceIdiom == .pad {
      setupAssistantItem()
    } else {
      setupAccessoryView()
    }
    
//    _kbView.keyInput = self
    _kbView.lang = textInputMode?.primaryLanguage ?? ""
    
    KBSound.isMutted = BKUserConfigurationManager.userSettingsValue(
      forKey: BKUserConfigMuteSmartKeysPlaySound)
    
    let nc = NotificationCenter.default
      
    nc.addObserver(
      self,
      selector: #selector(_inputModeChanged),
      name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
    
    nc.addObserver(
      self,
      selector: #selector(_keyboardWillChangeFrame(notification:)),
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    
    nc.addObserver(
      self,
      selector: #selector(_keyboardWillHideNotification(notification:)),
      name: UIResponder.keyboardWillHideNotification, object: nil)
    
    nc.addObserver(
      self,
      selector: #selector(_keyboardDidHideNotification(notification:)),
      name: UIResponder.keyboardDidHideNotification, object: nil)
    
    nc.addObserver(
      self,
      selector: #selector(_keyboardWillShowNotification),
      name: UIResponder.keyboardWillShowNotification, object: nil)
    
    nc.addObserver(
      self,
      selector: #selector(_keyboardDidShowNotification),
      name: UIResponder.keyboardDidShowNotification, object: nil)
    
    
    nc.addObserver(self, selector: #selector(_updateSettings), name: NSNotification.Name.BKUserConfigChanged, object: nil)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  var softwareKB: Bool {
    get { !_kbView.traits.isHKBAttached }
    set { _kbView.traits.isHKBAttached = !newValue }
  }
  
  @objc func _updateSettings() {
    KBSound.isMutted = BKUserConfigurationManager.userSettingsValue(
    forKey: BKUserConfigMuteSmartKeysPlaySound)
    
    let hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(
    forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
    
    if hideSmartKeysWithHKB != _hideSmartKeysWithHKB {
      _hideSmartKeysWithHKB = hideSmartKeysWithHKB
      if traitCollection.userInterfaceIdiom == .pad {
        setupAssistantItem()
      } else {
        setupAccessoryView()
      }
      refreshInputViews()
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
  
  override func onOut(_ data: String) {
    device?.view.displayInput(data)
    device?.write(data)
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
  
  func reset() {
    
  }
  
  // TODO: IME
//  override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
//    super.setMarkedText(markedText, selectedRange: selectedRange)
//    if let text = markedText {
//      _kbView.traits.isIME = !text.isEmpty
//    } else {
//      _kbView.traits.isIME = false
//    }
//  }
//
//  override func unmarkText() {
//    super.unmarkText()
//    _kbView.traits.isIME = false
//  }
  
  @objc func _inputModeChanged() {
    DispatchQueue.main.async {
      self._kbView.lang = self.textInputMode?.primaryLanguage ?? ""
    }
  }
  
//  override func becomeFirstResponder() -> Bool {
//    let res = super.becomeFirstResponder()
//    device?.focus()
//    _kbView.isHidden = false
//    refreshInputViews()
//    // TODO: fix
////    if _kbView.traits.isFloatingKB {
////      DispatchQueue.main.async {
////        self.reloadInputViews()
////      }
////    }
//    return res
//  }
  
  func contentView() -> UIView? {
    scrollView.subviews.first
  }
  
  func realBecomeFirstResponder() -> Bool {
    let res = contentView()?.becomeFirstResponder()

    device?.focus()
    _kbView.isHidden = false
    refreshInputViews()
    return res == true
  }
  
  var isRealFirstResponder: Bool {
    contentView()?.isFirstResponder == true
  }
  
  func refreshInputViews() {
    if traitCollection.userInterfaceIdiom != .pad {
      return
    }

    contentView()?.inputAssistantItem.leadingBarButtonGroups = [.init(barButtonItems: [UIBarButtonItem()], representativeItem: nil)]
    contentView()?.reloadInputViews()
    if (_hideSmartKeysWithHKB && _kbView.traits.isHKBAttached) {
      _removeSmartKeys()
      contentView()?.reloadInputViews()
    }
    
//    contentView()?.inputAssistantItem.leadingBarButtonGroups = []
//    contentView()?.reloadInputViews()
//    if !_hideSmartKeysWithHKB {
//      contentView()?.reloadInputViews()
//    }
    
    // Double relaod inputs fixes: https://github.com/blinksh/blink/issues/803
//    let v = self.inputAccessoryView
//    inputAccessoryView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
//    reloadInputViews()
//    inputAccessoryView = v
//    if !_hideSmartKeysWithHKB {
//      reloadInputViews()
//    }
  }
  
  override func onIME(_ event: String, data: String) {
    if event == "compositionstart" && data.isEmpty {
    } else if event == "compositionend" {
      device?.view?.setIme("", completionHandler: nil)
    } else {
      device?.view?.setIme(data) {  (data, error) in
        guard
          error == nil,
          let resp = data as? [String: Any],
          let markedRect = resp["markedRect"] as? String
        else {
          return
        }
        var rect = NSCoder.cgRect(for: markedRect)
        let suggestionsHeight: CGFloat = 44
        let maxY = rect.maxY
        let minY = rect.minY
        if maxY - suggestionsHeight < 0 {
          rect.origin.y = maxY
        } else {
          rect.origin.y = minY
        }
        
        debugPrint(rect)
        rect.size.height = 0
        rect.size.width = 0
        
        if let r = self.device?.view?.convert(rect, to: self.superview) {
          self.frame = r
        }
      }
    }
  }
  
  override var canBecomeFirstResponder: Bool { true }
  
//  override func resignFirstResponder() -> Bool {
//    let res = super.resignFirstResponder()
//    if res {
//      device?.blur()
//      _kbView.isHidden = true
//    }
//    return res
//  }
  
//  override var canResignFirstResponder: Bool {
//    let state = window?.windowScene?.activationState
//    return state == .foregroundActive || state == .foregroundInactive
//  }
  
//  override func insertText(_ text: String) {
//    defer {
//      _kbView.turnOffUntracked()
//    }
//
//    if text != _kbView.repeatingSequence {
//      _kbView.stopRepeats()
//    }
//
//    let traits = _kbView.traits
//    if traits.contains(.cmdOn) && text.count == 1 {
//      var flags = traits.modifierFlags
//      var input = text.lowercased()
//      if input != text {
//        flags.insert(.shift)
//      }
//      input = _langCharsMap[input] ?? input
//
//      if let (cmd, res) = _matchCommand(input: input, flags: flags),
//        let action = cmd.action  {
//        res.perform(action, with: cmd)
//      } else {
//        switch(input) {
//        case "c": copy(self)
//        case "x": cut(self)
//        case "z": flags.contains(.shift) ? undoManager?.undo() : undoManager?.redo()
//        case "v": paste(self)
//        default: super.insertText(text);
//        }
//      }
//    } else if traits.contains([.altOn, .ctrlOn]) {
//      escCtrlSeq(withInput:text)
//    } else if traits.contains(.altOn) {
//      escSeq(withInput: text)
//    } else if traits.contains(.ctrlOn) {
//      ctrlSeq(withInput: text)
//    } else {
//      super.insertText(text)
//    }
//  }
  
  func deviceWrite(_ input: String!) {
//    super.deviceWrite(input)
//    _kbView.turnOffUntracked()
  }
  
  func _removeSmartKeys() {
    _inputAccessoryView = nil
    self.removeAssistantsFromView()
//    realInputAssistantItem?.leadingBarButtonGroups = []
//    realInputAssistantItem?.trailingBarButtonGroups = []
  }
  
  func setupAccessoryView() {
    realInputAssistantItem?.leadingBarButtonGroups = []
    realInputAssistantItem?.trailingBarButtonGroups = []
    _inputAccessoryView = KBAccessoryView(kbView: kbView)
  }
  
  override var inputAccessoryView: UIView? {
    _inputAccessoryView
  }
  
  func setupAssistantItem() {
    let proxy = KBProxy(kbView: kbView)
    let item = UIBarButtonItem(customView: proxy)
    realInputAssistantItem?.leadingBarButtonGroups = []
    realInputAssistantItem?.trailingBarButtonGroups = [UIBarButtonItemGroup(barButtonItems: [item], representativeItem: nil)]
  }
  
  var realInputAssistantItem: UITextInputAssistantItem? {
    self.scrollView.subviews.first?.inputAssistantItem
  }
  
  func _setupWithKBNotification(notification: NSNotification) {
    
    guard
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal // we reconfigure kb only for local notifications
    else {
      return
    }
    
    var traits       = _kbView.traits
    let mainScreen   = UIScreen.main
    let screenHeight = mainScreen.bounds.height
    let isIPad       = traitCollection.userInterfaceIdiom == .pad
    var isOnScreenKB = kbFrameEnd.size.height > 140
    // External screen kb workaround
    if isOnScreenKB && isIPad && device?.view?.window?.screen !== mainScreen {
       isOnScreenKB = kbFrameEnd.origin.y < screenHeight - 140
    }
    
    let isFloatingKB = isIPad && kbFrameEnd.origin.x > 0 && kbFrameEnd.origin.y > 0
    
    defer {
      traits.isFloatingKB = isFloatingKB
      traits.isHKBAttached = !isOnScreenKB
      _kbView.traits = traits
    }
    
    if traits.isHKBAttached && isOnScreenKB {
      if isIPad {
        if isFloatingKB {
          _kbView.kbDevice = .in6_5
          traits.isPortrait = true
          setupAccessoryView()
        } else {
          setupAssistantItem()
        }
      } else {
        setupAccessoryView()
      }
    } else if !traits.isHKBAttached && !isOnScreenKB {
      _kbView.kbDevice = .detect()
      if _hideSmartKeysWithHKB {
        _removeSmartKeys()
      } else if isIPad {
        setupAssistantItem()
      } else {
        setupAccessoryView()
      }
    } else if !traits.isFloatingKB && isFloatingKB {
      if isFloatingKB {
        _kbView.kbDevice = .in6_5
        traits.isPortrait = true
        setupAccessoryView()
      } else {
        setupAssistantItem()
      }
    } else if traits.isFloatingKB && !isFloatingKB {
      _kbView.kbDevice = .detect()
      _removeSmartKeys()
      setupAssistantItem()
    } else {
      return
    }
    
    DispatchQueue.main.async {
//      self.contentView()?.inputAccessoryView?.invalidateIntrinsicContentSize()
//      self.contentView()?.reloadInputViews()
    }
  }
  
  @objc func _keyboardWillShowNotification(notification: NSNotification) {
    _setupWithKBNotification(notification: notification)
  }
  
  @objc func _keyboardWillHideNotification(notification: NSNotification) {
    _setupWithKBNotification(notification: notification)
  }
  
  @objc func _keyboardDidHideNotification(notification: NSNotification) {
  }

  @objc func _keyboardDidShowNotification(notification: NSNotification) {
    _keyboardWillChangeFrame(notification: notification)
  }
  
  @objc func _keyboardWillChangeFrame(notification: NSNotification) {
    guard
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool
    else {
      return
    }
        
    var bottomInset: CGFloat = 0

    let screenMaxY = UIScreen.main.bounds.size.height
    
    let kbMaxY = kbFrameEnd.maxY
    let kbMinY = kbFrameEnd.minY
    
    if kbMaxY >= screenMaxY {
      bottomInset = screenMaxY - kbMinY
    }
    
    if (bottomInset < 30) {
      bottomInset = 0
    }
    
    if isLocal && traitCollection.userInterfaceIdiom == .pad {
      let isFloating = kbFrameEnd.origin.y > 0 && kbFrameEnd.origin.x > 0 || kbFrameEnd == .zero
      if !_kbView.traits.isFloatingKB && isFloating {
        _kbView.kbDevice = .in6_5
        _kbView.traits.isPortrait = true
        setupAccessoryView()
        DispatchQueue.main.async {
          self.contentView()?.reloadInputViews()
        }
      } else if _kbView.traits.isFloatingKB && !isFloating && !_kbView.traits.isHKBAttached {
        _kbView.kbDevice = .detect()
        _removeSmartKeys()
        setupAssistantItem()
        DispatchQueue.main.async {
          self.contentView()?.reloadInputViews()
        }
      }
      _kbView.traits.isFloatingKB = isFloating
    }

    LayoutManager.updateMainWindowKBBottomInset(bottomInset);
  }
  
  @objc static let shared = SmarterTermInput()
}


extension SmarterTermInput: TermInput {
  var secureTextEntry: Bool {
    get {
      false
    }
    set(secureTextEntry) {
      
    }
  }
  
  func insertText(_ text: String!) {
    
  }
  
  func fkeySeq(_ cmd: UIKeyCommand!) {
    
  }
  
  func arrowSeq(_ cmd: UIKeyCommand!) {
    
  }
  
  func cursorSeq(_ cmd: UIKeyCommand!) {
    
  }
  
  func escCtrlSeq(withInput input: String!) {
    
  }
  
  func escSeq(withInput input: String!) {
    
  }
  
  func ctrlSeq(withInput input: String!) {
    
  }
  
  
}
