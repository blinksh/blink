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

class KBKeyViewTriangle: KBKeyView {
  private let _aTextLayer = CATextLayer()
  private let _bTextLayer = CATextLayer()
  private let _cTextLayer = CATextLayer()
  
  private var _touchFirstLocation: CGPoint = .zero
  private var _progressV: CGFloat = 0
  private var _progressH: CGFloat = 0
  
  override init(key: KBKey, keyDelegate: KBKeyViewDelegate) {
    super.init(key: key, keyDelegate: keyDelegate)
    
    _aTextLayer.string = key.shape.primaryText
    _bTextLayer.string = key.shape.secondaryText
    _cTextLayer.string = key.shape.tertiaryText
    
    for textLayer in [_cTextLayer, _bTextLayer, _aTextLayer] {
      textLayer.alignmentMode = .center
      textLayer.allowsFontSubpixelQuantization = true
      layer.addSublayer(textLayer)
    }
    
    _setupColorsAndFonts()
    
    layer.rasterizationScale = traitCollection.displayScale
    layer.shouldRasterize = true
    layer.masksToBounds = true
  }
  
  private func _setupColorsAndFonts() {
    let kbSizes = keyDelegate.kbSizes
    let scale = traitCollection.displayScale
    let font = UIFont.systemFont(
      ofSize: min(UIFont.buttonFontSize, kbSizes.key.fonts.text),
      weight: .medium)

    
    for textLayer in [_cTextLayer, _bTextLayer, _aTextLayer] {
      textLayer.contentsScale = scale
      textLayer.font = font
      textLayer.fontSize = font.pointSize
    }
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    _setupColorsAndFonts()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let insets = keyDelegate.kbSizes.key.insets.key
    let parentSize = bounds.inset(by: insets).size
    let aSize = _aTextLayer.preferredFrameSize()
    let bSize = _bTextLayer.preferredFrameSize()
    let cSize = _cTextLayer.preferredFrameSize()
    
    let center = CGPoint(x: parentSize.width * 0.5 + insets.left, y: parentSize.height * 0.5 + insets.top)
    
    _aTextLayer.bounds = CGRect(origin: .zero, size: aSize)
    _bTextLayer.bounds = CGRect(origin: .zero, size: bSize)
    _cTextLayer.bounds = CGRect(origin: .zero, size: cSize)
    
    _aTextLayer.position = center
    _bTextLayer.position = center
    _cTextLayer.position = center
    
    let bScale: CGFloat = 0.5 + 0.5 * _progressV
    let bTy: CGFloat = -12 + 12 * _progressV
    let bTx: CGFloat = -(bounds.width / 3 - bSize.width * 0.5) + (bounds.width / 3 - bSize.width * 0.5) * _progressH
    let bOpacity: CGFloat = 0.3 + 0.7 * _progressV * (1 + _progressH)
    
    _bTextLayer.foregroundColor = UIColor.label.withAlphaComponent(bOpacity).cgColor
    _bTextLayer.transform = CATransform3DConcat(
      CATransform3DMakeScale(bScale, bScale, bScale),
      CATransform3DMakeTranslation(bTx, bTy, 0)
    )
    
    let cScale: CGFloat = 0.5 + 0.5 * _progressV
    let cTy: CGFloat = -12 + 12 * _progressV
    let cTx: CGFloat = bounds.width / 3 - cSize.width * 0.5 + (bounds.width / 3 - cSize.width * 0.5) * _progressH
    let cOpacity: CGFloat = 0.3 + 0.7 * _progressV * (1 - _progressH)
    
    _cTextLayer.foregroundColor = UIColor.label.withAlphaComponent(cOpacity).cgColor
    _cTextLayer.transform = CATransform3DConcat(
      CATransform3DMakeScale(cScale, cScale, cScale),
      CATransform3DMakeTranslation(cTx, cTy, 0)
    )
    
    
    let aScale: CGFloat = 1 - _progressV
    let aTy: CGFloat = 6 + 14 * _progressV
    let aOpacity: CGFloat = 1 - 0.5 * _progressV
    
    _aTextLayer.transform =
      CATransform3DConcat(
        CATransform3DMakeScale(aScale, aScale, aScale),
        CATransform3DMakeTranslation(0, aTy, 0)
      )
    _aTextLayer.foregroundColor = UIColor.label.withAlphaComponent(aOpacity).cgColor
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else {
      return
    }
    
    _touchFirstLocation = touch.location(in: self)
    self.backgroundColor = .tertiarySystemBackground
    super.touchesBegan(touches, with: event)
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    
    guard let touch = touches.first else {
     return
    }
       
    let loc = touch.location(in: self)
    let completeDY = bounds.height - 10
    let completeDX = bounds.width - 20
    
    let dy = min(
      max(loc.y - _touchFirstLocation.y, 0),
      completeDY
    )
    
    var dx = loc.x - _touchFirstLocation.x
    if (dx < 0) {
      dx = max(dx, -completeDX)
    } else {
      dx = min(dx, completeDX)
    }
    
    if dy < 0.3 {
      dx = 0
    }
    
    _progressH = dx / completeDX
    _progressV = dy / completeDY
    
    if _progressV > 0.03 {
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
    case .triangle(let a, let b, let c):
      if _progressV < 0.75 {
        keyDelegate.keyViewTriggered(keyView: self, value: a)
      } else {
        if (_progressH > 0.3) {
          keyDelegate.keyViewTriggered(keyView: self, value: b)
        }
        if (_progressH < 0.3) {
          keyDelegate.keyViewTriggered(keyView: self, value: c)
        }
      }
    default: break
    }
    
    _progressV = 0
    _progressH = 0
    setNeedsLayout()
    
    super.touchesEnded(touches, with: event)
  }
    
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    _progressV = 0
    _progressH = 0
    
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.2)
    setNeedsLayout()
    layoutIfNeeded()
    CATransaction.commit()
    
    super.touchesCancelled(touches, with: event)
  }
}
