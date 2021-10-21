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


enum BlinkFilesProtocol: String {
  case ssh = "ssh"
  case local = "local"
  case sftp = "sftp"
}

func buildTranslator(for encodedRootPath: String) -> AnyPublisher<Translator, Error> {
  guard let rootData = Data(base64Encoded: encodedRootPath),
        let rootPath = String(data: rootData, encoding: .utf8) else {
    return Fail(error: "Wrong encoded identifier for Translator").eraseToAnyPublisher()
  }

  // rootPath: ssh:host:root_folder
  let components = rootPath.split(separator: ":")

  // TODO At least two components. Tweak for sftp
  let remoteProtocol = BlinkFilesProtocol(rawValue: String(components[0]))
  let pathAtFiles: String
  let host: String?
  if components.count == 2 {
    pathAtFiles = String(components[1])
    host = nil
  } else {
    pathAtFiles = String(components[2])
    host = String(components[1])
  }

  switch remoteProtocol {
  case .local:
    return local(path: pathAtFiles)
  case .sftp:
    guard let host = host else {
      return .fail(error: "Missing host in Translator route")
    }
    return sftp(host: host, path: pathAtFiles)
  default:
    return .fail(error: "Not implemented")
  }
}

fileprivate func local(path: String) -> AnyPublisher<Translator, Error> {
  return Local().walkTo(path)
}

fileprivate func sftp(host: String, path: String) -> AnyPublisher<Translator, Error> {
  let (host, config) = SSHClientConfigProvider.config(host: host)
  let log = BlinkLogger("SFTP")
  // NOTE We use main queue as this is an extension. Should move it to a different one though,
  // in case of future changes.
  return Just(config).receive(on: DispatchQueue.main).flatMap {
    SSHClient
      .dial(host, with: $0)
      .print("Dialing...")
    //.receive(on: FileTranslatorPool.shared.backgroundRunLoop)
      .flatMap { conn -> AnyPublisher<SFTPClient, Error> in
        return conn.requestSFTP()
      }//.print("SFTP")
      .mapError { error -> Error in
        log.error("Error connecting: \(error)")
        return NSFileProviderError.couldNotConnect(dueTo: error)
      }
      .flatMap { $0.walkTo(path)
                   .mapError { error -> Error in
                     log.error("Error walking to base path \(path): \(error)")
                     return NSFileProviderError(.noSuchItem)
                   }
      }
      .eraseToAnyPublisher()
  }.eraseToAnyPublisher()
}

class SSHClientConfigProvider {

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
        proxyCommand: bkConfig.proxyCommand(forHost: host),
        authMethods: availableAuthMethods,
        agent: agent,
        loggingVerbosity: SSHLogLevel.debug,
        verifyHostCallback: nil,
        connectionTimeout: 300,
        sshDirectory: BlinkPaths.ssh()!,
        logger: PassthroughSubject<String, Never>(),
        compression: false,
        compressionLevel: 6
      )
    )
  }
}
