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
import WebKit

extension WKWebView {
  
  @objc(WKWebViewScroller)
  class Scroller: UIScrollView, UIScrollViewDelegate {
    @objc weak var wkWebView: WKWebView? = nil
    
    let _jsScrollerPath: String
    
    fileprivate init(frame: CGRect, jsScrollerPath: String) {
      _jsScrollerPath = jsScrollerPath
      super.init(frame: frame)
      
      alwaysBounceVertical = true
      alwaysBounceHorizontal = false
      isDirectionalLockEnabled = true
      keyboardDismissMode = .interactive
      delaysContentTouches = false
      
      self.delegate = self
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
      wkWebView?.evaluateJavaScript("\(_jsScrollerPath).reportScroll(\(contentOffset.x), \(contentOffset.y));", completionHandler: nil)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let view = super.hitTest(point, with: event)
      if view === self {
        return nil
      }
      return view
    }
    
    override func didMoveToSuperview() {
      if (self.superview != nil) {
        self.superview?.addGestureRecognizer(panGestureRecognizer)
      }
      
    }

  }
  
  class MessageHandler: NSObject, WKScriptMessageHandler {

    private var _scroller: Scroller
    
    init(scroller: Scroller) {
      _scroller = scroller
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
      guard
        let msg = message.body as? [String: Any],
        let op = msg["op"] as? String
      else {
        return
      }
      
      switch op {
      case "resize":
        _scroller.contentSize = NSCoder.cgSize(for: msg["contentSize"] as? String ?? "")
      case "scrollTo":
        let animated = msg["animated"] as? Bool == true
        let x: CGFloat = msg["x"] as? CGFloat ?? 0
        let y: CGFloat = msg["y"] as? CGFloat ?? 0
        _scroller.setContentOffset(CGPoint(x: x, y: y), animated: animated)
      default: break
      }
    }
  }
  
  @objc func createScroller(jsScrollerPath: String) -> Scroller {
    let scroller = Scroller(frame: bounds, jsScrollerPath: jsScrollerPath)
    scroller.wkWebView = self
    scroller.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    let handler = MessageHandler(scroller: scroller)
    self.configuration.userContentController.add(handler, name: "wkScroller")
    addSubview(scroller)
    return scroller
  }

}
