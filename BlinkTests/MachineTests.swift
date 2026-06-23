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

import XCTest
@testable import Blink

class MachineTests: XCTestCase {

  private func makeMachine() -> Machine {
    let machine = Machine(name: "prod")
    machine.sessionKeys = [UUID(), UUID()]
    machine.currentSessionKey = machine.sessionKeys.first
    return machine
  }

  private func assertSameStructure(_ a: MachineState, _ b: MachineState,
                                   file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(a.id, b.id, file: file, line: line)
    XCTAssertEqual(a.name, b.name, file: file, line: line)
    XCTAssertEqual(a.currentSlotID, b.currentSlotID, file: file, line: line)
    XCTAssertEqual(a.slots.map { $0.id }, b.slots.map { $0.id }, file: file, line: line)
    XCTAssertEqual(a.slots.map { $0.sessionKey }, b.slots.map { $0.sessionKey }, file: file, line: line)
  }

  func testStateRoundTripsThroughLiveMachine() {
    let original = makeMachine().state
    let rebuilt = Machine(state: original).state
    assertSameStructure(original, rebuilt)
  }

  func testStorePersistsAndLoads() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = MachineStore(directoryURL: dir)
    let state = makeMachine().state

    try store.save(state)
    let loaded = try XCTUnwrap(store.machineState(id: state.id))

    assertSameStructure(state, loaded)
  }

  func testStoreReturnsNilForUnknownID() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }

    let store = MachineStore(directoryURL: dir)
    XCTAssertNil(store.machineState(id: UUID()))
  }
}
