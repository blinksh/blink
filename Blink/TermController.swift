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

@objc protocol TermControlDelegate: NSObjectProtocol {
  // May be do it optional
  func terminalHangup(control: TermController)
  @objc optional func terminalDidResize(control: TermController)
}

@objc protocol ControlPanelDelegate: NSObjectProtocol {
  func controlPanelOnClose()
  func controlPanelOnPaste()
  func currentTerm() -> TermController!
}

class TermController: UIViewController {
  private weak var _sessionRegistry: SessionRegistry? = nil
  private let _meta: SessionMeta
  
  private var _termDevice = TermDevice()
  private var _termView = TermView(frame: .zero)
  private var _sessionParams: MCPParams = {
    let params = MCPParams()
    
    params.fontSize = BKDefaults.selectedFontSize()?.intValue ?? 16
    params.fontName = BKDefaults.selectedFontName()
    params.themeName = BKDefaults.selectedThemeName()
    params.enableBold = BKDefaults.enableBold()
    params.boldAsBright = BKDefaults.isBoldAsBright()
    params.viewSize = .zero
    params.layoutMode = BKDefaults.layoutMode().rawValue
    
    return params
  }()
  private var _bgColor: UIColor? = nil
  private var _fontSizeBeforeScaling: Int? = nil
  
  @objc public var activityKey: String? = nil
  @objc public var termDevice: TermDevice { get { _termDevice } }
  @objc weak var delegate: TermControlDelegate? = nil
  @objc var sessionParams: MCPParams { _sessionParams }
  @objc var bgColor: UIColor? {
    get { _bgColor }
    set { _bgColor = newValue }
  }
  
  private var _session: MCPSession? = nil
  
  required init(meta: SessionMeta? = nil) {
    _meta = meta ?? SessionMeta()
    super.init(nibName: nil, bundle: nil)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func loadView() {
    super.loadView()
    _termDevice.delegate = self
    _termDevice.attachView(_termView)
    _termView.backgroundColor = _bgColor
    view = _termView
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    resumeIfNeeded()
    
    _termView.load(with: _sessionParams)
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(_relayout),
      name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate), object: nil)
  }
  
  @objc func _relayout() {
    guard
      let window = view.window,
      window.screen === UIScreen.main
    else {
      return
    }
    
    view.setNeedsLayout()
  }
  
  public override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    let layoutMode = BKLayoutMode(rawValue: _sessionParams.layoutMode) ?? BKLayoutMode.default
    _termView.additionalInsets = LayoutManager.buildSafeInsets(for: self, andMode: layoutMode)
    _termView.layoutLockedFrame = _sessionParams.layoutLockedFrame
    _termView.layoutLocked = _sessionParams.layoutLocked
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    _sessionParams.viewSize = view.bounds.size
  }
  
  @objc public func terminate() {
    _termView.terminate()
    _session?.kill()
  }
  
  @objc public func lockLayout() {
    _sessionParams.layoutLocked = true
    _sessionParams.layoutLockedFrame = _termView.webViewFrame()
  }
  
  @objc public func unlockLayout() {
    _sessionParams.layoutLocked = false
    view.setNeedsLayout()
  }
  
  @objc public func isRunningCmd() -> Bool {
    return _session?.isRunningCmd() ?? false
  }
  
  @objc public func canRestoreUserActivityState(
    _ activity: NSUserActivity) -> Bool
  {
    return _session?.isRunningCmd() == false || activity.title == activityKey
  }
  
  @objc public func scaleWithPich(_ pinch: UIPinchGestureRecognizer) {
    switch pinch.state {
    case .began: fallthrough
    case .ended:
      _fontSizeBeforeScaling = _sessionParams.fontSize
    case .changed:
      guard let initialSize = _fontSizeBeforeScaling else {
        return
      }
      let newSize = Int(round(CGFloat(initialSize) * pinch.scale))
      guard newSize == _sessionParams.fontSize else {
        return
      }
      _termView.setFontSize(newSize as NSNumber)
    default:  break
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
    _termDevice.attachView(nil)
    _session?.device = nil
    _session?.stream = nil
    _session = nil
  }
  
}

extension TermController: SessionDelegate {
  public func indexCommand(_ cmdLine: String!) {
    // TODO:
  }
  
  public func sessionFinished() {
    if _sessionParams.hasEncodedState() {
      _session = nil
      return
    }

    delegate?.terminalHangup(control: self)
  }
}

extension TermController: TermDeviceDelegate {
  public func deviceIsReady() {
    startSession()
  }
  
  public func deviceSizeChanged() {
    _sessionParams.rows = _termDevice.rows
    _sessionParams.cols = _termDevice.cols
    
    delegate?.terminalDidResize?(control: self)
    _session?.sigwinch()
  }
  
  public func viewFontSizeChanged(_ size: Int) {
    _sessionParams.fontSize = size
    _termDevice.input?.reset()
  }
  
  public func handleControl(_ control: String!) -> Bool {
    return _session?.handleControl(control) ?? false
  }
  
  public func deviceFocused() {
    _session?.setActiveSession()
  }
  
  public func viewController() -> UIViewController! {
    return self
  }
}

extension TermController: SuspendableSession {
  
  var sessionRegistry: SessionRegistry? {
    get { _sessionRegistry }
    set { _sessionRegistry = newValue }
  }
  
  var meta: SessionMeta { _meta }
  
  var _decodableKey: String { "params" }
  
  func startSession() {
    guard _session == nil
    else {
      return
    }
    
    _session = MCPSession(
      device: _termDevice,
      andParams: _sessionParams)
    
    _session?.delegate = self
    _session?.execute(withArgs: "")
  }
  
  
  func resume(with unarchiver: NSKeyedUnarchiver) {
    guard
      unarchiver.containsValue(forKey: _decodableKey),
      let params = unarchiver.decodeObject(of: MCPParams.self, forKey: _decodableKey)
    else {
      return
    }
    
    _sessionParams = params
    
    guard
      _sessionParams.hasEncodedState(),
      _session == nil // will be created on startSession
    else {
      return
    }
    
    let input = _termDevice.input
    _termDevice = TermDevice()
    _termDevice.cols = params.cols
    _termDevice.rows = params.rows
    _termDevice.delegate = self
    _termDevice.attachView(_termView)
    _termDevice.attachInput(input)
    
    if _termView.isReady {
      startSession()
    }
    
    if view.bounds.size != params.viewSize {
      _session?.sigwinch()
    }
  }
  
  func suspendedSession(with archiver: NSKeyedArchiver) {
    guard
      let session = _session
    else {
      return
    }
    
    _sessionParams.cleanEncodedState()
    session.suspend()
    
    let hasEncodedState = _sessionParams.hasEncodedState()
    
    debugPrint("has encoded state", hasEncodedState)
    archiver.encode(_sessionParams, forKey: _decodableKey)
  }
}
