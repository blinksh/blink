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

class CommandControl: UIControl {
  
  let backgroundView = UIView()
  let label = UILabel()
  
  init(title: String, target: Any?, action: Selector) {
    super.init(frame: .zero)
    label.text = title
    label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
    label.textColor = label.textColor?.withAlphaComponent(0.8)
    addSubview(backgroundView)
    addSubview(label)
    addTarget(target, action: action, for: .touchUpInside)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override var isHighlighted: Bool {
    didSet {
      backgroundView.alpha = isHighlighted ? 0 : 1
    }
  }
  
  override var backgroundColor: UIColor? {
    get {
      return backgroundView.backgroundColor
    }
    set {
      backgroundView.backgroundColor = newValue
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    backgroundView.frame = bounds
    label.sizeToFit()
    label.center = backgroundView.center
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    isHighlighted = true
    for t in touches {
      for r in t.gestureRecognizers ?? [] {
        r.dropTouches()
      }
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    isHighlighted = false
    guard
      let touch = touches.first,
      bounds.contains(touch.location(in: self))
    else {
      return
    }
    sendActions(for: .touchUpInside)
  }
  
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    isHighlighted = false
  }
}
