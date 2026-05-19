////////////////////////////////////////////////////////////////////////////////
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

extension UUID {
  /// First segment of the UUID — a short, greppable token for logs.
  var short: String { String(uuidString.prefix(8)) }
}

/// A stable position inside a `Machine` that holds one session. A Slot's `id` is
/// independent of the `sessionKey` it holds: a session may move between Slots.
final class Slot {
  let id: UUID
  var sessionKey: UUID

  init(id: UUID = UUID(), sessionKey: UUID) {
    self.id = id
    self.sessionKey = sessionKey
  }
}

struct SlotState: Codable {
  var id: UUID
  var sessionKey: UUID
}

/// Serializable projection of a `Machine`: identity and structure, independent
/// of any live instance.
struct MachineState: Codable {
  var id: UUID
  var name: String
  var slots: [SlotState]
  var currentSlotID: UUID?
}

/// A stable, self-contained workspace: an ordered set of `Slot`s plus the
/// currently displayed one.
final class Machine {
  let id: UUID
  var name: String

  private(set) var slots: [Slot] = []
  private var currentSlotID: UUID? = nil

  private let log = Zuse.logger(.machine, "Machine")

  init(id: UUID = UUID(), name: String = "default") {
    self.id = id
    self.name = name
  }

  init(state: MachineState) {
    self.id = state.id
    self.name = state.name
    self.slots = state.slots.map { Slot(id: $0.id, sessionKey: $0.sessionKey) }
    self.currentSlotID = state.currentSlotID
    log.info("restored \(name) slots=\(slots.count)")
  }

  /// A Machine the user has not saved yet, marked by a `DEF`-prefixed id; its
  /// name is the id's first segment.
  static func makeDefault() -> Machine {
    let id = UUID(uuidString: "DEF" + UUID().uuidString.dropFirst(3))!
    return Machine(id: id, name: String(id.uuidString.prefix(8)))
  }

  /// Restore a Machine from its persisted structure, or nil if none on disk.
  static func restore(id: UUID) -> Machine? {
    MachineStore.shared.machineState(id: id).map { Machine(state: $0) }
  }

  var state: MachineState {
    MachineState(
      id: id,
      name: name,
      slots: slots.map { SlotState(id: $0.id, sessionKey: $0.sessionKey) },
      currentSlotID: currentSlotID
    )
  }

  /// Session keys in slot order. Assigning reconciles slots against the new
  /// list, preserving the identity of any slot whose key is unchanged.
  var sessionKeys: [UUID] {
    get { slots.map { $0.sessionKey } }
    set {
      var existing = Dictionary(slots.map { ($0.sessionKey, $0) },
                                uniquingKeysWith: { first, _ in first })
      slots = newValue.map { key in
        existing.removeValue(forKey: key) ?? Slot(sessionKey: key)
      }
      if let id = currentSlotID, !slots.contains(where: { $0.id == id }) {
        currentSlotID = nil
      }
    }
  }

  var isEmpty: Bool { slots.isEmpty }
  var count: Int { slots.count }

  func index(ofSession key: UUID) -> Int? {
    slots.firstIndex { $0.sessionKey == key }
  }

  func sessionKey(at index: Int) -> UUID? {
    slots.indices.contains(index) ? slots[index].sessionKey : nil
  }

  var currentSessionKey: UUID? {
    get {
      guard let id = currentSlotID else { return nil }
      return slots.first { $0.id == id }?.sessionKey
    }
    set {
      if let key = newValue, let slot = slots.first(where: { $0.sessionKey == key }) {
        currentSlotID = slot.id
      } else {
        currentSlotID = nil
      }
      persistStructure()
    }
  }

  /// Insert a new Slot for `sessionKey` right after the current one, or append
  /// it when there is no current Slot.
  func insertAfterCurrent(sessionKey: UUID) {
    let slot = Slot(sessionKey: sessionKey)
    if let id = currentSlotID, let idx = slots.firstIndex(where: { $0.id == id }) {
      slots.insert(slot, at: idx + 1)
    } else {
      slots.append(slot)
    }
    persistStructure()
  }

  func append(sessionKey: UUID) {
    slots.append(Slot(sessionKey: sessionKey))
    persistStructure()
  }

  func removeSlot(at index: Int) {
    guard slots.indices.contains(index) else { return }
    let removed = slots.remove(at: index)
    if removed.id == currentSlotID {
      currentSlotID = nil
    }
    persistStructure()
  }

  /// Persist this Machine's structure to its store.
  private func persistStructure() {
    try? MachineStore.shared.save(state)
  }

  // MARK: Sessions

  /// The session backing a slot, if it is already materialized.
  func session(for sessionKey: UUID) -> SuspendableSession? {
    SessionStore.shared.session(forKey: sessionKey)
  }

  /// The meta a slot's session is built from when it must be re-created.
  func meta(for sessionKey: UUID) -> SessionMeta {
    SessionStore.shared.meta(forKey: sessionKey)
  }

  func track(_ session: SuspendableSession) {
    SessionStore.shared.track(session: session)
  }

  func removeSession(for sessionKey: UUID) {
    SessionStore.shared.remove(forKey: sessionKey)
  }

  /// Stop a session's runtime; its archive is removed separately.
  func stopSession(for sessionKey: UUID) {
    session(for: sessionKey)?.stopSession()
  }

  // MARK: Lifecycle

  /// Suspend this Machine: archive its live sessions and persist its structure.
  func suspend() {
    log.info("suspend \(name) slots=\(slots.count)")
    for key in sessionKeys {
      if let session = session(for: key) {
        SessionStore.shared.suspendIfNeeded(session: session)
      }
    }
    persistStructure()
  }

  /// Wake this Machine's live sessions; each decides whether it actually resumes.
  func resume() {
    log.info("resume \(name) slots=\(slots.count)")
    for key in sessionKeys {
      session(for: key)?.resumeIfNeeded()
    }
  }
}

/// Persists a `MachineState` to disk, one file per Machine.
final class MachineStore {
  static let shared = MachineStore(directoryURL: MachineStore.defaultDirectoryURL())

  private let directoryURL: URL
  private let log = Zuse.logger(.machine, "MachineStore")

  init(directoryURL: URL) {
    self.directoryURL = directoryURL
  }

  private static func defaultDirectoryURL() -> URL {
    let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)) ?? FileManager.default.temporaryDirectory
    return base.appendingPathComponent("machines")
  }

  func save(_ state: MachineState) throws {
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(state)
    try data.write(to: url(forID: state.id),
                   options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    log.info("saved \(state.name) slots=\(state.slots.count)")
  }

  func machineState(id: UUID) -> MachineState? {
    guard let data = try? Data(contentsOf: url(forID: id)) else {
      log.debug("no state for \(id.short)")
      return nil
    }
    return try? JSONDecoder().decode(MachineState.self, from: data)
  }

  /// Destroy a Machine entirely: its sessions' archives and its stored state.
  func destroy(id: UUID) {
    log.info("destroy \(id.short)")
    machineState(id: id)?.slots.forEach { SessionStore.shared.remove(forKey: $0.sessionKey) }
    try? FileManager.default.removeItem(at: url(forID: id))
  }

  /// Remove session archives no machine references.
  func removeOrphanSessions() {
    SessionStore.shared.removeArchives(keeping: referencedSessionKeys())
  }

  private func referencedSessionKeys() -> Set<UUID> {
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directoryURL, includingPropertiesForKeys: nil) else { return [] }
    var keys = Set<UUID>()
    for file in files where file.pathExtension == "json" {
      if let data = try? Data(contentsOf: file),
         let state = try? JSONDecoder().decode(MachineState.self, from: data) {
        keys.formUnion(state.slots.map { $0.sessionKey })
      }
    }
    return keys
  }

  private func url(forID id: UUID) -> URL {
    directoryURL.appendingPathComponent("\(id.uuidString).json")
  }
}

// MARK: - Session layer

class SessionMeta: Codable {
  fileprivate(set) var key: UUID = UUID()
  // Used by the session to flag its status after SS operations
  var isSuspended: Bool = false
}

protocol SuspendableSession: class {
  var meta: SessionMeta { get }
  init(meta: SessionMeta?)
  // Wake if appropriate; the session decides whether it actually resumes.
  func resumeIfNeeded()
  func resume(with unarchiver: NSKeyedUnarchiver?)
  func suspendSession(with archiver: NSKeyedArchiver)
  // Tears the live session down; persistence is handled separately on suspend
  func stopSession()
}

/// Holds live sessions and their on-disk archives, keyed by session id. The
/// session layer the Machine builds on.
final class SessionStore {
  static let shared = SessionStore()

  private var _sessionsIndex: [UUID: SuspendableSession] = [:]
  private let log = Zuse.logger(.machine, "SessionStore")

  fileprivate func track(session: SuspendableSession) {
    _sessionsIndex[session.meta.key] = session
    log.debug("track \(session.meta.key.short)")
  }

  fileprivate func session(forKey key: UUID) -> SuspendableSession? {
    _sessionsIndex[key]
  }

  /// A meta for re-creating a slot's session; suspended only if an archive
  /// exists to restore from, otherwise fresh (started from a default payload).
  fileprivate func meta(forKey key: UUID) -> SessionMeta {
    let meta = SessionMeta()
    meta.key = key
    meta.isSuspended = hasArchive(forKey: key)
    return meta
  }

  fileprivate func hasArchive(forKey key: UUID) -> Bool {
    guard let url = try? _fsSessionURL(key) else { return false }
    return FileManager.default.fileExists(atPath: url.path)
  }

  fileprivate func remove(forKey key: UUID) {
    _fsRemove(forKey: key)
    _sessionsIndex.removeValue(forKey: key)
    log.debug("remove \(key.short)")
  }

  fileprivate func removeArchives(keeping keep: Set<UUID>) {
    let keep = keep.union(_sessionsIndex.keys)
    guard let folder = try? _fsSessionsFolder(),
          let files = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil) else { return }
    for file in files {
      guard let key = UUID(uuidString: file.lastPathComponent), !keep.contains(key) else { continue }
      _fsRemove(forKey: key)
      log.info("swept orphan session \(key.short)")
    }
  }

  fileprivate func suspendIfNeeded(session: SuspendableSession) {
    guard !session.meta.isSuspended else {
      return
    }

    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    session.suspendSession(with: archiver)

    // No live payload to snapshot — nothing to persist.
    guard session.meta.isSuspended else { return }

    _fsWrite(archiver.encodedData, forKey: session.meta.key)
    log.info("suspended session \(session.meta.key.short)")
  }

  func resumeIfNeeded(session: SuspendableSession) {
    guard session.meta.isSuspended else {
      return
    }

    // The archive is behind complete file protection; reading it while the
    // device is locked fails. Retry until protected data is available.
    guard UIApplication.shared.isProtectedDataAvailable else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak session] in
        guard let session = session else { return }
        SessionStore.shared.resumeIfNeeded(session: session)
      }
      return
    }

    // A read failure past the lock guard is permanent; pass nil so the session
    // runs its failure path rather than being left unresolved.
    log.info("resume session \(session.meta.key.short)")
    let unarchiver = _fsRead(forKey: session.meta.key).flatMap { try? NSKeyedUnarchiver(forReadingFrom: $0) }
    session.resume(with: unarchiver)
  }

  private var _fsSessionsFolderURL: URL? = nil

  private func _fsSessionsFolder() throws -> URL {
    if let fsSessionFolderURL = _fsSessionsFolderURL {
      return fsSessionFolderURL
    }

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

    _fsSessionsFolderURL = supporDirUrl

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
    } catch {
      return nil
    }
  }
}
