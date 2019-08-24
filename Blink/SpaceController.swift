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

public class SpaceController: SafeLayoutViewController {
  
  weak var _nextSpaceCtrl: SpaceController? = nil
  
  struct UIState: UserActivityCodable {
    var keys: [UUID] = []
    var currentKey: UUID? = nil
    var bgColor:CodableColor? = nil
    
    static var activityType: String { "space.ctrl.ui.state" }
  }

  private lazy var _viewportsController = UIPageViewController(
    transitionStyle: .scroll,
    navigationOrientation: .horizontal,
    options: [.spineLocation: UIPageViewController.SpineLocation.mid]
  )
  private lazy var _touchOverlay = TouchOverlay(frame: .zero)
  
  private var _viewportsKeys = [UUID]()
  private var _currentKey: UUID? = nil
  
  private var _hud: MBProgressHUD? = nil
  private var _musicHUD: MBProgressHUD? = nil
  private var _previousKBFrame: CGRect = .zero
  
  private var _kbdCommands:[UIKeyCommand] = []
  private var _kbdCommandsWithoutDiscoverability: [UIKeyCommand] = []
  private var _proposedKBBottomInset: CGFloat = 0
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    guard
      let window = view.window
//      let scene = window.windowScene
      else {
      return
    }
    
    
    if window.screen == UIScreen.main {
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
    
    
//    view.addSubview(_termInput)
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
        DispatchQueue.main.async {
          self._attachInputToCurrentTerm()
        }
            
      }
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
  
  @objc func _didBecomeKeyWindow(win: NSNotification) {
    guard let window = view.window else {
      currentDevice?.blur()
      return
    }
    
    if window.isKeyWindow {
      if SmarterTermInput.shared.superview !== self.view {
        if window.screen === UIScreen.main {
          self.view.addSubview(SmarterTermInput.shared)
//        } else {
//          SmarterTermInput.shared.becomeFirstResponder()
        }
      }
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
    
    if let currentKey = _currentKey,
      let idx = _viewportsKeys.firstIndex(of: currentKey)?.advanced(by: 1) {
      _viewportsKeys.insert(term.meta.key, at: idx)
    } else {
      _viewportsKeys.insert(term.meta.key, at: _viewportsKeys.count)
    }
    
    SessionRegistry.shared.track(session: term)
    
    _viewportsController.setViewControllers([term], direction: .forward, animated: animated) { (didComplete) in
      DispatchQueue.main.async {
        self._currentKey = term.meta.key
        self._displayHUD()
        self._attachInputToCurrentTerm()
        if let completion = completion {
          completion(didComplete)
        }
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
    _removeCurrentSpace()
  }
  
  private func _removeCurrentSpace() {
    guard
      let currentKey = _currentKey,
      let idx = _viewportsKeys.firstIndex(of: currentKey)
    else {
      return
    }
    
    SessionRegistry.shared.remove(forKey: currentKey)
    _viewportsKeys.remove(at: idx)
    if _viewportsKeys.isEmpty {
      _createShell(userActivity: nil, key: nil, animated: true)
      return
    }

    let direction: UIPageViewController.NavigationDirection
    let term: TermController
    
    if idx < _viewportsKeys.endIndex {
      direction = .forward
      term = SessionRegistry.shared[_viewportsKeys[idx]]
    } else {
      direction = .reverse
      term = SessionRegistry.shared[_viewportsKeys[idx - 1]]
    }
    term.bgColor = view.backgroundColor ?? .black
      
    _viewportsController.setViewControllers([term], direction: direction, animated: true) { (didComplete) in
      self._currentKey = term.meta.key
      self._displayHUD()
      self._attachInputToCurrentTerm()
    }
  }
  
  @objc func _focusOnShell() {
    _attachInputToCurrentTerm()
    SmarterTermInput.shared.becomeFirstResponder()
  }
  
  func _attachInputToCurrentTerm() {
    currentDevice?.attachInput(SmarterTermInput.shared)
  }
  
  var currentDevice: TermDevice? {
    currentTerm()?.termDevice
  }
  
  var _skipKBChangeFrameHandler: Bool = false
  
  @objc func _keyboardWillChangeFrame(sender: NSNotification) {
    guard
      _skipKBChangeFrameHandler == false,
      let userInfo = sender.userInfo,
      let kbFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      isLocal ? _previousKBFrame != kbFrame :  abs(_previousKBFrame.height - kbFrame.height) > 6 // reduce reflows (local height 69, other - 72)!
    else {
      _skipKBChangeFrameHandler = false
      return
    }
    
    _previousKBFrame = kbFrame
    
    var bottomInset: CGFloat = 0
    var isFloatingKB = false
    var isSoftwareKB = true
    
    let viewMaxY = view.frame.maxY
    
    let kbMaxY = kbFrame.maxY
    let kbMinY = kbFrame.minY

    let input = SmarterTermInput.shared
    
    if kbMaxY >= viewMaxY {
      bottomInset = viewMaxY - kbMinY
    } else if kbMinY < viewMaxY && kbMaxY < viewMaxY {
      // Floating
      isFloatingKB = true
      isSoftwareKB = true
      
      if let accessoryView = input.inputAccessoryView {
        bottomInset = accessoryView.bounds.height
      }
    }
    
    defer {
      input.setNeedsLayout()
      _proposedKBBottomInset = bottomInset;
      view.setNeedsLayout()
      updateKbBottomSafeMargins(bottomInset)
    }
    
    // Only key window can change input props
    guard view.window?.isKeyWindow == true
    else {
      return
    }

    let kbView = input.kbView
    
    kbView.traits.isFloatingKB = isFloatingKB
    
    if traitCollection.userInterfaceIdiom == .phone {
      isSoftwareKB = kbFrame.height > 100
      
      if kbView.traits.isHKBAttached == isSoftwareKB {
        kbView.traits.isHKBAttached = !isSoftwareKB
        // TODO: find goodway to remove loop
        _skipKBChangeFrameHandler = true
        DispatchQueue.main.async {
          kbView.inputAccessoryView?.invalidateIntrinsicContentSize()
          kbView.reloadInputViews()
        }
      }
    } else if isFloatingKB && input.inputAccessoryView == nil {
      // put in iphone mode
      kbView.kbDevice = .in6_5
      kbView.traits.isPortrait = true
      kbView.traits.isHKBAttached = !isSoftwareKB
      input.setupAccessoryView()
      bottomInset = input.inputAccessoryView?.frame.height ?? 0
      input.reloadInputViews()
    } else if !isFloatingKB && input.inputAccessoryView != nil {
      kbView.kbDevice = .detect()
      input.setupAssistantItem()
      input.reloadInputViews()
    }
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
  func restore(withState state: UIState) {
    _viewportsKeys = state.keys
    _currentKey = state.currentKey
    if let bgColor = UIColor(codableColor: state.bgColor) {
      view.backgroundColor = bgColor
    }
    
    view.setNeedsLayout()
    view.layoutIfNeeded()
  }
  
  func dumpUIState() -> UIState {
    UIState(keys: _viewportsKeys,
            currentKey: _currentKey,
            bgColor: CodableColor(uiColor: view.backgroundColor)
    )
  }
  
  @objc static func onDidDiscardSceneSessions(_ sessions: Set<UISceneSession>) {
    let registry = SessionRegistry.shared
    sessions.forEach { session in
      guard
        let uiState = SpaceController.UIState(userActivity: session.stateRestorationActivity)
      else {
        return
      }
      
      uiState.keys.forEach { registry.remove(forKey: $0) }
    }
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
  private func _controller(controller: UIViewController, advancedBy: Int) -> UIViewController? {
    guard let ctrl = controller as? TermController else {
      return nil
    }
    let key = ctrl.meta.key
    guard
      let idx = _viewportsKeys.firstIndex(of: key)?.advanced(by: advancedBy),
      idx >= 0 && idx < _viewportsKeys.endIndex
    else {
      return nil
    }
    
    let newKey = _viewportsKeys[idx]
    let newCtrl: TermController = SessionRegistry.shared[newKey]
    newCtrl.bgColor = view.backgroundColor ?? .black
    return newCtrl
  }
  
  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
    _controller(controller: viewController, advancedBy: -1)
  }
  
  public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
    _controller(controller: viewController, advancedBy: 1)
  }
  
}

extension SpaceController: ControlPanelDelegate {
  @objc func controlPanelOnClose() {
    _closeCurrentSpace()
  }
  
  @objc func controlPanelOnPaste() {
    _attachInputToCurrentTerm()
    SmarterTermInput.shared.yank(self);
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
    SmarterTermInput.shared.reset()
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
      
      // Screens
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
  
  private func _moveToShell(idx: Int) {
    guard
      idx >= _viewportsKeys.startIndex,
      idx < _viewportsKeys.endIndex,
      let currentKey = _currentKey,
      let currentIdx = _viewportsKeys.firstIndex(of: currentKey)
    else {
      return
    }
    let key = _viewportsKeys[idx]
    let term: TermController = SessionRegistry.shared[key]
    let direction: UIPageViewController.NavigationDirection = currentIdx < idx ? .forward : .reverse
        
    _viewportsController.setViewControllers([term], direction: direction, animated: true) { (didComplete) in
      self._currentKey = term.meta.key
      self._displayHUD()
      self._attachInputToCurrentTerm()
    }
  }
  
  private func _advanceShell(by: Int) {
    guard
      let currentKey = _currentKey,
      let idx = _viewportsKeys.firstIndex(of: currentKey)?.advanced(by: by)
    else {
      return
    }
        
    _moveToShell(idx: idx)
  }
  
  @objc private func _nextShellAction() {
    _advanceShell(by: 1)
  }
  
  @objc private func _prevShellAction() {
    _advanceShell(by: -1)
  }
  
  
  @objc func _focusOtherScreenAction() {
    let app = UIApplication.shared
    let sessions = Array(app.openSessions)
      .sorted(by: {(a, b) in
      a.persistentIdentifier > b.persistentIdentifier
    })
//    view.window?.windowScene?.session.persistentIdentifier
    guard
      sessions.count > 1,
      let session = view.window?.windowScene?.session,
      let idx = sessions.firstIndex(of: session)?.advanced(by: 1)
    else  {
      return
    }
    
    let nextSession: UISceneSession
    if idx < sessions.endIndex {
      nextSession = sessions[idx]
    } else {
     nextSession = sessions[0]
    }
    
    if
      let scene = nextSession.scene as? UIWindowScene,
      scene.activationState == .foregroundActive || scene.activationState == .foregroundInactive,
      let delegate = scene.delegate as? SceneDelegate,
      let window = delegate.window,
      let spaceCtrl = window.rootViewController as? SpaceController {
        if nextSession.role == .windowExternalDisplay {
          spaceCtrl._focusOnShell()
        } else {
          window.makeKeyAndVisible()
        }
    } else {
      app.requestSceneSessionActivation(nextSession, userActivity: nil, options: nil, errorHandler: nil)
    }
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
    DispatchQueue.main.async {
      let storyboard = UIStoryboard(name: "Settings", bundle: nil)
      let vc = storyboard.instantiateViewController(identifier: "NavSettingsController")
      self.present(vc, animated: true, completion: nil)
    }
  }
  
}
