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

// RevenueCat import removed for privacy

let Blink15BundleID = "sh.blink.blinkshell"

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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? = nil
  private var _ctrl = DummyVC()
  private var _lockCtrl: UIViewController? = nil
  private var _spCtrl = SpaceController()
  private var paywallWindow: UIWindow? = nil

  public func showingPaywall() -> Bool {
    self.paywallWindow != nil
  }

  override var editingInteractionConfiguration: UIEditingInteractionConfiguration {
    super.editingInteractionConfiguration
  }

  @objc private func _showPaywallIfNeeded() {
    // Disabled: paywall bypassed in privacy-enhanced build (no subscription checks).
    return
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    if scene == ShadowWindow.shared?.refWindow.windowScene {
      ShadowWindow.shared?.layer.removeFromSuperlayer()
      ShadowWindow.shared?.windowScene = nil
//      ShadowWindow.shared = nil
    } else if scene == ShadowWindow.shared?.windowScene {
      // We need to move it
      ShadowWindow.shared?.windowScene = UIApplication.shared.connectedScenes.activeAppScene(exclude: scene)
    }
  }

  /**
   Handles the `ssh://`, `vscode://` and `http(s)://` URL schemes.
   */
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {

    if let sshUrlScheme = URLContexts.first(where: { $0.url.scheme == "ssh" })?.url {
      _handleSshUrlScheme(with: sshUrlScheme)
    } else if let codeUrlScheme = URLContexts.first(where: { $0.url.scheme == "vscode" })?.url {
      _handleCodeUrlScheme(with: codeUrlScheme)
    } else if let httpScheme = URLContexts.first(where: { $0.url.scheme == "http" || $0.url.scheme == "https"})?.url {
      _handleCodeUrlScheme(with: httpScheme)
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

    defer {
      self._showPaywallIfNeeded()
    }

    #if targetEnvironment(macCatalyst)
      if let titlebar = windowScene.titlebar {
        titlebar.titleVisibility = .hidden
        titlebar.autoHidesToolbarInFullScreen = true
      }
    #endif

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

    // Await until scene and streams are ready
    // NOTE We could also store the contexts and use them later.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      self.scene(scene, openURLContexts: connectionOptions.urlContexts)
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

  func sceneDidBecomeActive(_ scene: UIScene) {
    guard let window = window else {
      return
    }

    // 0. Local Auth AutoLock Check on old screens
    _lockNonInteractiveScreenIfNeeded()


    if window == ShadowWindow.shared?.refWindow {
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

    if let paywallWindow = paywallWindow {
      _ = KBTracker.shared.input?.resignFirstResponder()
      paywallWindow.makeKeyAndVisible()
      return;
    }

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
        if self.paywallWindow != nil {
          _ = KBTracker.shared.input?.resignFirstResponder()
        }
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
        if self.paywallWindow != nil {
          _ = KBTracker.shared.input?.resignFirstResponder()
        }
        if scene.activationState == .foregroundActive,
          input?.isRealFirstResponder == false {
          spCtrl.focusOnShellAction()
        }
      }

      return
    }

    if input?.window === window {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if self.paywallWindow != nil {
          _ = KBTracker.shared.input?.resignFirstResponder()
        }
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

fileprivate extension URL {
  func getQueryStringParameter(param: String) -> String? {
    guard let url = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
    return url.percentEncodedQueryItems?.first(where: { $0.name == param })?.value
  }
}

// MARK: Manage the `scene(_:openURLContexts:)` actions
extension SceneDelegate {

  /*
   Handles the `ssh://` URL scheme.
   */
  private func _handleSshUrlScheme(with sshUrl: URL) {
    func buildSSHCommand(from url: URL) -> String? {
      // Goal is to tokenize a SSH Command. The risk is that the URL may contian injection parameters.
      // We sanitize the input and make sure the result, specially the user@host part is a valid shell token.
      // The SSH library takes care of validating the host, user, etc...
      guard url.scheme == "ssh" else { return nil }
      guard let host = url.host?.removingPercentEncoding,
            host.rangeOfCharacter(from: .controlCharacters) == nil,
            host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            !host.starts(with:"-"),
            !host.starts(with:".") else {
        return nil
      }

      var sshCommand = "ssh "

      if let port = url.port {
        sshCommand += "-p \(port) "
      }

      if let userinfo = url.user?.removingPercentEncoding,
         userinfo.rangeOfCharacter(from: .controlCharacters) == nil {
        // Extract only the username before the first ";" if conn-params exist
        let username = userinfo.components(separatedBy: ";").first ?? ""
        guard username.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !username.starts(with:"-"),
              !username.starts(with:".") else {
          return nil
        }

        if username.count > 0 {
          sshCommand += "-l \(username) "
        }
      }

      sshCommand += "\(host)"
      return sshCommand
    }

    guard let sshCommand = buildSSHCommand(from: sshUrl),
          sshCommand.rangeOfCharacter(from: .controlCharacters) == nil else {
      return
    }

    _spCtrl.runShellSessionIntent(command: sshCommand)
  }

  // vscode://<path_to_file>
  // vscode://<repository>
  // vscode://github.codespaces/connect?name=
  // vscode://file/path/to/file/file.ext:55:20
  private func _handleCodeUrlScheme(with url: URL) {
    guard let fileProtocol = url.host else {
      return
    }

    var codeCommand = "code "
    var urlPath = url.path
    if ["sftp", "local"].contains(fileProtocol) {
      if fileProtocol == "sftp" {
        // host/ -> host:/;  host/~ -> host:~/
        let components = url.pathComponents
        if components.count < 2 {
          return
        }
        let hostName = components[1]
        codeCommand += "\(hostName):"
        urlPath = url.pathComponents[2...].joined(separator: "/")
        if urlPath.isEmpty {
          urlPath = "/"
        }
      }
      codeCommand += "\(urlPath)"
    } else if fileProtocol.lowercased() == "github.codespaces",
              url.path == "/connect",
              let codespaceName = url.getQueryStringParameter(param: "name") {
      codeCommand += "https://\(codespaceName).github.dev"
    }
    else {
      codeCommand += url.absoluteString
    }

    if codeCommand.rangeOfCharacter(from: .controlCharacters) != nil {
      return
    }

    _spCtrl.runShellSessionIntent(command: codeCommand)
  }

  private func _handleHttpUrlScheme(with url: URL) {
    let urlCommand = url.absoluteString
    if urlCommand.rangeOfCharacter(from: .controlCharacters) != nil {
      return
    }

    _spCtrl.runShellSessionIntent(command: "code \(urlCommand)")
  }
}
