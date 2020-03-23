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

@objc class TermView2: SmarterTermInput {
  
}

class SmarterTermInput: KBWebView {
  
  var kbView = KBView()
  
  private var _inputAccessoryView: UIView? = nil
  
  var isHardwareKB: Bool { kbView.traits.isHKBAttached }
  
  var device: TermDevice? = nil {
    didSet { reportStateReset() }
  }
  
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  
  override init(frame: CGRect, configuration: WKWebViewConfiguration) {
    
    super.init(frame: frame, configuration: configuration)
    
    kbView.keyInput = self
    kbView.lang = textInputMode?.primaryLanguage ?? ""
    
    // Assume hardware kb by default, since sometimes we don't have kbframe change events
    // if shortcuts toggle in Settings.app is off.
    kbView.traits.isHKBAttached = true
    
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
    super.layoutSubviews()
    
    guard
      let scene = window?.windowScene
      else {
        return
    }
    if traitCollection.userInterfaceIdiom == .phone {
      kbView.traits.isPortrait = scene.interfaceOrientation.isPortrait
    }
  }
  
  override func ready() {
    super.ready()
    reportLang()
    
    device?.focus()
    kbView.isHidden = false
    kbView.invalidateIntrinsicContentSize()
    _refreshInputViews()
//    disableTextSelectionView()
  }
  
  
  // overriding chain
  override var next: UIResponder? {
    guard let responder = device?.view?.superview
      else {
        return super.next
    }
    return responder
  }
  
  func reset() {
    
  }
  
  @objc func _inputModeChanged() {
    DispatchQueue.main.async {
      self.reportLang()
    }
  }
  
  func reportLang() {
    let lang = self.textInputMode?.primaryLanguage ?? ""
    kbView.lang = lang
    reportLang(lang, isHardwareKB: kbView.traits.isHKBAttached)
  }
  
  override var inputAssistantItem: UITextInputAssistantItem {
    let item = super.inputAssistantItem
    if item.trailingBarButtonGroups.count > 1 {
      item.trailingBarButtonGroups = [item.trailingBarButtonGroups[0]]
    }
    if item.trailingBarButtonGroups.count > 0 {
      item.leadingBarButtonGroups = []
    }
    kbView.setNeedsLayout()
    return item
  }
  
  override func becomeFirstResponder() -> Bool {
    let res = super.becomeFirstResponder()
//    disableTextSelectionView()
    if !webViewReady {
      return res
    }
    
    device?.focus()
    kbView.isHidden = false
    _inputAccessoryView?.isHidden = false
    //    _kbView.invalidateIntrinsicContentSize()
//    _refreshInputViews()
    
    return res
  }
  
  var isRealFirstResponder: Bool {
    return contentView()?.isFirstResponder == true
  }
  
  func reportStateReset() {
    reportStateReset(false)
    device?.view?.cleanSelection()
  }
  
  func _refreshInputViews() {
    guard
      traitCollection.userInterfaceIdiom == .pad,
      let assistantItem = contentView()?.inputAssistantItem
      else {
        if (KBTracker.shared.hideSmartKeysWithHKB && kbView.traits.isHKBAttached) {
          _removeSmartKeys()
        }
        contentView()?.reloadInputViews()
        kbView.reset()
        //      _inputAccessoryView?.invalidateIntrinsicContentSize()
        reportStateReset()
        return;
    }
    
    
    assistantItem.leadingBarButtonGroups = [.init(barButtonItems: [UIBarButtonItem()], representativeItem: nil)]
    reloadInputViews()
    if (KBTracker.shared.hideSmartKeysWithHKB && kbView.traits.isHKBAttached) {
      _removeSmartKeys()
    }
    contentView()?.reloadInputViews()
    kbView.reset()
    reportStateReset()
    // Double reload inputs fixes: https://github.com/blinksh/blink/issues/803
    contentView()?.reloadInputViews()
  }
  
  override func resignFirstResponder() -> Bool {
    let res = super.resignFirstResponder()
    if res {
      device?.blur()
      kbView.isHidden = true
      _inputAccessoryView?.isHidden = true
      reloadInputViews()
    }
    return res
  }
  
  func _setupAccessoryView() {
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = []
    if let _ = _inputAccessoryView as? KBAccessoryView {
    } else {
      _inputAccessoryView = KBAccessoryView(kbView: kbView)
    }
  }
  
  override var inputAccessoryView: UIView? {
    return _inputAccessoryView
  }
  
  func _setupAssistantItem() {
    let item = inputAssistantItem
    
    let proxyItem = UIBarButtonItem(customView: KBProxy(kbView: kbView))
    let group = UIBarButtonItemGroup(barButtonItems: [proxyItem], representativeItem: nil)
    item.leadingBarButtonGroups = []
    item.trailingBarButtonGroups = [group]
  }
  
  func _removeSmartKeys() {
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
    
    var traits       = kbView.traits
    let mainScreen   = UIScreen.main
    let screenHeight = mainScreen.bounds.height
    let isIPad       = traitCollection.userInterfaceIdiom == .pad
    
//    var isOnScreenKB: Bool
    var isOnScreenKB = isIPad ? kbFrameEnd.size.height > 116 : screenHeight >= kbFrameEnd.maxY
    
    // External screen kb workaround
    if isOnScreenKB && isIPad && device?.view?.window?.screen !== mainScreen {
      isOnScreenKB = kbFrameEnd.origin.y < screenHeight - 140
    }
    
    let isFloatingKB = isIPad && kbFrameEnd.origin.x > 0 && kbFrameEnd.origin.y > 0
    
    defer {
      traits.isFloatingKB = isFloatingKB
      traits.isHKBAttached = !isOnScreenKB
      kbView.traits = traits
      reportLang()
    }
    
    if traits.isHKBAttached && isOnScreenKB {
      if isIPad {
        if isFloatingKB {
          kbView.kbDevice = .in6_5
          traits.isPortrait = true
          _setupAccessoryView()
        } else {
          _setupAssistantItem()
        }
      } else {
        _setupAccessoryView()
      }
    } else if !traits.isHKBAttached && !isOnScreenKB {
      kbView.kbDevice = .detect()
      if KBTracker.shared.hideSmartKeysWithHKB {
        _removeSmartKeys()
      } else if isIPad {
        _setupAssistantItem()
      } else {
        _setupAccessoryView()
      }
    } else if !traits.isFloatingKB && isFloatingKB {
      if isFloatingKB {
        kbView.kbDevice = .in6_5
        traits.isPortrait = true
        _setupAccessoryView()
      } else {
        _setupAssistantItem()
      }
    } else if traits.isFloatingKB && !isFloatingKB {
      kbView.kbDevice = .detect()
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
//    super._keyboardDidChangeFrame(notification)
  }
  
  override func _keyboardWillChangeFrame(_ notification: Notification) {
//    super._keyboardWillChangeFrame(notification)
//    guard
//      let userInfo = notification.userInfo,
//      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
//      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool
//      else {
//        return
//    }
//
//    var bottomInset: CGFloat = 0
//
//    let screenMaxY = UIScreen.main.bounds.size.height
//
//    let kbMaxY = kbFrameEnd.maxY
//    let kbMinY = kbFrameEnd.minY
//
//    if kbMaxY >= screenMaxY {
//      bottomInset = screenMaxY - kbMinY
//    }
//
//    if (bottomInset < 30) {
//      bottomInset = 0
//    }
//
//    if isLocal && traitCollection.userInterfaceIdiom == .pad {
//      let isFloating = kbFrameEnd.origin.y > 0 && kbFrameEnd.origin.x > 0 || kbFrameEnd == .zero
//      if !_kbView.traits.isFloatingKB && isFloating {
//        _kbView.kbDevice = .in6_5
//        _kbView.traits.isPortrait = true
//        _setupAccessoryView()
//        DispatchQueue.main.async {
//          self.contentView()?.reloadInputViews()
//        }
//      } else if _kbView.traits.isFloatingKB && !isFloating && !_kbView.traits.isHKBAttached {
//        _kbView.kbDevice = .detect()
//        _removeSmartKeys()
//        _setupAssistantItem()
//        DispatchQueue.main.async {
//          self.contentView()?.reloadInputViews()
//        }
//      }
//      _kbView.traits.isFloatingKB = isFloating
//    }
//
//    if bottomInset == 0 && _kbView.traits.isFloatingKB,
//      let safeInsets = superview?.safeAreaInsets {
//      bottomInset = _kbView.intrinsicContentSize.height + safeInsets.bottom
//    }
//
//    LayoutManager.updateMainWindowKBBottomInset(bottomInset);
  }
  
  override func _keyboardWillShow(_ notification: Notification) {
//    super._keyboardWillShow(notification)
//    _setupWithKBNotification(notification: notification)
  }
  
  override func _keyboardWillHide(_ notification: Notification) {
//    super._keyboardWillHide(notification)
//    _setupWithKBNotification(notification: notification)
  }
  
  override func _keyboardDidHide(_ notification: Notification) {
//    super._keyboardDidHide(notification)
  }
  
  override func _keyboardDidShow(_ notification: Notification) {
//    super._keyboardDidShow(notification)
//    _kbView.invalidateIntrinsicContentSize()
//    _keyboardWillChangeFrame(notification)
  }
  
  @objc static let shared = SmarterTermInput()
}

// - MARK: Web communication
extension SmarterTermInput {
  
  override func onOut(_ data: String) {
    defer {
      kbView.turnOffUntracked()
    }
    
    guard
      let device = device,
      let deviceView = device.view,
      let scene = deviceView.window?.windowScene,
      scene.activationState == .foregroundActive
    else {
        return
    }
    
    deviceView.displayInput(data)
    
    let ctrlC = "\u{0003}"
    let ctrlD = "\u{0004}"
    
    if data == ctrlC || data == ctrlD,
      device.delegate?.handleControl(data) == true {
      return
    }
    device.write(data)
  }
  
  override func onCommand(_ command: String) {
    kbView.turnOffUntracked()
    guard
      let device = device,
      let scene = device.view.window?.windowScene,
      scene.activationState == .foregroundActive,
      let cmd = Command(rawValue: command),
      let spCtrl = spaceController
    else {
        return
    }
    
    spCtrl._onCommand(cmd)
  }
  
  var spaceController: SpaceController? {
    var n = next
    while let responder = n {
      if let spCtrl = responder as? SpaceController {
        return spCtrl
      }
      n = responder.next
    }
    return nil
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
    kbView.stopRepeats()
  }
  
  override func onIME(_ event: String, data: String) {
    guard let deviceView = device?.view
      else {
        return
    }
    
    if event == "compositionstart" && data.isEmpty {
    } else if event == "compositionend" {
      kbView.traits.isIME = false
      deviceView.setIme("", completionHandler: nil)
    } else { // "compositionupdate"
      kbView.traits.isIME = true
      deviceView.setIme(data) {  (data, error) in
        guard
          error == nil,
          let resp = data as? [String: Any],
          let markedRect = resp["markedRect"] as? String
        else {
            return
        }
        let webViewFrame = deviceView.webViewFrame()
        var rect = NSCoder.cgRect(for: markedRect)
        let maxY = rect.maxY
        let minY = rect.minY
        if maxY > webViewFrame.height * 0.3 && maxY < webViewFrame.height * 0.8 {
          rect.origin.y = minY - 44 - 14
        } else if maxY > webViewFrame.height * 0.8 {
          rect.origin.y = minY - 8
        } else {
          rect.origin.y = maxY
        }
        
        rect.size.height = 0
        rect.size.width = 0
        
        self.frame = deviceView.convert(rect, to: self.superview)
      }
    }
  }
  
  func stuckKey() -> KeyCode? {
    let mods: UIKeyModifierFlags = [.shift, .control, .alternate, .command]
    let stuck = mods.intersection(trackingModifierFlags)
    
    // Return command key first
    if stuck.contains(.command) {
      return KeyCode.commandLeft
    }

    if stuck.contains(.shift) {
      return KeyCode.shiftLeft
    }
    if stuck.contains(.control) {
      return KeyCode.controlLeft
    }
    
    if stuck.contains(.alternate) {
      return KeyCode.optionLeft
    }
    
    return nil
  }
}
// - MARK: Config

extension SmarterTermInput {
  @objc private func _setupStyle() {
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
//    KBSound.isMutted = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigMuteSmartKeysPlaySound)
//    let hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
//    
//    if hideSmartKeysWithHKB != hideSmartKeysWithHKB {
//      _hideSmartKeysWithHKB = hideSmartKeysWithHKB
//      if traitCollection.userInterfaceIdiom == .pad {
//        _setupAssistantItem()
//      } else {
//        _setupAccessoryView()
//      }
//      _refreshInputViews()
//    }
  }
}


// - MARK: Commands

extension SmarterTermInput {
  
  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    switch action {
    case #selector(UIResponder.paste(_:)):
      return sender != nil
    case #selector(UIResponder.copy(_:)),
         #selector(TermView.pasteSelection(_:)),
         #selector(Self.soSelection(_:)),
         #selector(Self.googleSelection(_:)),
         #selector(Self.shareSelection(_:)):
      return sender != nil && device?.view?.hasSelection == true
    case #selector(Self.copyLink(_:)),
         #selector(Self.openLink(_:)):
      return sender != nil && device?.view?.detectedLink != nil
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
  
  @objc func googleSelection(_ sender: Any) {
    guard
      let deviceView = device?.view,
      let query = deviceView.selectedText?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
      let url = URL(string: "https://google.com/search?q=\(query)")
    else {
        return
    }
    
    blink_openurl(url)
  }
  
  @objc func soSelection(_ sender: Any) {
    guard
      let deviceView = device?.view,
      let query = deviceView.selectedText?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
      let url = URL(string: "https://stackoverflow.com/search?q=\(query)")
    else {
        return
    }
    
    blink_openurl(url)
  }
  
  @objc func shareSelection(_ sender: Any) {
    guard
      let vc = device?.delegate?.viewController(),
      let deviceView = device?.view,
      let text = deviceView.selectedText
    else {
        return
    }
    
    let ctrl = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    ctrl.popoverPresentationController?.sourceView = deviceView
    ctrl.popoverPresentationController?.sourceRect = deviceView.selectionRect
    vc.present(ctrl, animated: true, completion: nil)
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
