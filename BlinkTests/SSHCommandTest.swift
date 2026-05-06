//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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
import BlinkConfig

@testable import Blink

final class SSHCommandTest: XCTestCase {
  func testSSHCommandParams() throws {
    var cmd: SSHCommand
    XCTAssertThrowsError(try SSHCommand.parse(["-t", "-T", "user@host"]))
    XCTAssertThrowsError(try SSHCommand.parse(["-o", "ForwardAgent", "yes", "user@host"]))
    cmd = try SSHCommand.parse(["-L", "11:forward:00", "-o", "ForwardAgent=yes", "user@host","-vv", "-p", "2222", "-L", "forward", "--", "cat", "-v", "hello"])
    XCTAssertTrue(cmd.customPort == 2222)
    XCTAssertTrue(cmd.command == ["cat", "-v", "hello"])
    XCTAssertTrue(cmd.localForward.count == 2)
    // Resolved at the SSH Config level
    XCTAssertTrue(cmd.agentForward == false)
    XCTAssertTrue(cmd.verbosity == 2)
  }

  //   -o "SetEnv=FOO=bar"        ["-o", "SetEnv=FOO=bar"]    outer pair stripped
  //   -o SetEnv="FOO=bar"        ["-o", "SetEnv=\"FOO=bar\""] inner quotes kept
  //   -o SetEnv='FOO=bar'        ["-o", "SetEnv='FOO=bar'"]   inner quotes kept
  //   -o SetEnv=FOO=bar          ["-o", "SetEnv=FOO=bar"]
  //   -o "SetEnv=A=1 B=2"        ["-o", "SetEnv=A=1 B=2"]    space survives quoting
  //   -o SetEnv="A=1 B=2"        ["-o", "SetEnv=\"A=1", "B=2\""]  UNRECOVERABLE:
  //      inner quote isn't recognized, so the embedded space splits the token.
  //      Users must quote the whole `-o` argument for that case.

  func testOptionsParsing() throws {
    // Bare, double-quoted, single-quoted, and ProxyCommand-with-`=`.
    XCTAssertEqual(try SSHCommand.parse(["-o", "SetEnv=FOO=bar", "user@host"])
                     .sshOptions()["setenv"] as? [String], ["FOO=bar"])
    XCTAssertEqual(try SSHCommand.parse(["-o", "SetEnv=\"FOO=bar\"", "user@host"])
                     .sshOptions()["setenv"] as? [String], ["FOO=bar"])
    XCTAssertEqual(try SSHCommand.parse(["-o", "SetEnv='FOO=bar'", "user@host"])
                     .sshOptions()["setenv"] as? [String], ["FOO=bar"])
    XCTAssertEqual(try SSHCommand.parse(["-o", "ProxyCommand=ssh --foo=bar jump", "user@host"])
                     .sshOptions()["proxycommand"] as? String, "ssh --foo=bar jump")

    // Repeated -o accumulates for list-valued keys (SetEnv, SendEnv, ...).
    let multi = try SSHCommand.parse([
      "-o", "SetEnv=FOO=1", "-o", "SetEnv=BAR=2",
      "-o", "SendEnv=A",    "-o", "SendEnv=B",
      "user@host",
    ])
    XCTAssertEqual(try multi.sshOptions()["setenv"] as? [String], ["FOO=1", "BAR=2"])
    XCTAssertEqual(try multi.sshOptions()["sendenv"] as? [String], ["A", "B"])

    // Whole-arg quoted with embedded space: SSHCommand keeps the value intact;
    // BKSSHHost.castList performs the final ["A=1", "B=2"] split.
    let spaced = try SSHCommand.parse(["-o", "SetEnv=A=1 B=2", "user@host"])
    XCTAssertEqual(try spaced.sshOptions()["setenv"] as? [String], ["A=1 B=2"])
    XCTAssertEqual(try spaced.bkSSHHost().setEnv, ["A=1", "B=2"])

    // Malformed: no separator, empty value, empty key.
    for bad in ["JustAKey", "SetEnv=", "=oops"] {
      XCTAssertThrowsError(try SSHCommand.parse(["-o", bad, "user@host"]))
    }
  }
}
