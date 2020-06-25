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
import Combine

@objc protocol CommandsHUDViewDelegate: NSObjectProtocol {
  func currentTerm() -> TermController?
  func spaceController() -> SpaceController?
}

class CommandsHUGView: UIView {
  var _alphaCancable: AnyCancellable? = nil
  var _layerCancable: AnyCancellable? = nil
  weak var _window: UIWindow? = nil
  weak var delegate: CommandsHUDViewDelegate? = nil
  var _shadowEffectView: UIVisualEffectView
  var _visualEffect2: UIVisualEffectView
  var _contentView = UIView()
  
  struct Colors {
    var bg: UIColor
    var button: UIColor
    var shadow: UIColor
    
    static var dark: Self {
      Colors(
        bg: UIColor(red: 0.33, green: 0.33, blue: 0.35, alpha: 0.33),
        button: UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha:1),
        shadow: UIColor.clear
      )
    }
    
    static var light: Self {
      Colors(
        bg: UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.33),
        button: UIColor.white,
        shadow: UIColor.black
      )
    }
  }
  
  var colors: Colors {
    switch BKDefaults.keyboardStyle() {
    case .dark: return .dark
    case .light: return .light
    default:
      return traitCollection.userInterfaceStyle == .light ? .light : .dark
    }
  }
  
  private var _lockControl = CommandControl(title: "Lock", symbol: "lock.slash", accessibilityLabel: "Lock layout")
  private var _layoutControl = CommandControl(title: "Fit")
  
  private var _controls: [CommandControl] = []
  
  override init(frame: CGRect) {
    
    _shadowEffectView = UIVisualEffectView(effect: .none)
    _shadowEffectView.backgroundColor = UIColor.separator
    let effect = UIBlurEffect(style: .systemMaterial)
    _visualEffect2 = UIVisualEffectView(effect: effect)
    
    super.init(frame: frame)
    alpha = 0
    _controls = [
      _lockControl.with(target: self, action: #selector(_changeLayoutLock)),
      CommandControl(title: "Close", symbol: "xmark.rectangle", accessibilityLabel: "Close shell")
        .with(target: self, action: #selector(_closeShell)),
      CreateShellCommandControl()
        .with(target: self, action: #selector(_newShell)),
    ]
    
    if DeviceInfo.shared().hasCorners {
      _layoutControl.canBeIcon = false
      _controls.insert(_layoutControl.with(target: self, action: #selector(_changeLayout)), at: 0)
    }
    
    let vibrancy = UIVibrancyEffect(blurEffect: effect, style: .separator)
    
    addSubview(_shadowEffectView)
    addSubview(_contentView)
    _contentView.addSubview(_visualEffect2)
    
    let v = UIVisualEffectView(effect: vibrancy)
    _visualEffect2.contentView.addSubview(v)

    _style();
  }
  
  func _style() {
    let cols = colors
    _contentView.backgroundColor = cols.bg
    
    for vc in _controls {
      vc.backgroundColor = cols.button
      _contentView.addSubview(vc)
    }
    
    _shadowEffectView.layer.shadowRadius = 15
    _shadowEffectView.layer.shadowOpacity = 0.5
    _shadowEffectView.layer.shadowOffset = .zero
    _shadowEffectView.layer.shadowColor = cols.shadow.cgColor
    _shadowEffectView.layer.cornerRadius = 18.5
    
    _shadowEffectView.contentView.clipsToBounds = true
    
    _contentView.clipsToBounds = true
    _contentView.layer.cornerRadius = 18.5
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc func _changeLayoutLock() {
    guard let params = delegate?.currentTerm()?.sessionParams
    else {
      return
    }
    if params.layoutLocked {
      delegate?.spaceController()?.currentTerm()?.unlockLayout()
    } else {
      delegate?.spaceController()?.currentTerm()?.lockLayout()
    }
    updateHUD()
  }
  
  @objc func _changeLayout() {
    guard let term = delegate?.currentTerm()
    else {
      return
    }
    
    let params = term.sessionParams
    params.layoutMode = _nextLayoutMode(mode: BKLayoutMode(rawValue: params.layoutMode)).rawValue
    if (params.layoutLocked) {
      term.unlockLayout()
    }
    term.view?.setNeedsLayout()
    updateHUD()
  }
  
  @objc func _newShell() {
    delegate?.spaceController()?.newShellAction()
  }
  
  @objc func _closeShell() {
    delegate?.spaceController()?.closeShellAction()
  }
  
  func updateHUD() {
    guard let params = delegate?.currentTerm()?.sessionParams
    else {
      return
    }
    
    if params.layoutLocked {
      _lockControl.setTitle(title: "Unlock", accessibilityLabel: "Unlock layout")
      _lockControl.setSymbol(symbol: "lock.slash")
    } else {
      _lockControl.setTitle(title: "Lock", accessibilityLabel: "Lock layout")
      _lockControl.setSymbol(symbol: "lock")
    }
    
    let modeName = LayoutManager.layoutMode(toString: BKLayoutMode(rawValue: params.layoutMode) ?? .default);
    
    _layoutControl.setTitle(title: modeName, accessibilityLabel: modeName)
  }
  
  func _nextLayoutMode(mode: BKLayoutMode?) -> BKLayoutMode {
    switch (mode) {
    case nil: fallthrough
    case .default:
      return .safeFit;
    case .safeFit:
      return .fill;
    case .fill:
      return .cover;
    case .cover:
      return .safeFit;
    @unknown default:
      return .safeFit
    }
  }
  
  func attachToWindow(inputWindow: UIWindow?) {
    // UIEditingOverlayGestureView
    guard let inputWin = inputWindow,
      inputWindow != _window,
      let gestureOverlayView = inputWin.rootViewController?.view.subviews.last
    else {
      return
    }
    _window = inputWin;
    
    gestureOverlayView.addSubview(self)
    
    let sublayers: ReferenceWritableKeyPath<CALayer, [CALayer]?> = \CALayer.sublayers
    _layerCancable = gestureOverlayView.layer.publisher(for: sublayers).sink(receiveValue: { (layers) in
      let hud = gestureOverlayView.subviews.filter { NSStringFromClass($0.classForCoder).hasPrefix("UI") }.first
      self._bindAlpha(hudView: hud)
      self.superview?.bringSubviewToFront(self)
    })
  }
  
  
  private func _bindAlpha(hudView: UIView?) {
    guard let hud = hudView else {
      alpha = 0
      return
    }
    let alphaPath: ReferenceWritableKeyPath<UIView, CGFloat> = \.alpha
    
     _alphaCancable = hud
       .publisher(for: alphaPath)
       .print()
       .assign(to: alphaPath, on: self)
    
    alpha = hud.alpha
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    _style()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard let supView = superview,
      let spaceWidth = delegate?.spaceController()?.view?.bounds.size.width
    else {
      return
    }
    
    
    var x: CGFloat = 0
    var width: CGFloat = 87.5
    var displayAsIcons = false
    if traitCollection.userInterfaceIdiom != .pad || spaceWidth < 400 {
//      width = 60
      width = 70
      displayAsIcons = true
    }
    for vc in _controls {
      vc.displayAsIcon = displayAsIcons
      vc.label.sizeToFit()
      vc.frame = CGRect(x: x, y: 0, width: width, height: 37)
      x = vc.frame.maxX
      x += 0.5
    }
    
    let size = CGSize(
      width: x,
      height: 37
    )
    
    let origin = CGPoint(
      x: 0,
      y: supView.bounds.height - LayoutManager.mainWindowKBBottomInset() - size.height - 31
    )
    
    let f = CGRect(origin: origin, size: size)
    if f == self.frame {
      return
    }
    self.frame = f
    _shadowEffectView.frame = self.bounds
    _contentView.frame = self.bounds
    _visualEffect2.frame = self.bounds
    
    self.center = CGPoint(x: spaceWidth * 0.5, y: self.center.y)
  }
}
