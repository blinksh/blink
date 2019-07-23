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
  
  override init() {
    super.init()
    _fsReadMetaIndex()
  }
  
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
    _fsRemove(forKey: key)
  }
  
  func remove(session: SuspendableSession?) {
    if let key = session?.meta.key {
      remove(forKey: key)
    }
  }
  
  @objc func suspend() {
    _sessionsIndex.forEach { self.suspendIfNeeded(session: $1) }
    _fsWriteMetaIndex()
  }
  
  func suspendIfNeeded(session: SuspendableSession) {
    guard !session.meta.isSuspended else {
      return
    }
    
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    session.suspendedSession(with: archiver)
    _fsWrite(archiver.encodedData, forKey: session.meta.key)
    session.meta.isSuspended = true
  }
  
  func resumeIfNeeded(session: SuspendableSession) {
    guard session.meta.isSuspended else {
      return
    }

    resume(forKey: session.meta.key)
  }
  
  func resume(forKey key: UUID) {
    guard
      let session = _sessionsIndex[key],
      let data = _fsRead(forKey: key),
      let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
    else {
        return
    }
    
    session.resume(with: unarchiver)
    session.meta.isSuspended = false
  }
  
  private func _fsSessionsFolder() throws -> URL {
    let fm = FileManager.default
    var supporDirUrl = try fm.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    
    supporDirUrl.appendPathComponent("sessions")
    var isDir:ObjCBool = false
    if !fm.fileExists(atPath: supporDirUrl.path, isDirectory: &isDir) {
      try fm.createDirectory(at: supporDirUrl, withIntermediateDirectories: true, attributes: nil)
    }
    
    return supporDirUrl
  }
  
  private func _fsSessionURL(_ key: UUID) throws -> URL {
    let sessionsFolderURL = try _fsSessionsFolder()
    var fileURL = sessionsFolderURL
    fileURL.appendPathComponent(key.uuidString)
    return fileURL
  }
  
  private func _fsRemove(forKey key: UUID) {
    let fm = FileManager.default
    do {
      let sessionURL = try _fsSessionURL(key)
      if fm.fileExists(atPath: sessionURL.path) {
        try fm.removeItem(at: sessionURL)
      }
    } catch let e {
      debugPrint(e)
    }
  }
  
  private func _fsWrite(_ data: Data, forKey key: UUID) {
    do {
      let sessionURL = try _fsSessionURL(key)
      try data.write(to: sessionURL, options: [.atomic, .completeFileProtection])
    } catch let e {
      debugPrint(e)
    }
  }
  
  private func _fsRead(forKey key: UUID) -> Data? {
   do {
      let sessionURL = try _fsSessionURL(key)
      let data = try Data(contentsOf: sessionURL)
      return data
    } catch let e {
      debugPrint(e)
      return nil
    }
  }
  
  private func _fsWriteMetaIndex() {
    let jsonEncoder = JSONEncoder()
    do {
      let data = try jsonEncoder.encode(_metaIndex)
      let sessionsFolder = try _fsSessionsFolder()
      let indexURL = sessionsFolder.appendingPathComponent("index.json")
      try data.write(to: indexURL, options: [.atomic])
    } catch let e {
      debugPrint(e)
    }
  }
  
  private func _fsReadMetaIndex() {
    do {
      let sessionsFolder = try _fsSessionsFolder()
      let indexURL = sessionsFolder.appendingPathComponent("index.json")
      let data = try Data(contentsOf: indexURL)
      let jsonDecoder = JSONDecoder()
      _metaIndex = try jsonDecoder.decode(type(of: _metaIndex), from: data)
    } catch let e {
      debugPrint(e)
    }
  }
}
