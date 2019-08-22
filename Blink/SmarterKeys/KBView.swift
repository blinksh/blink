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

import Foundation
import UIKit

fileprivate extension UIGestureRecognizer {
  func dropTouches() {
    if isEnabled {
      isEnabled = false
      isEnabled = true
    }
  }
}

class KBView: UIView {
  private var _leftSection: KBSection
  private var _middleSection: KBSection
  private var _rightSection: KBSection
  private let _scrollView = UIScrollView()
  private let _scrollViewLeftBorder = UIView()
  private let _scrollViewRightBorder = UIView()
  private let _indicatorLeft = UIView()
  private let _indicatorRight = UIView()
  var safeBarWidth: CGFloat = 0
  var kbDevice: KBDevice = .detect() {
    didSet {
      if oldValue != kbDevice {
        _updateSections()
      }
    }
  }
  var kbSizes: KBSizes = .portrait_iPhone_4
  
  private var _onModifiersSet: Set<KBKeyView> = []
  private var _untrackedModifiersSet: Set<KBKeyView> = []
  
  weak var keyInput: UIKeyInput? = nil
  
  var lang: String = "" {
    didSet {
      if oldValue != lang {
        _updateSections()
      }
    }
  }
  
  override var intrinsicContentSize: CGSize {
    CGSize(width: UIView.noIntrinsicMetric, height: kbSizes.kb.height)
  }

  var traits: KBTraits = .initial {
    didSet {
      if traits != oldValue {
        setNeedsLayout()
      }
    }
  }
  
  override init(frame: CGRect) {
    let layout = kbDevice.layoutFor(lang: lang)
    
    _leftSection = KBSection(keys:layout.left)
    _middleSection = KBSection(keys:layout.middle)
    _rightSection = KBSection(keys:layout.right)
    
    
    super.init(frame: frame)
    _scrollView.alwaysBounceVertical = false
    _scrollView.alwaysBounceHorizontal = false
    _scrollView.isDirectionalLockEnabled = true
    _scrollView.showsHorizontalScrollIndicator = false
    _scrollView.showsVerticalScrollIndicator = false
    _scrollView.delaysContentTouches = false
    _scrollView.contentInsetAdjustmentBehavior = .never
    _scrollView.delegate = self
    
    addSubview(_scrollView)
    addSubview(_scrollViewLeftBorder)
    addSubview(_scrollViewRightBorder)
    
//    _scrollViewLeftBorder.backgroundColor = UIColor.gray.withAlphaComponent(0.45)
//    _scrollViewRightBorder.backgroundColor = UIColor.gray.withAlphaComponent(0.45)
    
    if traitCollection.userInterfaceStyle == .light {
      _scrollViewLeftBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.15)
      _scrollViewRightBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.15)
    } else {
      _scrollViewLeftBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
      _scrollViewRightBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
    }
//    _scrollViewLeftBorder.backgroundColor = UIColor.tertiarySystemBackground.withAlphaComponent(0.5)
//    _scrollViewRightBorder.backgroundColor = UIColor.tertiarySystemBackground.withAlphaComponent(0.5)
    
//    addSubview(_indicatorLeft)
//    addSubview(_indicatorRight)
    
    _indicatorLeft.backgroundColor = UIColor.blue.withAlphaComponent(0.45)
    _indicatorRight.backgroundColor = UIColor.orange.withAlphaComponent(0.45)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  func _updateSections() {
    _leftSection.views.forEach { $0.removeFromSuperview() }
    _middleSection.views.forEach { $0.removeFromSuperview() }
    _rightSection.views.forEach { $0.removeFromSuperview() }
    
    let layout = kbDevice.layoutFor(lang: lang)
    
    _leftSection   = KBSection(keys:layout.left)
    _middleSection = KBSection(keys:layout.middle)
    _rightSection  = KBSection(keys:layout.right)
    
    traits.hasSuggestions = ["zh-Hans", "zh-Hant", "ja-JP"].contains(lang)
    setNeedsLayout()
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    traits.toggle(traitCollection.userInterfaceStyle == .light, on: .light, off: .dark)
    
    if traitCollection.userInterfaceStyle == .light {
      _scrollViewLeftBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.15)
      _scrollViewRightBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.15)
    } else {
      _scrollViewLeftBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
      _scrollViewRightBorder.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let strictSpace = !traits.isHKBAttached && traits.hasSuggestions
    self.kbSizes = kbDevice.sizesFor(portrait: traits.isPortrait)
    
    let top: CGFloat = 0;

    let height       = kbSizes.kb.height
    let iconWidth    = kbSizes.key.widths.icon
    let keyWidth     = kbSizes.key.widths.key
    let wideKeyWidth = kbSizes.key.widths.wide
    
    let spacer       = kbSizes.kb.spacer
    let mainPadding  = kbSizes.kb.padding
    
    var middleLeft  = mainPadding
    var middleRight = frame.width - mainPadding
    
    func viewWidth(_ shape: KBKeyShape) -> CGFloat {
      switch shape {
      case .icon:    return iconWidth
      case .wideKey: return wideKeyWidth
      case .arrows:  return wideKeyWidth
      default:       return keyWidth
      }
    }
    
    let leftViews   = _leftSection.apply(traits: traits, for: self, keyDelegate: self)
    let middleViews = _middleSection.apply(traits: traits, for: _scrollView, keyDelegate: self)
    let rightViews  = _rightSection.apply(traits: traits, for: self, keyDelegate: self)

    var x = middleLeft
    for b in leftViews {
      let width = viewWidth(b.key.shape)
      b.frame = CGRect(x: x, y: top, width: width, height: height)
      b.isHidden = strictSpace && b.frame.maxX - mainPadding >= safeBarWidth
      x += width + spacer
      middleLeft = x
    }
    
    x = middleRight
    for b in rightViews.reversed() {
      let width = viewWidth(b.key.shape)
      x -= width
      middleRight = x
      b.frame = CGRect(x: x, y: top, width: width, height: height)
      x -= spacer
    }
    
    middleRight -= spacer
    
    x = 0
    for b in middleViews {
      let width = viewWidth(b.key.shape)
      b.frame = CGRect(x: x, y: top, width: width, height: height)
      b.isHidden = strictSpace && b.frame.minX + mainPadding <= bounds.width - safeBarWidth
      x += width + spacer
    }
    
    _scrollView.frame = CGRect(x: middleLeft, y: top, width: middleRight - middleLeft, height: height)
    
    let spaceLeft = _scrollView.frame.width - x
    if spaceLeft > 0 {
      // We can tune layout
      let flexibleCount = middleViews.filter({ $0.key.isFlexible } ).count
      if flexibleCount > 0 {
        var flexibleWidth = CGFloat(flexibleCount) * keyWidth
        flexibleWidth = (flexibleWidth + spaceLeft) / CGFloat(flexibleCount)
        x = 0
        for b in middleViews {
          let width = b.key.isFlexible ? flexibleWidth : viewWidth(b.key.shape)
          b.frame = CGRect(x: x, y: top, width: width, height: height)
          x += width + spacer
        }
      }
    }
    
    _scrollView.contentSize = CGSize(width: x, height: height)
    _scrollView.isHidden = strictSpace
    
//    var borderFrame = CGRect(x: middleLeft - 1, y: 7, width: 1, height: height - 15)
    var borderFrame = CGRect(x: middleLeft - 1, y: 9, width: 1, height: height - 19)
    _scrollViewLeftBorder.frame = borderFrame
    borderFrame.origin.x = middleRight - 1
    _scrollViewRightBorder.frame = borderFrame
    
    _updateScrollViewBorders()
    
//    _indicatorLeft.frame = CGRect(x: 0, y: 0, width: safeBarWidth, height:55)
//    _indicatorRight.frame = CGRect(x: frame.width - safeBarWidth, y: 0 , width: safeBarWidth, height:55)
  }
  
  func _updateScrollViewBorders() {
    let size = _scrollView.contentSize
    let width = _scrollView.frame.width
    
    if size.width <= width {
      _scrollViewLeftBorder.isHidden = true
      _scrollViewRightBorder.isHidden = true
      return
    }
    
    let offset = _scrollView.contentOffset
    _scrollViewLeftBorder.isHidden = offset.x <= 0
    _scrollViewRightBorder.isHidden = size.width - offset.x <= width
  }
  
  func turnOffUntracked() {
    for keyView in _untrackedModifiersSet {
      if !keyView.isTracking {
        keyView.turnOff()
      }
    }
    for keyView in _onModifiersSet {
      if keyView.isTracking {
        _untrackedModifiersSet.insert(keyView)
      }
    }
    _untrackedModifiersSet = _onModifiersSet
  }
}

extension KBView: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    _updateScrollViewBorders()
  }
}

extension KBView: KBKeyViewDelegate {
  func keyViewAskedToCancecScroll(keyView: KBKeyView) {
    _scrollView.panGestureRecognizer.dropTouches()
  }
  
  func keyViewOn(keyView: KBKeyView, value: KBKeyValue) {
    _toggleModifier(kbKeyValue: value, value: true)
    if value.isModifier {
      _onModifiersSet.insert(keyView)
    }
  }
  
  func keyViewOff(keyView: KBKeyView, value: KBKeyValue) {
    _toggleModifier(kbKeyValue: value, value: false)
    _onModifiersSet.remove(keyView)
  }
  
  func keyViewCanGoOff(keyView: KBKeyView, value: KBKeyValue) -> Bool {
    if !value.isModifier {
      return true
    }
    
    if _untrackedModifiersSet.contains(keyView) {
      _untrackedModifiersSet.remove(keyView)
      return true
    }
    
    _untrackedModifiersSet.insert(keyView)
    return false
  }
    
  private func _toggleModifier(kbKeyValue: KBKeyValue, value: Bool) {
    switch kbKeyValue {
    case .cmd:
      traits.toggle(value, on: .cmdOn , off: .cmdOff)
    case .alt:
      traits.toggle(value, on: .altOn , off: .altOff)
    case .esc:
      traits.toggle(value, on: .escOn , off: .escOff)
    case .ctrl:
      traits.toggle(value, on: .ctrlOn , off: .ctrlOff)
    default: break
    }
  }
  
  func keyViewTriggered(keyView: KBKeyView, value: KBKeyValue) {
    if value.isModifier {
      return
    }
    
    switch value {
    case .text, .esc, .left, .right, .up, .down, .tab:
      keyInput?.insertText(value.text)
    default: break
    }
    
    turnOffUntracked()
  }
  
  func keyViewCancelled(keyView: KBKeyView) {
    _untrackedModifiersSet.remove(keyView)
    _onModifiersSet.remove(keyView)
  }
  
  func keyViewTouchesBegin(keyView: KBKeyView, touches: Set<UITouch>) {
    guard
      let touch = touches.first
    else {
      return
    }
    
    for recognizer in touch.gestureRecognizers ?? [] {
      guard
        recognizer !== _scrollView.panGestureRecognizer
      else {
        continue
      }

      recognizer.dropTouches()
    }
  }
}
