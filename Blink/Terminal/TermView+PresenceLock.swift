//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2025 Blink Mobile Shell Project
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

extension TermView {
  // Decides whether the terminal is present: appeared and in an active scene.
  // Leaving is reported at once; returning waits for the keyboard to settle.
  @objc(TermViewPresenceLock)
  final class PresenceLock: NSObject {
    static let settleDelay: TimeInterval = 0.35

    private weak var _view: UIView?
    private let _onChange: (Bool) -> Void
    private var _isAppeared = false
    private var _isSceneActive = true
    private var _isReleasePending = false
    private var _release: DispatchWorkItem? = nil

    @objc init(view: UIView, onChange: @escaping (Bool) -> Void) {
      _view = view
      _onChange = onChange
      super.init()

      let nc = NotificationCenter.default
      nc.addObserver(self, selector: #selector(_sceneWillDeactivate(_:)),
                     name: UIScene.willDeactivateNotification, object: nil)
      nc.addObserver(self, selector: #selector(_sceneDidActivate(_:)),
                     name: UIScene.didActivateNotification, object: nil)
      nc.addObserver(self, selector: #selector(_keyboardWillChangeFrame(_:)),
                     name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    deinit {
      _release?.cancel()
    }

    var isPresent: Bool { _isAppeared && _isSceneActive }

    @objc func didAppear() {
      _isAppeared = true
      if let scene = _view?.window?.windowScene {
        _isSceneActive = scene.activationState == .foregroundActive
      }
      _update()
    }

    @objc func willDisappear() {
      _isAppeared = false
      _update()
    }

    private func _update() {
      _cancelRelease()

      guard isPresent else {
        _onChange(false)
        return
      }

      _isReleasePending = true
      _scheduleRelease(after: Self.settleDelay)
    }

    private func _isOwnScene(_ n: Notification) -> Bool {
      guard let scene = n.object as? UIWindowScene else { return false }
      return _view?.window?.windowScene === scene
    }

    @objc private func _sceneWillDeactivate(_ n: Notification) {
      guard _isOwnScene(n) else { return }
      _isSceneActive = false
      _update()
    }

    @objc private func _sceneDidActivate(_ n: Notification) {
      guard _isOwnScene(n) else { return }
      _isSceneActive = true
      _update()
    }

    private func _scheduleRelease(after delay: TimeInterval) {
      _release?.cancel()
      let work = DispatchWorkItem { [weak self] in
        guard let self = self, self._isReleasePending, self.isPresent else { return }
        self._isReleasePending = false
        self._release = nil
        self._onChange(true)
      }
      _release = work
      DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func _cancelRelease() {
      _isReleasePending = false
      _release?.cancel()
      _release = nil
    }

    // A keyboard on its way in or out pushes the release past its animation.
    @objc private func _keyboardWillChangeFrame(_ n: Notification) {
      guard _isReleasePending else { return }
      let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
      _scheduleRelease(after: duration + Self.settleDelay)
    }

  }
}
