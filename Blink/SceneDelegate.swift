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

class DummyVC: UIViewController {
  override var prefersStatusBarHidden: Bool { true }
  public override var prefersHomeIndicatorAutoHidden: Bool { true }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? = nil
  var _ctrl = DummyVC()
  var _spCtrl = SpaceController()
  
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions)
  {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    
    self.window = UIWindow(windowScene: windowScene)
    _spCtrl.restoreWith(stateRestorationActivity: session.stateRestorationActivity)
    window?.rootViewController = _spCtrl
    window?.makeKeyAndVisible()
  }
  
  func sceneDidBecomeActive(_ scene: UIScene) {
    debugPrint("BK: sceneDidBecomeActive")
    
    window?.rootViewController = _spCtrl
    _spCtrl.currentTerm()?.resumeIfNeeded()
    _spCtrl.currentTerm()?.view?.setNeedsLayout()
    
    let input = SmarterTermInput.shared
    if
      _spCtrl.currentTerm()?.termDevice.view?.isFocused() == false,
      !input.isRealFirstResponder,
      input.window == self.window {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if !SmarterTermInput.shared.isRealFirstResponder && scene.activationState == .foregroundActive {
          self._spCtrl.focusOnShellAction()
        }
      }
    } else {
      SmarterTermInput.shared.reportStateReset()
    }
  }
  
  func sceneWillResignActive(_ scene: UIScene) {
    debugPrint("BK: sceneWillResignActive")
    // Trick to reset stick cmd key. #
    _ctrl.view.frame = _spCtrl.view.frame
    window?.rootViewController = _ctrl
    _ctrl.view.addSubview(_spCtrl.view)
  }
  
  func sceneWillEnterForeground(_ scene: UIScene) {
    debugPrint("BK: sceneWillResignActive")
  }
  
  func sceneDidEnterBackground(_ scene: UIScene) {
    debugPrint("BK: sceneDidEnterBackground")
  }
  
  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    _spCtrl.stateRestorationActivity()
  }

}
