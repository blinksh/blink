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

class UIScrollViewWithoutHitTest: UIScrollView {
  var isInfinit = false
  
  var reportedScroll: CGPoint? = nil
  
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let scrollBarWidth: CGFloat = 24
    if
      let result = super.hitTest(point, with: event),
      result !== self || point.x > self.bounds.size.width - scrollBarWidth {
      return result
    }
    return nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard isInfinit
    else {
      return
    }
    
    let requiredSize = CGSize(width: bounds.width /* * 10 */, height: bounds.height * 10)
    if contentSize != requiredSize {
      contentSize = requiredSize
    }
    
    recenterIfNeeded(force: false)
  }
  
  func recenterIfNeeded(force: Bool = false) {
    var currentOffset = contentOffset
    
    let centerOffsetY = (contentSize.height - bounds.size.height) * 0.5;
    
    let distanceFromCenterY = abs(currentOffset.y - centerOffsetY);
    
    if force || distanceFromCenterY > (contentSize.height / 4.0) {
      currentOffset = CGPoint(x: currentOffset.x, y: centerOffsetY)
      reportedScroll = currentOffset
      contentOffset = currentOffset
    }
  }
}

/**
 Gestures:
 
 - 1 finger tap - reports click
 - 2 finger pan - reports mouse wheel
 - 3 pinch - zoom
 */

@objc class WKWebViewGesturesInteraction: NSObject, UIInteraction {
  var view: UIView? = nil
  private weak var _wkWebView: WKWebView? = nil
  private let _scrollView = UIScrollViewWithoutHitTest()
  private let _termScrollView = UIScrollViewWithoutHitTest()
  private let _jsScrollerPath: String
  private let _1fTapRecognizer = UITapGestureRecognizer()
  private let _2fTapRecognizer = UITapGestureRecognizer()
  private let _pinchRecognizer = UIPinchGestureRecognizer()
  private let _3fTapRecognizer = UITapGestureRecognizer()
  private let _longPressRecognizer = UILongPressGestureRecognizer()
  private let _hoverRecognizer = UIHoverGestureRecognizer()
  private var _characterSize: CGSize? = nil
  private var _scrollPoint: CGPoint? = nil
  private var _scrollPointTrackpad: CGPoint? = nil
  
  @objc var focused: Bool = false;
  @objc var hasSelection: Bool = false {
    didSet {
      _pinchRecognizer.isEnabled = !hasSelection
      _1fTapRecognizer.isEnabled = !hasSelection
      
      if hasSelection {
        _scrollView.panGestureRecognizer.dropTouches()
        _termScrollView.panGestureRecognizer.dropTouches()
        view?.dropSuperViewTouches()
      }
    }
  }
  
  @objc var indicatorStyle: UIScrollView.IndicatorStyle {
    get { _scrollView.indicatorStyle }
    set { _scrollView.indicatorStyle = newValue }
  }
  
  var allRecognizers:[UIGestureRecognizer] {
    let recognizers = [
      _1fTapRecognizer,
      _2fTapRecognizer,
      _3fTapRecognizer,
      _pinchRecognizer,
      _longPressRecognizer,
      _scrollView.panGestureRecognizer,
      _termScrollView.panGestureRecognizer,
      _hoverRecognizer
    ]
    return recognizers
  }
  
  func willMove(to view: UIView?) {
    if let webView = view as? WKWebView {
      webView.scrollView.delaysContentTouches = false;
      webView.scrollView.canCancelContentTouches = false;
      webView.scrollView.isScrollEnabled = false;
      webView.scrollView.panGestureRecognizer.isEnabled = false;
      
      
      _scrollView.frame = webView.bounds
      webView.addSubview(_scrollView)
      webView.addSubview(_termScrollView)
      webView.configuration.userContentController.add(self, name: "wkScroller")
      
      for r in allRecognizers {
        webView.addGestureRecognizer(r)
      }
      
      _wkWebView = webView
    } else {
      _scrollView.removeFromSuperview()
      _termScrollView.removeFromSuperview()
      _wkWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "wkScroller")
      
      for r in allRecognizers {
        _wkWebView?.addGestureRecognizer(r)
      }
      
      _wkWebView = nil
    }
  }
  
  func didMove(to view: UIView?) {
    self.view = view
  }
  
  @objc init(jsScrollerPath: String) {
    _jsScrollerPath = jsScrollerPath
    super.init()
    _scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _scrollView.alwaysBounceVertical = false
    _scrollView.alwaysBounceHorizontal = false
    _scrollView.isDirectionalLockEnabled = true
    // iPad have dismiss button on keyboard
    if UIDevice.current.userInterfaceIdiom != .pad {
      _scrollView.keyboardDismissMode = .interactive
    }
    _scrollView.delaysContentTouches = false
    _scrollView.delegate = self
    
    
    _termScrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    _termScrollView.alwaysBounceVertical = false
    _termScrollView.alwaysBounceHorizontal = false
    _termScrollView.isDirectionalLockEnabled = true
    _termScrollView.keyboardDismissMode = _scrollView.keyboardDismissMode
    _termScrollView.delaysContentTouches = false
    _termScrollView.delegate = self
    _termScrollView.showsVerticalScrollIndicator = false
    _termScrollView.showsHorizontalScrollIndicator = false
    _termScrollView.isInfinit = true

    _3fTapRecognizer.numberOfTapsRequired = 1
    _3fTapRecognizer.numberOfTouchesRequired = 3
    _3fTapRecognizer.delegate = self
    
    _longPressRecognizer.delegate = self
    
    _1fTapRecognizer.numberOfTapsRequired = 1
    _1fTapRecognizer.numberOfTouchesRequired = 1
    _1fTapRecognizer.delegate = self
    _1fTapRecognizer.addTarget(self, action: #selector(_on1fTap(_:)))
    _1fTapRecognizer.require(toFail: _3fTapRecognizer)
    _1fTapRecognizer.require(toFail: _longPressRecognizer)
    
    _2fTapRecognizer.numberOfTapsRequired = 1
    _2fTapRecognizer.numberOfTouchesRequired = 2
    _2fTapRecognizer.delegate = self
    _2fTapRecognizer.addTarget(self, action: #selector(_on2fTap(_:)))
    _2fTapRecognizer.require(toFail: _pinchRecognizer)
    
    _pinchRecognizer.delegate = self
    _pinchRecognizer.addTarget(self, action: #selector(_onPinch(_:)))
    
    
    _hoverRecognizer.addTarget(self, action: #selector(_onHover(_:)))
  }
  
  private var _reportedY:CGFloat = 0
  
  @objc func _on1fTap(_ recognizer: UITapGestureRecognizer) {
    let point = recognizer.location(in: recognizer.view)
    switch recognizer.state {
    case .recognized:
      
      if focused {
        _wkWebView?.evaluateJavaScript("term_reportMouseClick(\(point.x), \(point.y), 1, \(BKDefaults.isKeyCastsOn() ? "true" : "false"));", completionHandler: nil)
      }
      if let target = _wkWebView?.target(forAction: #selector(focusOnShellAction), withSender: self) as? UIResponder {
        target.perform(#selector(focusOnShellAction), with: self)
      }
    default: break
    }
    
    
  }
  
  @objc func _on2fTap(_ recognizer: UITapGestureRecognizer) {
    switch recognizer.state {
    case .recognized:
      if let target = _wkWebView?.target(forAction: #selector(newShellAction), withSender: self) as? UIResponder {
        target.perform(#selector(newShellAction), with: self)
      }
    default: break
    }
  }
  
  @objc func _on1fPan(_ recognizer: UIPanGestureRecognizer) {
    let point = recognizer.location(in: recognizer.view)
    switch recognizer.state {
    case .began:
      _scrollView.panGestureRecognizer.dropTouches()
      recognizer.view?.superview?.dropSuperViewTouches()
      _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mousedown\", \(point.x), \(point.y), 1);", completionHandler: nil)
    case .changed:
      _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mousemove\", \(point.x), \(point.y), 1);", completionHandler: nil)
    case .ended: fallthrough
    case .cancelled:
      _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mouseup\", \(point.x), \(point.y), 1);", completionHandler: nil)
    default: break
    }
  }
  
  @objc func _onPinch(_ recognizer: UIPinchGestureRecognizer) {
    let dScale = 1.0 - recognizer.scale;
    if abs(dScale) > 0.06 {
      recognizer.view?.superview?.dropSuperViewTouches()
      _scrollView.panGestureRecognizer.dropTouches()
      _termScrollView.panGestureRecognizer.dropTouches()
      _2fTapRecognizer.dropTouches()
       
      if let target = _wkWebView?.target(forAction: #selector(scaleWithPich(_:)), withSender: recognizer) as? UIResponder {
        target.perform(#selector(scaleWithPich(_:)), with: recognizer)
      }
    }
  }
  
  @objc func _onHover(_ recognizer: UIHoverGestureRecognizer) {
    switch recognizer.state {
    case .began, .changed:
      _scrollPointTrackpad = recognizer.location(in: view)
    default: break
    }
  }
  
  @objc func scaleWithPich(_ pinch: UIPinchGestureRecognizer) {
    
  }
  
  @objc func newShellAction() {
    
  }
  
  @objc func focusOnShellAction() {
    
  }
  
}

extension WKWebViewGesturesInteraction: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}

extension WKWebViewGesturesInteraction: UIScrollViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let offset = scrollView.contentOffset
    
    if scrollView === _scrollView {
      _wkWebView?.evaluateJavaScript("\(_jsScrollerPath).reportScroll(\(offset.x), \(offset.y));", completionHandler: nil)
      return
    }
    
    
    
    if scrollView === _termScrollView {
      guard var reportedScroll = _termScrollView.reportedScroll
      else {
        return
      }
      
      let offsetY = max(offset.y, 0)
      
      let defaultFontSize = 20
      if _characterSize == .none || _characterSize == .zero {
        var size = BKDefaults.selectedFontSize().intValue
        if size == 0 {
          size = defaultFontSize
        }
        _characterSize = CGSize(width: size, height: size)
      }

      var charHeight: CGFloat = _characterSize?.height ?? CGFloat(defaultFontSize)
      if (charHeight <= 0) {
        charHeight = CGFloat(defaultFontSize)
      }
      
      let deltaY = offsetY - reportedScroll.y
      if abs(deltaY) < charHeight {
        return
      }
      let dY = CGFloat(Int(deltaY) / Int(charHeight)) * charHeight
      reportedScroll.y = reportedScroll.y + dY
      _termScrollView.reportedScroll = reportedScroll
      
      let point = _scrollPoint ?? _scrollPointTrackpad ?? CGPoint(x: scrollView.bounds.size.width * 0.5, y: scrollView.bounds.size.height * 0.5)
      
      _wkWebView?.evaluateJavaScript("term_reportWheelEvent(\"wheel\", \(point.x), \(point.y), \(0), \(dY));", completionHandler: nil)
    }
  }
  
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    if scrollView == _termScrollView {
      if _termScrollView.panGestureRecognizer.numberOfTouches > 0 {
        _scrollPoint = _termScrollView.panGestureRecognizer.location(in: view)
      } else {
        _scrollPoint = nil
      }
      _termScrollView.reportedScroll = _termScrollView.contentOffset
    }
  }
  
  func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    if scrollView == _termScrollView {
      _termScrollView.recenterIfNeeded(force: true)
    }
  }
  
  func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if scrollView == _termScrollView {
      if !decelerate {
        _termScrollView.recenterIfNeeded(force: true)
      }
    }
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
      let contentSize = NSCoder.cgSize(for: msg["contentSize"] as? String ?? "")
      let characterSize = NSCoder.cgSize(for: msg["characterSize"] as? String ?? "")
      let isPrimary = msg["isPrimary"] as? Bool ?? true
      
      _characterSize = characterSize
      _scrollView.contentSize = contentSize
      let offset = CGPoint(x: 0, y: max(contentSize.height - _scrollView.bounds.height, 0));
      _scrollView.contentOffset = offset
      
      _scrollView.panGestureRecognizer.isEnabled = isPrimary
      _termScrollView.panGestureRecognizer.isEnabled = !isPrimary
      
      
    case "scrollTo":
      let animated = msg["animated"] as? Bool == true
      let isPrimary = msg["isPrimary"] as? Bool ?? true
      
      let x: CGFloat = msg["x"] as? CGFloat ?? 0
      let y: CGFloat = msg["y"] as? CGFloat ?? 0
      let offset = CGPoint(x: x, y: y)
      
      _scrollView.panGestureRecognizer.isEnabled = isPrimary
      _termScrollView.panGestureRecognizer.isEnabled = !isPrimary
      
      if (offset == _scrollView.contentOffset) {
        return
      }
      // TODO: debounce?
      _scrollView.setContentOffset(offset, animated: animated)
      
      
    default: break
    }
  }
}
