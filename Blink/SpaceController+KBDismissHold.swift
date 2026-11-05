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

import UIKit

extension SpaceController {
  // Keeps a dismissed software keyboard down until a tap event.
  struct KBDismissHold {
    private enum State {
      case off
      // The window went to the back with the software keyboard down.
      case armed
      // The window is in front again, waiting for a tap that started after this.
      case holding(since: TimeInterval)
    }

    private var _state = State.off

    mutating func windowLeft(softwareKBDown: Bool) {
      _state = softwareKBDown ? .armed : .off
    }

    mutating func release() {
      _state = .off
    }

    mutating func admits(_ request: FocusRequest) -> Bool {
      switch (request, _state) {
      case (.explicit, _), (_, .off):
        return true
      case (.activation, .armed):
        _state = .holding(since: ProcessInfo.processInfo.systemUptime)
        return false
      case (.activation, .holding):
        return false
      case (.tap, .armed):
        // The window isn't in front yet, so this is the tap bringing it there.
        return false
      case (.tap(let began), .holding(let since)):
        return began > since
      }
    }
  }

  func _registerForKBDismissHoldNotifications(_ nc: NotificationCenter) {
    nc.addObserver(self, selector: #selector(_didResignKeyWindow(_:)),
                   name: UIWindow.didResignKeyNotification, object: nil)

    nc.addObserver(self, selector: #selector(_sceneWillDeactivate(_:)),
                   name: UIScene.willDeactivateNotification, object: nil)
  }

  @objc func _didResignKeyWindow(_ n: Notification) {
    guard let window = view.window, n.object as? UIWindow === window else {
      return
    }
    _recordKBStateOnLeave()
  }

  @objc func _sceneWillDeactivate(_ n: Notification) {
    guard let scene = n.object as? UIWindowScene, view.window?.windowScene === scene else {
      return
    }
    _recordKBStateOnLeave()
  }

  private func _recordKBStateOnLeave() {
    let input = KBTracker.shared.input
    let kbUp = input?.window === view.window && input?.isRealFirstResponder == true
    _kbDismissHold.windowLeft(softwareKBDown: !KBTracker.shared.isHardwareKB && !kbUp)
  }
}
