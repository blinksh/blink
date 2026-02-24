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

class KBAccessoryView: UIInputView {
  private let _kbView: KBView
  private var _glassEffectView: UIVisualEffectView?
  
  init(kbView: KBView) {
    _kbView = kbView
    super.init(frame: .zero, inputViewStyle: .keyboard)
    translatesAutoresizingMaskIntoConstraints = false
    allowsSelfSizing = true

    self.frame.size.height = _kbView.intrinsicContentSize.height
    
    if #available(iOS 26.0, *) {
      _setupGlassMaterialEffect()
    } else {
      // Earlier iOS versions: Add kbView directly to UIInputView
      addSubview(_kbView)
    }

    _kbView.translatesAutoresizingMaskIntoConstraints = false
    let margin: CGFloat = 0.0
    
    if #available(iOS 26.0, *) {
      guard let glassEffectView = _glassEffectView else { return }
      NSLayoutConstraint.activate([
        _kbView.leadingAnchor.constraint(equalTo: glassEffectView.contentView.leadingAnchor, constant: margin),
        _kbView.trailingAnchor.constraint(equalTo: glassEffectView.contentView.trailingAnchor, constant: -margin),
        //_kbView.topAnchor.constraint(equalTo: glassEffectView.contentView.topAnchor),
        _kbView.bottomAnchor.constraint(equalTo: glassEffectView.contentView.bottomAnchor)
      ])
    } else {
      NSLayoutConstraint.activate([
        _kbView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
        _kbView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
        //_kbView.topAnchor.constraint(equalTo: topAnchor),
        _kbView.bottomAnchor.constraint(equalTo: bottomAnchor)
      ])
    }
  }
  
  required init?(coder: NSCoder) {
    return nil
  }
  
  @available(iOS 26.0, *)
  private func _createGlassEffect() -> UIGlassEffect {
    let glassEffect = UIGlassEffect()
    glassEffect.isInteractive = true
    
    glassEffect.tintColor = .systemFill
    
    return glassEffect
  }
  
//  Commented because I think we can go with a general system setting for now.
//  Update effect based on keyboard settings.
//  @available(iOS 26.0, *)
//  private func _setupKeyboardStyle() {
//    guard let glassEffectView = _glassEffectView else { return }
//    
//    let glassEffect = _createGlassEffect()
//    
//
//    UIView.animate {
//      glassEffectView.effect = glassEffect
//    }
//  }
//  
//  private func _setupNotificationObserver() {
//    NotificationCenter.default.addObserver(
//      self,
//      selector: #selector(_keyboardStyleDidChange),
//      name: NSNotification.Name(rawValue: BKAppearanceChanged),
//      object: nil
//    )
//  }
//  
//  @objc private func _keyboardStyleDidChange() {
//    if #available(iOS 26.0, *) {
//      _setupKeyboardStyle()
//    }
//  }
  
  @available(iOS 26.0, *)
  private func _setupGlassMaterialEffect() {
    let glassEffectView = UIVisualEffectView()
    glassEffectView.translatesAutoresizingMaskIntoConstraints = false
    _glassEffectView = glassEffectView
    
    let glassEffect = _createGlassEffect()

    glassEffectView.contentView.addSubview(_kbView)
    
    addSubview(glassEffectView)
    
    NSLayoutConstraint.activate([
      glassEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      glassEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      glassEffectView.topAnchor.constraint(equalTo: topAnchor),
      glassEffectView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
    
    UIView.animate {
      glassEffectView.cornerConfiguration = .capsule(maximumRadius: 16)
      glassEffectView.effect = glassEffect
    }
  }
  
  override var intrinsicContentSize: CGSize {
    return CGSize(width: -1, height: _kbView.intrinsicContentSize.height)
  }
}

extension KBAccessoryView: UIInputViewAudioFeedback {
  var enableInputClicksWhenVisible: Bool {
    return !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigMuteSmartKeysPlaySound)
  }
}
