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
import SSH
import Combine


fileprivate let HostKeyChangedWarningMessage = """
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Host key for server changed. It is now: Public key hash %@.

An attacker might change the default server key to confuse your client into thinking the key does not exist. It is also possible that the host key has just been changed.\n
"""

fileprivate let HostKeyChangedReplaceRequestMessage = "Accepting the following prompt will replace the old fingerprint. Do you trust the host key? [Y/n]: "

fileprivate let HostKeyChangedUnknownRequestMessage = "Public key hash: %@. The server is unknown. Do you trust the host key? [Y/n]: "

fileprivate let HostKeyChangedNotFoundRequestMessage = "Public key hash: %@. The server is unknown. Do you trust the host key? [Y/n]: "

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
  @Option(name: .customShort("L"), help: "port:host:hostport Specifies that the given port on the local (client) host is to be forwarded to the given host and port on the remote side.")
  var localPortForward: String?
  var localPortForwardLocalPort: String? {
    get {
      return localPortForward?.components(separatedBy: ":")[0]
    }
  }
  var localPortForwardHost: String? {
    get {
      return localPortForward?.components(separatedBy: ":")[1].components(separatedBy: ":")[0]
    }
  }
  var localPortForwardRemotePort: String? {
    get {
      return localPortForward?.components(separatedBy: ":")[2]
    }
  }

  // Reverse Port forwarding
  @Option(name:  [.customShort("R")],
          help: "port:host:hostport Specifies that the given port on the remote (server) host is to be forwarded to the given host and port on the local side.")
  var reversePortForward: String?
  
  var reversePortForwardLocalPort: String? {
    get {
      return reversePortForward?.components(separatedBy: ":")[0]
    }
  }
  var reversePortForwardHost: String? {
    get {
      return reversePortForward?.components(separatedBy: ":")[1].components(separatedBy: ":")[0]
    }
  }
  var reversePortForwardRemotePort: String? {
    get {
      return reversePortForward?.components(separatedBy: ":")[2]
    }
  }
  
  // Verbosity levels
  @Flag(name: .customShort("v"), help: "First level of logging: Only warnings") var verbosityLogWarning = false
  @Flag(name: .customLong("vv", withSingleDash: true), help: "Second level of logging: High level protocol infomation") var verbosityLogProtocol = false
  @Flag(name: .customLong("vvv", withSingleDash: true), help: "Third level of logging: Lower level protocol information, packet level") var verbosityLogPacket = false
  @Flag(name: .customLong("vvvv", withSingleDash: true), help: "Maximum level of logging: Every function path") var verbosityLogFunctions = false
  
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
          help: "Forward stdio to the specified destination")
  var stdioHostAndPort: String?
  // If you are using these, then stdioFwd exists
  var stdioHost: String {
    get {
      stdioHostAndPort!.contains(":") ?
        stdioHostAndPort!.components(separatedBy: ":")[0] : stdioHostAndPort!
    }
  }
  var stdioPort: Int32 {
    get {
      stdioHostAndPort!.contains(":") ?
        Int32(stdioHostAndPort!.components(separatedBy: ":")[1])! : 22
    }
  }
  
    
  // SSH Port
  @Option(name:  [.customLong("port"), .customShort("p")],
          default: 22,
          help: "Specifies the port to connect to on the remote host.")
  var portNum: Int32
  var port: String { get {String(portNum) } }
  
  // Identity
  @Option(name:  [.customShort("i")],
          default: nil,
          help: """
  Selects a file from which the identity (private key) for public key authentication is read. The default is ~/.ssh/id_dsa, ~/.ssh/id_ecdsa, ~/.ssh/id_ed25519 and ~/.ssh/id_rsa.  Identity files may also be specified on a per-host basis in the configuration pane in the Settings of Blink.
  """)
  var identityFile: String?
  
  // Connect to User at Host
  @Argument(help: "[user@]host")
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
  
  @Argument(help: "command")
  var command: String?
  
  func run() throws {
  }
  
  func validate() throws {
  }
}

// Having access from CLI
// Having access from UI. Some parameters must already exist, others need to be tweaked.
// Pass it a host and get everything necessary to connect, but some functions still need to be setup.
class SSHClientConfigProvider {
  let device: TermDevice
  let command: SSHCommand
  
  fileprivate init(command cmd: SSHCommand, using device: TermDevice) {
    self.device = device
    self.command = cmd
  }
  
  static func config(command cmd: SSHCommand, using device: TermDevice) -> SSHClientConfig {
    let prov = SSHClientConfigProvider(command: cmd, using: device)
    
    let user = cmd.user ?? "carlos"
    let authMethods = prov.availableAuthMethods()
    
    return SSHClientConfig(user: user, proxyJump: cmd.proxyJump, authMethods: authMethods, verifyHostCallback: prov.cliVerifyHostCallback, sshDirectory: BlinkPaths.ssh()!)
  }
}

extension SSHClientConfigProvider {
  fileprivate func availableAuthMethods() -> [AuthMethod] {
    var authMethods: [AuthMethod] = []
    
    // Explicit identity
    if let identityFile = command.identityFile {
      if let identityKey = Self.privateKey(fromIdentifier: identityFile) {
        authMethods.append(AuthPublicKey(privateKey: identityKey))
      }
    }
    
    // Host key
    if let hostKey = Self.privateKey(fromHost: command.host) {
      authMethods.append(AuthPublicKey(privateKey: hostKey))
    }
    
    // Host password
    if let password = Self.password(fromHost: command.host) {
      authMethods.append(AuthPassword(with: password))
    }
    
    // All default keys
    for defaultKey in Self.defaultKeys() {
      authMethods.append(AuthPublicKey(privateKey: defaultKey))
    }
    
    // Interactive
    authMethods.append(AuthKeyboardInteractive(requestAnswers: self.authPrompt, wrongRetriesAllowed: 3))
    
    return authMethods
  }
  
  fileprivate func authPrompt(_ prompt: Prompt) -> AnyPublisher<[String], Error> {
    var answers: [String] = []

    if prompt.userPrompts.count > 0 {
      for question in prompt.userPrompts {
        if let input = device.readline(question.prompt, secure: true) {
          answers.append(input)
        }
      }
    }

    return Just(answers).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
  
  fileprivate static func privateKey(fromIdentifier identifier: String) -> String? {
    guard let publicKeys = (BKPubKey.all() as? [BKPubKey]) else {
      return nil
    }
    
    guard let privateKey = publicKeys.first(where: { $0.id == identifier }) else {
      return nil
    }
    
    return privateKey.privateKey
  }
  
  fileprivate static func privateKey(fromHost host: String) -> String? {

    guard let hosts = (BKHosts.all() as? [BKHosts]) else {
      return nil
    }

    guard let host = hosts.first(where: { $0.host == host }) else {
      return nil
    }

    guard let keyIdentifier = host.key, let privateKey = privateKey(fromIdentifier: keyIdentifier) else {
      return nil
    }

    return privateKey
  }
  
  fileprivate static func defaultKeys() -> [String] {
    guard let publicKeys = (BKPubKey.all() as? [BKPubKey]) else {
      return []
    }
    
    let defaultKeyNames = ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"]
    let keys: [String] = publicKeys.compactMap { defaultKeyNames.contains($0.id) ? $0.privateKey : nil }
    
    return keys.count > 0 ? keys : []
  }
  
  fileprivate static func password(fromHost host: String) -> String? {
    guard let hosts = (BKHosts.all() as? [BKHosts]) else {
      return nil
    }
    
    guard let host = hosts.first(where: { $0.host == host }) else {
      return nil
    }
    
    return host.password
  }
}

extension SSHClientConfigProvider {
  func cliVerifyHostCallback(_ prompt: SSH.VerifyHost) -> AnyPublisher<InteractiveResponse, Error> {
    var response: SSH.InteractiveResponse = .negative

    var messageToShow: String = ""

    switch prompt {
    case .changed(serverFingerprint: let serverFingerprint):
      let headerMessage = String(format: HostKeyChangedWarningMessage, serverFingerprint)
      messageToShow = String(format: "%@\n%@", headerMessage, HostKeyChangedReplaceRequestMessage)
    case .unknown(serverFingerprint: let serverFingerprint):
      messageToShow = String(format: HostKeyChangedUnknownRequestMessage, serverFingerprint)
    case .notFound(serverFingerprint: let serverFingerprint):
      messageToShow = String(format: HostKeyChangedNotFoundRequestMessage, serverFingerprint)
    @unknown default:
      break
    }

    let readAnswer = self.device.readline(messageToShow, secure: false)

    if let answer = readAnswer?.lowercased() {
      if answer.starts(with: "y") {
        response = .affirmative
      }
    } else {
      printLn("Cannot read input.")
    }

    return Just(response).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
  
  fileprivate func printLn(_ string: String) {
    let line = string.appending("\n")
    fwrite(line, line.lengthOfBytes(using: .utf8), 1, device.stream.out)
  }
}
