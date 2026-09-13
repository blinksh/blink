////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2026 Blink Mobile Shell Project
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

private final class KBDPadButton: UIButton {
  var onActivate: (() -> Void)?

  override func accessibilityActivate() -> Bool {
    guard let onActivate = onActivate else { return false }
    onActivate()
    return true
  }
}

// This panel never becomes first responder, so dragging and pressing it preserve terminal focus.
final class KBDPadView: UIView, UIGestureRecognizerDelegate {
  var inputProvider: (() -> SmarterTermInput?)?
  private let _values: [KBKeyValue] = [.up, .left, .right, .down]
  private var _timer: Timer?
  private weak var _repeatingInput: SmarterTermInput?
  private weak var _pressedButton: UIButton?
  private var _availableFrame: CGRect = .zero
  private var _dragOrigin: CGPoint = .zero

  init() {
    super.init(frame: CGRect(x: 0, y: 0, width: 168, height: 168))
    backgroundColor = .secondarySystemBackground
    layer.cornerRadius = 16
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOpacity = 0.2
    layer.shadowRadius = 8
    layer.shadowOffset = CGSize(width: 0, height: 2)
    accessibilityIdentifier = "terminal.dPad"

    let positions: [CGPoint] = [
      CGPoint(x: 60, y: 8), CGPoint(x: 8, y: 60),
      CGPoint(x: 112, y: 60), CGPoint(x: 60, y: 112),
    ]
    for (index, value) in _values.enumerated() {
      let button = KBDPadButton(type: .system)
      button.frame = CGRect(origin: positions[index], size: CGSize(width: 48, height: 48))
      button.tag = index
      button.setImage(UIImage(systemName: value.symbolName ?? "arrow.up"), for: .normal)
      button.tintColor = .label
      button.backgroundColor = .tertiarySystemFill
      button.layer.cornerRadius = 10
      button.accessibilityLabel = value.accessibilityLabel
      button.accessibilityTraits.insert(.keyboardKey)
      button.isExclusiveTouch = true
      button.addTarget(self, action: #selector(press(_:)), for: .touchDown)
      button.addTarget(
        self, action: #selector(releasePress),
        for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
      // VoiceOver activates controls without a touch-down event.
      button.onActivate = { [weak self] in
        self?.inputProvider?()?.kbView.sendKey(value)
      }
      addSubview(button)
    }

    let close = UIButton(type: .system)
    close.frame = CGRect(x: 8, y: 8, width: 44, height: 44)
    close.setImage(UIImage(systemName: "xmark"), for: .normal)
    close.tintColor = .secondaryLabel
    close.accessibilityLabel = "Close D-pad"
    close.addTarget(self, action: #selector(closePanel), for: .touchUpInside)
    addSubview(close)

    let reset = UIButton(type: .system)
    reset.frame = CGRect(x: 116, y: 8, width: 44, height: 44)
    reset.setImage(UIImage(systemName: "arrow.counterclockwise"), for: .normal)
    reset.tintColor = .secondaryLabel
    reset.accessibilityLabel = "Reset D-pad position"
    reset.addTarget(self, action: #selector(resetPosition), for: .touchUpInside)
    addSubview(reset)

    let grip = UIImageView(image: UIImage(systemName: "circle.grid.2x2.fill"))
    grip.frame = CGRect(x: 74, y: 74, width: 20, height: 20)
    grip.tintColor = .tertiaryLabel
    grip.isAccessibilityElement = false
    addSubview(grip)

    let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
    pan.delegate = self
    addGestureRecognizer(pan)
    NotificationCenter.default.addObserver(
      self, selector: #selector(stopRepeating),
      name: UIApplication.willResignActiveNotification, object: nil)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  deinit {
    _timer?.invalidate()
    NotificationCenter.default.removeObserver(self)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      stopRepeating()
    }
  }

  func constrainPosition(to availableFrame: CGRect) {
    if availableFrame != _availableFrame {
      stopRepeating()
    }
    _availableFrame = availableFrame
    // Keep the user's open/closed state while keyboard transitions leave no usable area.
    alpha = availableFrame.isEmpty ? 0 : 1
    isUserInteractionEnabled = !availableFrame.isEmpty
    guard !availableFrame.isEmpty else {
      stopRepeating()
      return
    }

    // Shrink only when necessary, keeping every control inside narrow or short viewports.
    let scale = min(
      1, min(availableFrame.width / bounds.width, availableFrame.height / bounds.height))
    transform = CGAffineTransform(scaleX: scale, y: scale)
    let halfWidth = bounds.width * scale / 2
    let halfHeight = bounds.height * scale / 2
    center = CGPoint(
      x: min(max(center.x, availableFrame.minX + halfWidth), availableFrame.maxX - halfWidth),
      y: min(max(center.y, availableFrame.minY + halfHeight), availableFrame.maxY - halfHeight))
  }

  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch)
    -> Bool
  {
    // Only the panel background drags; all buttons retain their touches.
    return touch.view === self
  }

  @objc private func drag(_ gesture: UIPanGestureRecognizer) {
    if gesture.state == .began {
      stopRepeating()
      _dragOrigin = center
    }
    let translation = gesture.translation(in: superview)
    center = CGPoint(x: _dragOrigin.x + translation.x, y: _dragOrigin.y + translation.y)
    constrainPosition(to: _availableFrame)
  }

  @objc private func closePanel() {
    stopRepeating()
    isHidden = true
  }

  @objc func resetPosition() {
    stopRepeating()
    guard !_availableFrame.isEmpty else { return }
    center = CGPoint(
      x: _availableFrame.maxX - bounds.width * transform.a / 2 - 12,
      y: _availableFrame.maxY - bounds.height * transform.d / 2 - 12)
    constrainPosition(to: _availableFrame)
  }

  @objc private func press(_ button: UIButton) {
    stopRepeating()
    guard let input = inputProvider?() else {
      return
    }
    _pressedButton = button
    _repeatingInput = input
    input.kbView.stopRepeats()
    input.kbView.sendKey(_values[button.tag])
    let timer = Timer(timeInterval: 0.5, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      self.repeatPress()
      guard self._pressedButton != nil else { return }
      let repeatingTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
        self?.repeatPress()
      }
      self._timer = repeatingTimer
      RunLoop.main.add(repeatingTimer, forMode: .common)
    }
    _timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func repeatPress() {
    // A held arrow must never leak into another session or a background window.
    guard !isHidden, window != nil, let input = _repeatingInput,
      input === inputProvider?(), let button = _pressedButton
    else {
      stopRepeating()
      return
    }
    input.kbView.sendKey(_values[button.tag])
  }

  @objc private func releasePress() {
    stopRepeating()
  }

  @objc func stopRepeating() {
    _timer?.invalidate()
    _timer = nil
    _pressedButton?.isHighlighted = false
    _pressedButton = nil
    _repeatingInput = nil
  }
}
