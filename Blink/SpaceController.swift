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
import MBProgressHUD


@objc public class SpaceController: SafeLayoutViewController {
  
  struct UIState: UserActivityCodable {
    var keys: [UUID] = []
    var currentKey: UUID? = nil
    var unfocused: Bool = true
    var bgColor:CodableColor? = nil
    
    static var activityType: String { "space.ctrl.ui.state" }
  }

  private lazy var _viewportsController = UIPageViewController(
    transitionStyle: .scroll,
    navigationOrientation: .horizontal,
    options:
      [.spineLocation: UIPageViewController.SpineLocation.mid]
  )
  private lazy var _termInput = TermInput()
  private lazy var _touchOverlay = TouchOverlay(frame: .zero)
  
  private var _viewportsKeys = [UUID]()
  private var _currentKey: UUID? = nil
  
  private var _hud: MBProgressHUD? = nil
  private var _musicHUD: MBProgressHUD? = nil
  
  private var _kbdCommands:[UIKeyCommand] = []
  private var _kbdCommandsWithoutDiscoverability: [UIKeyCommand] = []
  
  private var _unfocused = false
  private var _proposedKBBottomInset: CGFloat = 0
  private var _active = false
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if view.window?.screen == UIScreen.main {
      var insets = UIEdgeInsets.zero
      insets.bottom = _proposedKBBottomInset
      _touchOverlay.frame = view.bounds.inset(by: insets)
    } else {
      _touchOverlay.frame = view.bounds
    }
  }
  
  public override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    updateDeviceSafeMarings(view.safeAreaInsets)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    
    view.isOpaque = true
  
    _viewportsController.view.isOpaque = true
    _viewportsController.dataSource = self
    _viewportsController.delegate = self
    
    addChild(_viewportsController)
    
    if let v = _viewportsController.view {
      v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      v.layoutMargins = .zero
      v.frame = view.bounds
      view.addSubview(v)
    }
    
    _viewportsController.didMove(toParent: self)
    
    _touchOverlay.frame = view.bounds
    view.addSubview(_touchOverlay)
    _touchOverlay.touchDelegate = self
    // TODO:
//    _touchOverlay.controlPanel.controlPanelDelegate = self
    _touchOverlay.attach(_viewportsController)
    
    view.addSubview(_termInput)
    _registerForNotifications()
    _setupKBCommands()
    
    if _viewportsKeys.isEmpty {
      _createShell(userActivity: nil, key: nil, animated: false)
    } else if let key = _currentKey {
      let term: TermController = SessionRegistry.shared[key]
      term.delegate = self
//      term.userActivity = userActivity
      term.bgColor = view.backgroundColor ?? .black
      _viewportsController.setViewControllers([term], direction: .forward, animated: false) { (didComplete) in
            self._attachInputToCurrentTerm()
          }
    }
    
  }
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    if _termInput.isFirstResponder && view.window?.isKeyWindow == true {
      _attachInputToCurrentTerm()
      return
    }
    
    if !_unfocused {
      _focusOnShell()
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func _registerForNotifications() {
    let nc = NotificationCenter.default
    
    nc.removeObserver(self)
    
    nc.addObserver(self,
                   selector: #selector(_keyboardWillChangeFrame(sender:)),
                   name: UIResponder.keyboardWillChangeFrameNotification,
                   object: nil)
    

    nc.addObserver(self,
                   selector: #selector(_focusOnShell),
                   name: NSNotification.Name.BKUserAuthenticated,
                   object: nil)
    
    nc.addObserver(self,
                   selector: #selector(_didBecomeKeyWindow),
                   name: UIWindow.didBecomeKeyNotification,
                   object: nil)
  }
  
  @objc func _didBecomeKeyWindow() {
    guard let window = view.window else {
      return
    }
    
    if window.isKeyWindow {
      _focusOnShell()
    } else {
      currentDevice?.blur()
    }
  }
  
  @objc func _keyboardFuncTriggerChanged(_ notification: NSNotification) {
    guard
      let userInfo = notification.userInfo,
      let action = userInfo["func"] as? String,
      action == BKKeyboardFuncCursorTriggers
    else {
      return
    }
    
    _setupKBCommands()
  }
  
  func _createShell(
    userActivity: NSUserActivity?,
    key: String?,
    animated: Bool,
    completion: ((Bool) -> Void)? = nil)
  {
    let term = TermController()
    term.delegate = self
    term.userActivity = userActivity
    term.bgColor = view.backgroundColor ?? .black
    
    _viewportsKeys = [term.meta.key]
    
    SessionRegistry.shared.track(session: term)
    
    _viewportsController.setViewControllers([term], direction: .forward, animated: animated) { (didComplete) in
      self._currentKey = term.meta.key
      self._displayHUD()
      self._attachInputToCurrentTerm()
      if let completion = completion {
        completion(didComplete)
      }
    }
  }
  
  
  @objc func _toggleMusicHUD() {
    if let musicHUD = _musicHUD {
      musicHUD.hide(animated: true)
      _musicHUD = nil
      return
    }
    
    _hud?.hide(animated: false)
    
    let musicHud = MBProgressHUD.showAdded(to: _touchOverlay, animated: true)
    musicHud.mode = .customView
    musicHud.bezelView.style = .solidColor
    musicHud.bezelView.color = .clear
    musicHud.contentColor = .white
    musicHud.customView = MusicManager.shared().hudView()
    
    let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(_toggleMusicHUD))
    musicHud.backgroundView.addGestureRecognizer(tapRecognizer)
    _musicHUD = musicHud
  }
  
  func _closeCurrentSpace() {
    currentTerm()?.terminate()
    removeCurrentSpace()
  }
  
  @objc public func removeCurrentSpace() {
    
  }
  
  @objc func _focusOnShell() {
    _active = true
    _termInput.becomeFirstResponder()
    _attachInputToCurrentTerm()
  }
  
  func _attachInputToCurrentTerm() {
    currentDevice?.attachInput(_termInput)
  }
  
  var currentDevice: TermDevice? {
    get {
      currentTerm()?.termDevice
    }
  }
  
  @objc func _keyboardWillChangeFrame(sender: NSNotification) {
    var bottomInset: CGFloat = 0
    guard let kbFrame = sender.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
      return
    }
    
    let viewHeight = view.bounds.height
    if kbFrame.maxY >= viewHeight {
      bottomInset = viewHeight - kbFrame.origin.y
    }
    
    let accessoryView = _termInput.inputAccessoryView
    let accessoryHeight = accessoryView?.frame.height
    if bottomInset > 80 {
      accessoryView?.isHidden = false
      _termInput.softwareKB = true
    } else if bottomInset == accessoryHeight {
      if _touchOverlay.panGestureRecognizer.state == .recognized {
        accessoryView?.isHidden = true
      } else {
        accessoryView?.isHidden = !BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigShowSmartKeysWithXKeyBoard)
        _termInput.softwareKB = false
      }
    } else if kbFrame.height == 0 {
      accessoryView?.isHidden = true
    }
    
    if accessoryView?.isHidden == true,
      let accessoryH = accessoryHeight {
      bottomInset -= accessoryH
      if bottomInset < 0 {
        bottomInset = 0
      }
      _termInput.softwareKB = false
      
      _proposedKBBottomInset = bottomInset
      
      if (!_active) {
        view.setNeedsLayout()
        return
      }
      
      updateKbBottomSafeMargins(bottomInset)
    }
  }
  
  @objc public func viewScreenWillBecomeActive() {
    
  }
  
  @objc public func viewScreenDidBecomeInactive() {
    
  }
  
  @objc public func moveAllShellsFromSpaceController(_ spaceController: SpaceController) {
    
  }
  
  @objc public func moveCurrentShellFromSpaceController(_ spaceController: SpaceController) {
    
  }
  
  func _displayHUD() {
    if let musicHUD = _musicHUD {
      musicHUD.hide(animated: true)
      _musicHUD = nil
      return
    }
    
    _hud?.hide(animated: false)
    
    guard let term = currentTerm() else {
      return
    }
    
    let params = term.sessionParams
    
    if let bgColor = term.view.backgroundColor, bgColor != .clear {
      view.backgroundColor = bgColor
      _viewportsController.view.backgroundColor = bgColor
      view.window?.backgroundColor = bgColor
    }
    
    let hud = MBProgressHUD.showAdded(to: _touchOverlay, animated: _hud == nil)
    
    hud.mode = .customView
    hud.bezelView.color = .darkGray
    hud.contentColor = .white
    hud.isUserInteractionEnabled = false
    hud.alpha = 0.6
    
    let pages = UIPageControl()
    pages.currentPageIndicatorTintColor = .cyan
    pages.numberOfPages = _viewportsKeys.count
    pages.currentPage = _viewportsKeys.firstIndex(of: term.meta.key) ?? NSNotFound
    
    hud.customView = pages
    
    let title = term.title?.isEmpty == true ? nil : term.title
    if params.rows == 0 && params.cols == 0 {
      hud.label.numberOfLines = 1
      hud.label.text = title ?? "blink"
    } else {
      let geometry = "\(params.rows) x \(params.cols)"
      hud.label.numberOfLines = 2
      hud.label.text = "\(title ?? "blink")\n\(geometry)"
    }
    
    _hud = hud
    hud.hide(animated: true, afterDelay: 1)
    _touchOverlay.controlPanel.updateLayoutBar()
  }
  
}

extension SpaceController: UIStateRestorable {
  func restore(withState state: SpaceController.UIState) {
    _viewportsKeys = state.keys
    _unfocused = state.unfocused
    _currentKey = state.currentKey
    if let bgColor = UIColor(codableColor: state.bgColor) {
      view.backgroundColor = bgColor
    }
    
    view.setNeedsLayout()
    view.layoutIfNeeded()
  }
  
  func dumpUIState() -> SpaceController.UIState {
    UIState(keys: _viewportsKeys,
            currentKey: _currentKey,
            unfocused: _unfocused,
            bgColor: CodableColor(uiColor: view.backgroundColor)
    )
  }
}

extension SpaceController: UIPageViewControllerDelegate {
  public func pageViewController(
    _ pageViewController: UIPageViewController,
    didFinishAnimating finished: Bool,
    previousViewControllers: [UIViewController],
    transitionCompleted completed: Bool) {
    guard completed else {
      return
    }
    
    _currentKey = (pageViewController.viewControllers?.first as? TermController)?.meta.key
    _displayHUD()
    _attachInputToCurrentTerm()
  }
}

extension SpaceController: UIPageViewControllerDataSource {
  public func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerBefore viewController: UIViewController
    ) -> UIViewController?
  {
    guard let ctrl = viewController as? TermController else {
      return nil
    }
    
    let key = ctrl.meta.key
    guard
      let idx = _viewportsKeys.firstIndex(of: key),
      idx > 0 else {
      return nil
    }
    
    let newKey = _viewportsKeys[idx - 1]
    
    let newCtrl: TermController = SessionRegistry.shared[newKey]
    return newCtrl
  }
  
  public func pageViewController(
    _ pageViewController: UIPageViewController,
    viewControllerAfter viewController: UIViewController
    ) -> UIViewController?
  {
    guard let ctrl = viewController as? TermController else {
      return nil
    }
    
    let key = ctrl.meta.key
    guard
      let idx = _viewportsKeys.firstIndex(of: key),
      idx + 1 < _viewportsKeys.endIndex else {
        return nil
    }
    
    let newKey = _viewportsKeys[idx + 1]
    
    let newCtrl: TermController = SessionRegistry.shared[newKey]
    return newCtrl
  }
  
}

extension SpaceController: ControlPanelDelegate {
  @objc func controlPanelOnClose() {
    _closeCurrentSpace()
  }
  
  @objc func controlPanelOnPaste() {
    _attachInputToCurrentTerm()
    _termInput.yank(self);
  }
  
  @objc func currentTerm() -> TermController! {
    if let currentKey = _currentKey {
      return SessionRegistry.shared[currentKey]
    }
    return nil
  }
}

extension SpaceController: TouchOverlayDelegate {
  public func touchOverlay(_ overlay: TouchOverlay!, onOneFingerTap recognizer: UITapGestureRecognizer!) {
    guard let term = currentTerm() else {
      return
    }
    _termInput.reset()
    let point = recognizer.location(in: term.view)
    term.termDevice.focus()
    term.termDevice.view.reportTouch(in: point)
  }
  
  public func touchOverlay(_ overlay: TouchOverlay!, onTwoFingerTap recognizer: UITapGestureRecognizer!) {
    
  }
  
  public func touchOverlay(_ overlay: TouchOverlay!, onPinch recognizer: UIPinchGestureRecognizer!) {
    currentTerm()?.scaleWithPich(recognizer)
  }
}

extension SpaceController: TermControlDelegate {
  func terminalHangup(control: TermController) {
    if currentTerm() == control {
      _closeCurrentSpace()
    }
  }
  
  func terminalDidResize(control: TermController) {
    if currentTerm() == control {
      _displayHUD()
    }
  }
}

// MARK: General tunning

extension SpaceController {
  public override var canBecomeFirstResponder: Bool { true }
  public override var prefersStatusBarHidden: Bool { true }
  public override var prefersHomeIndicatorAutoHidden: Bool { true }
}


// MARK: Commands

extension SpaceController {
  public override var keyCommands: [UIKeyCommand]? {
    return _kbdCommands
  }
  
  // simple helper
  private func _cmd(_ title: String, _ action: Selector, _ input: String, _ flags: UIKeyModifierFlags) -> UIKeyCommand {
    return UIKeyCommand(
      __title: title,
      image: nil,
      action: action,
      input: input,
      modifierFlags: flags,
      propertyList: nil
    )
  }
  
  private func _setupKBCommands() {
    let modifierFlags = BKUserConfigurationManager.shortCutModifierFlags()
    let prevNextShellModifierFlags = BKUserConfigurationManager.shortCutModifierFlagsForNextPrevShell()
    
    let right = UIKeyCommand.inputRightArrow
    let left = UIKeyCommand.inputLeftArrow
    
    _kbdCommands = [
      _cmd("New Window",     #selector(_newWindowAction),   "t", prevNextShellModifierFlags),
      _cmd("Close Window",   #selector(_closeWindowAction), "w", prevNextShellModifierFlags),
    
      _cmd("New Shell",      #selector(_newShellAction),   "t", modifierFlags),
      _cmd("Close Shell",    #selector(_closeShellAction), "w", modifierFlags),
      
      _cmd("Next Shell",     #selector(_nextShellAction), "]", prevNextShellModifierFlags),
      _cmd("Previous Shell", #selector(_prevShellAction), "[", prevNextShellModifierFlags),
    
      // Alternative key commands for keyboard layouts having problems to access
      // some of the default ones (e.g. the German keyboard layout)
      _cmd("Next Shell",     #selector(_nextShellAction),  right, prevNextShellModifierFlags),
      _cmd("Previous Shell", #selector(_prevShellAction),  left,  prevNextShellModifierFlags),
      
      // Font size
      _cmd("Zoom In",    #selector(_increaseFontSizeAction), "+",  modifierFlags),
      _cmd("Zoom Out",   #selector(_decreaseFontSizeAction), "-",  modifierFlags),
      _cmd("Zoom Reset", #selector(_resetFontSizeAction),    "=",  modifierFlags),
      
      //
      _cmd("Focus Other Screen",         #selector(_focusOtherScreenAction),  "o", modifierFlags),
      _cmd("Move shell to other Screen", #selector(_moveToOtherScreenAction), "o", prevNextShellModifierFlags),
      
      // Misc
      _cmd("Show Config",    #selector(_showConfigAction), ",", modifierFlags),
      _cmd("Music Controls", #selector(_toggleMusicHUD),   "m", modifierFlags)
    ]
  }
  
  @objc private func _newShellAction() {
    _createShell(userActivity: nil, key: nil, animated: true)
  }
  
  @objc private func _closeShellAction() {
    _closeCurrentSpace()
  }
  
  @objc private func _nextShellAction() {
    
  }
  
  @objc private func _prevShellAction() {
    
  }
  
  
  @objc func _focusOtherScreenAction() {
    
  }
  
  @objc func _moveToOtherScreenAction() {
    
  }
  
  
  @objc func _newWindowAction() {
    UIApplication
      .shared
      .requestSceneSessionActivation(nil,
                                     userActivity: nil,
                                     options: nil,
                                     errorHandler: nil)
  }
  
  @objc func _closeWindowAction() {
    guard let session = view.window?.windowScene?.session else {
      return
    }
    UIApplication
      .shared
      .requestSceneSessionDestruction(session,
                                      options: nil,
                                      errorHandler: nil)
  }
  
  @objc func _increaseFontSizeAction() {
    currentDevice?.view?.increaseFontSize()
  }
  
  @objc func _decreaseFontSizeAction() {
    currentDevice?.view?.decreaseFontSize()
  }
  
  @objc func _resetFontSizeAction() {
    currentDevice?.view?.resetFontSize()
  }
  
  @objc func _showConfigAction() {
  }
  
}
