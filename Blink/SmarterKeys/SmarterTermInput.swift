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

class CaretHider {
  var _cancelable: AnyCancellable? = nil
  init(view: UIView) {
    _cancelable = view.layer.publisher(for: \.sublayers).sink { (layers) in
      if let caretView = view.value(forKeyPath: "caretView") as? UIView {
        caretView.isHidden = true
      }

      if let floatingView = view.value(forKeyPath: "floatingCaretView") as? UIView {
        floatingView.isHidden = true
      }
    }
  }
}


@objc class SmarterTermInput: KBWebView {
  
  var kbView = KBView()
  
  lazy var _kbProxy: KBProxy = {
    KBProxy(kbView: self.kbView)
  }()
  
  private var _inputAccessoryView: UIView? = nil
  
  var isHardwareKB: Bool { kbView.traits.isHKBAttached }
  
  weak var device: TermDevice? = nil {
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

    
    if traitCollection.userInterfaceIdiom == .pad {
      _setupAssistantItem()
    } else {
      _setupAccessoryView()
    }
    
    KBSound.isMutted = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigMuteSmartKeysPlaySound)
    
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    
    kbView.setNeedsLayout()
  }
  
  private var _caretHider: CaretHider? = nil
  
  override func ready() {
    super.ready()
    reportLang()
    
//    device?.focus()
    kbView.isHidden = false
    kbView.invalidateIntrinsicContentSize()
//    _refreshInputViews()
    
    if let v = selectionView() {
      _caretHider = CaretHider(view: v)
    }
  }
  
  func reset() {
    
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
    
    sync(traits: KBTracker.shared.kbTraits, device: KBTracker.shared.kbDevice, hideSmartKeysWithHKB: KBTracker.shared.hideSmartKeysWithHKB)
    
    let res = super.becomeFirstResponder()
    if !webViewReady {
      return res
    }
    
    device?.focus()
    kbView.isHidden = false
    setNeedsLayout()
    _refreshInputViews()
    
    _inputAccessoryView?.isHidden = false
    
    spaceController?.cleanupControllers()

    return res
  }
  
  var isRealFirstResponder: Bool {
    contentView()?.isFirstResponder == true
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
    contentView()?.reloadInputViews()
    if (KBTracker.shared.hideSmartKeysWithHKB && kbView.traits.isHKBAttached) {
      _removeSmartKeys()
    }
    contentView()?.reloadInputViews()
    kbView.reset()
    reportStateReset()
    // Double reload inputs fixes: https://github.com/blinksh/blink/issues/803
    contentView()?.reloadInputViews()
    kbView.isHidden = false
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
    _inputAccessoryView
  }
  
  func sync(traits: KBTraits, device: KBDevice, hideSmartKeysWithHKB: Bool) {
    kbView.kbDevice = device
    
    var needToReload = false
    defer {
      
      kbView.traits = traits
      
      if let scene = window?.windowScene {
        if traitCollection.userInterfaceIdiom == .phone {
          kbView.traits.isPortrait = scene.interfaceOrientation.isPortrait
        } else if kbView.traits.isFloatingKB {
          kbView.traits.isPortrait = true
        } else {
          kbView.traits.isPortrait = scene.interfaceOrientation.isPortrait
        }
      }
      
      
      if needToReload {
        DispatchQueue.main.async {
          self._refreshInputViews()
        }
      }
    }
    
    if hideSmartKeysWithHKB && traits.isHKBAttached {
      _removeSmartKeys()
      return
    }
    
    if traits.isFloatingKB {
      _setupAccessoryView()
      return
    }
    
    if traitCollection.userInterfaceIdiom == .pad {
      needToReload = inputAssistantItem.trailingBarButtonGroups.count != 1
      _setupAssistantItem()
    } else {
      needToReload = (_inputAccessoryView as? KBAccessoryView) == nil
      _setupAccessoryView()
    }
    
  }
  
  func _setupAssistantItem() {
    let item = inputAssistantItem
    
    let proxyItem = UIBarButtonItem(customView: _kbProxy)
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
    setNeedsLayout()
  }
  
  override func _keyboardDidChangeFrame(_ notification: Notification) {
  }
  
  override func _keyboardWillChangeFrame(_ notification: Notification) {
  }
  
  override func _keyboardWillShow(_ notification: Notification) {
  }
  
  override func _keyboardWillHide(_ notification: Notification) {
  }
  
  override func _keyboardDidHide(_ notification: Notification) {
  }
  
  override func _keyboardDidShow(_ notification: Notification) {
  }
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
    if event == "compositionstart" && data.isEmpty {
    } else if event == "compositionend" {
      kbView.traits.isIME = false
    } else { // "compositionupdate"
      kbView.traits.isIME = true
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
//      if #available(iOS 15.0, *) {
//        switch action {
//          case #selector(UIResponder.pasteAndMatchStyle(_:)),
//               #selector(UIResponder.pasteAndSearch(_:)),
//               #selector(UIResponder.pasteAndGo(_:)): return false
//          case _: break
//        }
//      }
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
