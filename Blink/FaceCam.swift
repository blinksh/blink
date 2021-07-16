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


import Foundation
import UIKit

fileprivate extension UIView {
  func setRecursiveBg(color: UIColor) {
    layer.removeAllAnimations()
    if self.backgroundColor != nil {
      self.backgroundColor = color
    }
    
    for v in subviews {
      v.setRecursiveBg(color: color)
    }
  }
}

fileprivate class PhotoOverlayController: UIImagePickerController {
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    view?.setRecursiveBg(color: UIColor.clear)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    sourceType = .camera
    cameraDevice = .front
    allowsEditing = false
    showsCameraControls = false
    view?.setRecursiveBg(color: UIColor.blinkTint)
  }
}

fileprivate final class FaceCamView: UIView, UIGestureRecognizerDelegate {
  private let _ctrl = PhotoOverlayController()
  fileprivate var controller: UIViewController { _ctrl }
  private let _tapRecognizer = UITapGestureRecognizer()
  private let _doubleTapRecognizer = UITapGestureRecognizer()
  private let _panRecognizer = UIPanGestureRecognizer()
  private let _pinchRecognizer = UIPinchGestureRecognizer()
  private let _rotationRecognizer = UIRotationGestureRecognizer()
  private let _longPressRecognizer = UILongPressGestureRecognizer()
  private let _placeholder = UIImageView(image: UIImage(systemName: "eyes"))
  private var _flipped = false
  var safeFrame: CGRect = .zero {
    didSet {
      _positionBackInSafeFrameIfNeeded()
    }
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    
    addSubview(_placeholder)
    _placeholder.bounds.size = CGSize(width: 36, height: 36)
    _placeholder.tintColor = .white
    
    addSubview(_ctrl.view)
    clipsToBounds = true
   
    backgroundColor = UIColor.blinkTint
    layer.masksToBounds = true
    layer.borderColor = UIColor.blinkTint.cgColor
    layer.borderWidth = 1.5
    
    _doubleTapRecognizer.addTarget(self, action: #selector(_doubleTap(recognizer:)))
    _tapRecognizer.addTarget(self, action: #selector(_tap(recognizer:)))
    _panRecognizer.addTarget(self, action: #selector(_pan(recognizer:)))
    _pinchRecognizer.addTarget(self, action: #selector(_pinch(recognizer:)))
    _rotationRecognizer.addTarget(self, action: #selector(_rotation(recognizer:)))
    _longPressRecognizer.addTarget(self, action: #selector(_longPress(recognizer:)))
    
    _doubleTapRecognizer.numberOfTapsRequired = 2
    
    _doubleTapRecognizer.delegate = self
    _tapRecognizer.delegate = self
    _panRecognizer.delegate = self
    _pinchRecognizer.delegate = self
    _rotationRecognizer.delegate = self
    _longPressRecognizer.delegate = self
    
    _tapRecognizer.shouldRequireFailure(of: _doubleTapRecognizer)
    
    addGestureRecognizer(_doubleTapRecognizer)
    addGestureRecognizer(_tapRecognizer)
    addGestureRecognizer(_panRecognizer)
    addGestureRecognizer(_pinchRecognizer)
    addGestureRecognizer(_rotationRecognizer)
    addGestureRecognizer(_longPressRecognizer)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  private func _positionBackInSafeFrameIfNeeded() {
    var center = self.center
    if safeFrame.contains(center) {
      return
    }

    let third = bounds.width / 3.0
    
    if center.x < safeFrame.minX {
      center.x = safeFrame.minX + third
    }
    if center.y < safeFrame.minY {
      center.y = safeFrame.minY + third
    }
    
    if center.x > safeFrame.maxX {
      center.x = safeFrame.maxX - third
    }
    if center.y > safeFrame.maxY {
      center.y = safeFrame.maxY - third
    }

    UIView.animate(
      withDuration: 1,
      delay: 0,
      usingSpringWithDamping: 0.9,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction],
      animations: {
        self.center = center
      },
      completion: nil
    )
  }
  
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    if super.point(inside: point, with: event) {
      let r = bounds.width * 0.5
      return point.offsetted(by: -r).magnitude <= r
    }
    
    return false
  }
    
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = bounds.width * 0.5
    
    _placeholder.center = CGPoint(x: bounds.width * 0.5, y: bounds.height * 0.5)
   
    #if targetEnvironment(macCatalyst)
    if _flipped {
      _ctrl.view.transform = CGAffineTransform(scaleX: -1, y: 1);
    } else {
      _ctrl.view.transform = CGAffineTransform(scaleX: 1, y: 1);
    }
    let width = bounds.width * 16.0/9.0
    _ctrl.view.frame = CGRect(x: (bounds.width - width) * 0.5, y: 0, width: width, height: bounds.height)
    #else
    
    let isPortait = (window?.windowScene?.interfaceOrientation ?? .landscapeLeft).isPortrait
    
    if traitCollection.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
      // try to center on face on ipads
      var offset = bounds.width / 3.0
      if isPortait {
        offset = 0
      }
      if _flipped {
        _ctrl.view.transform = CGAffineTransform(scaleX: -1, y: 1);
        _placeholder.transform = CGAffineTransform(scaleX: -1, y: 1);
        _ctrl.view.frame = CGRect(x: 0, y: 0, width: bounds.width + offset, height: bounds.height)
      } else {
        _ctrl.view.transform = CGAffineTransform(scaleX: 1, y: 1);
        _placeholder.transform = CGAffineTransform(scaleX: 1, y: 1);
        _ctrl.view.frame = CGRect(x: -offset, y: 0, width: bounds.width + offset, height: bounds.height)
        
      }
      
      
    } else  {      
      if _flipped {
        _ctrl.view.transform = CGAffineTransform(scaleX: -1, y: 1);
        _placeholder.transform = CGAffineTransform(scaleX: -1, y: 1);
      } else {
        _placeholder.transform = CGAffineTransform(scaleX: 1, y: 1);
        _ctrl.view.transform = CGAffineTransform(scaleX: 1, y: 1);
      }

      let height = bounds.width * 4.0/3.0
      _ctrl.view.frame = CGRect(x: 0, y: (bounds.height - height) * 0.5, width: bounds.width, height: height)
    }
    #endif
    
    
  }
  
  @objc func _doubleTap(recognizer: UITapGestureRecognizer) {
    switch recognizer.state {
    case .recognized:
      _flipped.toggle()
      setNeedsLayout()
    case _: break
    }
  }
  
  @objc func _tap(recognizer: UITapGestureRecognizer) {
    print(recognizer)
  }
  
  @objc func _pan(recognizer: UIPanGestureRecognizer) {
    switch recognizer.state {
    case .changed:
      let p = recognizer.translation(in: superview)
      center.offset(by: p)
      recognizer.setTranslation(.zero, in: superview)
    case .ended:
      let velocity = recognizer.velocity(in: superview)
      let targetPoint = _targetPoint(for: center, velocity: velocity)
      
      let distanceVector = CGPoint(x: center.x - targetPoint.x, y: center.y - targetPoint.y)
      let totalDistance = distanceVector.magnitude
      let magVelocity = velocity.magnitude
      
      let animationDuration: TimeInterval = 1
      let springVelocity: CGFloat = magVelocity / totalDistance / CGFloat(animationDuration)
      
      UIView.animate(
        withDuration: animationDuration,
        delay: 0,
        usingSpringWithDamping: 2.0,
        initialSpringVelocity: springVelocity,
        options: [.allowUserInteraction],
        animations: { self.center = targetPoint},
        completion: { _ in
          self._positionBackInSafeFrameIfNeeded()
        }
      )
    case _: break
    }
  }
  
  private func _targetPoint(for location: CGPoint, velocity: CGPoint) -> CGPoint {
    let m: CGFloat = 0.15
    
    return CGPoint(x: location.x + m * velocity.x, y: location.y + m * velocity.y)
  }
  
  
  @objc func _pinch(recognizer: UIPinchGestureRecognizer) {
    switch recognizer.state {
    case .changed:
      let scale = recognizer.scale
      let size = bounds.size
      self.bounds.size = CGSize(width: size.width * scale, height: size.height * scale)
      recognizer.scale = 1.0
    case .ended:
      let size = bounds.size
      if size.width > safeFrame.width * 1.5 || size.height > safeFrame.height * 1.5 {
        let length = min(safeFrame.width * 1.5, safeFrame.height * 1.5)
        UIView.animate(
          withDuration: 0.3,
          delay: 0,
          usingSpringWithDamping: 2.0,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction],
          animations: {
            self.bounds.size = CGSize(width: length, height: length)
          },
          completion: nil
        )
      } else if size.width < 80 || size.height < 80 {
        UIView.animate(
          withDuration: 0.3,
          delay: 0,
          usingSpringWithDamping: 2.0,
          initialSpringVelocity: 0,
          options: [.allowUserInteraction],
          animations: {
            self.bounds.size = CGSize(width: 80, height: 80)
          },
          completion: nil
        )
      }
    case _: break
    }
  }
  
  @objc func _rotation(recognizer: UIRotationGestureRecognizer) {
    switch recognizer.state {
    case .changed:
      self.transform = self.transform.rotated(by: recognizer.rotation)
      recognizer.rotation = 0
    case .ended:
      UIView.animate(
        withDuration: 0.3,
        delay: 0,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0,
        options: [.allowUserInteraction],
        animations: { self.transform = .identity },
        completion: nil
      )
    case _: break
    }
  }
  
  @objc func _longPress(recognizer: UILongPressGestureRecognizer) {
    print(recognizer)
  }
  
  @objc func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    true
  }
  
  
}


fileprivate extension CGPoint {
  var magnitude: CGFloat {
    sqrt(pow(x, 2) + pow(y, 2))
  }
  
  mutating func offset(by: CGPoint) {
    x += by.x
    y += by.y
  }
  
  func offsetted(by: CGFloat) -> CGPoint {
    var result = self
    result.x += by
    result.y += by
    return result
  }
}

class FaceCamManager {
  private let _view: FaceCamView
  private var _spaceCtrl: SpaceController? = nil
  
  init() {
    _view = FaceCamView(frame: CGRect(origin: .zero, size: CGSize(width: 80, height: 80)))
  }
  
  private static var __shared: FaceCamManager? = nil
  
  static func attach(spaceCtrl: SpaceController) {
    if __shared == nil {
      __shared = .init()
    } else {
      __shared?._view.removeFromSuperview()
      __shared?._view.controller.removeFromParent()
    }
    
    guard let shared = __shared
    else {
      return
    }
    
    shared._spaceCtrl = spaceCtrl
    
    let safeFrame = spaceCtrl.safeFrame
    
    let view = shared._view
    
    
    view.center = CGPoint(
      x: safeFrame.minX + safeFrame.width * 0.5,
      y: safeFrame.minY + safeFrame.height * 0.5
    )
    
    view.bounds.size = .zero
    
    spaceCtrl.view.addSubview(view)
    spaceCtrl.addChild(view.controller)
    
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      usingSpringWithDamping: 0.7,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction],
      animations: { view.bounds.size = CGSize(width: 140, height: 140) },
      completion: nil
    )
  }
  
  static func update(in spaceCtrl: SpaceController) {
    guard let shared = __shared,
          let ctrl = shared._spaceCtrl,
          ctrl == spaceCtrl
    else {
      return
    }
    
    shared._view.safeFrame = spaceCtrl.safeFrame
    spaceCtrl.view.bringSubviewToFront(shared._view)
    shared._view.setNeedsLayout()
  }
  
  static func turnOff() {
    guard let shared = __shared
    else {
      return
    }
    
    let view = shared._view
    
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      usingSpringWithDamping: 0.7,
      initialSpringVelocity: 0,
      options: [.allowUserInteraction],
      animations: { view.alpha = 0 },
      completion: { _ in
        view.alpha = 1
        view.removeFromSuperview()
        view.controller.removeFromParent()
        
        __shared = nil
      }
    )
    
    
  }
}
