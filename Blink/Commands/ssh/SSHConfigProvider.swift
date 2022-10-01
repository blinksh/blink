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
import BlinkConfig


fileprivate let HostKeyChangedWarningMessage = "@@WARNING! REMOTE IDENTIFICATION HAS CHANGED. New Public key hash: %@. Accepting the following prompt will add a new entry for this host. Do you trust the host key? [Y/n]: "

fileprivate let HostKeyChangedUnknownRequestMessage = "Public key hash: %@. The server is unknown. Do you trust the host key? [Y/n]: "

fileprivate let HostKeyChangedNotFoundRequestMessage = "Public key hash: %@. The server is unknown. Do you trust the host key? [Y/n]: "
// Having access from CLI
// Having access from UI. Some parameters must already exist, others need to be tweaked.
// Pass it a host and get everything necessary to connect, but some functions still need to be setup.

class SSHClientConfigProvider {
  let device: TermDevice
  let logger = PassthroughSubject<String, Never>()
  var logCancel: AnyCancellable? = nil
  let config: BKConfig
  
  fileprivate init(using device: TermDevice) throws {
    self.device = device
    self.config = try BKConfig()

    logCancel = logger.sink { [weak self] in self?.printLn($0, err: true) }
  }
  
  // Return HostName, SSHClientConfig for the server
  static func config(host: BKSSHHost, using device: TermDevice) throws -> SSHClientConfig {
    let prov = try SSHClientConfigProvider(using: device)

    let agent = prov.agent(for: host)

    let availableAuthMethods: [AuthMethod] = [AuthAgent(agent)] + prov.passwordAuthMethods(for: host)

    return
      host.sshClientConfig(authMethods: availableAuthMethods,
                           verifyHostCallback: (host.strictHostKeyChecking ?? true) ? prov.cliVerifyHostCallback : nil,
                           agent: agent,
                           logger: prov.logger)
  }
}

extension SSHClientConfigProvider {
  // NOTE Unused as we moved to a pure agent. Leaving here in case it is useful in the future.
  fileprivate func keyAuthMethods(for host: BKSSHHost) -> [AuthMethod] {
    var authMethods: [AuthMethod] = []

    // Explicit identity
    if let identities = host.identityFile {
      identities.forEach { identity in
        if let (identityKey, name) = config.privateKey(forIdentifier: identity) {
            authMethods.append(AuthPublicKey(privateKey: identityKey, keyName: name))
        }
      }
    } else {
      // All default keys
      for (defaultKey, name) in config.defaultKeys() {
        authMethods.append(AuthPublicKey(privateKey: defaultKey, keyName: name))
      }
    }

    return authMethods
  }
  
  fileprivate func passwordAuthMethods(for host: BKSSHHost) -> [AuthMethod] {
    var authMethods: [AuthMethod] = []

    // Host password
    if let password = host.password, !password.isEmpty {
      authMethods.append(AuthPassword(with: password))
    }

    authMethods.append(AuthKeyboardInteractive(requestAnswers: self.authPrompt, wrongRetriesAllowed: 2))
    // Password-Interactive
    authMethods.append(AuthPasswordInteractive(requestAnswers: self.authPrompt,
                                               wrongRetriesAllowed: 2))

    return authMethods
  }
  
  fileprivate func authPrompt(_ prompt: Prompt) -> AnyPublisher<[String], Error> {
    self.printLn(prompt.instruction, err: true)

    return prompt.userPrompts.publisher.tryMap { question -> String in
      guard let input = self.device.readline(question.prompt, secure: true) else {
        throw CommandError(message: "Couldn't read input")
      }
      return input
    }.collect()
    .eraseToAnyPublisher()
  }

  fileprivate func agent(for host: BKSSHHost) -> SSHAgent {
    let agent = SSHAgent()

    let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]

    if let signers = config.signer(forHost: host) {
      signers.forEach { (signer, name) in
        // NOTE We could also keep the reference and just read the key at the proper time.
        // TODO Errors. Either pass or log here, or if we create a different
        // type of key, then let the Agent fail.
        if let signer = signer as? BlinkConfig.InputPrompter {
          signer.setPromptOnView(device.view)
        }
        _ = agent.loadKey(signer, aka: name, constraints: consts)
      }
    } else {
      for (signer, name) in config.defaultSigners() {
        _ = agent.loadKey(signer, aka: name, constraints: consts)
      }
    }
    
    // Link to Default Agent
    agent.linkTo(agent: SSHAgentPool.defaultAgent)
    return agent
  }

}

extension SSHClientConfigProvider {
  func cliVerifyHostCallback(_ prompt: SSH.VerifyHost) -> AnyPublisher<InteractiveResponse, Error> {
    var response: SSH.InteractiveResponse = .negative

    let messageToShow: String
    switch prompt {
    case .changed(serverFingerprint: let serverFingerprint):
      messageToShow = String(format: HostKeyChangedWarningMessage, serverFingerprint)
    case .unknown(serverFingerprint: let serverFingerprint):
      messageToShow = String(format: HostKeyChangedUnknownRequestMessage, serverFingerprint)
    case .notFound(serverFingerprint: let serverFingerprint):
      messageToShow = String(format: HostKeyChangedNotFoundRequestMessage, serverFingerprint)
    }

    let readAnswer = self.device.readline(messageToShow, secure: false)

    if let answer = readAnswer?.lowercased() {
      if answer.starts(with: "y") || answer.isEmpty {
        response = .affirmative
      }
    } else {
      printLn("Cannot read input.", err: true)
    }

    return .just(response)
  }
  
  fileprivate func printLn(_ string: String, err: Bool = false) {
    let line = string.appending("\r\n")
    let s = err ? device.stream.err : device.stream.out
    fwrite(line, line.lengthOfBytes(using: .utf8), 1, s)
  }
}
