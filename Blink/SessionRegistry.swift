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

class SessionMeta: Codable {
  fileprivate(set) var key: UUID = UUID()
  fileprivate(set) var isSuspended: Bool = false
}

protocol SuspendableSession: class {
  var sessionRegistry: SessionRegistry? { get set }
  var meta: SessionMeta { get }
  init(meta: SessionMeta?)
  func resume(with unarchiver: NSKeyedUnarchiver)
  func suspendedSession(with archiver: NSKeyedArchiver)
}

extension SuspendableSession {
  func suspendIfNeeded() {
    sessionRegistry?.suspendIfNeeded(session: self)
  }
  
  func resumeIfNeeded() {
    sessionRegistry?.resumeIfNeeded(session: self)
  }
}


@objc class SessionRegistry: NSObject {
  private var _sessionsIndex: [UUID: SuspendableSession] = [:]
  private var _metaIndex: [UUID: SessionMeta] = [:]
  
  @objc public static let shared = SessionRegistry()
  
  func track(session: SuspendableSession) {
    let meta = session.meta
    let key = meta.key
    _metaIndex[key] = meta
    _sessionsIndex[key] = session
    session.sessionRegistry = self
  }
  
  subscript<T: SuspendableSession>(key: UUID) -> T {
    // 1. we already have it (same type)
    if let session = _sessionsIndex[key] as? T {
      return session
    }
    
    // 2. we have it only in meta index
    if let meta = _metaIndex[key] {
      meta.isSuspended = true
      let session = T(meta: meta)
      track(session: session)
      return session
    }
    
    // 3. creating new one
    let meta = SessionMeta()
    meta.key = key
    meta.isSuspended = true
    let session = T(meta: meta)
    track(session: session)
    return session
  }
  
  func remove(forKey key: UUID) {
    if let session = _sessionsIndex.removeValue(forKey: key) {
      session.sessionRegistry = nil
    }
    _metaIndex.removeValue(forKey: key)
    // TODO: remove from FS
  }
  
  func remove(session: SuspendableSession?) {
    if let key = session?.meta.key {
      remove(forKey: key)
    }
  }
  
  @objc func suspend() {
    _sessionsIndex.forEach { self.suspendIfNeeded(session: $1) }
    
  }
  
  func suspendIfNeeded(session: SuspendableSession) {
    let meta = session.meta
    guard
      !meta.isSuspended
    else {
      return
    }
    
  }
  
  func resumeIfNeeded(session: SuspendableSession) {
    let meta = session.meta
    guard
      meta.isSuspended
    else {
      return
    }

    resume(forKey: meta.key)
  }
  
  func resume(forKey key: UUID) {
    guard
      let session = _sessionsIndex[key],
      let data = _loadStateData(forKey: key),
      let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
    else {
        return
    }
    
    session.resume(with: unarchiver)
    session.meta.isSuspended = false
  }
  
  func writeState(session: SuspendableSession) {
    // write to FS
    session.meta.isSuspended = true
  }
  
  private func _loadStateData(forKey key: UUID) -> Data? {
    // load from FS
    return nil
  }
}
