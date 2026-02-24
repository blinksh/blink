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


import Combine
import UserNotifications
import AVFoundation

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

protocol LayoutInsetsProvider: AnyObject {
  func provideInsets(for controller: TermController) -> UIEdgeInsets
}

private class ProxyView: UIView {
  var controlledView: UIView? = nil
  private var _cancelable: AnyCancellable? = nil
  private var _hasBeenPlaced: Bool = false  // TEST: Track if view has been placed
  private var _isTerminated: Bool = false   // TEST: Prevent re-placement after termination

  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)
    if superview == nil {
      _cancelable = nil
    }
  }

  override func didMoveToSuperview() {
    super.didMoveToSuperview()

    _cancelable = nil

    guard
      let parent = superview
    else {
      return
    }

    _cancelable = parent.publisher(for: \.frame).sink { [weak self] frame in
      guard let controlledView = self?.controlledView,
            controlledView.superview != nil
      else {
        return
      }
      controlledView.frame = frame
    }

    placeControlledView()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard
      let parent = superview,
      let controlledView = controlledView
    else {
      return
    }
    controlledView.frame = parent.frame
  }

  func removeControlledView() {
    // TEST: Hide instead of remove (for temporary switching)
    guard let controlledView = controlledView else { return }
    controlledView.isHidden = true
  }

  func destroyControlledView() {
    // TEST: Full removal for terminal termination
    guard let controlledView = controlledView else { return }
    controlledView.removeFromSuperview()
    _hasBeenPlaced = false
    _isTerminated = true  // Prevent any future re-placement
  }

  func prepareForWindowMove() {
    // TEST: Remove for window move but allow re-placement in new window
    guard let controlledView = controlledView else { return }
    controlledView.removeFromSuperview()
    _hasBeenPlaced = false
    // Note: Don't set _isTerminated - this is a move, not termination
  }

  func placeControlledView() {
    // TEST: Never place if terminal was terminated
    if _isTerminated { return }

    guard
      let parent = superview,
      let container = parent.superview,
      let controlledView = controlledView
    else {
      return
    }

    controlledView.frame = parent.frame

    // TEST: Place once per container, then just show/hide
    // If view is in a different container (window changed), we need to re-place
    if !_hasBeenPlaced || controlledView.superview !== container {
      if
        let sharedWindow = ShadowWindow.shared,
        container.window == sharedWindow {

        sharedWindow.layer.removeFromSuperlayer()
        container.addSubview(controlledView)
        sharedWindow.refWindow.layer.addSublayer(sharedWindow.layer)

      } else {
        container.addSubview(controlledView)
      }
      _hasBeenPlaced = true
    }

    // Show the view when placing
    controlledView.isHidden = false
  }
}

class TermController: UIViewController {
  private let _meta: SessionMeta
 
  private var _termDevice = TermDevice()
  private var _bag = Array<AnyCancellable>()
  private var _termView = TermView(frame: .zero)
  private var _proxyView = ProxyView(frame: .zero)
  private var _sessionParams: MCPParams = {
    let params = MCPParams()
    
    params.fontSize = BLKDefaults.selectedFontSize()?.intValue ?? 16
    params.fontName = BLKDefaults.selectedFontName()
    params.themeName = BLKDefaults.selectedThemeName()
    params.enableBold = BLKDefaults.enableBold()
    params.boldAsBright = BLKDefaults.isBoldAsBright()
    params.viewSize = .zero
    params.layoutMode = BLKDefaults.layoutMode().rawValue
    
    return params
  }()
  private var _bgColor: UIColor? = nil
  private var _fontSizeBeforeScaling: Int? = nil
  
  @objc public var viewIsLoaded: Bool = false
  
  @objc public var activityKey: String? = nil
  @objc public var termDevice: TermDevice { _termDevice }
  @objc weak var delegate: TermControlDelegate? = nil
  weak var layoutProvider: LayoutInsetsProvider? = nil
  @objc var sessionParams: MCPParams { _sessionParams }
  @objc var bgColor: UIColor? {
    get { _bgColor }
    set { _bgColor = newValue }
  }
  
  // State Properties for Input Management
  var isReady: Bool {
    _termDevice.view?.isReady ?? false
  }
  
  var isAttached: Bool {
    KBTracker.shared.input == _termDevice.view?.webView
  }
  
  override var isFirstResponder: Bool {
    _termDevice.view?.webView.isFirstResponder ?? false
  }
  
  
  private var _session: MCPSession? = nil
  
  required init(meta: SessionMeta? = nil) {
    _meta = meta ?? SessionMeta()
    super.init(nibName: nil, bundle: nil)
  }
  
  convenience init(sceneRole: UISceneSession.Role? = nil) {
    self.init(meta: nil)
    if sceneRole == .windowExternalDisplayNonInteractive {
      _sessionParams.fontSize = BLKDefaults.selectedExternalDisplayFontSize()?.intValue ?? 24
    }
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc public func toggleLayoutLock() {
    if sessionParams.layoutLocked {
      self.unlockLayout()
    } else {
      self.lockLayout()
    }
  }
  
  func placeToContainer() {
    _proxyView.placeControlledView()
  }

  func removeFromContainer() -> Bool {
    if KBTracker.shared.input == _termView.webView {
      return false
    }
    _proxyView.removeControlledView()
    return true
  }

  func prepareForWindowMove() {
    // TEST: Prepare terminal for move to different window
    _proxyView.prepareForWindowMove()
  }

  public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    if !coordinator.isAnimated {
      return
    }

    super.viewWillTransition(to: size, with: coordinator)
    
    coordinator.animate(alongsideTransition: nil) { _ in
      NotificationCenter.default.post(name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate), object: nil)
    }
  }
  
  public override func loadView() {
    super.loadView()
    _termDevice.delegate = self
    _termDevice.attachView(_termView)
    _termView.backgroundColor = _bgColor
    _proxyView.controlledView = _termView;
    _proxyView.isUserInteractionEnabled = false
    view = _proxyView
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    viewIsLoaded = true

    resumeIfNeeded()

    _termView.load(with: _sessionParams)
    
    let layoutMode = BKLayoutMode(rawValue: _sessionParams.layoutMode) ?? BKLayoutMode.default
    _termView.additionalInsets = layoutProvider?.provideInsets(for: self) ?? LayoutManager.buildSafeInsets(for: self, andMode: layoutMode)
    print("🔧 termView initialInsets: \(_termView.additionalInsets)")
    
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

    guard let window = view.window,
      let windowScene = window.windowScene,
      windowScene.activationState == .foregroundActive
    else {
      return
    }

    let layoutMode = BKLayoutMode(rawValue: _sessionParams.layoutMode) ?? BKLayoutMode.default
    _termView.additionalInsets = layoutProvider?.provideInsets(for: self) ?? LayoutManager.buildSafeInsets(for: self, andMode: layoutMode)
    // print("🔧 termView initialInsets: \(_termView.additionalInsets)")
    // let layoutMode = BKLayoutMode(rawValue: _sessionParams.layoutMode) ?? BKLayoutMode.default
    // print("🔧 Layout Mode: \(layoutMode)")
    // _termView.additionalInsets = LayoutManager.buildSafeInsets(for: self, andMode: layoutMode)
    //print("🔧 termView additionalInsets: \(_termView.additionalInsets)")
    _termView.layoutLockedFrame = _sessionParams.layoutLockedFrame
    _termView.layoutLocked = _sessionParams.layoutLocked
    _termView.setNeedsLayout()
  }
  
  public override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    _sessionParams.viewSize = view.bounds.size
  }
  
  @objc public func terminate() {
    NotificationCenter.default.post(name: .deviceTerminated, object: nil, userInfo: ["device": _termDevice])
    _proxyView.destroyControlledView()
    _termDevice.delegate = nil
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
      guard newSize != _sessionParams.fontSize else {
        return
      }
      _termView.setFontSize(newSize as NSNumber)
    default:  break
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
    _session?.delegate = nil
    _session = nil
  }
  
}

extension TermController: SessionDelegate {
  public func sessionFinished() {
    if _sessionParams.hasEncodedState() {
      _session?.delegate = nil
      _session = nil
      return
    }

    delegate?.terminalHangup(control: self)
  }
}

let _apiRoutes:[String: (MCPSession, String) -> AnyPublisher<String, Never>] = [
  "history.search": History.searchAPI,
  "completion.for": Complete.forAPI
]


/// Types of supported notifications
@objc enum BKNotificationType: NSInteger {
  case bell = 0
  case osc = 1
}

// MARK: - TermDeviceDelegate methods
extension TermController: TermDeviceDelegate {
  
  /**
   When a `ring-bell` notification has been received on `TermView` react to it by sounding a bell if the terminal that sent it
   is in focus and if it's not send a notification. Tapping the notification opens the session that sent it.
   
   Only reproduce haptic feedback on iPhones and if it's enabled.
   
   Enable/Disable standard OSC sequences & iTerm2 notifications
   */
  func viewDidReceiveBellRing() {
    
    if BLKDefaults.isPlaySoundOnBellOn() && _termView.isFocused() {
      AudioServicesPlaySystemSound(1103);
    }
  
    viewNotify(["title": "🔔 \(_termView.title ?? "")", "type": BKNotificationType.bell.rawValue])
    
    // Haptic feedback is only visible from iPhones
    if UIDevice.current.userInterfaceIdiom == .phone && !BLKDefaults.hapticFeedbackOnBellOff() {
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
  }
  
  /**
   Presents a UserNotification with the `title` & `body` values passed on `data`. Tapping on the notification opens the terminal that originated the notification. Also triggered when the terminal receives a standard `OSC` sequence & iTerm2-like notification.
   
   - Parameters:
    - data: Set the `title` and `body` String values to display those values in the notification banner. Set the `type`'s rawValue of `BKNotificationType` to identify the type of notification used.
   */
  func viewNotify(_ data: [AnyHashable : Any]!) {
    
    guard let notificationTypeRaw = data["type"] as? Int, let notificationType = BKNotificationType(rawValue: notificationTypeRaw) else {
      return
    }
        
    if notificationType  == .bell && (_termView.isFocused() || !BLKDefaults.isNotificationOnBellUnfocusedOn())
        || notificationType == .osc && !BLKDefaults.isOscNotificationsOn() {
       return
    }
    
    let content = UNMutableNotificationContent()
    content.title = (data["title"] as? String) ?? title ?? "Blink"
    content.body = (data["body"] as? String) ?? ""
    content.sound = .default
    content.threadIdentifier = meta.key.uuidString
    content.targetContentIdentifier = "blink://open-scene/\(view?.window?.windowScene?.session.persistentIdentifier ?? "")"
    
    let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound, .announcement]) { (granted, error) in
      if granted {
        center.add(req, withCompletionHandler: nil)
      }
    }
  }
  
  func apiCall(_ api: String!, andRequest request: String!) {
    guard
      let api = api,
      let session = _session,
      let call = _apiRoutes[api]
    else {
      return
    }

    weak var termView = _termView

    _ = call(session, request)
      .receive(on: RunLoop.main)
      .sink { termView?.apiResponse(api, response: $0) }
  }
  
  public func deviceIsReady() {
    startSession()
    
    // Input progression. When device becomes ready, check if we need to become first responder
    if isAttached {
      _becomeFirstResponder()
    }
  }
  
  func activateInput() {
    if !isAttached {
      _attachInput()
    }
    
    if isReady {
      _becomeFirstResponder()
    }
    // If not ready, wait for isReady call to trigger _becomeFirstResponder()
  }

  func resignInput() {
    guard isAttached && isReady else {
      return
    }

    guard let deviceView = _termDevice.view else { return }

    deviceView.webView.reportFocus(false)

    // It is key to reset here so when attached again, settings are synced and the keyboard state is properly reset.
    KBTracker.shared.attach(input: nil)

    _ = _termDevice.view?.webView.resignFirstResponder()
  }
  
  private func _attachInput() {
    guard let deviceView = _termDevice.view else { return }
    
    let input = KBTracker.shared.input
    
    if deviceView.browserView != nil {
      KBTracker.shared.attach(input: deviceView.browserView)
      _termDevice.attachInput(deviceView.browserView)
      _ = deviceView.browserView.becomeFirstResponder()
      if input != KBTracker.shared.input {
        input?.reportFocus(false)
      }
      return
    }

    KBTracker.shared.attach(input: deviceView.webView)
    _termDevice.attachInput(deviceView.webView)
  }
  
  private func _becomeFirstResponder() {
    guard let deviceView = _termDevice.view else { return }
    
    if !isAttached && !isReady{ return }
    
    deviceView.webView.reportFocus(true)
    _termDevice.focus()
    
    let input = KBTracker.shared.input

    if input != KBTracker.shared.input {
      input?.reportFocus(false)
    }

    _ = _termDevice.view?.webView.becomeFirstResponder()
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
  
  public func handleControl(_ control: String!) -> Void {
    _session?.handleControl(control)
  }
  
  public func deviceFocused() {
    view.setNeedsLayout()
  }
  
  public func viewController() -> UIViewController! {
    return self
  }
  
  public func xCallbackLineSubmitted(_ line: String, _ successUrl: URL? = nil) {
    _session?.enqueueXCallbackCommand(line, xCallbackSuccessUrl: successUrl)
  }
  
  public func lineSubmitted(_ line: String!) {
    _session?.enqueueCommand(line)
  }
  
  @objc public func setLayoutMode(layoutMode: BKLayoutMode) {
    self.sessionParams.layoutMode = layoutMode.rawValue
    
    NotificationCenter.default.post(name: NSNotification.Name(rawValue: LayoutManagerBottomInsetDidUpdate), object: nil)
    
    if (self.sessionParams.layoutLocked) {
      self.unlockLayout()
    }
    self.view?.setNeedsLayout()
  }
}

extension TermController: SuspendableSession {
  
  var meta: SessionMeta { _meta }
  
  var _decodableKey: String { "params" }
  
  func startSession() {
    guard _session == nil
    else {
      if view.bounds.size != _sessionParams.viewSize {
        _session?.sigwinch()
      }
      return
    }
    
    _session = MCPSession(
      device: _termDevice,
      andParams: _sessionParams)
    
    if let initialPrompt = WhatsNewInfo.mustDisplayInitialPrompt() {
      _termDevice.writeOutLn(initialPrompt)
    }
    
    _session?.delegate = self
    _session?.execute(withArgs: "")
    
    if view.bounds.size != _sessionParams.viewSize {
      _session?.sigwinch()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self._termView.setClipboardWrite(true)
    }
  }
  
  
  func resume(with unarchiver: NSKeyedUnarchiver) {
    guard
      unarchiver.containsValue(forKey: _decodableKey),
      let params = unarchiver.decodeObject(of: MCPParams.self, forKey: _decodableKey)
    else {
      return
    }
    
    _sessionParams = params
    _session?.sessionParams = params
   
    if _sessionParams.hasEncodedState() {
      _session?.execute(withArgs: "")
    }

    if view.bounds.size != _sessionParams.viewSize {
      _session?.sigwinch()
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      self._termView.setClipboardWrite(true)
    }
  }
  
  func suspendedSession(with archiver: NSKeyedArchiver) {
    guard
      let session = _session
    else {
      return
    }
    
    _termView.setClipboardWrite(false)
    _sessionParams.cleanEncodedState()
    session.suspend()
    
    let hasEncodedState = _sessionParams.hasEncodedState()
    
    debugPrint("has encoded state", hasEncodedState)
    archiver.encode(_sessionParams, forKey: _decodableKey)
  }
}

extension Notification.Name {
  static let deviceTerminated = Notification.Name("deviceTerminated")
}
