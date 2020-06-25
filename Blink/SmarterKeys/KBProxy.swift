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

class KBProxy: UIView {
  private unowned var _kbView: KBView
  
  init(kbView: KBView) {
    _kbView = kbView
    super.init(frame: .zero)
  }
  
  required init?(coder: NSCoder) {
    return nil
  }
  
  private var _barButtonView: UIView? {
    // BarButtonItemView
    // AssistantButtonBarGroupView
    // View
    // AssistantButtonBarView -- defines safe width
    superview?.superview?.superview?.superview
  }
  
  private var _placeView: UIView? {
    // SystemInputAssistantView
    _barButtonView?.superview
  }
  
  public override func didMoveToSuperview() {
    super.didMoveToSuperview()

    guard let placeView = _placeView else {
      _kbView.isHidden = true//removeFromSuperview()
      return
    }

    placeView.addSubview(_kbView)
    
    setNeedsLayout()
  }
  
  public override func layoutSubviews() {
    super.layoutSubviews()
    
    guard
      let placeView = _placeView,
      let barButtonView = _barButtonView,
      let _ = window
    else {
      _kbView.isHidden = true
      return
    }
    
    _kbView.isHidden = false
    
    placeView.bringSubviewToFront(_kbView)
    // Detecting dismiss kb icon
    var rightBottom = CGPoint(x: bounds.width, y: bounds.height)
    rightBottom = convert(rightBottom, to: placeView)
    
    var bKBframe = placeView.bounds
    
    var hardwareKBAttached = false
    if bKBframe.size.width - rightBottom.x > 58 /* better check? */ {
      bKBframe.size.width -= (bKBframe.size.width - rightBottom.x) - 6
      hardwareKBAttached = true
    }
//    var traits = _kbView.traits
    
//    traits.isHKBAttached = hardwareKBAttached
//    traits.isPortrait = win.bounds.width < win.bounds.height
//    debugPrint("KBProxy isPortatit", traits.isPortrait)
    
//    _kbView.traits = traits
    _kbView.safeBarWidth = barButtonView.frame.width
    _kbView.frame = bKBframe
  }
}
