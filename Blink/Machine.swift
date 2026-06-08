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

  /// The session backing a slot.
  func session(for sessionKey: UUID) -> SuspendableSession? {
    SessionRegistry.shared.session(forKey: sessionKey)
  }

  func track(_ session: SuspendableSession) {
    SessionRegistry.shared.track(session: session)
  }

  func removeSession(for sessionKey: UUID) {
    SessionRegistry.shared.remove(forKey: sessionKey)
  }
}
