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
    let style = BKDefaults.keyboardStyle()
    switch style {
    case .dark: return .dark
    case .light: return .light
    default:
      return traitCollection.userInterfaceStyle == .light ? .light : .dark
    }
  }
  
  private var _controls: [CommandControl] = []
  
  override init(frame: CGRect) {
    
    _shadowEffectView = UIVisualEffectView(effect: .none)
    _shadowEffectView.backgroundColor = UIColor.separator
    let effect = UIBlurEffect(style: .systemMaterial)
    _visualEffect2 = UIVisualEffectView(effect: effect)

    super.init(frame: frame)
    alpha = 0
    _controls = [
      CommandControl(title: "Fit", target: self, action: #selector(_changeLayout)),
      CommandControl(title: "Close", target: self, action: #selector(_closeShell)),
      CommandControl(title: "Create", target: self, action: #selector(_newShell)),
    ]
    
    let vibrancy = UIVibrancyEffect(blurEffect: effect, style: .separator)
    
    addSubview(_shadowEffectView)
    addSubview(_contentView)
    _contentView.addSubview(_visualEffect2)
    
    let v = UIVisualEffectView(effect: vibrancy)
    _visualEffect2.contentView.addSubview(v)
    
    let sep = UIView(frame: CGRect(x: 67.5, y: 0, width: 1, height: 37))
    sep.backgroundColor = UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.1)
    sep.backgroundColor = .red
    
    v.contentView.addSubview(sep)
    
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
  
  @objc func _changeLayout() {
    
  }
  
  @objc func _newShell() {
    delegate?.spaceController()?.newShellAction()
  }
  
  @objc func _closeShell() {
    delegate?.spaceController()?.closeShellAction()
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
      let hud = gestureOverlayView.subviews.filter({$0 != self}).first
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
       .assign(to: alphaPath, on: self)
    alpha = hud.alpha
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    _style()
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard let supView = superview
//    let hud = supView.subviews.filter({$0 != self}).first
    else {
      return
    }
    
    
    var x: CGFloat = 0
    for vc in _controls {
      vc.label.sizeToFit()
      vc.frame = CGRect(x: x, y: 0, width: 87.5, height: 37)
      x = vc.frame.maxX
      x += 0.5
    }
    
    let size = CGSize(
      width: x,
      height: 37
    )
    
    let origin = CGPoint(
      x: 0,
      y: supView.bounds.height - LayoutManager.mainWindowKBBottomInset() - size.height - 24
    )
    
    self.frame = CGRect(origin: origin, size: size)
    _shadowEffectView.frame = self.bounds
    _contentView.frame = self.bounds
    _visualEffect2.frame = self.bounds
    
    if let width = delegate?.spaceController()?.view?.bounds.size.width {
      self.center = CGPoint(x: width * 0.5, y: self.center.y)
    }
  }
}
