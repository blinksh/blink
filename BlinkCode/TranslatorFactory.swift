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


import Combine
import Foundation

import BlinkFiles
import BlinkConfig
import SSH


public enum TranslatorFactories {}

public struct RootPath {
  let url: URL // should be private
  
  //var fullPath: String { url.absoluteString }
  var protocolIdentifier: String { url.scheme! }
  var host: String? { url.host }
  var filesAtPath: String { url.path }
  
  init(_ rootPath: String) {
    self.url = URL(string: rootPath)!
  }
  
  init(_ url: URL) {
    self.url = url
  }
}

extension TranslatorFactories {
  public static let local = Self.Local()
  
  public struct Local {
    public func build(_ path: RootPath) -> AnyPublisher<Translator, Error> {
      return Just(BlinkFiles.Local()).mapError {$0 as Error}.eraseToAnyPublisher()
    }
  }
}

extension TranslatorFactories {
  struct TranslatorError: Error, Encodable {
    let message: String
  }
  
  public static let sftp = Self.SFTP()
  
  public class SFTP {
    public func buildOn<T: Scheduler>(_ scheduler: T, hostAlias: String) -> AnyPublisher<Translator, Error> {
      let hostName: String
      let config: SSHClientConfig
      
      do {
        guard let (name, cfg) = try SSHClientFileProviderConfig.config(host: hostAlias) else {
          return .fail(error: TranslatorError(message: "Could not find config for given host."))
        }
        hostName = name
        config = cfg
      } catch {
        return .fail(error: TranslatorError(message: "Configuration error - \(error)"))
      }
      
      return Just(config)
        .receive(on: scheduler).flatMap {
          SSHClient
            .dial(hostName, with: $0)
            .print("Dialing...")
            .flatMap { $0.requestSFTP() }
            .tryMap  { try SFTPTranslator(on: $0) }
            .print("SFTP")
            .flatMap { $0.walkTo("") }
        }.eraseToAnyPublisher ()
    }
  }

  // A special FileProvider configuration that skips over user input configurations.
  class SSHClientFileProviderConfig {

    static func config(host title: String) throws -> (String, SSHClientConfig)? {

      let bkConfig = BKConfig()
      let agent = SSHAgent()

      let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]

      guard let host = try bkConfig.bkSSHHost(title),
            let hostName = host.hostName else {
        return nil
      }
      
      if let signers = bkConfig.signer(forHost: host) {
        signers.forEach { (signer, name) in
          _ = agent.loadKey(signer, aka: name, constraints: consts)
        }
      }
      
      for (signer, name) in bkConfig.defaultSigners() {
        _ = agent.loadKey(signer, aka: name, constraints: consts)
      }

      var availableAuthMethods: [AuthMethod] = [AuthAgent(agent)]
      if let password = host.password, !password.isEmpty {
        availableAuthMethods.append(AuthPassword(with: password))
      }

      return (hostName,
              host.sshClientConfig(authMethods: availableAuthMethods,
                                   agent: agent))
    }
  }

}
