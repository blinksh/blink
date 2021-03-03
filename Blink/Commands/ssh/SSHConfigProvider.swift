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
// Having access from CLI
// Having access from UI. Some parameters must already exist, others need to be tweaked.
// Pass it a host and get everything necessary to connect, but some functions still need to be setup.
class SSHClientConfigProvider {
  let device: TermDevice
  let command: SSHCommand
  let logger = PassthroughSubject<String, Never>()
  var logCancel: AnyCancellable? = nil
  
  fileprivate init(command cmd: SSHCommand, using device: TermDevice) {
    self.device = device
    self.command = cmd

    logCancel = logger.sink { [weak self] in self?.printLn($0, err: true) }
  }
  
  // Return HostName, SSHClientConfig for the server and Options for the Connection
  static func config(command cmd: SSHCommand, using device: TermDevice) -> (String, SSHClientConfig) {
    let host = cmd.host
    let prov = SSHClientConfigProvider(command: cmd, using: device)
    let agent = prov.agent(forHost: host)
    let availableAuthMethods: [AuthMethod] = [AuthAgent(agent)] + prov.passwordAuthMethods()

    let options = try? cmd.connectionOptions.get()
    
    return (
      BKConfig.hostName(forHost: host) ?? cmd.host,
      SSHClientConfig(
        // first use 'user' from options, then from cmd and last defaultUserName and fallback to `root`
        user: options?.user ?? cmd.user ?? BKDefaults.defaultUserName() ?? "root",
        // first use `port` from command, then from options and defaults to 22
        port: options?.port ?? cmd.port.map(String.init) ?? "22",
        proxyJump: cmd.proxyJump,
        proxyCommand: options?.proxyCommand ?? BKConfig.proxyCommand(forHost: host),
        authMethods: availableAuthMethods,
        agent: agent,
        loggingVerbosity: SSHLogLevel(rawValue: cmd.verbose) ?? SSHLogLevel.debug,
        verifyHostCallback: (options?.strictHostChecking ?? true) ? prov.cliVerifyHostCallback : nil,
        connectionTimeout: options?.connectionTimeout ?? 30,
        sshDirectory: BlinkPaths.ssh()!,
        logger: prov.logger,
        compression: options?.compression ?? true,
        compressionLevel: options?.compressionLevel.map { Int($0) } ?? 6
      )
    )
  }
}

enum BKConfig {
  static func privateKey(forIdentifier identifier: String) -> (String, String)? {
    guard let publicKeys = (BKPubKey.all() as? [BKPubKey]) else {
      return nil
    }
    
    guard let privateKey = publicKeys.first(where: { $0.id == identifier }) else {
      return nil
    }
    
    return (privateKey.privateKey, identifier)
  }
  
  static private func host(_ host: String) -> BKHosts? {
    guard let hosts = (BKHosts.all() as? [BKHosts]) else {
      return nil
    }

    return hosts.first(where: { $0.host == host })
  }
  
  static func privateKey(forHost host: String) -> (String, String)? {
    guard let host = Self.host(host) else {
      return nil
    }

    guard let keyIdentifier = host.key, let privateKey = privateKey(forIdentifier: keyIdentifier) else {
      return nil
    }

    return privateKey
  }
  
  static func defaultKeys() -> [(String, String)] {
    guard let publicKeys = (BKPubKey.all() as? [BKPubKey]) else {
      return []
    }
    
    let defaultKeyNames = ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"]
    let keys: [(String, String)] = publicKeys.compactMap { defaultKeyNames.contains($0.id) ? ($0.privateKey, $0.id) : nil }
    
    return keys.count > 0 ? keys : []
  }
  
  static func password(forHost host: String) -> String? {
    Self.host(host)?.password
  }

  static func hostName(forHost host: String) -> String? {
    Self.host(host)?.hostName
  }
  
  static func proxyCommand(forHost host: String) -> String? {
    Self.host(host)?.proxyCmd
  }
  
  static func user(forHost host: String) -> String? {
    Self.host(host)?.user
  }
  
  static func port(forHost host: String) -> String? {
    Self.host(host)?.port.stringValue
  }
}

extension SSHClientConfigProvider {
  fileprivate func keyAuthMethods() -> [AuthMethod] {
    var authMethods: [AuthMethod] = []
    
    // Explicit identity
    if let identityFile = command.identityFile,
       let (identityKey, name) = BKConfig.privateKey(forIdentifier: identityFile) {
      authMethods.append(AuthPublicKey(privateKey: identityKey, keyName: name))
    } else if let (hostKey, name) = BKConfig.privateKey(forHost: command.host) {
      authMethods.append(AuthPublicKey(privateKey: hostKey, keyName: name))
    } else {
      // All default keys
      for (defaultKey, name) in BKConfig.defaultKeys() {
        authMethods.append(AuthPublicKey(privateKey: defaultKey, keyName: name))
      }
    }

    return authMethods
  }
  
  fileprivate func passwordAuthMethods() -> [AuthMethod] {
    var authMethods: [AuthMethod] = []
    // Host password
    if let password = BKConfig.password(forHost: command.host), !password.isEmpty {
      authMethods.append(AuthPassword(with: password))
    } else {
      // Interactive
      authMethods.append(AuthKeyboardInteractive(requestAnswers: self.authPrompt, wrongRetriesAllowed: 3))
    }
    
    return authMethods
  }
  
  fileprivate func authPrompt(_ prompt: Prompt) -> AnyPublisher<[String], Error> {
    return prompt.userPrompts.publisher.tryMap { question -> String in
      guard let input = self.device.readline(question.prompt, secure: true) else {
        throw CommandError(message: "Couldn't read input")
      }
      return input
    }.collect()
    .eraseToAnyPublisher()
  }

  fileprivate func agent(forHost host: String) -> SSHAgent {
    let agent = SSHAgent()
    agent.constraintsPublisher = { (keyName) in
      // NOTE The Agent is attached to the host here, so we can potentially print information about the host itself.
      print(keyName)
      return Just(.affirmative).mapError { $0 as Error }.eraseToAnyPublisher()
    }
    
    if let identityFile = command.identityFile,
       let (identityKey, name) = BKConfig.privateKey(forIdentifier: identityFile) {
      // NOTE We could also keep the reference and just read the key at the proper time.
      // TODO Errors. Either pass or log here, or if we create a different
      // type of key, then let the Agent fail.
      // TODO Need to pass name.
      // TODO It would make sense for the constructor to sanitize directly. But that would also mean
      // we would have to pass a Data, or work with Strings in another convenience init.
      if let blob = SSHKey.sanitize(key: identityKey).data(using: .utf8),
         let key = try? SSHKey(fromBlob: blob) {
        agent.loadKey(key, aka: name)
      }
    } else if let (hostKey, name) = BKConfig.privateKey(forHost: command.host) {
      if let blob = SSHKey.sanitize(key: hostKey).data(using: .utf8),
         let key = try? SSHKey(fromBlob: blob) {
        agent.loadKey(key, aka: name)
      }
    } else {
      for (defaultKey, name) in BKConfig.defaultKeys() {
        if let blob = SSHKey.sanitize(key: defaultKey).data(using: .utf8),
           let key = try? SSHKey(fromBlob: blob) {
          agent.loadKey(key, aka: name)
        }
      }
    }
    return agent
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
    }

    let readAnswer = self.device.readline(messageToShow, secure: false)

    if let answer = readAnswer?.lowercased() {
      if answer.starts(with: "y") {
        response = .affirmative
      }
    } else {
      printLn("Cannot read input.", err: true)
    }

    return Just(response).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
  
  fileprivate func printLn(_ string: String, err: Bool = false) {
    let line = string.appending("\r\n")
    let s = err ? device.stream.err : device.stream.out
    fwrite(line, line.lengthOfBytes(using: .utf8), 1, s)
  }
}
