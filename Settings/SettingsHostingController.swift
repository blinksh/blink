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

import SwiftUI
import UIKit

@objc class SettingsHostingController: NSObject {
  private static func _createWith<T: View>(view: T, nav: UINavigationController?) -> UIViewController {
    guard
      let nav = nav
    else {
      return UIHostingController(rootView: view)
    }
    return UIHostingController(rootView: NavView(navController: nav)  { view } )
  }
  
  @objc static func createKeyboardControllerWith(nav: UINavigationController?) -> UIViewController {
    _createWith(
      view: KBConfigView(config: KBTracker.shared.loadConfig()),
      nav: nav
    )
  }
  
  @objc static func createNotificationsWith(nav: UINavigationController?) -> UIViewController {
    _createWith(
      view: BKNotificationsView(),
      nav: nav
    )
  }
  
  @objc static func createKeysWith(nav: UINavigationController?) -> UIViewController {
    _createWith(
      view: KeysListView(),
      nav: nav
    )
  }
  
  @objc static func createKeyPickerWith(nav: UINavigationController?, keyID: String, delegate: KeysPickerViewDelegate) -> UIViewController {
    _createWith(
      view: KeysPickerView(currentKey: keyID, delegate: delegate),
      nav: nav
    )
  }
  
//  @objc static func createNewKeyWith(nav: UINavigationController?, newKeyDelegate: NewKeyViewDelegate) -> UIViewController {
//    _createWith(
//      view: NewKeyView(delegate: newKeyDelegate),
//      nav: nav
//    )
//  }
}
