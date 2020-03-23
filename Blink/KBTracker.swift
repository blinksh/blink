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

class KBTracker {
  
  private(set) var hideSmartKeysWithHKB = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
  
  static let shared = KBTracker()
  private(set) var kbTraits = KBTraits.initial
  private(set) var kbDevice = KBDevice.detect()
  
  private(set) var input: SmarterTermInput? = nil
  
  var isHardwareKB: Bool { kbTraits.isHKBAttached }
  
  private func _loadKBConfigData() -> Data? {
    guard
      let url = BlinkPaths.blinkKBConfigURL(),
      let data = try? Data(contentsOf: url)
      else {
        return nil
    }
    return data
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
  }
  
  func attach(input: SmarterTermInput?) {
    self.input = input
    if let input = input {
      kbTraits = input.kbView.traits
    }
  }
  
  init() {
    let nc = NotificationCenter.default
    
    nc.addObserver(self, selector: #selector(_keyboardDidChangeFrame(_:)), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
    nc.addObserver(self, selector: #selector(_keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
  }
  
  private func _setupWithKBNotification(notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let kbFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal // we reconfigure kb only for local notifications
      else {
        if notification.userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool == false {
          self.input?.reportFocus(false)
        }
        return
    }
    
    var traits       = kbTraits
    let mainScreen   = UIScreen.main
    let screenHeight = mainScreen.bounds.height
    let isIPad       = UIDevice.current.userInterfaceIdiom == .pad
    
    
    var isOnScreenKB = isIPad ? kbFrameEnd.size.height > 116 : screenHeight >= kbFrameEnd.maxY
    
    // External screen kb workaround
    if isOnScreenKB && isIPad && input?.window?.screen !== mainScreen {
      isOnScreenKB = kbFrameEnd.origin.y < screenHeight - 140
    }
    
    let isFloatingKB = isIPad && kbFrameEnd.origin.x > 0 && kbFrameEnd.origin.y > 0
    
    let input = self.input
    
    defer {
      traits.isFloatingKB = isFloatingKB
      traits.isHKBAttached = !isOnScreenKB
      input?.kbView.traits = traits
      input?.reportLang()
    }
    
    if traits.isHKBAttached && isOnScreenKB {
      if isIPad {
        if isFloatingKB {
          input?.kbView.kbDevice = .in6_5
          traits.isPortrait = true
          input?._setupAccessoryView()
        } else {
          input?._setupAssistantItem()
        }
      } else {
        input?._setupAccessoryView()
      }
    } else if !traits.isHKBAttached && !isOnScreenKB {
      input?.kbView.kbDevice = .detect()
      if hideSmartKeysWithHKB {
        input?._removeSmartKeys()
      } else if isIPad {
        input?._setupAssistantItem()
      } else {
        input?._setupAccessoryView()
      }
    } else if !traits.isFloatingKB && isFloatingKB {
      if isFloatingKB {
        input?.kbView.kbDevice = .in6_5
        traits.isPortrait = true
        input?._setupAccessoryView()
      } else {
        input?._setupAssistantItem()
      }
    } else if traits.isFloatingKB && !isFloatingKB {
      input?.kbView.kbDevice = .detect()
      input?._removeSmartKeys()
      input?._setupAssistantItem()
    } else {
      return
    }
    
    DispatchQueue.main.async {
      input?._refreshInputViews()
    }
  }
  
  @objc private func _keyboardDidChangeFrame(_ notification: Notification) {
  }
  
  @objc private func _keyboardWillChangeFrame(_ notification: Notification) {
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
    
    let idiom = UIDevice.current.userInterfaceIdiom
    let input = self.input
    
    if isLocal && idiom == .pad {
      let isFloating = kbFrameEnd.origin.y > 0 && kbFrameEnd.origin.x > 0 || kbFrameEnd == .zero
      
      if !kbTraits.isFloatingKB && isFloating {
        kbDevice = .in6_5
        kbTraits.isPortrait = true
        input?._setupAccessoryView()
        DispatchQueue.main.async {
          input?.contentView()?.reloadInputViews()
        }
      } else if kbTraits.isFloatingKB && !isFloating && !kbTraits.isHKBAttached {
        kbDevice = .detect()
        input?._removeSmartKeys()
        input?._setupAssistantItem()
        DispatchQueue.main.async {
          input?.contentView()?.reloadInputViews()
        }
      }
      kbTraits.isFloatingKB = isFloating
    }
    
    //    if bottomInset == 0 && _kbTraits.isFloatingKB,
    //      let safeInsets = superview?.safeAreaInsets {
    //      bottomInset = _kbView.intrinsicContentSize.height + safeInsets.bottom
    //    }
    
    LayoutManager.updateMainWindowKBBottomInset(bottomInset);
  }
  
  @objc private func _keyboardWillShow(_ notification: Notification) {
    _setupWithKBNotification(notification: notification)
  }
  
  @objc private func _keyboardWillHide(_ notification: Notification) {
    _setupWithKBNotification(notification: notification)
  }
  
  @objc private func _keyboardDidHide(_ notification: Notification) {
  }
  
  @objc private func _keyboardDidShow(_ notification: Notification) {
  }
}
