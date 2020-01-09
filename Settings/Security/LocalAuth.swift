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
import LocalAuthentication

@objc class LocalAuth: NSObject {
  
  static var unlockNotification = Notification.Name("blink.localauth.unlock")
  
  @objc static let shared = LocalAuth()
  
  static var _maxInactiveInterval = TimeInterval(10 * 60)
  private var _didEnterBackgroundAt: Date? = nil
  private var _inProgress = false
  
  override init() {
    super.init()
    
    // worm up LAContext
    LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    
    if BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigAutoLock) {
      _didEnterBackgroundAt = Date.distantPast
    }
    
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: OperationQueue.main
    ) { _ in
      self._didEnterBackgroundAt = Date()
    }
  }
  
  var lockRequired: Bool {
    guard
      let didEnterBackgroundAt = _didEnterBackgroundAt,
      BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigAutoLock),
      Date().timeIntervalSince(didEnterBackgroundAt) > LocalAuth._maxInactiveInterval
    else {
      return false
    }
    
    return true
  }
  
  func unlock(scene: UIScene) {
    guard
      scene.session.role == .windowApplication,
      _inProgress == false
    else {
      return
    }
    
    autheticate(callback: { [weak self] (success) in
      if success {
        self?.stopTrackTime()
        NotificationCenter.default.post(name: LocalAuth.unlockNotification, object: nil)
      }
    }, reason: "to unlock blink.")
  }
  
  func stopTrackTime() {
    _didEnterBackgroundAt = nil
  }
  
  @objc func autheticate(callback: @escaping (_ success: Bool) -> Void, reason: String = "to access sensitive data.") {
    if _inProgress {
      callback(false)
    }
    _inProgress = true
    
    let context = LAContext()
    var error: NSError?
    guard
      context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    else {
      debugPrint(error?.localizedDescription ?? "Can't evaluate policy")
      _inProgress = false
      callback(false)
      return
    }

    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason ) { success, error in
      DispatchQueue.main.async {
        self._inProgress = false
        callback(success)
      }
    }
  }
  
}
