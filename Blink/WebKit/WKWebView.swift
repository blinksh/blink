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

fileprivate struct TermCell: Equatable {
  let col: Int
  let row: Int
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
  private let _handlerName: String
  private let _1fTapRecognizer = UITapGestureRecognizer()
  private let _2ndClickRecognizer = UITapGestureRecognizer()
  private let _1fPanRecognizer = UIPanGestureRecognizer()
  private let _2fTapRecognizer = UITapGestureRecognizer()
  private let _pinchRecognizer = UIPinchGestureRecognizer()
  private let _3fTapRecognizer = UITapGestureRecognizer()
  private let _longPressRecognizer = UILongPressGestureRecognizer()
  private let _hoverRecognizer = UIHoverGestureRecognizer()
  private var _pointerInteraction: Any? = nil
  private var _characterSize: CGSize? = nil
  private var _scrollPoint: CGPoint? = nil
  private var _scrollPointTrackpad: CGPoint? = nil
  private var _mouseDragMode: Bool = false
  private var _mouseDragStartPoint: CGPoint? = nil
  private var _lastDragPoint: CGPoint? = nil
  private var _lastDragCell: TermCell? = nil
  private var _mouseHoverMode: Bool = false
  private var _lastHoverCell: TermCell? = nil
  private var _isPrimaryScreen: Bool = true

  @objc var focused: Bool = false {
    didSet {
      guard !focused else {
        return
      }
      _endMouseDrag(at: nil)
    }
  }
  @objc var hasSelection: Bool = false {
    didSet {
      _pinchRecognizer.isEnabled = !hasSelection
      _1fTapRecognizer.isEnabled = !hasSelection

      if hasSelection {
        _scrollView.panGestureRecognizer.dropTouches()
        _termScrollView.panGestureRecognizer.dropTouches()
        _1fPanRecognizer.dropTouches()
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
      _2ndClickRecognizer,
      _1fPanRecognizer,
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
      webView.configuration.userContentController.add(self, name: _handlerName)
      
      for r in allRecognizers {
        webView.addGestureRecognizer(r)
      }

      let pointerInteraction = UIPointerInteraction(delegate: self)
      webView.addInteraction(pointerInteraction)
      _pointerInteraction = pointerInteraction

      _wkWebView = webView
    } else {
      _endMouseDrag(at: nil)

      _scrollView.removeFromSuperview()
      _termScrollView.removeFromSuperview()
      _wkWebView?.configuration.userContentController.removeScriptMessageHandler(forName: _handlerName)

      for r in allRecognizers {
        _wkWebView?.removeGestureRecognizer(r)
      }

      if let interaction = _pointerInteraction as? UIPointerInteraction {
        _wkWebView?.removeInteraction(interaction)
        _pointerInteraction = nil
      }

      _wkWebView = nil
    }
  }
  
  func didMove(to view: UIView?) {
    self.view = view
  }
  
  @objc convenience init(jsScrollerPath: String) {
    self.init(jsScrollerPath: jsScrollerPath, handlerName: "wkScroller")
  }
  
  @objc init(jsScrollerPath: String, handlerName: String) {
    _jsScrollerPath = jsScrollerPath
    _handlerName = handlerName
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
    _longPressRecognizer.addTarget(self, action: #selector(_onLongPress(_:)))

    _1fTapRecognizer.numberOfTapsRequired = 1
    _1fTapRecognizer.numberOfTouchesRequired = 1
    _1fTapRecognizer.delegate = self
    _1fTapRecognizer.addTarget(self, action: #selector(_on1fTap(_:)))
    _1fTapRecognizer.require(toFail: _3fTapRecognizer)
    _1fTapRecognizer.require(toFail: _longPressRecognizer)
    _1fTapRecognizer.require(toFail: _1fPanRecognizer)

    _2ndClickRecognizer.numberOfTapsRequired = 1
    _2ndClickRecognizer.numberOfTouchesRequired = 1
    _2ndClickRecognizer.buttonMaskRequired = .secondary
    _2ndClickRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
    _2ndClickRecognizer.delegate = self
    _2ndClickRecognizer.addTarget(self, action: #selector(_onSecondaryClick(_:)))

    _1fPanRecognizer.minimumNumberOfTouches = 1
    _1fPanRecognizer.maximumNumberOfTouches = 1
    _1fPanRecognizer.delegate = self
    _1fPanRecognizer.addTarget(self, action: #selector(_on1fPan(_:)))
    _1fPanRecognizer.require(toFail: _longPressRecognizer)
    _1fPanRecognizer.cancelsTouchesInView = true // Consume all touches when active
    _1fPanRecognizer.isEnabled = false // Disabled by default, only enabled during drag mode

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

  // A hold arms the drag and the press follows on lift, once WebKit has placed
  // the caret. Cmd+click does both at once.
  private func _armMouseDrag() {
    _mouseDragMode = true
    _mouseDragStartPoint = nil
    _lastDragPoint = nil
    _lastDragCell = nil
    _1fPanRecognizer.isEnabled = true
    _applyPanEnablement()
  }

  private func _pressMouseDrag(at point: CGPoint) {
    _mouseDragStartPoint = point
    _lastDragPoint = point
    _lastDragCell = _cell(for: point)
    _reportMouse("mousedown", at: point, buttons: 1)
  }

  private func _moveMouseDrag(to point: CGPoint) {
    guard _mouseDragMode, _mouseDragStartPoint != nil else {
      return
    }
    _lastDragPoint = point

    let cell = _cell(for: point)
    if let cell = cell, cell == _lastDragCell {
      return
    }
    _lastDragCell = cell
    _reportMouse("mousemove", at: point, buttons: 1)
  }

  private func _endMouseDrag(at point: CGPoint?) {
    guard _mouseDragMode else {
      return
    }

    if let anchor = _mouseDragStartPoint {
      _reportMouse("mouseup", at: point ?? _lastDragPoint ?? anchor, buttons: 0)
    }

    _mouseDragMode = false
    _mouseDragStartPoint = nil
    _lastDragPoint = nil
    _lastDragCell = nil
    _lastHoverCell = nil
    _1fPanRecognizer.isEnabled = false
    _applyPanEnablement()
  }

  private func _hoverMouse(to point: CGPoint) {
    guard _mouseHoverMode, !_mouseDragMode else {
      return
    }

    let cell = _cell(for: point)
    if let cell = cell, cell == _lastHoverCell {
      return
    }
    _lastHoverCell = cell
    _reportMouse("mousemove", at: point, buttons: 0)
  }

  private func _applyPanEnablement() {
    _scrollView.panGestureRecognizer.isEnabled = !_mouseDragMode && _isPrimaryScreen
    _termScrollView.panGestureRecognizer.isEnabled = !_mouseDragMode && !_isPrimaryScreen
  }

  private func _reportMouse(_ name: String, at point: CGPoint, buttons: Int, button: Int = 0) {
    let p = _clampToView(point)
    _wkWebView?.evaluateJavaScript(
      "term_reportMouseEvent(\"\(name)\", \(p.x), \(p.y), \(buttons), \(button));",
      completionHandler: nil
    )
  }

  // A recognized gesture keeps reporting locations off-view, and hterm does not
  // clamp the cell it derives from them.
  private func _clampToView(_ point: CGPoint) -> CGPoint {
    guard let bounds = _wkWebView?.bounds, bounds.width > 0, bounds.height > 0 else {
      return point
    }
    return CGPoint(
      x: min(max(point.x, 0), bounds.width - 1),
      y: min(max(point.y, 0), bounds.height - 1)
    )
  }

  private func _cell(for point: CGPoint) -> TermCell? {
    guard let size = _characterSize, size.width > 0, size.height > 0 else {
      return nil
    }
    return TermCell(col: Int(point.x / size.width), row: Int(point.y / size.height))
  }

  // WebKit's caret sits on the character the hold landed on, which is closer to
  // what was meant than the raw touch point.
  private func _caretPoint(fallback point: CGPoint) -> CGPoint {
    guard
      let contentView = _wkWebView?.scrollView.subviews.first(where: { view in
        String(describing: type(of: view)).contains("WKContent")
      }),
      let textInput = contentView as? UITextInput,
      let selectedRange = textInput.selectedTextRange,
      let rect = _wkWebView?.convert(textInput.caretRect(for: selectedRange.start), from: contentView)
    else {
      return point
    }
    return CGPoint(x: rect.midX, y: rect.midY)
  }

  @objc func _on1fTap(_ recognizer: UITapGestureRecognizer) {
    let point = recognizer.location(in: recognizer.view)
    switch recognizer.state {
    case .recognized:
      let wasInDragMode = _mouseDragMode
      let cmdPressed = recognizer.modifierFlags.contains(.command)

      if focused {
        if cmdPressed {
          if _mouseDragMode {
            _endMouseDrag(at: point)
          } else {
            _armMouseDrag()
            _pressMouseDrag(at: point)
          }
        } else {
          _wkWebView?.evaluateJavaScript("term_reportMouseClick(\(point.x), \(point.y), 1, \(BLKDefaults.isKeyCastsOn() ? "true" : "false"));", completionHandler: nil)
        }
      }

      if !cmdPressed && !wasInDragMode {
        if let target = _wkWebView?.target(forAction: #selector(focusOnShellAction), withSender: self) as? UIResponder {
          target.perform(#selector(focusOnShellAction), with: self)
        }
      }
    default: break
    }
  }
  
  @objc func _onSecondaryClick(_ recognizer: UITapGestureRecognizer) {
    guard
      recognizer.state == .recognized,
      focused,
      recognizer.modifierFlags.contains(.command)
    else {
      // Without cmd the click is left to the terminal menu.
      return
    }

    let point = recognizer.location(in: recognizer.view)
    _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mousedown\", \(point.x), \(point.y), 2, 2);", completionHandler: nil)
    _wkWebView?.evaluateJavaScript("term_reportMouseEvent(\"mouseup\", \(point.x), \(point.y), 0, 2);", completionHandler: nil)
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

  @objc func _onLongPress(_ recognizer: UILongPressGestureRecognizer) {
    let point = recognizer.location(in: recognizer.view)

    switch recognizer.state {
    case .began:
      guard focused, !_mouseDragMode else {
        return
      }
      _armMouseDrag()

    case .ended:
      guard _mouseDragMode, _mouseDragStartPoint == nil else {
        return
      }
      _pressMouseDrag(at: _caretPoint(fallback: point))

    case .cancelled, .failed:
      if _mouseDragStartPoint == nil {
        _endMouseDrag(at: nil)
      }

    default:
      break
    }
  }

  @objc func _on1fPan(_ recognizer: UIPanGestureRecognizer) {
    guard _mouseDragMode else {
      return
    }

    let point = recognizer.location(in: recognizer.view)

    switch recognizer.state {
    case .began:
      recognizer.view?.superview?.dropSuperViewTouches()

    case .changed:
      _moveMouseDrag(to: point)

    case .ended, .cancelled, .failed:
      _endMouseDrag(at: point)

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
    guard focused else {
      return
    }

    let point = recognizer.location(in: recognizer.view)

    switch recognizer.state {
    case .began, .changed:
      _scrollPointTrackpad = point
      _moveMouseDrag(to: point)
      _hoverMouse(to: point)
    default: break
    }
  }

  @objc func scaleWithPich(_ pinch: UIPinchGestureRecognizer) {

  }

  @objc func newShellAction() {

  }

  @objc func focusOnShellAction() {

  }

  // Clicks read cmd off their own event, so only the release matters here: it is
  // what ends a latched drag.
  @objc func setCmdKeyPressed(_ pressed: Bool) {
    if !pressed {
      _endMouseDrag(at: nil)
    }
  }

}

extension WKWebViewGesturesInteraction: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    // When in drag mode, the 1f pan should be exclusive - don't allow other gestures
    if _mouseDragMode && gestureRecognizer === _1fPanRecognizer {
      return false
    }
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
        var size = BLKDefaults.selectedFontSize().intValue
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
      var dY = CGFloat(Int(deltaY) / Int(charHeight)) * charHeight
      reportedScroll.y = reportedScroll.y + dY
      _termScrollView.reportedScroll = reportedScroll
      
      let point = _scrollPoint ?? _scrollPointTrackpad ?? CGPoint(x: scrollView.bounds.size.width * 0.5, y: scrollView.bounds.size.height * 0.5)
     
      if BLKDefaults.doInvertVerticalScroll() {
        dY *= -1.0;
      }
      
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
      let viewSize = NSCoder.cgSize(for: msg["viewSize"] as? String ?? "")
      let isPrimary = msg["isPrimary"] as? Bool ?? true

      _characterSize = characterSize

      // The scroller mirrors the JS scrollPort, so its viewport height must
      // come from the same resize the DOM observed.
      if viewSize.height > 0 {
        _scrollView.autoresizingMask = [.flexibleWidth]
        var frame = _scrollView.frame
        frame.size.height = viewSize.height
        _scrollView.frame = frame
      }

      _scrollView.contentSize = contentSize
      let offset = CGPoint(x: 0, y: max(contentSize.height - _scrollView.bounds.height, 0));
      _scrollView.contentOffset = offset

      _isPrimaryScreen = isPrimary
      _applyPanEnablement()


    case "scrollTo":
      let animated = msg["animated"] as? Bool == true
      let isPrimary = msg["isPrimary"] as? Bool ?? true
      
      let x: CGFloat = msg["x"] as? CGFloat ?? 0
      let y: CGFloat = msg["y"] as? CGFloat ?? 0
      let offset = CGPoint(x: x, y: y)

      _isPrimaryScreen = isPrimary
      _applyPanEnablement()

      if (offset == _scrollView.contentOffset) {
        return
      }
      // TODO: debounce?
      _scrollView.setContentOffset(offset, animated: animated)

    case "mouseHover":
      _mouseHoverMode = msg["enabled"] as? Bool ?? false
      _lastHoverCell = nil
      
    default: break
    }
  }
}

extension WKWebViewGesturesInteraction: UIPointerInteractionDelegate {
  func pointerInteraction(_ interaction: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
    return defaultRegion
  }

  func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
    return nil
  }
}
