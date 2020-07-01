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
import SwiftUI

class ExternalWindow: UIWindow {
  var shadowWindow: UIWindow? = nil
}

@objc class ShadowWindow: UIWindow {
  private let _refWindow: UIWindow
  private let _spCtrl: SpaceController
  
  var spaceController: SpaceController { _spCtrl }
  @objc var refWindow: UIWindow { _refWindow }
  
  init(windowScene: UIWindowScene, refWindow: UIWindow, spCtrl: SpaceController) {
    _refWindow = refWindow
    _spCtrl = spCtrl
    
    super.init(windowScene: windowScene)
    
    frame = _refWindow.frame
    rootViewController = _spCtrl
    self.clipsToBounds = false
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var frame: CGRect {
    get { _refWindow.frame }
    set { super.frame = _refWindow.frame }
  }
  
  
  @objc static var shared: ShadowWindow? = nil
}

class DummyVC: UIViewController {
  override var canBecomeFirstResponder: Bool { true }
  override var prefersStatusBarHidden: Bool { true }
  public override var prefersHomeIndicatorAutoHidden: Bool { true }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? = nil
  private var _ctrl = DummyVC()
  private var _lockCtrl: UIViewController? = nil
  private var _spCtrl = SpaceController()
  
  func sceneDidDisconnect(_ scene: UIScene) {
    if scene == ShadowWindow.shared?.refWindow.windowScene {
      ShadowWindow.shared?.layer.removeFromSuperlayer()
      ShadowWindow.shared?.windowScene = nil
      ShadowWindow.shared = nil
    } else if scene == ShadowWindow.shared?.windowScene {
      // We need to move it
      ShadowWindow.shared?.windowScene = UIApplication.shared.connectedScenes.activeAppScene(exclude: scene)
    }
  }
  
  /**
   Handles the `ssh://` URL schemes and x-callback-url for devices that are running iOS 13 or higher.
   */
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    
    if let sshUrlScheme = URLContexts.first(where: { $0.url.scheme == "ssh" })?.url {
      handleSshUrlScheme(with: sshUrlScheme)
    } else if let xCallbackUrl = URLContexts.first(where: { $0.url.scheme == "blinkshell" })?.url {
      handleXcallbackUrl(with: xCallbackUrl)
    }
  }
  
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions)
  {
    _ = KBTracker.shared
    
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    
    let conditions = scene.activationConditions
    
    conditions.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
    conditions.prefersToActivateForTargetContentIdentifierPredicate = NSPredicate(format: "SELF == 'blink://open-scene/\(scene.session.persistentIdentifier)'")
    
    _spCtrl.sceneRole = session.role
    _spCtrl.restoreWith(stateRestorationActivity: session.stateRestorationActivity)
    
    if session.role == .windowExternalDisplay,
      let mainScene = UIApplication.shared.connectedScenes.activeAppScene() {
      
      if BKDefaults.overscanCompensation() == .BKBKOverscanCompensationMirror {
        return
      }
      
      let window = ExternalWindow(windowScene: windowScene)
      self.window = window
    
      let shadowWin = ShadowWindow(windowScene: mainScene, refWindow: window, spCtrl: _spCtrl)
      defer { ShadowWindow.shared = shadowWin }
      
      window.shadowWindow = shadowWin
      
      shadowWin.makeKeyAndVisible()
      
      window.rootViewController = UIViewController()
      window.layer.addSublayer(shadowWin.layer)
      
//      window.makeKeyAndVisible()
      window.isHidden = false
      shadowWin.windowLevel = .init(rawValue: UIWindow.Level.normal.rawValue - 1)
      
      return
    }
    
    let window = UIWindow(windowScene: windowScene)
    self.window = window
    
    window.rootViewController = _spCtrl
    window.isHidden = false
  }
  
  func sceneDidBecomeActive(_ scene: UIScene) {
    
    guard let window = window else {
      return
    }
    
    if (scene.session.role == .windowExternalDisplay) {
      if LocalAuth.shared.lockRequired {
        if let lockCtrl = _lockCtrl {
          if window.rootViewController != lockCtrl {
            window.rootViewController = lockCtrl
          }
          
          return
        }

        
        _lockCtrl = UIHostingController(rootView: LockView(unlockAction: nil))
        window.rootViewController = _lockCtrl
        return
      }
      if window.rootViewController == _lockCtrl {
        window.rootViewController = UIViewController()
      }
      _lockCtrl = nil
      
      if let shadowWin = ShadowWindow.shared {
        window.layer.addSublayer(shadowWin.layer)
      }
      
      return
    }
    
    
    // 1. Local Auth AutoLock Check
    
    if LocalAuth.shared.lockRequired {
      if let lockCtrl = _lockCtrl {
        if window.rootViewController != lockCtrl {
          window.rootViewController = lockCtrl
        }
        
        return
      }
      
      let unlockAction = scene.session.role == .windowApplication ? LocalAuth.shared.unlock : nil
      
      _lockCtrl = UIHostingController(rootView: LockView(unlockAction: unlockAction))
      window.rootViewController = _lockCtrl
      
      unlockAction?()

      return
    }

    _lockCtrl = nil
    LocalAuth.shared.stopTrackTime()
    
    if let shadowWindow = ShadowWindow.shared,
      shadowWindow.windowScene == scene,
      let refScene = shadowWindow.refWindow.windowScene {
      ShadowWindow.shared?.refWindow.windowScene?.delegate?.sceneDidBecomeActive?(refScene)
    }
    
    // 2. Set space controller back and refresh layout
    
    let spCtrl = _spCtrl
    
    if window.rootViewController != spCtrl {
      window.rootViewController = spCtrl
    }
    
    guard let term = spCtrl.currentTerm() else {
      return
    }
    
    term.resumeIfNeeded()
    term.view?.setNeedsLayout()
    
    // We can present config or stuck view. 
    guard spCtrl.presentedViewController == nil else {
      return
    }
    
    // 3. Stuck Key Check
    
    let input = KBTracker.shared.input
    if let key = input?.stuckKey() {
      debugPrint("BK:", "stuck!!!")
      input?.setTrackingModifierFlags([])
      
      if input?.isHardwareKB == true && key == .commandLeft {
        let ctrl = UIHostingController(rootView: StuckView(keyCode: key, dismissAction: {
          spCtrl.onStuckOpCommand()
        }))
        
        ctrl.modalPresentationStyle = .formSheet
        spCtrl.stuckKeyCode = key
        spCtrl.present(ctrl, animated: false)

        return
      }
    }
    
    spCtrl.stuckKeyCode = nil
    
    // 4. Focus Check
    
    if input == nil {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if KBTracker.shared.input == nil {
          window.makeKey()
          spCtrl.focusOnShellAction()
          KBTracker.shared.input?.reportFocus(true)
        }
      }
      return
    }
    
    if term.termDevice.view?.isFocused() == false,
      input?.isRealFirstResponder == false,
      input?.window === window {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if scene.activationState == .foregroundActive,
          input?.isRealFirstResponder == false {
          spCtrl.focusOnShellAction()
        }
      }
      
      return
    }
    
    if input?.window === window {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if scene.activationState == .foregroundActive,
          term.termDevice.view?.isFocused() == false {
          spCtrl.focusOnShellAction()
        }
      }

      return
    }
    
    input?.reportStateReset()
  }
  
  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    _setDummyVC()
    return _spCtrl.stateRestorationActivity()
  }
  
  private func _setDummyVC() {
    if let _ = _spCtrl.presentedViewController {
      return
    }
    // Trick to reset stick cmd key.
    _ctrl.view.frame = _spCtrl.view.frame
    window?.rootViewController = _ctrl
    _ctrl.view.addSubview(_spCtrl.view)
  }
  
  @objc var spaceController: SpaceController { _spCtrl }

}

// MARK: Manage the `scene(_:openURLContexts:)` actions
extension SceneDelegate {
  
  /**
   Handles the `ssh://` URL schemes and x-callback-url for devices that are running iOS 13 or higher.
   - Parameters:
     - xCallbackUrl: The x-callback-url specified by the user
   */
  func handleSshUrlScheme(with sshUrl: URL) {
    
    var sshCommand = "ssh"
    
    // Progressively unwrap all of the parameters available on the URL to form
    // the SSH command to be later passed to the shell
    if let port = sshUrl.port {
      sshCommand += " -p \(port)"
    }
    
    if let username = sshUrl.user {
      sshCommand += " \(username)@"
    }
    
    if let host = sshUrl.host {
      sshCommand += "\(host)"
    }
    
    guard let term = _spCtrl.currentTerm() else {
      return
    }
    
    _spCtrl.focusOnShellAction()
    
    if term.isRunningCmd() {
      // If a SSH/mosh connection is already open in the current terminal shell
      // create a new one and then write the SSH command
      
      _spCtrl.newShellAction()
      
      guard let term = _spCtrl.currentTerm() else {
        return
      }
      
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
        term.termDevice.write(sshCommand)
      }
    } else {
      // No running command or shell found running, run the SSH command on the
      // available shell
      term.termDevice.write(sshCommand)
    }
  }
  
  /**
   Handles the x-callback-url, if  a successful `x-success` URL is provided when being called from apps like Shortcuts it returns to the original app after a successful execution.
    - Parameters:
      - xCallbackUrl: The x-callback-url specified by the user, URL format should be `blinkshell://run?key=KEY&cmd=CMD%20ENCODED`
   */
  func handleXcallbackUrl(with xCallbackUrl: URL) {
    
    guard let xCallbackUrlHost = xCallbackUrl.host, xCallbackUrlHost == "run" else {
      return
    }
    
    let components = URLComponents(url: xCallbackUrl, resolvingAgainstBaseURL: true)
    
    var xCancelURL: URL?
    var xSuccessURL: URL?
    var xErrorURL: URL?
    
    guard let items = components?.queryItems else {
      return
    }
    
    if let xCancel = items.first(where: { $0.name == "x-cancel" })?.value {
      xCancelURL = URL(string: xCancel)
    }
    
    if let xError = items.first(where: { $0.name == "x-error" })?.value {
      xErrorURL = URL(string: xError)
    }
    
    if let xSuccess = items.first(where: { $0.name == "x-success" })?.value {
      xSuccessURL = URL(string: xSuccess)
    }
    
    guard BKDefaults.isXCallBackURLEnabled() else {
      if let xCancelURL = xCancelURL {
        blink_openurl(xCancelURL)
      }
      return
    }
    
    // Cancel execution of the command if the x-callback-url doesn't have a
    // key field present that is needed to allow URL actions
    guard let keyItem: String = items.first(where: { $0.name == "key" })?.value else {
      
      if let xCancelURL = xCancelURL {
        blink_openurl(xCancelURL)
      }
      
      return
    }
    
    // Cancel the execution of the command as x-callback-url are not
    // enabled for the user's or the x-callback-url does not have
    // the correct key set
    guard keyItem == BKDefaults.xCallBackURLKey() else {
      
      if let xErrorURL = xErrorURL {
        blink_openurl(xErrorURL)
      }
      return
    }
    
    guard let cmdItem: String = items.first(where: { $0.name == "cmd" })?.value else {
      if let xErrorURL = xErrorURL {
        blink_openurl(xErrorURL)
      }
      return
    }
    
    let spCtrl = _spCtrl
    
    guard let term = spCtrl.currentTerm() else {
      if let xErrorURL = xErrorURL {
        blink_openurl(xErrorURL)
      }
      return
    }
    
    spCtrl.focusOnShellAction()
    
    // If SSH/mosh connection is already open in the current terminal shell
    // create a new one and then write the SSH command
    if term.isRunningCmd() {
      
      spCtrl.newShellAction()
      
      guard let term = spCtrl.currentTerm() else {
        if let xErrorURL = xErrorURL {
          blink_openurl(xErrorURL)
        }
        return
      }
      
      // Wait until the new terminal has been opened and loaded,
      // then submit the new command
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
        term.xCallbackLineSubmitted(cmdItem, xSuccessURL)
      }
    } else {
      // There's a free terminal to use, submit the command directly
      term.xCallbackLineSubmitted(cmdItem, xSuccessURL)
    }
  }
  
}
