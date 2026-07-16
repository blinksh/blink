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


import XCTest
@testable import Blink

class SessionParamsTests: XCTestCase {

  // Secure coding persists the config fields, but the snapshot storage is
  // runtime-only transport and must not be written into the archive.
  func testSecureCodingPersistsConfigButNotSnapshot() {
    let mosh = MoshParams()
    mosh.ip = "192.168.1.1"
    mosh.port = "22"
    mosh.key = "id_ed25519"
    mosh.putEncodedState(Data([0x01, 0x02, 0x03]))

    let params = MCPParams()
    params.childSessionType = "mosh"
    params.childSessionParams = mosh

    let restored = secureRoundTrip(params)
    XCTAssertEqual(restored?.childSessionType, "mosh")

    let restoredMosh = restored?.childSessionParams as? MoshParams
    XCTAssertEqual(restoredMosh?.ip, "192.168.1.1")
    XCTAssertEqual(restoredMosh?.port, "22")
    XCTAssertEqual(restoredMosh?.key, "id_ed25519")
    XCTAssertNil(restoredMosh?.encodedStateStorage, "Snapshot must not be persisted")
  }

  // The snapshot passes through once: put makes it available, take returns and
  // drains it. MCPParams forwards to its child, so this also covers composition.
  func testSnapshotTransportDrainsOnce() {
    let params = MCPParams()
    params.childSessionParams = MoshParams()

    XCTAssertFalse(params.hasEncodedState())

    let snapshot = Data([0xAA, 0xBB])
    params.putEncodedState(snapshot)
    XCTAssertTrue(params.hasEncodedState())

    XCTAssertEqual(params.takeEncodedState(), snapshot)
    XCTAssertFalse(params.hasEncodedState(), "take must drain the snapshot")
    XCTAssertNil(params.takeEncodedState())
  }

  private func secureRoundTrip(_ params: MCPParams) -> MCPParams? {
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    archiver.encode(params, forKey: "params")
    let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
    return unarchiver?.decodeObject(of: MCPParams.self, forKey: "params")
  }
}
