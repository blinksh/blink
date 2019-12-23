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

class DummyVC: UIViewController {
  override var canBecomeFirstResponder: Bool { true }
  override var prefersStatusBarHidden: Bool { true }
  public override var prefersHomeIndicatorAutoHidden: Bool { true }
}

struct StuckView: View {
  private var _emojies = ["😱", "🤪", "🧐", "🥺", "🤔", "🤭", "🙈", "🙊"]
  var keyCode: KeyCode
  var dismissAction: () -> ()
  
  init(keyCode: KeyCode, dismissAction: @escaping () -> ()) {
    self.keyCode = keyCode
    self.dismissAction = dismissAction
  }
  
  var body: some View {
      VStack {
        HStack {
          Spacer()
          Button(action: dismissAction, label: { Text("Close") })
        }.padding()
        Spacer()
        Text(_emojies.randomElement() ?? "🤥").font(.system(size: 60)).padding(.bottom, 26)
        Text("Stuck key detected.").font(.headline).padding(.bottom, 30)
        Text("Press \(keyCode.fullName) key").font(.system(size: 30))
        Spacer()
        Text("Also, please file radar (TODO: link to instructions).").padding()
      }
  }
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
    debugPrint("BK:", "willConnnectTo")
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    
    self.window = UIWindow(windowScene: windowScene)
    _spCtrl.restoreWith(stateRestorationActivity: session.stateRestorationActivity)
    window?.rootViewController = _spCtrl
    window?.makeKeyAndVisible()
  }
  
  func sceneDidBecomeActive(_ scene: UIScene) {
    debugPrint("BK:", "sceneDidBecomeActive")
    window?.rootViewController = _spCtrl
    guard let term = _spCtrl.currentTerm()
    else {
      return
    }
    term.resumeIfNeeded()
    term.view?.setNeedsLayout()
    
    let input = SmarterTermInput.shared
    if let key = input.stuckKey() {
      debugPrint("BK:", "stuck!!!")
      input.setTrackingModifierFlags([])
      let ctrl = UIHostingController(rootView: StuckView(keyCode: key, dismissAction: {
        self._spCtrl.onStuckOpCommand()
      }))
      ctrl.modalPresentationStyle = .formSheet
      _spCtrl.stuckKeyCode = key
      _spCtrl.present(ctrl, animated: false)
      return;
    } else {
      _spCtrl.stuckKeyCode = nil
    }
    if
      term.termDevice.view?.isFocused() == false,
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
    debugPrint("BK:", "sceneWillResignActive")
  }
  
  func sceneWillEnterForeground(_ scene: UIScene) {
    debugPrint("BK:", "sceneWillEnterForeground")
  }
  
  func sceneDidEnterBackground(_ scene: UIScene) {
    debugPrint("BK:", "sceneDidEnterBackground")
  }
  
  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    debugPrint("BK:", "stateRestorationActivity")
    _setDummyVC()
    return _spCtrl.stateRestorationActivity()
  }
  
  private func _setDummyVC() {
    debugPrint("BK:", "_setDummyVC")
    // Trick to reset stick cmd key.
    _ctrl.view.frame = _spCtrl.view.frame
    window?.rootViewController = _ctrl
    _ctrl.view.addSubview(_spCtrl.view)
  }

}
