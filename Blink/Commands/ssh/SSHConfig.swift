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

  // Connect to User at Host
  @Argument(help: "[user@]host[#port]")
  var userAtHost: String
  var hostAlias: String {
    get {
      let comps = userAtHost.components(separatedBy: "@")
      let hostAndPort = comps[comps.count - 1]
      let compsHost = hostAndPort.components(separatedBy: "#")
      return compsHost[0]
    }
  }
  var user: String? {
    get {
      // Login name preference over user@host
      if let user = loginName {
        return user
      }
      var comps = userAtHost.components(separatedBy: "@")
      if comps.count > 1 {
        comps.removeLast()
        return comps.joined(separator: "@")
      }
      return nil
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
  
  // Port forwarding options
  @Option(name: .customShort("L"),
          help: "<localport>:<bind_address>:<remoteport> Specifies that the given port on the local (client) host is to be forwarded to the given host and port on the remote side."
  )
  var localForward: [String] = []

  // Remote Port forwarding
  @Option(name:  [.customShort("R")],          
          help: "port:host:hostport Specifies that the given port on the remote (server) host is to be forwarded to the given host and port on the local side."
  )
  var remoteForward: [String] = []

  // Verbosity levels
  // (Magic) When a flag is of type Int, the value is parsed as a count of the number of times that the flag is specified.
  @Flag(name: .shortAndLong)
  var verbosity: Int
  // The possible values are: QUIET, FATAL, ERROR, INFO, VERBOSE, DEBUG. The default is INFO.
  // If DEBUG2, DEBUG3, etc... we would just transform to debug, which is our max.
  var logLevel: String? {
    switch verbosity {
    case 0:
      return "QUIET"
    case 1:
      return "INFO"
    case 2:
      return "VERBOSE"
    case 3:
      return "DEBUG"
    case 4...:
      return "DEBUG2"
    default:
      return nil
    }
  }

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
          transform: { try BindAddressInfo($0) })
  var stdioHostAndPort: BindAddressInfo?

  @Option(
    name: [.customShort("o", allowingJoined: true)],
    help: .init(
      "Secondary connection options in config file format.",
      valueName: "option"
      )
  )
  var options: [String] = []

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
  var dynamicForward: [String] = []
  
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

  @Argument(
    parsing: .remaining,
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

  func run() throws {}

  func validate() throws {
    let _ = try sshOptions()
    
    if disableTTY && forceTTY {
      throw ValidationError("Incompatible flags t and T")
    }
  }
}

// TODO Working with half baked strings may be error prone.
// We could use an enum, so the structure would be from the [Enum: Any].
extension SSHCommand {
  func bkSSHHost() throws -> BKSSHHost {
    // Create an SSH Config dictionary with the content of the command.
    // Note that the Host is actually not defined by the command, as it may be just an alias.
    // If the resulting Host calculation does not have a host, then we set it up.
    var params = try sshOptions()

    if let user = self.user {
      params["user"] = user
    }

    if let port = self.port {
      params["port"] = String(port)
    }

    if let identityFile = self.identityFile {
      params["identityfile"] = identityFile
    }

    if let proxyJump = self.proxyJump {
      params["proxyjump"] = proxyJump
    }

    if let logLevel = self.logLevel {
      params["loglevel"] = logLevel
    }

    if !self.localForward.isEmpty {
      params["localforward"] = self.localForward
    }

    if !self.remoteForward.isEmpty {
      params["remoteforward"] = self.remoteForward
    }

    if !self.dynamicForward.isEmpty {
      params["dynamicforward"] = dynamicForward
    }

    if agentForward {
      params["forwardagent"] = "yes"
    } 

    if !command.isEmpty {
      params["remotecommand"] = command.joined(separator: " ")
    }

    if disableTTY {
      params["requesttty"] = "no"
    } else if forceTTY {
      params["requesttty"] = "force"
    }
    
    return try BKSSHHost(content: params)
  }

  func sshOptions() throws -> [String: Any] {
    var params: [String: Any] = [:]

    for o in options {
      var option = o.components(separatedBy: "=")
      if option.count != 2 {
        option = o.components(separatedBy: " ")
        if option.count != 2 {
          throw ValidationError("\(option[0]) missing value")
        }
      }

      // The BKSSHHost will perform further validation when generating the configuration
      params[option[0]] = option[1]
    }

    return params
  }
}

enum SSHControlCommands: String, CaseIterable, ExpressibleByArgument {
  case forward = "forward"
  case exit = "exit"
  case cancel = "cancel"
  case stop = "stop"
}
