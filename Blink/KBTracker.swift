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


import Foundation
import UIKit

class KBObserver: NSObject, UIInteraction {
  weak var view: UIView? = nil
  var bottomInset: CGFloat? {
    guard
      let view = self.view,
      let screen = view.window?.screen
    else {
      return nil
    }
    let fromCoordinateSpace = screen.coordinateSpace
    let toCoordinateSpace: UICoordinateSpace = view
    
    let convertedKbEndFrame = fromCoordinateSpace.convert(kbScreenFrame ?? .zero, to: toCoordinateSpace)
    
    let viewIntersection = view.bounds.intersection(convertedKbEndFrame)
    return viewIntersection.isEmpty ? 0.0 : viewIntersection.size.height
  }
  
  var kbScreenFrame: CGRect? = nil
  
  func willMove(to view: UIView?) {
    
  }
  
  func didMove(to view: UIView?) {
    self.view = view
    let nc = NotificationCenter.default
    if view == nil {
      nc.removeObserver(self)
    } else {
      nc.addObserver(
          self,
          selector: #selector(_keyboardWillShow(notification:)),
          name: UIResponder.keyboardWillShowNotification,
          object: nil)
      nc.addObserver(
          self,
          selector: #selector(_keyboardWillHide(notification:)),
          name: UIResponder.keyboardWillHideNotification,
          object: nil)
      nc.addObserver(
          self,
          selector: #selector(_keyboardWillChangeFrame(notification:)),
          name: UIResponder.keyboardWillChangeFrameNotification,
          object: nil)
    }
  }
  
  @objc private func _keyboardWillShow(notification: Notification) {
    guard
      let screen = notification.object as? UIScreen,
      let view = self.view,
      screen.isEqual(view.window?.screen),
      let kbEndFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      kbEndFrame != self.kbScreenFrame
    else {
//      print("!!! will show", notification.userInfo)
      return
    }
     
    KBTracker.shared.detectHardwareKBWithSoftwareKBHeight(height: kbEndFrame.height)

    self.kbScreenFrame = kbEndFrame
    self.view?.setNeedsLayout()
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate), object: nil)
  }

  @objc private func _keyboardWillHide(notification: Notification) {
    guard
      let screen = notification.object as? UIScreen,
      let view = self.view,
      screen.isEqual(view.window?.screen),
      let kbEndFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      kbEndFrame != self.kbScreenFrame
    else {
//      print("!!! will hide", notification.userInfo)
      return
    }
     
    KBTracker.shared.detectHardwareKBWithSoftwareKBHeight(height: kbEndFrame.height)

    self.kbScreenFrame = kbEndFrame
    self.view?.setNeedsLayout()
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate), object: nil)
  }

  @objc private func _keyboardWillChangeFrame(notification: Notification) {
    // keyboardWillChangeFrameNotification always comes with a corresponding keyboardWillShowNotification or keyboardWillHideNotification.
    // Code moved to the more explicit show and hide notifications.
    return
    guard
      let screen = notification.object as? UIScreen,
      let view = self.view,
      screen.isEqual(view.window?.screen),
      let kbEndFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      kbEndFrame != self.kbScreenFrame
    else {
//      print("!!! change frame", notification.userInfo)
      return
    }
    
    KBTracker.shared.detectHardwareKBWithSoftwareKBHeight(height: kbEndFrame.height)
    
     
    self.kbScreenFrame = kbEndFrame
    self.view?.setNeedsLayout()
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate), object: nil)
  }

}

class KBTracker: NSObject {
  private(set) var hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
  
  @objc static let shared = KBTracker()
  
  private(set) var kbTraits = KBTraits.initial
  private(set) var kbDevice = KBDevice.detect()
  
  private(set) var input: SmarterTermInput? = nil
  
  @objc var detectHardwareKBWithHeight = true
  
  func detectHardwareKBWithSoftwareKBHeight(height: CGFloat) {
    if detectHardwareKBWithHeight {
      KBTracker.shared.isHardwareKB = height < 150
    }
  }
  
  @objc var isHardwareKB: Bool = true {
    didSet {
      let oldValue = kbTraits.isHKBAttached;
      kbTraits.isHKBAttached = isHardwareKB
      input?.kbView.traits.isHKBAttached = isHardwareKB
      input?.kbView.setNeedsLayout()
      if kbTraits.isHKBAttached != oldValue {
        input?.sync(traits: kbTraits, device: kbDevice, hideSmartKeysWithHKB: hideSmartKeysWithHKB)
      }
    }
  }
  
  private func _loadKBConfigData() -> Data? {
    guard
      let url = BlinkPaths.blinkKBConfigURL(),
      let data = try? Data(contentsOf: url)
      else {
        return nil
    }
    return data
  }
  
  func kbAlreadyConfigured() -> Bool {
    _loadKBConfigData() != nil
  }
  
  func loadConfig() -> KBConfig {
    guard
      let data = _loadKBConfigData(),
      let cfg = try? JSONDecoder().decode(KBConfig.self, from: data)
      else {
        return KBConfig()
    }
    return cfg;
  }
  
  func saveAndApply(config: KBConfig) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    guard
      let url = BlinkPaths.blinkKBConfigURL(),
      let data = try? encoder.encode(config)
      else {
        return
    }
    
    try? data.write(to: url, options: .atomicWrite)
    input?.configure(config)
    UIMenuSystem.main.setNeedsRebuild()
  }
  
  func attach(input: SmarterTermInput?) {
    self.input = input
    input?.sync(traits: kbTraits, device: kbDevice, hideSmartKeysWithHKB: hideSmartKeysWithHKB)
  }
  
  override init() {
    super.init()
    let nc = NotificationCenter.default
    
//    kbTraits.isHKBAttached = true
    
    nc.addObserver(self, selector: #selector(_keyboardDidChangeFrame(_:)), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
    nc.addObserver(self, selector: #selector(_inputModeChanged), name: UITextInputMode.currentInputModeDidChangeNotification, object: nil)
    nc.addObserver(self, selector: #selector(_updateSettings), name: NSNotification.Name.BKUserConfigChanged, object: nil)
  }
  
  @objc private func _updateSettings() {
    hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
  
    input?.sync(traits: kbTraits, device: kbDevice, hideSmartKeysWithHKB: hideSmartKeysWithHKB)
  }
  
  @objc func _inputModeChanged() {
    if let input = self.input {
      DispatchQueue.main.async {
        input.reportLang()
      }
    }
  }
  
  private func _setupWithKBNotification(notification: Notification) {
    
    guard
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal // we reconfigure kb only for local notifications
      else {
//        if notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool == false {
//          self.input?.reportFocus(false)
//        }
        return
    }
    
    let mainScreen   = UIScreen.main
    let screenHeight = mainScreen.bounds.height
    let isIPad       = UIDevice.current.userInterfaceIdiom == .pad
    
    
    var isOnScreenKB = isIPad ? kbFrameEnd.size.height > 116 : screenHeight >= kbFrameEnd.maxY
    
    // External screen kb workaround
    if isOnScreenKB && isIPad && input?.window?.screen !== mainScreen {
      isOnScreenKB = kbFrameEnd.origin.y < screenHeight - 140
    }
    
    let isFloatingKB = isIPad && kbFrameEnd.origin.x > 0 && kbFrameEnd.origin.y > 0
    
    defer {
      kbTraits.isFloatingKB = isFloatingKB
      input?.sync(traits: kbTraits, device: kbDevice, hideSmartKeysWithHKB: hideSmartKeysWithHKB)
    }
    
    if !kbTraits.isHKBAttached && isOnScreenKB  {
      if isIPad {
        if isFloatingKB {
          kbDevice = .in6_5
          kbTraits.isPortrait = true
        } else {
          kbDevice = .detect()
        }
      }
      return
    }
    
    if kbTraits.isHKBAttached && !isOnScreenKB {
      kbDevice = .detect()
      return
    }
    if !kbTraits.isFloatingKB && isFloatingKB {
      if isFloatingKB {
        kbDevice = .in6_5
        kbTraits.isPortrait = true
      }
      return
    }
    if kbTraits.isFloatingKB && !isFloatingKB {
      kbDevice = .detect()
    }
  }
  
  
  @objc private func _keyboardWillChangeFrame(_ notification: Notification) {
  }
  
  @objc private func _keyboardDidChangeFrame(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let _ = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let _ = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect //,
      else {
        return
    }
    
    
    if isHardwareKB {
      if kbTraits.isFloatingKB {
          kbDevice = .detect()
      }
      kbTraits.isFloatingKB = false
    }
  }

  @objc private func _keyboardWillShow(_ notification: Notification) {
    // iOS 16.1 reports screen
    
//    debugPrint("_keyboardWillShow", notification.userInfo)
//    debugPrint("_keyboardWillShow")
//    _setupWithKBNotification(notification: notification)
  }
  
  @objc private func _keyboardWillHide(_ notification: Notification) {
    
//    debugPrint("_keyboardWillHide", notification.userInfo)
//    debugPrint("_keyboardWillHide")
//    _setupWithKBNotification(notification: notification)
  }
  
  @objc private func _keyboardDidHide(_ notification: Notification) {
//    debugPrint("_keyboardDidHide", notification.userInfo)
//    debugPrint("_keyboardDidHide")
  }
  
  @objc private func _keyboardDidShow(_ notification: Notification) {
//    debugPrint("_keyboardDidShow", notification.userInfo)
//    debugPrint("_keyboardDidShow")
  }
  
}
