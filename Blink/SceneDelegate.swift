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
import SafariServices
import SwiftUI

import RevenueCat


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? = nil

  private var _ctrl = DummyVC()
  private var _lockCtrl: UIViewController? = nil
  private var _spCtrl = SpaceController()
  @objc var spaceController: SpaceController { _spCtrl }
  private var paywallWindow: UIWindow? = nil

  private let log = Zuse.logger(.machine, "Scene")

  override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
    super.editingInteractionConfiguration
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions)
  {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    log.info("willConnect role=\(session.role.rawValue)")

    defer {
      self._makePaywallWindowIfNeeded()
    }

    let conditions = scene.activationConditions

    conditions.canActivateForTargetContentIdentifierPredicate = NSPredicate(value: true)
    conditions.prefersToActivateForTargetContentIdentifierPredicate = NSPredicate(format: "SELF == 'blink://open-scene/\(scene.session.persistentIdentifier)'")

    _spCtrl.sceneRole = session.role
    _spCtrl.restoreWith(stateRestorationActivity: session.stateRestorationActivity)

    if session.role == .windowExternalDisplayNonInteractive,
      let mainScene = UIApplication.shared.connectedScenes.activeAppScene() {

      if BLKDefaults.overscanCompensation() == .BKBKOverscanCompensationMirror {
        return
      }

      let window = ExternalWindow(windowScene: windowScene)
      self.window = window

      let shadowWin: ShadowWindow

      if let win = ShadowWindow.shared {
        win.refWindow = window
        _spCtrl = win.spaceController
        shadowWin = win
      } else {
        shadowWin = ShadowWindow(windowScene: mainScene, refWindow: window, spCtrl: _spCtrl)
        ShadowWindow.shared = shadowWin
      }

      window.shadowWindow = shadowWin

      window.rootViewController = UIViewController()
      window.layer.addSublayer(shadowWin.layer)

      shadowWin.windowLevel = .init(rawValue: UIWindow.Level.normal.rawValue - 1)
      // External window and shadow window stay hidden until sceneDidBecomeActive
      // reveals them. Same create-vs-activate rule as the main window.

      return
    }

    let window = UIWindow(windowScene: windowScene)
    self.window = window

    window.rootViewController = _spCtrl
    // Window stays hidden until _activateFrontWindow reveals the chosen front state.

    // Parse connection-time URLs into SceneCommands synchronously; SC drains
    // them when its current TermController fires deviceIsReady.
    let pendingCommands = connectionOptions.urlContexts.compactMap {
      SceneCommands.from(url: $0.url)
    }
    if !pendingCommands.isEmpty {
      _spCtrl.enqueueSceneCommands(pendingCommands)
    }
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    log.info("sceneDidBecomeActive protectedData=\(UIApplication.shared.isProtectedDataAvailable)")
    guard let window = window else {
      return
    }

    _lockNonInteractiveScreenIfNeeded()

    // External-display SD: reveal the external window and hand input routing
    // to the shadow window it hosts on the main scene. The regular scene's
    // SD drives the rest of activation.
    if window == ShadowWindow.shared?.refWindow {
      window.isHidden = false
      if let shadowWindow = ShadowWindow.shared {
        shadowWindow.isHidden = false
        shadowWindow.makeKey()
      }
      return
    }

    // If this SD owns the shadow window, forward activation to the refScene
    // so that the regular scene's own activation logic runs.
    if let shadowWindow = ShadowWindow.shared,
       shadowWindow.windowScene == scene,
       let refScene = shadowWindow.refWindow.windowScene {
      ShadowWindow.shared?.refWindow.windowScene?.delegate?.sceneDidBecomeActive?(refScene)
    }

    _activateFrontWindow()
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    log.info("sceneWillEnterForeground protectedData=\(UIApplication.shared.isProtectedDataAvailable)")
    // Resume on the real return-from-background; unlike didBecomeActive this does
    // not fire on the transient activation during a device lock.
    if UIApplication.shared.isProtectedDataAvailable {
      _spCtrl.machine.resume()
    }
  }

  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    _setDummyVC()
    return _spCtrl.stateRestorationActivity()
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    log.info("sceneDidDisconnect")
    if scene == ShadowWindow.shared?.refWindow.windowScene {
      ShadowWindow.shared?.layer.removeFromSuperlayer()
      ShadowWindow.shared?.windowScene = nil
//      ShadowWindow.shared = nil
    } else if scene == ShadowWindow.shared?.windowScene {
      // We need to move it
      ShadowWindow.shared?.windowScene = UIApplication.shared.connectedScenes.activeAppScene(exclude: scene)
    } else {
      // iOS reclaimed this scene; preserve its Machine while still reachable.
      let machine = _spCtrl.machine
      log.info("suspend on disconnect \(machine.name)")
      machine.suspend()
    }
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      if let command = SceneCommands.from(url: context.url) {
        command.perform(on: _spCtrl)
        return
      }
    }
  }

  private func _lockNonInteractiveScreenIfNeeded() {
    guard
      let window = ShadowWindow.shared?.refWindow,
      let sceneDelegate = window.windowScene?.delegate as? SceneDelegate
    else {
      return
    }

    if LocalAuth.shared.lockRequired {
      if let lockCtrl = sceneDelegate._lockCtrl {
        if window.rootViewController != lockCtrl {
          window.rootViewController = lockCtrl
        }

        return
      }


      sceneDelegate._lockCtrl = UIHostingController(rootView: LockView(unlockAction: nil))
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

  /// Suspend every active scene's Machine directly — the path for when the
  /// per-scene background suspend won't fire (foreground terminate, or the
  /// protected-data lock deadline). Idempotent; the same Machine can back more
  /// than one scene (external display), so it is suspended once.
  @objc static func suspendActiveMachines() {
    var seen = Set<ObjectIdentifier>()
    for scene in UIApplication.shared.connectedScenes {
      guard let machine = (scene.delegate as? SceneDelegate)?.spaceController.machine else {
        continue
      }
      if seen.insert(ObjectIdentifier(machine)).inserted {
        machine.suspend()
      }
    }
    Zuse.logger(.machine, "Scene").info("suspend \(seen.count) active machine(s)")
  }

  @objc static func resumeActiveMachines() {
    var seen = Set<ObjectIdentifier>()
    for scene in UIApplication.shared.connectedScenes {
      guard let machine = (scene.delegate as? SceneDelegate)?.spaceController.machine else {
        continue
      }
      if seen.insert(ObjectIdentifier(machine)).inserted {
        machine.resume()
      }
    }
    Zuse.logger(.machine, "Scene").info("resume \(seen.count) active machine(s)")
  }
}

extension SceneDelegate {
  // Creates the paywall window when entitlements require it. Create-only —
  // does not make the window key or animate it in. That belongs to
  // _activateFrontWindow, which is called at activation.
  private func _makePaywallWindowIfNeeded() {
    guard !EntitlementsManager.shared.hasActiveSubscriptions(),
          let windowScene = self.window?.windowScene,
          self.paywallWindow == nil
    else {
      return
    }

    let paywallWindow = UIWindow(windowScene: windowScene)
    paywallWindow.windowLevel = .statusBar + 0.5
    paywallWindow.layer.opacity = 0
    self.paywallWindow = paywallWindow

    let view = NewIntroPageWindow(urlHandler: blink_openurl,
                                  dismissHandler: { [weak self] in
                                    UIView.animate(withDuration: 0.5) {
                                      self?.paywallWindow?.layer.opacity = 0
                                    } completion: { _ in
                                      self?.paywallWindow = nil
                                      self?._activateFrontWindow()
                                    }
                                  })
    let ctrl = StatusBarLessViewController(rootView: view)
    ctrl.lockPortrait = UIDevice.current.userInterfaceIdiom == .phone
    paywallWindow.rootViewController = ctrl
  }

  // Single decision point for which window is the key window for this scene.
  // Paywall takes precedence, then LocalAuth lock, then Space (SC).
  private func _activateFrontWindow() {
    guard let window = window, let windowScene = window.windowScene else {
      return
    }

    if let paywallWindow = paywallWindow {
      _ = KBTracker.shared.input?.resignFirstResponder()
      paywallWindow.makeKeyAndVisible()
      if paywallWindow.layer.opacity < 1 {
        UIView.animate(withDuration: 0.3) {
          paywallWindow.layer.opacity = 1
        }
      }
      return
    }

    if LocalAuth.shared.lockRequired {
      if let lockCtrl = _lockCtrl {
        if window.rootViewController !== lockCtrl {
          window.rootViewController = lockCtrl
        }
        window.isHidden = false
        return
      }
      let unlockAction = windowScene.session.role == .windowApplication ? LocalAuth.shared.unlock : nil
      let lockCtrl = UIHostingController(rootView: LockView(unlockAction: unlockAction))
      _lockCtrl = lockCtrl
      window.rootViewController = lockCtrl
      window.isHidden = false
      // The LocalAuth overlay steals the foreground-active state, and on dismiss the sceneActivate is called again,
      // and the _activateFrontWindow called again, so the flow progresses.
      unlockAction?()
      return
    }

    _lockCtrl = nil
    LocalAuth.shared.stopTrackTime()

    if window.rootViewController !== _spCtrl {
      window.rootViewController = _spCtrl
    }
    window.isHidden = false

    guard _spCtrl.presentedViewController == nil else {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak windowScene] in
      guard let self = self,
            let windowScene = windowScene,
            self.paywallWindow == nil,
            windowScene.activationState == .foregroundActive,
            // Don't steal key from a shadow window hosted on this scene.
            ShadowWindow.shared?.windowScene !== windowScene,
            self._spCtrl.currentTerm()?.termDevice.view?.isFocused() != true
      else {
        return
      }
      window.makeKey()
      self._spCtrl.focusOnShellAction()
    }
  }
}

class ExternalWindow: UIWindow {
  var shadowWindow: UIWindow? = nil
}

@objc class ShadowWindow: UIWindow {
  private var _refWindow: UIWindow
  private let _spCtrl: SpaceController

  var spaceController: SpaceController { _spCtrl }
  @objc var refWindow: UIWindow {
    get {
      _refWindow
    }
    set {
      _refWindow = newValue
    }
  }

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
