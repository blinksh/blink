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

public class TermController: StateViewController {
  private var _termDevice = TermDevice()
  private var _termView = TermView(frame: .zero, andBgColor: nil)
  private var _sessionParameters: MCPSessionParameters? = nil
  private var _bgColor: UIColor? = nil
  private var _fontSizeBeforeScaling: Int? = nil
  
  @objc public var activityKey: String? = nil
  @objc public var termDevice: TermDevice { get { _termDevice } }
  @objc weak var delegate: TermControlDelegate? = nil
  @objc public var sessionParameters: MCPSessionParameters? { get { _sessionParameters }}
  @objc public var bgColor: UIColor? {
    get { _bgColor }
    set { _bgColor = newValue }
  }
  
  private var _session: MCPSession? = nil
  
  @objc public init() {
    super.init(meta: nil)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func loadView() {
    _termDevice.delegate = self
    _termDevice.attachView(_termView)
    view = _termView
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    if _sessionParameters == nil {
      _initSessionParameters()
    }
    
    _termView?.load(with: _sessionParameters)
  }
  
  public override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    guard
      let termView = _termView,
      let params = _sessionParameters
    else {
      return
    }
    termView.additionalInsets = LayoutManager.buildSafeInsets(for: self, andMode: params.layoutMode)
    termView.layoutLockedFrame = params.layoutLockedFrame
    termView.layoutLocked = params.layoutLocked
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    
    guard let params = _sessionParameters else {
      return
    }
    let size = view.bounds.size
    
    params.viewWidth = size.width;
    params.viewHeight = size.height;
  }
  
  func _initSessionParameters() {
    let params = MCPSessionParameters()
    
    params.fontSize = BKDefaults.selectedFontSize()?.intValue ?? 16
    params.fontName = BKDefaults.selectedFontName()
    params.themeName = BKDefaults.selectedThemeName()
    params.enableBold = BKDefaults.enableBold()
    params.boldAsBright = BKDefaults.isBoldAsBright()
    
    let size = view.bounds.size
    
    params.viewWidth = size.width
    params.viewHeight = size.height
    params.layoutMode = BKDefaults.layoutMode()
    
    _sessionParameters = params
  }
  
  func startSession() {
    _session = MCPSession(
      device: _termDevice,
      andParametes: _sessionParameters)
    
    _session?.delegate = self
    _session?.execute(withArgs: "")
  }
  
  @objc public func terminate() {
    _termView?.terminate()
    _session?.kill()
  }
  
  @objc public func lockLayout() {
    _sessionParameters?.layoutLocked = true
    if let frame = _termView?.webViewFrame() {
      _sessionParameters?.layoutLockedFrame = frame
    }
  }
  
  @objc public func unlockLayout() {
    _sessionParameters?.layoutLocked = false
    view.setNeedsLayout()
  }
  
  @objc public func suspend() {
    _sessionParameters?.cleanEncodedState()
    _session?.suspend()
  }
  
  @objc public func resume() {
    guard
      _sessionParameters?.hasEncodedState() == true
    else {
      return
    }
  }
  
  @objc public func isRunningCmd() -> Bool {
    return _session?.isRunningCmd() ?? false
  }
  
  @objc public func canRestoreUserActivityState(_ activity: NSUserActivity) -> Bool {
    return _session?.isRunningCmd() == false || activity.title == activityKey
  }
  
  @objc public func scaleWithPich(_ pinch: UIPinchGestureRecognizer) {
    switch pinch.state {
    case .began: fallthrough
    case .ended:
      _fontSizeBeforeScaling = _sessionParameters?.fontSize
    case .changed:
      guard let initialSize = _fontSizeBeforeScaling else {
        return
      }
      let newSize = Int(round(CGFloat(initialSize) * pinch.scale))
      guard newSize == _sessionParameters?.fontSize else {
        return
      }
      _termView?.setFontSize(newSize as NSNumber)
    default:  break
    }
  }
  
  deinit {
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
    if (_sessionParameters?.hasEncodedState() == true) {
      return
    }
    
    delegate?.terminalHangup(control: self)
  }
}

extension TermController: TermDeviceDelegate {
  public func deviceIsReady() {
    startSession()
    // TODO: restore activity?
  }
  
  public func deviceSizeChanged() {
    _sessionParameters?.rows = termDevice.rows
    _sessionParameters?.cols = termDevice.cols
    
    delegate?.terminalDidResize?(control: self)
  }
  
  public func viewFontSizeChanged(_ size: Int) {
    _sessionParameters?.fontSize = size
    termDevice.input?.reset()
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
