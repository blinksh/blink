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
  
  private var _kbView = KBView()
  private var _hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
  private var _inputAccessoryView: UIView? = nil
  
  var device: TermDevice? = nil {
    didSet { reportStateReset() }
  }
  
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  
  override init(frame: CGRect, configuration: WKWebViewConfiguration) {
    
    super.init(frame: frame, configuration: configuration)
    
    _kbView.keyInput = self
    _kbView.lang = textInputMode?.primaryLanguage ?? ""
    
    _setupStyle()
    
    if traitCollection.userInterfaceIdiom == .pad {
      _setupAssistantItem()
    } else {
      _setupAccessoryView()
    }
    
    KBSound.isMutted = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigMuteSmartKeysPlaySound)
    
    let nc = NotificationCenter.default

    nc.addObserver(
      self,
      selector: #selector(_inputModeChanged),
      name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)

    nc.addObserver(
      self,
      selector: #selector(_updateSettings),
      name: NSNotification.Name.BKUserConfigChanged, object: nil)
    
    nc.addObserver(
      self,
      selector: #selector(_setupStyle),
      name: NSNotification.Name(rawValue: BKAppearanceChanged), object: nil)
  }
  
  override func layoutSubviews() {
    debugPrint("KB: layoutSubviews")
    super.layoutSubviews()
    
    guard
      let scene = window?.windowScene
    else {
      return
    }
    if traitCollection.userInterfaceIdiom == .phone {
      _kbView.traits.isPortrait = scene.interfaceOrientation.isPortrait
    }
  }
  
  override func ready() {
    debugPrint("KB: ready", isFirstResponder, isRealFirstResponder)
    super.ready()
    reportLang(_kbView.lang)
    
    device?.focus()
    _kbView.isHidden = false
    _kbView.invalidateIntrinsicContentSize()
    _refreshInputViews()
    disableTextSelectionView()
  }
  
 
  // overriding chain
  override var next: UIResponder? {
//    debugPrint("KB: next")
    guard let responder = device?.view?.superview
    else {
      return super.next
    }
    return responder
  }
  
  func reset() {
    
  }
  
  @objc func _inputModeChanged() {
    debugPrint("KB: _inputModeChanged")
    DispatchQueue.main.async {
      let lang = self.textInputMode?.primaryLanguage ?? ""
      self._kbView.lang = lang
      self.reportLang(lang)
    }
  }
  
  override var inputAssistantItem: UITextInputAssistantItem {
    debugPrint("KB: inputAssistantItem", super.inputAssistantItem.trailingBarButtonGroups.count)
    let item = super.inputAssistantItem
    if item.trailingBarButtonGroups.count > 1 {
      item.trailingBarButtonGroups = [item.trailingBarButtonGroups[0]]
    }
    if item.trailingBarButtonGroups.count > 0 {
      item.leadingBarButtonGroups = []
    }
    _kbView.setNeedsLayout()
    return item
  }
  
  override func becomeFirstResponder() -> Bool {
    debugPrint("KB: becomeFirstResponder")
    let res = super.becomeFirstResponder()
    disableTextSelectionView()

    if !webViewReady {
      return res
    }
    
    device?.focus()
    _kbView.isHidden = false
    _inputAccessoryView?.isHidden = false
    _kbView.invalidateIntrinsicContentSize()
    _refreshInputViews()
    
    return res
  }
  
  var isRealFirstResponder: Bool {
    debugPrint("KB: isRealFirstResponder")
    return contentView()?.isFirstResponder == true
  }
  
  private func _refreshInputViews() {
    debugPrint("KB: _refreshInputViews")
    guard
      traitCollection.userInterfaceIdiom == .pad,
      let assistantItem = contentView()?.inputAssistantItem
    else {
      contentView()?.reloadInputViews()
      return;
    }

    // Double reload inputs fixes: https://github.com/blinksh/blink/issues/803
    assistantItem.leadingBarButtonGroups = [.init(barButtonItems: [UIBarButtonItem()], representativeItem: nil)]
    reloadInputViews()
    if (_hideSmartKeysWithHKB && _kbView.traits.isHKBAttached) {
      _removeSmartKeys()
    }
//    reloadInputViews()
  }
  
  override func resignFirstResponder() -> Bool {
    debugPrint("KB: resignFirstResponder")
    let res = super.resignFirstResponder()
    if res {
      device?.blur()
      _kbView.isHidden = true
      _inputAccessoryView?.isHidden = true
      reloadInputViews()
    }
    return res
  }
  
  private func _setupAccessoryView() {
    debugPrint("KB: _setupAccessoryView")
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = []
    if let _ = _inputAccessoryView as? KBAccessoryView {
//      v.isHidden = false
    } else {
      _inputAccessoryView = KBAccessoryView(kbView: _kbView)
    }
  }
  
  override var inputAccessoryView: UIView? {
    return _inputAccessoryView
  }
  
  private func _setupAssistantItem() {
    debugPrint("KB: _setupAssistantItem")
    let item = inputAssistantItem

    let proxyItem = UIBarButtonItem(customView: KBProxy(kbView: _kbView))
    let group = UIBarButtonItemGroup(barButtonItems: [proxyItem], representativeItem: nil)
    item.leadingBarButtonGroups = []
    item.trailingBarButtonGroups = [group]
  }
  
  private func _removeSmartKeys() {
    debugPrint("KB: _removeSmartKeys")
    _inputAccessoryView = UIView(frame: .zero)
    guard let item = contentView()?.inputAssistantItem
    else {
      return
    }
    item.leadingBarButtonGroups = []
    item.trailingBarButtonGroups = []
  }
  
  // - MARK: Keyboard Frame Events
  
  private func _setupWithKBNotification(notification: Notification) {
    debugPrint("KB: _setupWithKBNotification")
    guard
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal // we reconfigure kb only for local notifications
    else {
      if notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool == false {
        self.device?.view?.blur()
      }
      return
    }
    
    var traits       = _kbView.traits
    let mainScreen   = UIScreen.main
    let screenHeight = mainScreen.bounds.height
    let isIPad       = traitCollection.userInterfaceIdiom == .pad
    var isOnScreenKB = kbFrameEnd.size.height > 110
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
          _setupAccessoryView()
        } else {
          _setupAssistantItem()
        }
      } else {
        _setupAccessoryView()
      }
    } else if !traits.isHKBAttached && !isOnScreenKB {
      _kbView.kbDevice = .detect()
      if _hideSmartKeysWithHKB {
        _removeSmartKeys()
      } else if isIPad {
        _setupAssistantItem()
      } else {
        _setupAccessoryView()
      }
    } else if !traits.isFloatingKB && isFloatingKB {
      if isFloatingKB {
        _kbView.kbDevice = .in6_5
        traits.isPortrait = true
        _setupAccessoryView()
      } else {
        _setupAssistantItem()
      }
    } else if traits.isFloatingKB && !isFloatingKB {
      _kbView.kbDevice = .detect()
      _removeSmartKeys()
      _setupAssistantItem()
    } else {
      return
    }
    
    DispatchQueue.main.async {
      self._refreshInputViews()
    }
  }

  override func _keyboardDidChangeFrame(_ notification: Notification) {
    super._keyboardDidChangeFrame(notification)
    debugPrint("KB: _keyboardDidChangeFrame")
  }
  
  override func _keyboardWillChangeFrame(_ notification: Notification) {
    super._keyboardWillChangeFrame(notification)
    debugPrint("KB: _keyboardWillChangeFrame")
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
        _setupAccessoryView()
        DispatchQueue.main.async {
          self.contentView()?.reloadInputViews()
        }
      } else if _kbView.traits.isFloatingKB && !isFloating && !_kbView.traits.isHKBAttached {
        _kbView.kbDevice = .detect()
        _removeSmartKeys()
        _setupAssistantItem()
        DispatchQueue.main.async {
          self.contentView()?.reloadInputViews()
        }
      }
      _kbView.traits.isFloatingKB = isFloating
    }

    LayoutManager.updateMainWindowKBBottomInset(bottomInset);
  }
  
  override func _keyboardWillShow(_ notification: Notification) {
    super._keyboardWillShow(notification)
    debugPrint("KB: _keyboardWillShow")
    _setupWithKBNotification(notification: notification)
  }
  
  override func _keyboardWillHide(_ notification: Notification) {
    super._keyboardWillHide(notification)
    debugPrint("KB: _keyboardWillHide")
  }
  
  override func _keyboardDidHide(_ notification: Notification) {
    super._keyboardDidHide(notification)
    debugPrint("KB: _keyboardDidHide")
  }
  
  override func _keyboardDidShow(_ notification: Notification) {
    super._keyboardDidShow(notification)
    debugPrint("KB: _keyboardDidShow")
    _kbView.invalidateIntrinsicContentSize()
    _keyboardWillChangeFrame(notification)
  }
  
  @objc static let shared = SmarterTermInput()
}

// - MARK: Web communication
extension SmarterTermInput {
  
  override func onOut(_ data: String) {
    defer {
      _kbView.turnOffUntracked()
    }
    
    guard let device = device else {
      return
    }
    
    device.view?.displayInput(data)
    
    let ctrlC = "\u{0003}"
    let ctrlD = "\u{0004}"
    
    if data == ctrlC || data == ctrlD,
      device.delegate?.handleControl(data) == true {
      return
    }
    device.write(data)
  }
  
  override func onCommand(_ command: String) {
    _kbView.turnOffUntracked()
    if let cmd = Command(rawValue: command) {
      var n = next
      while let r = n {
        if let sc = r as? SpaceController {
          sc._onCommand(cmd)
          return
        }
        n = r.next
      }
    }
  }
  
  override func onSelection(_ args: [AnyHashable : Any]) {
     if let dir = args["dir"] as? String, let gran = args["gran"] as? String {
       device?.view?.modifySelection(inDirection: dir, granularity: gran)
     } else if let op = args["command"] as? String {
       switch op {
       case "change": device?.view?.modifySideOfSelection()
       case "copy": copy(self)
       case "paste": device?.view?.pasteSelection(self)
       case "cancel": fallthrough
       default:  device?.view?.cleanSelection()
       }
     }
   }
   
   override func onMods() {
     _kbView.stopRepeats()
   }
   
   override func onIME(_ event: String, data: String) {
     guard let deviceView = device?.view
     else {
       return
     }
     
     if event == "compositionstart" && data.isEmpty {
     } else if event == "compositionend" {
       _kbView.traits.isIME = false
       deviceView.setIme("", completionHandler: nil)
     } else { // "compositionupdate"
       _kbView.traits.isIME = true
       deviceView.setIme(data) {  (data, error) in
         guard
           error == nil,
           let resp = data as? [String: Any],
           let markedRect = resp["markedRect"] as? String
         else {
           return
         }
         var rect = NSCoder.cgRect(for: markedRect)
         let maxY = rect.maxY
         let minY = rect.minY
         let suggestionsHeight: CGFloat = 44
         
         if maxY - suggestionsHeight < 0 {
           rect.origin.y = maxY
         } else {
           rect.origin.y = minY
         }
         
         rect.size.height = 0
         rect.size.width = 0
         
         self.frame = deviceView.convert(rect, to: self.superview)
       }
     }
   }
}
// - MARK: Config

extension SmarterTermInput {
  @objc private func _setupStyle() {
      debugPrint("KB: _setupStyle")
     tintColor = .cyan
     switch BKDefaults.keyboardStyle() {
     case .light:
       overrideUserInterfaceStyle = .light
     case .dark:
       overrideUserInterfaceStyle = .dark
     default:
       overrideUserInterfaceStyle = .unspecified
     }
   }

   @objc private func _updateSettings() {
    debugPrint("KB: _updateSettings")
     KBSound.isMutted = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigMuteSmartKeysPlaySound)
     let hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
     
     if hideSmartKeysWithHKB != _hideSmartKeysWithHKB {
       _hideSmartKeysWithHKB = hideSmartKeysWithHKB
       if traitCollection.userInterfaceIdiom == .pad {
         _setupAssistantItem()
       } else {
         _setupAccessoryView()
       }
       _refreshInputViews()
     }
   }
}


// - MARK: Commands

extension SmarterTermInput {
  
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    switch action {
    case #selector(UIResponder.paste(_:)):
      return true
    case #selector(UIResponder.copy(_:)),
         #selector(TermView.pasteSelection(_:)):
      return device?.view?.hasSelection == true
    case #selector(Self.copyLink(_:)),
         #selector(Self.openLink(_:)):
      return device?.view?.detectedLink != nil
    default:
      return super.canPerformAction(action, withSender: sender)
    }
  }
  
  override func copy(_ sender: Any?) {
    device?.view?.copy(sender)
  }
  
  override func paste(_ sender: Any?) {
    device?.view?.paste(sender)
  }
  
  @objc func copyLink(_ sender: Any) {
    guard
      let deviceView = device?.view,
      let url = deviceView.detectedLink
    else {
      return
    }
    UIPasteboard.general.url = url
    deviceView.cleanSelection()
  }
  
  @objc func openLink(_ sender: Any) {
    guard
      let deviceView = device?.view,
      let url = deviceView.detectedLink
    else {
      return
    }
    deviceView.cleanSelection()
    
    blink_openurl(url)
  }
  
  @objc func pasteSelection(_ sender: Any) {
    device?.view?.pasteSelection(sender)
  }
}


extension SmarterTermInput: TermInput {
  var secureTextEntry: Bool {
    get {
      false
    }
    set(secureTextEntry) {
      
    }
  }
  
}
