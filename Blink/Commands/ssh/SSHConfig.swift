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


fileprivate let Version = "1.0.0"

struct SSHCommand: ParsableCommand {
  static var configuration = CommandConfiguration(
    // Optional abstracts and discussions are used for help output.
    abstract: "A LibSSH SSH client (remote login program)",
    discussion: """
    ssh (SSH client) is a program for logging into a remote machine and for executing commands on a remote machine. It is intended to replace rlogin and rsh, and provide secure encrypted communications between two untrusted hosts over an insecure network.

    ssh connects and logs into the specified hostname (with optional user name). The user must prove his/her identity to the remote machine using one of several methods depending on the protocol version used (see below).
    """,

    // Commands can define a version for automatic '--version' support.
    version: Version)

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

  @Option(
    name: [.customShort("O", allowingJoined: true)],
    help: .init(
      "Control an active connection multiplexing master process. Valid commands: (\(SSHControlCommands.allCases.map(\.rawValue).joined(separator: ", ")))",
     valueName: "ctl_cmd"
   )
  )
  var control: SSHControlCommands?

  @Flag(name: [.customShort("N")],
        help: "Do not execute a remote command. This is useful for just forwarding ports.")
  var noRemoteCommand: Bool = false
  var startsSession: Bool { get {
    control == nil && !noRemoteCommand && stdioHostAndPort == nil
  }}
  var blocks: Bool { get {
    stdioHostAndPort != nil || control == nil
  }}
//  var startsSession: Bool { get {
//    // A session is started if there is no "noCommands" flag, or if the command is not a control one.
//    return !noExecuteShell
//  }}
//  var blocks: Bool { get {
//    return stdioHostAndPort == nil && !noExecuteShell &&
//  }}

  // Login name
  @Option(
    name: [.customShort("l", allowingJoined: true)],
    help: .init(
      "Login name. This option can also be specified at the host",
      valueName: "login_name"
    )
  )
  var loginName: String?

  // Jumps
  @Option(
    name: [.customShort("J")],
    help: .init(
      "Jump Hosts in a comma separated list",
      valueName: "destination"
    )
  )
  var proxyJump: String?

  // Stdio forward
  @Option(name: [.customShort("W")],
          help: .init(
            "Forward stdio to the specified destination",
            valueName: "host:port"
          ),
          transform: { try StdioForwardInfo($0) })
  var stdioHostAndPort: StdioForwardInfo?

  @Option(
    name: [.customShort("o", allowingJoined: true)],
    help: .init(
      "Secondary connection options in config file format.",
      valueName: "option"
      )
  )
  var options: [String] = []
  var connectionOptions: Result<ConfigFileOptions, Error> {
    Result { try ConfigFileOptions(options) }
  }

  // TODO Constraint things like port. Perform some validation
  // TODO Special -o commands - send env variables, etc...
  // TODO -F customize config file
  // TODO Disable host key check
  @Flag(name: [.customShort("T")],
        help: "Disable pseudo-tty allocation")
  var disableTTY: Bool = false

  @Flag(name: [.customShort("t")],
        help: "Force pseudo-tty allocation.")
  var forceTTY: Bool = false

  @Flag(name: [.customShort("G")],
        help: "Print configuration for host and exit.")
  var printConfiguration: Bool = false
  
  @Flag(name: [.customShort("A")], help: "Forward Agent.")
  var agentForward: Bool = false

  // SSH Port
  @Option(
    name: [.customShort("p", allowingJoined: true)],
    help: .init(
      "Specifies the port to connect to on the remote host.",
      valueName: "port"
    )
  )
  var customPort: UInt16?

  @Option(
    name: [.customShort("D", allowingJoined: true)],
    help: .init(
      "Dynamic port forwarding",
      valueName: "port"
    )
  )
  var dynamicForwardingPort: UInt16?
  
  // Identity
  @Option(
    name: [.customShort("i")],
    help: .init(
      """
      Selects a file from which the identity (private key) for public key authentication is read. The default is ~/.ssh/id_dsa, ~/.ssh/id_ecdsa, ~/.ssh/id_ed25519 and ~/.ssh/id_rsa.  Identity files may also be specified on a per-host basis in the configuration pane in the Settings of Blink.
      """,
      valueName: "identity"
    )
  )
  var identityFile: String?

  // Connect to User at Host
  @Argument(help: "[user@]host[#port]")
  var userAtHost: String
  var host: String {
    get {
      let comps = userAtHost.components(separatedBy: "@")
      let hostAtPort = comps.count > 1 ? comps[1] : comps[0]
      let compsHost = hostAtPort.components(separatedBy: "#")
      return compsHost[0]
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

  @Argument(
    parsing: .unconditionalRemaining,
    help: .init(
      "If a <command> is specified, it is executed on the remote host instead of a login shell",
      valueName: "command"
    )
  )
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

    if disableTTY && forceTTY {
      throw ValidationError("Incompatible flags t and T")
    }
  }
}

struct ConfigFileOptions {
  var user: String?
  var port: String?
  var proxyCommand: String?
  var compression: Bool?
  var compressionLevel: UInt?
  var connectionTimeout: Int?
  var controlMaster: Bool = true
  var sendEnv: [String: String] = [:]
  var strictHostChecking: Bool = true
  
  init(_ options: [String]) throws {
    let lang = String(cString: getenv("LANG"))
    let term = String(cString: getenv("TERM"))
    sendEnv = ["TERM": term, "LANG": lang]

    for o in options {
      var option = o.components(separatedBy: "=")
      if option.count != 2 {
        option = o.components(separatedBy: " ")
        if option.count != 2 {
          throw ValidationError("\(option[0]) missing value")
        }
      }
      switch option[0].lowercased() {
      case "user":
        self.user = option[1]
      case "port":
        self.port = option[1]
      case "proxycommand":
        self.proxyCommand = option[1]
      case "compression":
        compression = try ConfigFileOptions.yesNoValue(option[1], name: "compression")
      case "compressionlevel":
        guard let level = UInt(option[1]) else {
          throw ValidationError("Compression level is not a number")
        }
        guard (1...9).contains(level) else {
          throw ValidationError("Compression level must be between 1-9")
        }
        compressionLevel = level
      case "connectiontimeout":
        connectionTimeout = Int(option[1])
      case "controlmaster":
        controlMaster = try ConfigFileOptions.yesNoValue(option[1], name: "controlmaster")
      case "sendenv":
        var key = option[1]
        if key.starts(with: "-") {
          key.removeFirst()
          sendEnv.removeValue(forKey: key)
        } else {
          let env = String(cString: getenv(key))
          if env.isEmpty {
            continue
          }
          sendEnv[key] = env
        }
      case "stricthostchecking":
        strictHostChecking = try ConfigFileOptions.yesNoValue(option[1], name: "stricthostchecking")
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
  let remotePort: UInt16
  let bindAddress: String
  let localPort: UInt16
  
  private let pattern = #"^((?<localPort>\d+):)?(?<bindAddress>\[([\w:.]+)\]|([\w.]+)):(?<remotePort>\d+)$"#

  init(_ info: String) throws {
    let regex = try! NSRegularExpression(pattern: pattern)
    
    guard let match = regex.firstMatch(in: info,
                                       range: NSRange(location: 0, length: info.count))
    else {
      throw ValidationError("Missing <localport>:<bind_address>:<remoteport> for port forwarding.")
    }
    guard let r = Range(match.range(withName: "localPort"), in: info),
          let localPort = UInt16(info[r])
    else {
      throw ValidationError("Invalid local port.")
    }
    self.localPort = localPort
    
    guard let r = Range(match.range(withName: "remotePort"), in: info),
          let remotePort = UInt16(info[r])
    else {
      throw ValidationError("Invalid remote port.")
    }
    self.remotePort = remotePort
    
    guard let r = Range(match.range(withName: "bindAddress"), in: info)
    else {
      throw ValidationError("Invalid bind address.")
    }
    var bindAddress = String(info[r])
    bindAddress.removeAll(where: { $0 == "[" || $0 == "]" })
    self.bindAddress = bindAddress
  }
}

struct StdioForwardInfo: Equatable {
  let remotePort: UInt16
  let bindAddress: String

  private let pattern = #"^(?<bindAddress>\[([\w:.]+)\]|([\w.]+)):(?<remotePort>\d+)$"#

  init(_ info: String) throws {
    let regex = try! NSRegularExpression(pattern: pattern)
    
    guard let match = regex.firstMatch(in: info,
                                       range: NSRange(location: 0, length: info.count))
    else {
      throw ValidationError("Missing <bind_address>:<remoteport> for stdio forwarding.")
    }
    
    guard let r = Range(match.range(withName: "remotePort"), in: info),
          let remotePort = UInt16(info[r])
    else {
      throw ValidationError("Invalid remote port.")
    }
    self.remotePort = remotePort
    
    guard let r = Range(match.range(withName: "bindAddress"), in: info)
    else {
      throw ValidationError("Invalid bind address.")
    }
    var bindAddress = String(info[r])
    bindAddress.removeAll(where: { $0 == "[" || $0 == "]" })
    self.bindAddress = bindAddress
  }
}

enum SSHControlCommands: String, CaseIterable, ExpressibleByArgument {
  case forward = "forward"
  case exit = "exit"
  case cancel = "cancel"
  case stop = "stop"
}
