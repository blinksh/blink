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
import ArgumentParser


struct SSHCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    // Optional abstracts and discussions are used for help output.
    abstract: "A LibSSH SSH client (remote login program)",
    discussion: """
    ssh (SSH client) is a program for logging into a remote machine and for executing commands on a remote machine. It is intended to replace rlogin and rsh, and provide secure encrypted communications between two untrusted hosts over an insecure network.

    ssh connects and logs into the specified hostname (with optional user name). The user must prove his/her identity to the remote machine using one of several methods depending on the protocol version used (see below).
    """,

    // Commands can define a version for automatic '--version' support.
    version: "1.0.0")

  // Port forwarding options
  @Option(name: .customShort("L"),
          help: "<localport>:<bind_address>:<remoteport> Specifies that the given port on the local (client) host is to be forwarded to the given host and port on the remote side.",
          transform: {  try PortForwardInfo($0) })
  var localPortForward: PortForwardInfo?

  // Reverse Port forwarding
  @Option(name:  [.customShort("R")],
          help: "port:host:hostport Specifies that the given port on the remote (server) host is to be forwarded to the given host and port on the local side.",
          transform: { try PortForwardInfo($0) })
  var reversePortForward: PortForwardInfo?

  // Verbosity levels
  // (Magic) When a flag is of type Int, the value is parsed as a count of the number of times that the flag is specified.
  @Flag(name: .shortAndLong)
  var verbose: Int

  @Option(name: [.customShort("O")],
          help: "Control an active connection multiplexing master process",
          transform: {
            try SSHControlCommands(rawValue: $0) ?? {
              throw ArgumentParser.ValidationError("Unknown control command.")
            }()

  } )
  var control: SSHControlCommands?

  @Flag(name: [.customShort("N")],
        help: "Do not execute a remote command. This is useful for just forwarding ports.")
  var noExecuteShell: Bool = false
  var startsSession: Bool { get {
    // A session is started if there is no "noCommands" flag, or if the command is not a control one.
    return !noExecuteShell && control == nil
  }}

  // Login name
  @Option(name: [.customShort("l")],
          help: "Login name. This option can also be specified at the host")
  var loginName: String?

  // Jumps
  @Option(name:  [.customShort("J")],
          help: "Jump Hosts in a comma separated list")
  var proxyJump: String?

  // Stdio forward
  @Option(name: [.customShort("W")],
          help: "Forward stdio to the specified destination",
          transform: { try StdioForwardInfo($0) })
  var stdioHostAndPort: StdioForwardInfo?

  @Option(name: [.customShort("o")],
          help: "Secondary connection options in config file format.")
  var options: [String] = []
  var connectionOptions: Result<ConfigFileOptions, Error> {
    get { Result { try ConfigFileOptions(options) } }
  }

  // TODO Constraint things like port. Perform some validation
  // TODO Special -o commands - send env variables, etc...
  // TODO -G print configuration
  // TODO -F customize config file
  // TODO -t request tty. And the opposite, just launch in background.
  // TODO Disable host key check

  // SSH Port
  @Option(name: [.customLong("port"), .customShort("p")],
          help: "Specifies the port to connect to on the remote host.")
  var customPort: UInt16?

  // Identity
  @Option(name: [.customShort("i")],
          help: """
  Selects a file from which the identity (private key) for public key authentication is read. The default is ~/.ssh/id_dsa, ~/.ssh/id_ecdsa, ~/.ssh/id_ed25519 and ~/.ssh/id_rsa.  Identity files may also be specified on a per-host basis in the configuration pane in the Settings of Blink.
  """)
  var identityFile: String?

  // Connect to User at Host
  @Argument(help: "[user@]host[#port]")
  var userAtHost: String
  var host: String {
    get {
      let comps = userAtHost.components(separatedBy: "@")
      return comps.count > 1 ? comps[1] : comps[0]
    }
  }
  var user: String? {
    get {
      // Login name preference over user@host
      if let user = loginName {
        return user
      }
      let comps = userAtHost.components(separatedBy: "@")
      return comps.count > 1 ? comps[0] : nil
    }
  }
  var port: UInt16? {
    get {
      if let port = customPort {
        return port
      }
      let comps = userAtHost.components(separatedBy: "#")
      return comps.count > 1 ? UInt16(comps[1]) : nil
    }
  }

  @Argument(parsing: .unconditionalRemaining,
            help: "command")
  //@Argument(help: "command")
  fileprivate var cmd: [String] = []
  var command: [String] {
    get {
      if cmd.first == "--" {
        return Array(cmd.dropFirst())
      } else {
        return cmd
      }
    }
  }

  func run() throws {
  }

  func validate() throws {
    let _ = try connectionOptions.get()
  }
}

struct ConfigFileOptions {
  var proxyCommand: String?
  var compression: Bool?
  var compressionLevel: UInt?
  var controlMaster: Bool = true

  init(_ options: [String]) throws {
    for o in options {
      let option = o.components(separatedBy: "=")
      if option.count != 2 {
        throw ValidationError("\(option[0]) missing value")
      }
      switch option[0].lowercased() {
      case "proxycommand":
        self.proxyCommand = option[1]
      case "compression":
        compression = try ConfigFileOptions.yesNoValue(option[1], name: "compression")
      case "compressionlevel":
        guard let level = UInt(option[1]) else {
          throw ValidationError("Compression level is not a number")
        }
        if !(level > 0 && level < 10) {
          throw ValidationError("Compression level must be between 1-9")
        }
        compressionLevel = level
      case "controlmaster":
        controlMaster = try ConfigFileOptions.yesNoValue(option[1], name: "controlmaster")
      default:
        throw ValidationError("Unknown option \(option[0])")
      }
    }
  }

  fileprivate static func yesNoValue(_ str: String, name: String) throws -> Bool {
    switch str.lowercased() {
    case "yes":
      return true
    case "no":
      return false
    default:
      throw ValidationError("Value \(name) should be yes/no")
    }
  }
}

struct PortForwardInfo: Equatable {
  let localPort: UInt16
  let bindAddress: String
  let remotePort: UInt16

  init(_ pattern: String) throws {
    let comps = pattern.components(separatedBy: ":")
    if comps.count != 3 {
      throw ValidationError("Missing <localport>:<bind_address>:<remoteport> for port forwarding.")
    }

    guard let localPort = UInt16(comps[0]) else {
      throw ValidationError("Invalid port \(comps[0])")
    }
    self.localPort = localPort

    self.bindAddress = comps[1]

    guard let remotePort = UInt16(comps[2]) else {
      throw ValidationError("Invalid port \(comps[2])")
    }
    self.remotePort = remotePort
  }
}

struct StdioForwardInfo {
  let bindAddress: String
  let remotePort: UInt16

  init(_ pattern: String) throws {
    let comps = pattern.components(separatedBy: ":")
    if comps.count != 2 {
      throw ValidationError("Missing <bind_address>:<remoteport> for stdio forwarding.")
    }

    self.bindAddress = comps[0]

    guard let remotePort = UInt16(comps[1]) else {
      throw ValidationError("Invalid port \(comps[1])")
    }
    self.remotePort = remotePort
  }
}

enum SSHControlCommands: String {
  case forward = "forward"
  case exit = "exit"
  case cancel = "cancel"
  case stop = "stop"
}
