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

public class SpaceController: UIViewController {
  
  struct UIState: UserActivityCodable {
    var keys: [UUID] = []
    var currentKey: UUID? = nil
    var bgColor: CodableColor? = nil
    
    static var activityType: String { "space.ctrl.ui.state" }
  }

  private lazy var _viewportsController = UIPageViewController(
    transitionStyle: .scroll,
    navigationOrientation: .horizontal,
    options: [.spineLocation: UIPageViewController.SpineLocation.mid]
  )
  
  private var _viewportsKeys = [UUID]()
  private var _currentKey: UUID? = nil
  
  private var _hud: MBProgressHUD? = nil
  
  private var _overlay = UIView()
  private var _kbdCommands:[UIKeyCommand] = []
  private var _kbdCommandsWithoutDiscoverability: [UIKeyCommand] = []
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    guard let window = view.window
    else {
      return
    }
    
    if window.screen === UIScreen.main {
      var insets = UIEdgeInsets.zero
      insets.bottom = LayoutManager.mainWindowKBBottomInset()
      // TODO: Bottom insets
      _overlay.frame = view.bounds.inset(by: insets)
    } else {
      _overlay.frame = view.bounds
    }
    
    _commandsHUD.setNeedsLayout()
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
    
    _overlay.isUserInteractionEnabled = false
    view.addSubview(_overlay)
    
    _commandsHUD.delegate = self
    _registerForNotifications()
    _setupKBCommands()
    
    _commandsHUD.delegate = self
    
    if _viewportsKeys.isEmpty {
      _createShell(userActivity: nil, animated: false)
    } else if let key = _currentKey {
      let term: TermController = SessionRegistry.shared[key]
      term.delegate = self
      term.bgColor = view.backgroundColor ?? .black
      _viewportsController.setViewControllers([term], direction: .forward, animated: false) { (didComplete) in
        if SmarterTermInput.shared.device == nil {
          DispatchQueue.main.async {
            self._attachInputToCurrentTerm()
          }
        }
      }
    }
  }
  
  let _commandsHUD = CommandsHUGView(frame: .zero)
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    _didBecomeKeyWindow()
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    if view.window?.isKeyWindow == true {
      DispatchQueue.main.async {
        SmarterTermInput.shared.reloadInputViews()
      }
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  func _registerForNotifications() {
    let nc = NotificationCenter.default
    
    nc.addObserver(self,
                   selector: #selector(_focusOnShell),
                   name: NSNotification.Name.BKUserAuthenticated,
                   object: nil)
    
    nc.addObserver(self,
                   selector: #selector(_didBecomeKeyWindow),
                   name: UIWindow.didBecomeKeyNotification,
                   object: nil)
    
    nc.addObserver(self, selector: #selector(_relayout),
                   name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate),
                   object: nil)
  }
  
  @objc func _didBecomeKeyWindow() {
    guard
      let window = view.window,
      window.isKeyWindow
    else {
      currentDevice?.blur()
      return
    }
    
    if SmarterTermInput.shared.superview !== view,
      window.screen === UIScreen.main {
      view.addSubview(SmarterTermInput.shared)
    }
    _focusOnShell()
    DispatchQueue.main.async {
      if let win = self.view.window?.windowScene?.windows.last,
        win !== self.view.window,
        win.screen === UIScreen.main,
        self._commandsHUD.superview == nil
      {
        self._commandsHUD.attachToWindow(inputWindow: win)
      }
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
    
    self._currentKey = term.meta.key
    _viewportsController.setViewControllers([term], direction: .forward, animated: animated) { (didComplete) in
      DispatchQueue.main.async {
        self._displayHUD()
        self._attachInputToCurrentTerm()
        if let completion = completion {
          completion(didComplete)
        }
      }
    }
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
    currentTerm()?.delegate = nil
    SessionRegistry.shared.remove(forKey: currentKey)
    _viewportsKeys.remove(at: idx)
    if _viewportsKeys.isEmpty {
      _createShell(userActivity: nil, animated: true)
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
    
    self._currentKey = term.meta.key
    
    _viewportsController.setViewControllers([term], direction: direction, animated: true) { (didComplete) in
      self._displayHUD()
      self._attachInputToCurrentTerm()
    }
  }
  
  @objc func _focusOnShell() {
    _attachInputToCurrentTerm()
    let input = SmarterTermInput.shared
    if !input.isFirstResponder {
      _ = input.becomeFirstResponder()
    } else {
      input.refreshInputViews()
    }
    // We should make input window key window
    if input.window?.isKeyWindow == false {
      input.window?.makeKeyAndVisible()
    }
  }
  
  func _attachInputToCurrentTerm() {
    if let device = currentDevice {
      device.attachInput(SmarterTermInput.shared)
      device.focus()
    }
  }
  
  var currentDevice: TermDevice? {
    currentTerm()?.termDevice
  }
  
  @objc public func moveAllShellsFromSpaceController(_ spaceController: SpaceController) {
    
  }
  
  @objc public func moveCurrentShellFromSpaceController(_ spaceController: SpaceController) {
    
  }
  
  func _displayHUD() {
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
    
    let hud = MBProgressHUD.showAdded(to: _overlay, animated: _hud == nil)
    
    hud.mode = .customView
    hud.bezelView.color = .darkGray
    hud.contentColor = .white
    hud.isUserInteractionEnabled = false
    hud.alpha = 0.6
    
    let pages = UIPageControl()
    pages.currentPageIndicatorTintColor = .cyan
    pages.numberOfPages = _viewportsKeys.count
    let pageNum = _viewportsKeys.firstIndex(of: term.meta.key)
    pages.currentPage = pageNum ?? NSNotFound
    
    hud.customView = pages
    
    let title = term.title?.isEmpty == true ? nil : term.title
    
    var sceneTitle = "[\(pageNum == nil ? 1 : pageNum! + 1) of \(_viewportsKeys.count)] \(title ?? "blink")"
    
    if params.rows == 0 && params.cols == 0 {
      hud.label.numberOfLines = 1
      hud.label.text = title ?? "blink"
    } else {
      let geometry = "\(params.cols)×\(params.rows)"
      hud.label.numberOfLines = 2
      hud.label.text = "\(title ?? "blink")\n\(geometry)"
      
      sceneTitle += " | " + geometry
    }
    
    _hud = hud
    hud.hide(animated: true, afterDelay: 1)
    
    view.window?.windowScene?.title = sceneTitle
  }
  
}

extension SpaceController: UIStateRestorable {
  func restore(withState state: UIState) {
    _viewportsKeys = state.keys
    _currentKey = state.currentKey
    if let bgColor = UIColor(codableColor: state.bgColor) {
      view.backgroundColor = bgColor
    }
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
    
    guard let termController = pageViewController.viewControllers?.first as? TermController
    else {
      return
    }
    _currentKey = termController.meta.key
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
    newCtrl.delegate = self
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
      title: title,
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
    
      _cmd("New Shell",      #selector(newShellAction),   "t", modifierFlags),
      _cmd("Close Shell",    #selector(closeShellAction), "w", modifierFlags),
      
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
    ]
  }
  
  @objc func focusOnShellAction() {
    SmarterTermInput.shared.reset()
    _focusOnShell()
  }
  
  @objc func newShellAction() {
    _createShell(userActivity: nil, animated: true)
  }
  
  @objc func closeShellAction() {
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
      .filter({ $0.scene?.activationState == .foregroundActive || $0.scene?.activationState == .foregroundInactive })
      .sorted(by: { $0.persistentIdentifier < $1.persistentIdentifier })
    
    guard
      sessions.count > 1,
      let session = view.window?.windowScene?.session,
      let idx = sessions.firstIndex(of: session)?.advanced(by: 1)
    else  {
      _ = SmarterTermInput.shared.resignFirstResponder()
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
      if nextSession.role == .windowExternalDisplay || window.isKeyWindow {
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
    guard
      let session = view.window?.windowScene?.session,
      session.role == .windowApplication // Can't close windows on external monitor
    else {
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
    if view.window?.windowScene?.session.role == .windowExternalDisplay {
      return
    }
    
    DispatchQueue.main.async {
      let storyboard = UIStoryboard(name: "Settings", bundle: nil)
      let vc = storyboard.instantiateViewController(identifier: "NavSettingsController")
      self.present(vc, animated: true, completion: nil)
    }
  }
  
}

extension SpaceController: CommandsHUDViewDelegate {
  @objc func currentTerm() -> TermController? {
    if let currentKey = _currentKey {
      return SessionRegistry.shared[currentKey]
    }
    return nil
  }
  
  @objc func spaceController() -> SpaceController? {
    return self
  }
}
