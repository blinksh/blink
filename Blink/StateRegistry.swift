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

// TODO: Fill with data
public class State: Codable {
}

// TODO: Fill with data
public class StateMeta: Codable {
  var key: String = UUID().uuidString
  var title: String? = nil
  var suspended: Bool = false
}

public class StateViewController: UIViewController {
  private var _meta: StateMeta
  public var meta: StateMeta { get { return _meta } }
  public weak var stateRegistry: StateRegistry? = nil
  
  init(meta: StateMeta? = nil) {
    _meta = meta ?? StateMeta()
    super.init(nibName: nil, bundle: nil)
  }
  
  public override var title: String? {
    get { return meta.title }
    set { meta.title = newValue }
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    resumeIfNeeded()
  }
  
  public func suspendIfNeeded() {
    guard
      !meta.suspended,
      let registry = stateRegistry else {
        return
    }
    registry.writeState(meta: meta, state: State())
  }
  
  public func resumeIfNeeded() {
    guard
      meta.suspended,
      let registry = stateRegistry
      else {
        return
    }
    
    registry.resume(forKey: meta.key)
  }
  
  func resumeWithState(state: State?) {
    // Should be implemented in subclasses
  }
}


@objc public class StateRegistry: NSObject {
  private var _controllersIndex: [String: StateViewController] = [:]
  private var _metaIndex: [String: StateMeta] = [:]
  
  @objc public static let shared = StateRegistry()
  
  @objc func track(controller: StateViewController) {
    let meta = controller.meta
    let key = meta.key
    _metaIndex[key] = meta
    _controllersIndex[key] = controller
    controller.stateRegistry = self
  }
  
  @objc func get(forKey key: String) -> StateViewController? {
    if let ctrl = _controllersIndex[key] {
      return ctrl
    }
    
    // TODO load
    return nil
  }
  
  @objc func remove(forKey key: String) {
    if let ctrl = _controllersIndex.removeValue(forKey: key) {
      ctrl.stateRegistry = nil
    }
    _metaIndex.removeValue(forKey: key)
    // TODO: remove from FS
  }
  
  @objc func remove(controller: StateViewController?) {
    if let key = controller?.meta.key {
      remove(forKey: key)
    }
  }
  
  @objc func suspend() {
    _controllersIndex.values.forEach { $0.suspendIfNeeded() }
  }
  
  @objc func resume(forKey key: String) {
    guard
      let ctrl =  _controllersIndex[key]
      else {
        return
    }
    let state = _loadState(forKey: key)
    ctrl.resumeWithState(state: state)
    ctrl.meta.suspended = false
  }
  
  func writeState(meta: StateMeta, state: State) {
    // write to FS
    meta.suspended = true
  }
  
  func _loadState(forKey key: String) -> State? {
    // load from FS
    return nil
  }
}
