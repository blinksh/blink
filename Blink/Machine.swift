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

  init(id: UUID = UUID(), name: String = "default") {
    self.id = id
    self.name = name
  }

  init(state: MachineState) {
    self.id = state.id
    self.name = state.name
    self.slots = state.slots.map { Slot(id: $0.id, sessionKey: $0.sessionKey) }
    self.currentSlotID = state.currentSlotID
  }

  /// A Machine the user has not saved yet, marked by a `DEF`-prefixed id; its
  /// name is the id's first segment.
  static func makeDefault() -> Machine {
    let id = UUID(uuidString: "DEF" + UUID().uuidString.dropFirst(3))!
    return Machine(id: id, name: String(id.uuidString.prefix(8)))
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
      guard let key = newValue,
            let slot = slots.first(where: { $0.sessionKey == key })
      else {
        currentSlotID = nil
        return
      }
      currentSlotID = slot.id
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
  }

  func append(sessionKey: UUID) {
    slots.append(Slot(sessionKey: sessionKey))
  }

  func removeSlot(at index: Int) {
    guard slots.indices.contains(index) else { return }
    let removed = slots.remove(at: index)
    if removed.id == currentSlotID {
      currentSlotID = nil
    }
  }

  // MARK: Sessions

  /// The session backing a slot, if it is already materialized.
  func session(for sessionKey: UUID) -> SuspendableSession? {
    SessionRegistry.shared.session(forKey: sessionKey)
  }

  /// The meta a slot's session is built from when it must be re-created.
  func meta(for sessionKey: UUID) -> SessionMeta {
    SessionRegistry.shared.meta(forKey: sessionKey)
  }

  func track(_ session: SuspendableSession) {
    SessionRegistry.shared.track(session: session)
  }

  func removeSession(for sessionKey: UUID) {
    SessionRegistry.shared.remove(forKey: sessionKey)
  }

  // MARK: Lifecycle

  /// Archive every live session this Machine holds.
  func suspend() {
    for key in sessionKeys {
      if let session = session(for: key) {
        SessionRegistry.shared.suspendIfNeeded(session: session)
      }
    }
  }
}

/// Persists a `MachineState` to disk, one file per Machine.
final class MachineStore {
  static let shared = MachineStore(directoryURL: MachineStore.defaultDirectoryURL())

  private let directoryURL: URL

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
  }

  func machineState(id: UUID) -> MachineState? {
    guard let data = try? Data(contentsOf: url(forID: id)) else { return nil }
    return try? JSONDecoder().decode(MachineState.self, from: data)
  }

  func remove(id: UUID) {
    try? FileManager.default.removeItem(at: url(forID: id))
  }

  private func url(forID id: UUID) -> URL {
    directoryURL.appendingPathComponent("\(id.uuidString).json")
  }
}
