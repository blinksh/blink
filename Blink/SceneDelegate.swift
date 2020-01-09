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
        HStack {
          Text("Also, please")
          Button(action: {
            let url = URL(string: "https://github.com/blinksh/blink/wiki/Known-Issue:Cmd-key-stuck-while-switching-between-apps-with-Cmd-Tab")!
            blink_openurl(url)
          }, label:  { Text("file radar.") })
        }.padding()
      }
  }
}

struct LockView: View {
  var scene: UIScene
  
  var body: some View {
    VStack {
      Spacer()
      Image(systemName: "lock.shield.fill")
        .font(.system(size: 70))
        .accentColor(Color(UIColor.blinkTint))
        .padding()
      Text("Autolocked")
        .font(.headline)
        .padding()
      Spacer()
      Spacer()
      Spacer()
      Spacer()
      if scene.session.role == .windowApplication {
        Button(action: { LocalAuth.shared.unlock(scene: self.scene) }, label: { Text("Unlock") })
          .padding().padding()
      }
    }
  }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? = nil
  var _ctrl = DummyVC()
  var _lockCtrl: UIViewController? = nil
  var _spCtrl = SpaceController()
  
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions)
  {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    
    _spCtrl.sceneRole = session.role
    
    self.window = UIWindow(windowScene: windowScene)
    _spCtrl.restoreWith(stateRestorationActivity: session.stateRestorationActivity)
    window?.rootViewController = _spCtrl
    window?.makeKeyAndVisible()
  }
  
  func sceneDidBecomeActive(_ scene: UIScene) {
    
    if LocalAuth.shared.lockRequired {
      if let lockCtrl = _lockCtrl {
        if window?.rootViewController != lockCtrl {
          window?.rootViewController = lockCtrl
        }
      } else {
        let ctrl = UIHostingController(rootView: LockView(scene: scene))
        window?.rootViewController = ctrl
        _lockCtrl = ctrl
        LocalAuth.shared.unlock(scene: scene)
      }
      return
    } else {
      _lockCtrl = nil
    }
    
    if window?.rootViewController != _spCtrl {
      window?.rootViewController = _spCtrl
    }
    
    guard let term = _spCtrl.currentTerm()
    else {
      return
    }
    
    
    term.resumeIfNeeded()
    term.view?.setNeedsLayout()
    let spCtrl = _spCtrl
    
    let input = SmarterTermInput.shared
    if let key = input.stuckKey() {
      debugPrint("BK:", "stuck!!!")
      input.setTrackingModifierFlags([])
      let ctrl = UIHostingController(rootView: StuckView(keyCode: key, dismissAction: {
        spCtrl.onStuckOpCommand()
      }))
      ctrl.modalPresentationStyle = .formSheet
      spCtrl.stuckKeyCode = key
      spCtrl.present(ctrl, animated: false)
      return;
    } else {
      spCtrl.stuckKeyCode = nil
    }
    
    
    guard spCtrl.presentedViewController == nil else {
      return
    }
    
    if
      term.termDevice.view?.isFocused() == false,
      !input.isRealFirstResponder,
      input.window == self.window {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if !SmarterTermInput.shared.isRealFirstResponder,
          scene.activationState == .foregroundActive {
          spCtrl.focusOnShellAction()
        }
      }
    } else if input.window == self.window {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
        if term.termDevice.view?.isFocused() == false,
          scene.activationState == .foregroundActive {
          spCtrl.focusOnShellAction()
        }
      }
    } else {
      SmarterTermInput.shared.reportStateReset()
    }
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

}
