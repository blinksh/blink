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
  
  static func config(command cmd: SSHCommand, config options: ConfigFileOptions?, using device: TermDevice) -> SSHClientConfig {
    let prov = SSHClientConfigProvider(command: cmd, using: device)
    
    // TODO Apply connection options, that is different than config.
    // The config helps in the pool, but then you can connect there in many ways.
    let proxy: String? = options?.proxyCommand ?? proxyCommand(from: cmd.host)
    
    return SSHClientConfig(
      // first use 'user' from options, then from cmd and last defaultUserName and fallback to `root`
      user: options?.user ?? cmd.user ?? BKDefaults.defaultUserName() ?? "root",
      // first use `port` from command, then from options and defaults to 22
      port: cmd.port.map(String.init) ?? options?.port ?? "22",
      proxyJump: cmd.proxyJump,
      proxyCommand: proxy,
      authMethods: prov.availableAuthMethods(),
      loggingVerbosity: SSHLogLevel(rawValue: cmd.verbose) ?? SSHLogLevel.debug,
      verifyHostCallback: (options?.strictHostChecking ?? true) ? prov.cliVerifyHostCallback : nil,
      sshDirectory: BlinkPaths.ssh()!,
      logger: prov.logger,
      compression: options?.compression ?? true,
      compressionLevel: options?.compressionLevel.map { Int($0) } ?? 6
    )
  }
}

extension SSHClientConfigProvider {
  fileprivate func availableAuthMethods() -> [AuthMethod] {
    var authMethods: [AuthMethod] = []
    
    // Explicit identity
    if let identityFile = command.identityFile {
      if let (identityKey, name) = Self.privateKey(fromIdentifier: identityFile) {
        authMethods.append(AuthPublicKey(privateKey: identityKey, keyName: name))
      }
    } else {
      // Host key
      if let (hostKey, name) = Self.privateKey(fromHost: command.host) {
        authMethods.append(AuthPublicKey(privateKey: hostKey, keyName: name))
      } else {
        // All default keys
        for (defaultKey, name) in Self.defaultKeys() {
          authMethods.append(AuthPublicKey(privateKey: defaultKey, keyName: name))
        }
      }
    }
    
    // Host password
    if let password = Self.password(fromHost: command.host), !password.isEmpty {
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
  
  fileprivate static func privateKey(fromIdentifier identifier: String) -> (String, String)? {
    guard let publicKeys = (BKPubKey.all() as? [BKPubKey]) else {
      return nil
    }
    
    guard let privateKey = publicKeys.first(where: { $0.id == identifier }) else {
      return nil
    }
    
    return (privateKey.privateKey, identifier)
  }
  
  fileprivate static func privateKey(fromHost host: String) -> (String, String)? {

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
  
  fileprivate static func defaultKeys() -> [(String, String)] {
    guard let publicKeys = (BKPubKey.all() as? [BKPubKey]) else {
      return []
    }
    
    let defaultKeyNames = ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"]
    let keys: [(String, String)] = publicKeys.compactMap { defaultKeyNames.contains($0.id) ? ($0.privateKey, $0.id) : nil }
    
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
  
  fileprivate static func proxyCommand(from host: String) -> String? {
    guard let hosts = (BKHosts.all() as? [BKHosts]) else {
      return nil
    }

    guard let host = hosts.first(where: { $0.host == host }) else {
      return nil
    }
    
    return host.proxyCmd
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
      printLn("Cannot read input.", err: true)
    }

    return Just(response).setFailureType(to: Error.self).eraseToAnyPublisher()
  }
  
  fileprivate func printLn(_ string: String, err: Bool = false) {
    let line = string.appending("\n")
    let s = err ? device.stream.err : device.stream.out
    fwrite(line, line.lengthOfBytes(using: .utf8), 1, s)
  }
}
