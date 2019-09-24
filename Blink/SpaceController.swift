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

class SpaceController: UICollectionViewController {
  
  struct UIState: UserActivityCodable {
    var keys: [UUID] = []
    var currentKey: UUID? = nil
    var bgColor:CodableColor? = nil
    
    static var activityType: String { "space.ctrl.ui.state" }
  }
  
  private var _currentKey: UUID? = nil
  
  private var _hud: MBProgressHUD? = nil
  
  private var _kbdCommands:[UIKeyCommand] = []
  private var _kbdCommandsWithoutDiscoverability: [UIKeyCommand] = []
  private let _dataSource = SpaceDataSource()
  
  init() {
    super.init(collectionViewLayout: UICollectionViewFlowLayout())
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    debugPrint("willDisplay", indexPath)
  }
  
  var _isTransitioning: Bool = false
  override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
    debugPrint("didEndDisplaying", indexPath)
    guard
      _isTransitioning == false,
      let cell = collectionView.visibleCells.first as? TermCell,
      let term = cell.term,
      _currentKey != term.meta.key,
      SmarterTermInput.shared.isFirstResponder
    else {
      return
    }
    _currentKey = term.meta.key
    _attachInputToCurrentTerm()
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    guard let window = view.window
    else {
      return
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
  
    collectionView.allowsMultipleSelection = false
    collectionView.showsVerticalScrollIndicator = false
    collectionView.showsHorizontalScrollIndicator = false

    collectionView.minimumZoomScale = 0.1
    collectionView.maximumZoomScale = 5
    collectionView.keyboardDismissMode = .interactive
    collectionView.isDirectionalLockEnabled = true
    collectionView.contentInsetAdjustmentBehavior = .never
    collectionView.isPagingEnabled = true
    collectionView.alwaysBounceHorizontal = true
    collectionView.dropDelegate = self
    collectionView.dataSource = _dataSource
    
    collectionView.register(TermCell.self, forCellWithReuseIdentifier: TermCell.identifier)
    
    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    configuration.interSectionSpacing = 0
    configuration.scrollDirection = .horizontal
    
    let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak collectionView] (_, env) -> NSCollectionLayoutSection? in
      guard let collectionView = collectionView
      else {
          return nil
      }
      
      let bounds = collectionView.bounds
      
      let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(bounds.size.width), heightDimension: .absolute(bounds.size.height))
      let item = NSCollectionLayoutItem(layoutSize: itemSize)
      item.contentInsets = .zero
      
      let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(bounds.size.width), heightDimension: .absolute(bounds.size.height))
      let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
      group.interItemSpacing = .fixed(0);
      
      let section = NSCollectionLayoutSection(group: group)
      section.interGroupSpacing = 0
      
      let contentInsets = env.container.effectiveContentInsets
      
      section.contentInsets = NSDirectionalEdgeInsets(
        top: -contentInsets.top,
        leading: -contentInsets.leading,
        bottom: -contentInsets.bottom,
        trailing: -contentInsets.trailing
      )
      
      return section
    }, configuration: configuration)
    collectionView.setCollectionViewLayout(layout, animated: false)
    
    _dataSource.cellBuilder = { [weak self] (collectionView, indexPath, key) -> UICollectionViewCell? in
      debugPrint("cellForIndexPathh", indexPath, key)
      guard
        let self = self,
        let termCell = collectionView.dequeueReusableCell(withReuseIdentifier: TermCell.identifier, for: indexPath) as? TermCell
      else {
        return nil
      }
      
      
      termCell.backgroundColor = self.view.backgroundColor
      let term: TermController = SessionRegistry.shared[key]
      term.delegate = self
      self.addChild(term)
      termCell.term = term
      term.didMove(toParent: self)
      
      return termCell;
    }
    
    _commandsHUD.delegate = self
    _registerForNotifications()
    _setupKBCommands()
    
    _commandsHUD.delegate = self
    
    if _dataSource.isEmpty {
      _dataSource.setInitialData(data: [UUID()])
      return
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated);
    
    guard
      let idx = _dataSource.index(for: _currentKey),
      let collectionView = collectionView
    else {
      return
    }
    collectionView.repage(for: view.bounds.size, page: idx, totalPages: _dataSource.count)
  }
  
  public override func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
    collectionView.isScrollEnabled = false
  }
  
  public override func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
    collectionView.isScrollEnabled = true
  }
  
  override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    currentTerm()?.termDevice.view?.dropTouches()
  }
  
  let _commandsHUD = CommandsHUGView(frame: .zero)
  
  public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    _didBecomeKeyWindow()
  }
  
  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    _isTransitioning = true
    super.viewWillTransition(to: size, with: coordinator)

    collectionView.panGestureRecognizer.dropTouches()
    
    if let scrollView = collectionView {
      let page = _dataSource.index(for: _currentKey)
      let totalPages = _dataSource.count

      coordinator.animateAlongsideTransition(in: view, animation: { (t) in
        scrollView.repage(for: size, page: page, totalPages: totalPages, animated: false)
      }) { (ctx) in
        self._isTransitioning = false
      }
    }
    
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
    guard let window = view.window else {
      currentDevice?.blur()
      return
    }
    
    if window.isKeyWindow {
      if SmarterTermInput.shared.superview !== self.view
        && window.screen === UIScreen.main {
          view.addSubview(SmarterTermInput.shared)
        }
      _focusOnShell()
      DispatchQueue.main.async {
        if let win = self.view.window?.windowScene?.windows.last, win !== self.view.window,
          self._commandsHUD.superview == nil {
          self._commandsHUD.attachToWindow(inputWindow: win)
        }
      }
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
  
  func _createShell(animated: Bool) {
    
    if collectionView.isDragging || collectionView.isDecelerating {
      return
    }
    
    let term: TermController = SessionRegistry.shared[UUID()]
    term.delegate = self
    
    _dataSource.insert(items: [term.meta.key], after: _currentKey)
    
    let ds = _dataSource
    
    if let collectionView = collectionView {
      _dataSource.apply(collectionView: collectionView) {
        let page = ds.index(for: term.meta.key)
        let totalPages = ds.count
        collectionView.repage(for: collectionView.bounds.size, page: page, totalPages: totalPages, animated: animated)
      }
    }
  }
  
  func _closeCurrentSpace() {
    currentTerm()?.terminate()
    _removeCurrentSpace()
  }
  
  
  private func _removeCurrentSpace() {
    guard
      let currentKey = _currentKey
    else {
      return
    }
    currentTerm()?.delegate = nil
    SessionRegistry.shared.remove(forKey: currentKey)
    _dataSource.delete(items: [currentKey])
    
    if _dataSource.isEmpty {
      _currentKey = nil
      _dataSource.insert(items: [UUID()], after: nil)
    }

    _dataSource.apply(collectionView: collectionView)
  }
  
  @objc func _focusOnShell() {
    if let idx = collectionView.indexPathsForVisibleItems.first,
      let key = _dataSource.keyFor(indexPath: idx) {
      _currentKey = key
    }
    _attachInputToCurrentTerm()
    if !SmarterTermInput.shared.isFirstResponder {
      _ = SmarterTermInput.shared.becomeFirstResponder()
    }
  }
  
  func _attachInputToCurrentTerm() {
    currentDevice?.attachInput(SmarterTermInput.shared)
    currentDevice?.focus()
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
      view.window?.backgroundColor = bgColor
    }
    
    let hud = MBProgressHUD.showAdded(to: view, animated: _hud == nil)
    
    hud.mode = .customView
    hud.bezelView.color = .darkGray
    hud.contentColor = .white
    hud.isUserInteractionEnabled = false
    hud.alpha = 0.6
    
    let pages = UIPageControl()
    pages.currentPageIndicatorTintColor = .cyan
    pages.numberOfPages = _dataSource.count
    let pageNum = _dataSource.uiIndexOf(key: term.meta.key)
    pages.currentPage = pageNum ?? NSNotFound
    
    hud.customView = pages
    
    let title = term.title?.isEmpty == true ? nil : term.title
    
    var sceneTitle = "[\(pageNum == nil ? 1 : pageNum! + 1) of \(_dataSource.uiData.count)] \(title ?? "blink")"
    
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
    _dataSource.setInitialData(data: state.keys)
    _currentKey = state.currentKey
    if let bgColor = UIColor(codableColor: state.bgColor) {
      view.backgroundColor = bgColor
    }
  }
  
  func dumpUIState() -> UIState {
    UIState(keys: _dataSource.uiData,
            currentKey: _currentKey,
            bgColor: CodableColor(uiColor: view.backgroundColor)
    )
  }
  
  @objc static func onDidDiscardSceneSessions(_ sessions: Set<UISceneSession>) {
    let registry = SessionRegistry.shared
    for session in sessions {
      guard
        let uiState = UIState(userActivity: session.stateRestorationActivity)
      else {
        continue
      }
      
      uiState.keys.forEach { registry.remove(forKey: $0) }
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
    if collectionView.isDragging || collectionView.isDecelerating {
      return
    }
    
    SmarterTermInput.shared.reset()
    _focusOnShell()
  }
  
  @objc func newShellAction() {
    _createShell(animated: true)
  }
  
  @objc func closeShellAction() {
    _closeCurrentSpace()
  }
  
  private func _moveToShell(idx: Int) {
    let viewPorts = _dataSource.uiData
    guard
      idx >= viewPorts.startIndex,
      idx < viewPorts.endIndex
    else {
      return
    }
    
    let id = viewPorts[idx]
    
    if let path = _dataSource.indexPath(for: id) {
      collectionView.scrollToItem(at: path, at: .left, animated: true)
    }
  }
  
  private func _advanceShell(by: Int) {
    guard
      let idx = _dataSource.index(for: _currentKey)?.advanced(by: by)
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
    let sessions = Array(app.openSessions).filter({$0.scene?.activationState == .foregroundActive})
      .sorted(by: {(a, b) in
      a.persistentIdentifier < b.persistentIdentifier
    })

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

extension SpaceController: UICollectionViewDropDelegate {
  
  func collectionView(_ collectionView: UICollectionView, dropSessionDidEnter session: UIDropSession) {
//    collectionView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
//    collectionView.isPagingEnabled = false
  }
  
  func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
//    collectionView.transform = CGAffineTransform.identity
  }
  
  func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
//    collectionView.transform = CGAffineTransform.identity
//    collectionView.isPagingEnabled = true
  }
  
  func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
    
  }
  
  func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
    return true
  }
  
  
  func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
//    collectionView.
    
    return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
  }
  
  func collectionView(_ collectionView: UICollectionView, dropPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
//    let cell = collectionView.cellForItem(at: indexPath) as! TermCell
    let previewParameters = UIDragPreviewParameters()
//    previewParameters.visiblePath = UIBezierPath(rect: cell.clippingRectForPhoto)
    return previewParameters
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
