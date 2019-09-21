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

protocol WKWebViewGesturesInteractionDelegate: NSObjectProtocol {
  
}

class UIScrollViewWithoutHitTest: UIScrollView {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    return nil
  }
}

@objc class WKWebViewGesturesInteraction: NSObject, UIInteraction {
  var view: UIView? = nil
  private var _wkWebView: WKWebView? = nil
  private var _scrollView = UIScrollViewWithoutHitTest()
  private var _jsScrollerPath: String
  private var _panGestureRecognizer = UIPanGestureRecognizer()
  private var _tapGestureRecognizer = UITapGestureRecognizer()
  
  @objc init(jsScrollerPath: String) {
    _jsScrollerPath = jsScrollerPath
    super.init()
    _scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _scrollView.alwaysBounceVertical = true
    _scrollView.alwaysBounceHorizontal = false
    _scrollView.isDirectionalLockEnabled = true
    _scrollView.keyboardDismissMode = .interactive
    _scrollView.delaysContentTouches = false
    _scrollView.delegate = self
    
    _panGestureRecognizer.minimumNumberOfTouches = 2
    _panGestureRecognizer.maximumNumberOfTouches = 2
    _panGestureRecognizer.addTarget(self, action: #selector(_onPan(_:)))
    _panGestureRecognizer.delegate = self
    
    _tapGestureRecognizer.numberOfTapsRequired = 1
    _tapGestureRecognizer.numberOfTouchesRequired = 1
    _tapGestureRecognizer.addTarget(self, action: #selector(_onTap(_:)))
    _tapGestureRecognizer.delegate = self
  }
  
  func willMove(to view: UIView?) {
    if let view = view {
      _scrollView.frame = view.bounds
    } else {
      _wkWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "wkScroller")
    }
  }
  
  func didMove(to view: UIView?) {
    if let webView = view as? WKWebView {
      webView.scrollView.delaysContentTouches = false;
      webView.scrollView.canCancelContentTouches = false;
      webView.scrollView.isScrollEnabled = false;
      webView.scrollView.panGestureRecognizer.isEnabled = false;
      
      
      webView.addSubview(_scrollView)
      webView.addGestureRecognizer(_scrollView.panGestureRecognizer)
      webView.configuration.userContentController.add(self, name: "wkScroller")
      webView.addGestureRecognizer(_panGestureRecognizer)
      webView.addGestureRecognizer(_tapGestureRecognizer)

      
      _wkWebView = webView
    } else {
      _scrollView.removeFromSuperview()
    }
  }
  
  private var _reportedY:CGFloat = 0
  
  @objc func _onPan(_ recognizer: UIPanGestureRecognizer) {
    let point = recognizer.location(in: recognizer.view)
    
    switch recognizer.state {
    case .began:
      _scrollView.panGestureRecognizer.dropTouches()
      _scrollView.isScrollEnabled = false
      _scrollView.showsVerticalScrollIndicator = false
      _reportedY = point.y
    case .changed:
      let dY = point.y - _reportedY;
      if abs(dY) < 5 {
        return
      }
      _reportedY = point.y
      let deltaY = dY > 0 ? -1 : 1
      let deltaX = 0 // hterm supports only deltaY for now
      _wkWebView?.evaluateJavaScript("term_reportWheelEvent(\"wheel\", \(point.x), \(point.y), \(deltaX), \(deltaY));", completionHandler: nil)
    case .ended: fallthrough
    case .cancelled:
      _scrollView.isScrollEnabled = true
      _scrollView.showsVerticalScrollIndicator = true
    default: break
    }
  }
  
  @objc func _onTap(_ recognizer: UITapGestureRecognizer) {
    let point = recognizer.location(in: recognizer.view)
    switch recognizer.state {
    case .recognized:
      _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mousedown\", \(point.x), \(point.y));", completionHandler: nil)
      _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mouseup\", \(point.x), \(point.y));", completionHandler: nil)
    default: break
    }
  }
  
}

extension WKWebViewGesturesInteraction: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}

extension WKWebViewGesturesInteraction: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let point = scrollView.contentOffset
    _wkWebView?.evaluateJavaScript("\(_jsScrollerPath).reportScroll(\(point.x), \(point.y));", completionHandler: nil)
  }
}

extension WKWebViewGesturesInteraction: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard
      let msg = message.body as? [String: Any],
      let op = msg["op"] as? String
    else {
      return
    }
    
    switch op {
    case "resize":
      _scrollView.contentSize = NSCoder.cgSize(for: msg["contentSize"] as? String ?? "")
    case "scrollTo":
      let animated = msg["animated"] as? Bool == true
      let x: CGFloat = msg["x"] as? CGFloat ?? 0
      let y: CGFloat = msg["y"] as? CGFloat ?? 0
      _scrollView.setContentOffset(CGPoint(x: x, y: y), animated: animated)
    default: break
    }
  }
}
