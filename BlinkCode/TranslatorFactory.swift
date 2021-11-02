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


// TODO Temporary until we decide what domain these errors should belong to.
extension String: Error {}


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

//public struct RootPath {
//  let fullPath: String
//  let protocolIdentifier: String
//  let host: String?
//  let filesAtPath: String
//
//  // rootPath: ssh:host:root_folder
//  init(_ rootPath: String) {
//    self.fullPath = rootPath
//    let components = rootPath.split(separator: ":")
//
//    let protocolIdentifier = String(components[0])
//    let filesAtPath: String
//    let host: String?
//    if components.count == 2 {
//      filesAtPath = String(components[1])
//      host = nil
//    } else {
//      filesAtPath = String(components[2])
//      host = String(components[1])
//    }
//
//    self.protocolIdentifier = protocolIdentifier
//    self.host = host
//    self.filesAtPath = filesAtPath
//  }
//}

public enum TranslatorFactories {}

extension TranslatorFactories {
  public static let local = Self.Local()
  
  public struct Local {
    public func build(_ path: RootPath) -> AnyPublisher<Translator, Error> {
      return Just(BlinkFiles.Local()).mapError {$0 as Error}.eraseToAnyPublisher()
    }
  }
}

extension TranslatorFactories {
  public static let sftp = Self.SFTP()
  
  public class SFTP {
    public func buildOn<T: Scheduler>(_ scheduler: T, rootPath: RootPath) -> AnyPublisher<Translator, Error> {
      guard let hostIdentifier = rootPath.host else {
        return Fail(error: "Missing host on rootpath").eraseToAnyPublisher()
      }

      let (host, config) = SSHClientFileProviderConfig.config(host: hostIdentifier)

      return Just(())
        .receive(on: scheduler).flatMap {
          SSHClient
            .dial(host, with: config)
            .print("Dialing...")
            .flatMap { conn -> AnyPublisher<SFTPClient, Error> in
              return conn.requestSFTP()
            }
            .print("SFTP")
            .flatMap { $0.walkTo("") }
        }.eraseToAnyPublisher ()
    }
  }

  // A special FileProvider configuration that skips over user input configurations.
  class SSHClientFileProviderConfig {

    static func config(host: String) -> (String, SSHClientConfig) {

      BKHosts.loadHosts()
      BKPubKey.loadIDS()

      let bkConfig = BKConfig(allHosts: BKHosts.allHosts(), allIdentities: BKPubKey.all())
      let agent = SSHAgent()

      let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]

      if let (signer, name) = bkConfig.signer(forHost: host) {
        _ = agent.loadKey(signer, aka: name, constraints: consts)
      } else {
        for identity in ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"] {
          if let (signer, name) = bkConfig.signer(forIdentity: identity) {
            _ = agent.loadKey(signer, aka: name, constraints: consts)
          }
        }
      }

      var availableAuthMethods: [AuthMethod] = [AuthAgent(agent)]
      if let password = bkConfig.password(forHost: host), !password.isEmpty {
        availableAuthMethods.append(AuthPassword(with: password))
      }

      return (
        bkConfig.hostName(forHost: host)!,
        SSHClientConfig(
          user: bkConfig.user(forHost: host) ?? "root",
          port: bkConfig.port(forHost: host) ?? "22",
          proxyJump: nil,
          proxyCommand: nil,
          authMethods: availableAuthMethods,
          agent: agent,
          verifyHostCallback: nil,
          sshDirectory: BlinkPaths.ssh()!,
          logger: PassthroughSubject<String, Never>()
        )
      )
    }
  }

}
