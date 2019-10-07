////////////////////////////////////////////////////////////////////////////////
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


class KBKeyViewArrows: KBKeyView {
  let _symbols: [UIImageView]
  private var _touchFirstLocation: CGPoint = .zero
  
  private var _prevValue: KBKeyValue? = nil
  private var _keyValue: KBKeyValue? = nil
  private var _values: [KBKeyValue]
  
  private var _accessibilityElements:[KBKeyAccessibilityElement]? = nil
  private var _timer: Timer? = nil
  private var _repeating: Bool = false
  private var _repeatingSpeed: TimeInterval = 0.1
  
  override init(key: KBKey, keyDelegate: KBKeyViewDelegate) {
    
    _values = [.left, .down, .up, .right]
    _symbols = _values.map { value in
      UIImageView(
        image: UIImage(
          systemName: value.alternateSymbolName ?? "questionmark.diamond"
        )
      )
    }
    
    super.init(key: key, keyDelegate: keyDelegate)
    
    self.isAccessibilityElement = false
    
    let kbSizes = keyDelegate.kbSizes
    
    for symbol in _symbols {
      symbol.contentMode = .center
      symbol.preferredSymbolConfiguration = .init(pointSize: kbSizes.key.fonts.symbol,
                                                      weight: .regular)

      symbol.tintColor = UIColor.label
      addSubview(symbol)
    }
  }
  
  
  func _startTimer() {
    _timer?.invalidate()
    weak var weakSelf = self
    _timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
      weakSelf?._repeating = true
      weakSelf?._continueTimer(interval: 0.1)
    }
  }
  
  func _continueTimer(interval: TimeInterval) {
    _timer?.invalidate()
    weak var weakSelf = self
    _repeatingSpeed = interval
    
    weakSelf?._timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
      guard let view = weakSelf, let value = view._keyValue else {
        return
      }
      
      view.key.sound.playIfPossible()
      view.keyDelegate.keyViewTriggered(keyView: view, value: value)
    }
  }
  
  func _stopTimer() {
    _repeating = false
    _timer?.invalidate()
    _timer = nil
  }
  
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else {
      return
    }
    
    _stopTimer()
    _prevValue = nil
    _keyValue = nil
    _touchFirstLocation = touch.location(in: self)
    super.touchesBegan(touches, with: event)
    
    _updateState(touch: touch)
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    
    guard let touch = touches.first else {
      return
    }
    
    _updateState(touch: touch)
  }
  
  func _updateState(touch: UITouch) {
    let point = touch.location(in: self)
    
    let keyBounds = bounds.inset(by: keyDelegate.kbSizes.key.insets.key)
    let center = CGPoint(x: keyBounds.midX, y: keyBounds.midY)
    
    let delta = CGPoint(x: center.x - point.x, y: center.y - point.y)
    
    if abs(delta.x) < keyBounds.width * 0.2 && abs(delta.y) < keyBounds.height * 0.15 {
      _keyValue = nil
      _prevValue = nil
      _stopTimer()
      setNeedsLayout()
      return
    }
    
    if abs(delta.x) > abs(delta.y) {
      _keyValue = delta.x < 0 ? .right : .left
    } else {
      _keyValue = delta.y < 0 ? .down : .up
    }
    
    if _repeating {
      var speed = 0.1
      if abs(delta.x) > keyBounds.width * 0.9 || abs(delta.y) > keyBounds.height * 3  {
        speed = 0.08
      }
      if abs(delta.x) > keyBounds.width * 2 || abs(delta.y) > keyBounds.height * 4  {
        speed = 0.05
      }
      if speed !=  _repeatingSpeed {
        _continueTimer(interval: speed)
      }
    }
    
    if _prevValue != _keyValue {
      _prevValue = _keyValue
      _startTimer()
      setNeedsLayout()
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let value = _keyValue {
      keyDelegate.keyViewTriggered(keyView: self, value: value)
    }
    super.touchesEnded(touches, with: event)
  }
  
  override func turnOff() {
    _keyValue = nil
    _prevValue = nil
    _stopTimer()
    super.turnOff()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let symbolFrame = bounds.inset(by: keyDelegate.kbSizes.key.insets.symbol)
    
    let width = symbolFrame.width
    let height = symbolFrame.height
    
    let translates: [CGPoint] = [
      .init(x: -width * 0.25, y: 0),
      .init(x: 0, y: height * 0.15),
      .init(x: 0, y: -height * 0.15),
      .init(x: width * 0.25, y: 0),
    ]
    
    for (i, symbol) in _symbols.enumerated() {
      let current = _values[i] == _keyValue
      let scale: CGFloat = _keyValue == nil ? 0.65 : current ? 0.85 : 0.65
      let alpha: CGFloat = current ? 1.0 : 0.3
      symbol.frame = symbolFrame
      let translate = translates[i]
      symbol.center = CGPoint(x:symbol.center.x + translate.x, y: symbol.center.y + translate.y)
      symbol.transform = CGAffineTransform(scaleX: scale, y: scale)
      symbol.alpha = alpha
    }
    
    guard
      let elements = _accessibilityElements,
      elements.count == 2
      else {
      return
    }
    let size = bounds.width / CGFloat(elements.count)
    for (i, element) in elements.enumerated() {
      let elementFrame = CGRect(x: size * CGFloat(i), y: 0, width: size, height: bounds.height)
      element.accessibilityFrameInContainerSpace = elementFrame
    }
  }
}


extension KBKeyViewArrows: KBKeyAccessibilityElementDelegate {
  override var accessibilityElements: [Any]? {
    get {
      if let elements = _accessibilityElements {
        return elements
      }
      
      let leftRightElement = KBKeyAccessibilityElement(accessibilityContainer: self)
      leftRightElement.accessibilityLabel = "left right arrows"
      leftRightElement.accessibilityTraits.insert([.keyboardKey, .adjustable])
      leftRightElement.elementDelegate = self
      
      let upDownElement = KBKeyAccessibilityElement(accessibilityContainer: self)
      upDownElement.accessibilityLabel = "up down arrows"
      upDownElement.accessibilityTraits.insert([.keyboardKey, .adjustable])
      upDownElement.elementDelegate = self
      
      let elements = [leftRightElement, upDownElement]
      _accessibilityElements = elements
      self.accessibilityElements = elements
      
      return elements
    }
    set {
      super.accessibilityElements = newValue
      setNeedsLayout()
    }
  }
  
  func elementIncrement(element: KBKeyAccessibilityElement) {
    if element === _accessibilityElements?.first {
      element.accessibilityKBKeyValue = .right
    } else if element == _accessibilityElements?.last {
      element.accessibilityKBKeyValue = .up
    } else {
      return
    }
    _ = element.accessibilityActivate()
  }
  
  func elementDecrement(element: KBKeyAccessibilityElement) {
    if element === _accessibilityElements?.first {
      element.accessibilityKBKeyValue = .left
    } else if element == _accessibilityElements?.last {
      element.accessibilityKBKeyValue = .down
    } else {
      return
    }
    _ = element.accessibilityActivate()
  }
  
  func elementActivate(element: KBKeyAccessibilityElement) -> Bool {
    guard
      let value = element.accessibilityKBKeyValue
    else {
      return false
    }
    
    keyDelegate.keyViewOn(keyView: self, value: value)
    keyDelegate.keyViewTriggered(keyView: self, value: value)
    keyDelegate.keyViewOff(keyView: self, value: value)
    
    return true
  }
  
  
}
