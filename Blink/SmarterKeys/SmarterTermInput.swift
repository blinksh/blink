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
import Combine

@objc protocol CommandsHUDViewDelegate: NSObjectProtocol {
  func currentTerm() -> TermController?
}


class CommandsHUGView: UIView {
  var _alphaCancable: AnyCancellable? = nil
  weak var delegate: CommandsHUDViewDelegate? = nil
  var _visualEffect: UIVisualEffectView
  var _visualEffect2: UIVisualEffectView
  var _contentView = UIView()
  
  struct Colors {
    var bg: UIColor
    var button: UIColor
    
    static var dark: Self {
      Colors(
        bg: UIColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 0.33),
        button: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha:1)
      )
    }
    
    static var light: Self {
      Colors(
        bg: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.33),
        button: UIColor.white
      )
    }
  }
  
  var colors: Colors {
    return .light
//    traitCollection.userInterfaceStyle == .dark ? Colors.dark : Colors.light
  }
  
  override init(frame: CGRect) {
    _visualEffect = UIVisualEffectView(effect: .none)
    _visualEffect.backgroundColor = UIColor.separator
//    UIBlurEffectStyleSystemVibrantBackgroundRegular
    let effect = UIBlurEffect(style: .systemChromeMaterial)
    _visualEffect2 = UIVisualEffectView(effect: effect)

    super.init(frame: frame)
    
    let vibrancy = UIVibrancyEffect(blurEffect: effect, style: .separator)
    
    addSubview(_visualEffect)
    addSubview(_contentView)
    _contentView.addSubview(_visualEffect2)
    
    let v = UIVisualEffectView(effect: vibrancy)
    _visualEffect2.contentView.addSubview(v)
    
    let sep = UIView(frame: CGRect(x: 80, y: 0, width: 1, height: 37))
    sep.backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.1)
    sep.backgroundColor = .red
    
    v.contentView.addSubview(sep)
    
    let cols = colors
    _contentView.backgroundColor = cols.bg
    let subView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 37))
    subView.backgroundColor = cols.button
    _contentView.addSubview(subView)
    let subView1 = UIView(frame: CGRect(x: 80.5, y: 0, width: 80, height: 37))
    subView1.backgroundColor = cols.button
    _contentView.addSubview(subView1)
    
    
    self.layer.masksToBounds = true
    self.layer.cornerRadius = 37 * 0.5
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func attachToWindow(inputWindow: UIWindow?) {
    removeFromSuperview()

    guard let inputWin = inputWindow,
      let hud = inputWin.rootViewController?.view.subviews.last?.subviews.first
    else {
      return
    }

    let alphaPath: ReferenceWritableKeyPath<UIView, CGFloat> = \.alpha
    _alphaCancable = hud
      .publisher(for: alphaPath)
      .assign(to: alphaPath, on: self)
    alpha = hud.alpha
    
    inputWin.rootViewController?.view?.addSubview(self)
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    guard let supView = superview
    else {
      return
    }
    
    let size = CGSize(
      width: 300,
      height: 37
    )
    let origin = CGPoint(
      x: 0,
      y: supView.bounds.height - LayoutManager.mainWindowKBBottomInset() - size.height - 24
    )
    
    self.frame = CGRect(origin: origin, size: size)
    _visualEffect.frame = self.bounds
    _contentView.frame = self.bounds
    _visualEffect2.frame = self.bounds
    
    if let width = delegate?.currentTerm()?.view?.bounds.size.width {
      self.center = CGPoint(x: width * 0.5, y: self.center.y)
    }
  }
}

class SmarterTermInput: TermInput {
  
  private var _kbView: KBView
  private var _langCharsMap: [String: String]
  private var kbView: KBView { _kbView }
  private var _previousKBFrame: CGRect = .zero
  
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
      selector: #selector(_debounceKeyboardWillChangeFrame(notification:)),
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var softwareKB: Bool {
    get { !_kbView.traits.isHKBAttached }
    set { _kbView.traits.isHKBAttached = !newValue }
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
    return res
  }
  
  override func resignFirstResponder() -> Bool {
    let res = super.resignFirstResponder()
    device?.blur()
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
  
  func setupAccessoryView() {
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = []
    inputAccessoryView = KBAccessoryView(kbView: kbView)
  }
  
  func setupAssistantItem() {
    inputAccessoryView = nil
    let proxy = KBProxy(kbView: kbView)
    let item = UIBarButtonItem(customView: proxy)
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = [UIBarButtonItemGroup(barButtonItems: [item], representativeItem: nil)]
  }
  
  func removeIfHardwareKBAttached() {
    let showSmartKeys = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
    if kbView.traits.isHKBAttached && !showSmartKeys {
      inputAccessoryView?.isHidden = true
      inputAssistantItem.leadingBarButtonGroups = []
      inputAssistantItem.trailingBarButtonGroups = []
    }
  }
  
  private var _debounceTimer: Timer? = nil
  
  @objc func _debounceKeyboardWillChangeFrame(notification: NSNotification) {
    _debounceTimer?.invalidate()
    _debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { _ in
      self._keyboardWillChangeFrame(notification: notification)
    })
  }
  
  func _keyboardWillChangeFrame(notification: NSNotification) {
    guard
      let window = window,
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
//      let kbFrameBegin = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal ? _previousKBFrame != kbFrameEnd :  abs(_previousKBFrame.height - kbFrameEnd.height) > 6 // reduce reflows (local height 69, other - 72)!
    else {
      return
    }
    
    _previousKBFrame = kbFrameEnd
    
    var bottomInset: CGFloat = 0
    var isFloatingKB = false
    var isSoftwareKB = true
    
    let viewMaxY = UIScreen.main.bounds.height
    
    let kbMaxY = kbFrameEnd.maxY
    let kbMinY = kbFrameEnd.minY
    
    if kbMaxY >= viewMaxY {
      bottomInset = viewMaxY - kbMinY
    } else if kbMinY < viewMaxY && kbMaxY < viewMaxY {
      // Floating
      isFloatingKB = true
      isSoftwareKB = true
      
      if let accessoryView = inputAccessoryView {
        bottomInset = accessoryView.bounds.height
      }
    }
    
    // Only key window can change input props
    guard window.isKeyWindow == true
    else {
      return
    }

    defer {
      _kbView.setNeedsLayout()
      LayoutManager.updateMainWindowKBBottomInset(bottomInset);
    }
    
    let hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
    //[BKUserConfigurationManager userSettingsValueForKey:BKUserConfigShowSmartKeysWithXKeyBoard];
    
    kbView.traits.isFloatingKB = isFloatingKB
    
    if traitCollection.userInterfaceIdiom == .phone {
      isSoftwareKB = kbFrameEnd.height > 140
      
      if self.softwareKB != isSoftwareKB {
        self.softwareKB = isSoftwareKB
        DispatchQueue.main.async {
          self._kbView.inputAccessoryView?.invalidateIntrinsicContentSize()
          self._kbView.reloadInputViews()
        }
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
      setupAssistantItem()
      reloadInputViews()
    }
    
  }
  
  static let shared = SmarterTermInput()
}

