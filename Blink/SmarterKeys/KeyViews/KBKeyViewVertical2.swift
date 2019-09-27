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

class KBKeyViewVertical2: KBKeyView {
  private let _primaryTextLayer = CATextLayer()
  private let _secondaryTextLayer = CATextLayer()
  
  private var _touchFirstLocation: CGPoint = .zero
  private var _progress: CGFloat = 0
  
  private var _accessibilityElements:[KBKeyAccessibilityElement]? = nil
  
  override init(key: KBKey, keyDelegate: KBKeyViewDelegate) {
    super.init(key: key, keyDelegate: keyDelegate)
    
    _primaryTextLayer.string = key.shape.primaryText
    _secondaryTextLayer.string = key.shape.secondaryText
    
    for textLayer in [_secondaryTextLayer, _primaryTextLayer] {
      textLayer.alignmentMode = .center
      textLayer.allowsFontSubpixelQuantization = true
      layer.addSublayer(textLayer)
    }
    
    _setupFonts()
    
    layer.rasterizationScale = traitCollection.displayScale
    layer.shouldRasterize = true
    layer.masksToBounds = true
  }
  
  private func _setupFonts() {
    let scale = traitCollection.displayScale
    let font = UIFont.systemFont(
      ofSize: min(UIFont.buttonFontSize, keyDelegate.kbSizes.key.fonts.text),
      weight: .medium)
    
    for textLayer in [_secondaryTextLayer, _primaryTextLayer] {
      textLayer.font = font
      textLayer.fontSize = font.pointSize
      textLayer.contentsScale = scale
    }
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    _setupFonts()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let insets = keyDelegate.kbSizes.key.insets.key
    let parentSize = bounds.inset(by: insets).size
    let majorSize = _primaryTextLayer.preferredFrameSize()
    let minorSize = _secondaryTextLayer.preferredFrameSize()
    
    let center = CGPoint(
      x: parentSize.width * 0.5 + insets.left,
      y: parentSize.height * 0.5 + insets.top
    )
    
    _primaryTextLayer.bounds = CGRect(origin: .zero, size: majorSize)
    _secondaryTextLayer.bounds = CGRect(origin: .zero, size: minorSize)
    _primaryTextLayer.position = center
    _secondaryTextLayer.position = center
    
    let minorScale: CGFloat = 0.55 + 0.45 * _progress
    let sz = parentSize.height * 0.3
    let minorTy: CGFloat = -sz + sz * _progress
    let minorOpacity: CGFloat = 0.3 + 0.7 * _progress
    
    _secondaryTextLayer.foregroundColor = UIColor.label.withAlphaComponent(minorOpacity).cgColor
    _secondaryTextLayer.transform = CATransform3DConcat(
      CATransform3DMakeScale(minorScale, minorScale, minorScale),
      CATransform3DMakeTranslation(0, minorTy, 0)
    )
    
    let majorScale: CGFloat = 1 - _progress
    let majorTy: CGFloat = insets.top + 1 + 14 * _progress
    let majorOpacity: CGFloat = 1 - 0.5 * _progress
    
    _primaryTextLayer.transform =
      CATransform3DConcat(
        CATransform3DMakeScale(majorScale, majorScale, majorScale),
        CATransform3DMakeTranslation(0, majorTy, 0)
      )
    _primaryTextLayer.foregroundColor = UIColor.label.withAlphaComponent(majorOpacity).cgColor
    
    if let elements = _accessibilityElements?.first {
      elements.accessibilityFrameInContainerSpace = bounds
    }
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else {
      return
    }
    
    _touchFirstLocation = touch.location(in: self)
//    self.backgroundColor = .tertiarySystemBackground
    super.touchesBegan(touches, with: event)
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    
    guard let touch = touches.first else {
     return
    }
       
    let loc = touch.location(in: self)
    let completeDY = bounds.height - 10
    
    let dy = min(
      max(loc.y - _touchFirstLocation.y, 0),
      completeDY
    )

    _progress = dy / completeDY
    
    if _progress > 0.15 {
      keyDelegate.keyViewAskedToCancelScroll(keyView: self)
    }

    CATransaction.begin()
    CATransaction.setDisableActions(true)
    setNeedsLayout()
    layoutIfNeeded()
    CATransaction.commit()
  }
    
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    switch key.shape {
    case .vertical2(let a, let b):
      keyDelegate.keyViewTriggered(keyView: self, value: _progress < 0.75 ? a : b)
    default: break
    }
    _progress = 0
    
    super.touchesEnded(touches, with: event)
  }
    
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    _progress = 0
    
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.2)
    setNeedsLayout()
    layoutIfNeeded()
    CATransaction.commit()
    
    super.touchesCancelled(touches, with: event)
  }
}



extension KBKeyViewVertical2: KBKeyAccessibilityElementDelegate {
  override var accessibilityElements: [Any]? {
    get {
      if let elements = _accessibilityElements {
        return elements
      }
      
      let keyElement = KBKeyAccessibilityElement(accessibilityContainer: self)
      
      keyElement.accessibilityTraits.insert([.keyboardKey, .adjustable])
      keyElement.accessibilityKBKeyValue = key.shape.primaryValue
      keyElement.elementDelegate = self
      
      let elements = [keyElement]
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
      _progress = 0
      element.accessibilityKBKeyValue = key.shape.primaryValue
      setNeedsLayout()
    }
  }
  
  func elementDecrement(element: KBKeyAccessibilityElement) {
    if element === _accessibilityElements?.first {
      _progress = 1
      element.accessibilityKBKeyValue = key.shape.secondaryValue
      setNeedsLayout()
    }
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
