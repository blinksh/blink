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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow? = nil
  
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions)
  {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    
    _tuneOverscanIfNeeded(session: session)
    self.window = UIWindow(windowScene: windowScene)
    let spaceCntrl = SpaceController()
    spaceCntrl.restoreWith(stateRestorationActivity: session.stateRestorationActivity)
    window?.rootViewController = spaceCntrl
    window?.makeKeyAndVisible()
  }
  
  private func _tuneOverscanIfNeeded(session: UISceneSession) {
    guard
      UIScreen.screens.count > 1,
      let screen = UIScreen.screens.last,
      session.role == .windowExternalDisplay
    else {
      return
    }
    
    switch BKDefaults.overscanCompensation() {
     case .BKBKOverscanCompensationNone:
       screen.overscanCompensation = .none
     case .BKBKOverscanCompensationScale:
       screen.overscanCompensation = .scale;
     case .BKBKOverscanCompensationInsetBounds:
       screen.overscanCompensation = .insetBounds;
     default:
       break
    }
  }
  
  func sceneDidBecomeActive(_ scene: UIScene) {
    _spaceController?.currentTerm()?.resumeIfNeeded()
  }
  
  func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    _spaceController?.stateRestorationActivity()
  }
  
  private var _spaceController: SpaceController? {
    window?.rootViewController as? SpaceController
  }
}
