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
import FileProvider
import Foundation

import BlinkConfig
import BlinkFiles
import SSH


class TranslatorControl {
  let translator: Translator
  let connectionControl: SSHClientControl

  init(_ translator: Translator, connectionControl: SSHClientControl) {
    self.translator = translator
    self.connectionControl = connectionControl
  }
  
  deinit {
    self.connectionControl.cancel()
  }
}

enum BlinkFilesProtocol: String {
  case ssh = "ssh"
  case local = "local"
  case sftp = "sftp"
}

var logCancellables = Set<AnyCancellable>()


final class FileTranslatorCache {
  static let shared = FileTranslatorCache()
  private var translators: [String: TranslatorControl] = [:]
  private var references: [String: BlinkItemReference] = [:]
  private var fileList:   [String: [BlinkItemReference]] = [:]
  private var backgroundThread: Thread? = nil
  private var backgroundRunLoop: RunLoop = RunLoop.current


  private init() {}

  static func translator(for encodedRootPath: String) -> AnyPublisher<Translator, Error> {
    // Check if we have it cached, if it is still working
    if let translatorRef = shared.translators[encodedRootPath],
       translatorRef.translator.isConnected {
      return .just(translatorRef.translator)
    }

    guard let rootData = Data(base64Encoded: encodedRootPath),
          let rootPath = String(data: rootData, encoding: .utf8) else {
      return Fail(error: "Wrong encoded identifier for Translator").eraseToAnyPublisher()
    }

    // rootPath: ssh:host:root_folder
    let components = rootPath.split(separator: ":")
    guard let remoteProtocol = BlinkFilesProtocol(rawValue: String(components[0])) else {
      return .fail(error: "Not implemented")
    }

    let pathAtFiles: String
    let host: String?
    if remoteProtocol == .local {
      pathAtFiles = String(rootPath[components[1].startIndex...])
      host = nil
    } else {
      // The path will take the rest, independent of the components, because the colon is a valid character (not POSIX though)
      pathAtFiles = String(rootPath[components[2].startIndex...])
      host = String(components[1])
    }

    switch remoteProtocol {
    case .local:
      return Local().walkTo(pathAtFiles)
    case .sftp:
      guard let host = host else {
        return .fail(error: "Missing host in Translator route")
      }
      return SSHClient.dial(host, withConfigProvider: SSHClientConfigProvider.config)
        .flatMap { connControl in
          return Just(connControl.connection)
            .flatMap { conn -> AnyPublisher<SFTPClient, Error> in
              conn.handleSessionException = { error in print("SFTP Connection Exception \(error)") }
              return conn.requestSFTP()
            }
            .tryMap { try SFTPTranslator(on: $0) }
            .flatMap { $0.walkTo(pathAtFiles) }
            .map { t -> Translator in
              shared.translators[encodedRootPath] = TranslatorControl(t, connectionControl: connControl)
              return t
            }
        }.eraseToAnyPublisher()
    default:
      return .fail(error: "Not implemented")
    }
  }

  static func store(reference: BlinkItemReference) {
    print("storing File BlinkItemReference : \(reference.itemIdentifier.rawValue)")
    shared.references[reference.itemIdentifier.rawValue] = reference
  }
  static func remove(reference: BlinkItemReference) {
    shared.references.removeValue(forKey: reference.itemIdentifier.rawValue)
  }

  static func reference(identifier: BlinkItemIdentifier) -> BlinkItemReference? {
    print("requesting File BlinkItemReference : \(identifier.itemIdentifier.rawValue)")
    return shared.references[identifier.itemIdentifier.rawValue]
  }

  static func reference(url: URL) -> BlinkItemReference? {
    let manager = NSFileProviderManager.default
    let containerPath = manager.documentStorageURL.path

    // file://<containerPath>/<encodedRootPath>/<encodedPath>/filename
    // file://<containerPath>/<encodedRootPath>/path/filename
    // Remove containerPath, split and get encodedRootPath.
    var encodedPath = url.path
    encodedPath.removeFirst(containerPath.count)
    if encodedPath.hasPrefix("/") {
      encodedPath.removeFirst()
    }

    // <encodedRootPath>/<path>/<to>/filename
    return shared.references[encodedPath]
  }
}


class SSHClientConfigProvider {
  
  static func config(host title: String) throws -> (String, SSHClientConfig) {
   
    // NOTE This is just regular config initialization. Usually happens on AppDelegate, but the
    // FileProvider doesn't get another chance.
    BKHosts.loadHosts()
    BKPubKey.loadIDS()
    
    let bkConfig = try BKConfig()
    let agent = SSHAgent()
    let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]

    let host = try bkConfig.bkSSHHost(title)
    
    if let signers = bkConfig.signer(forHost: host) {
      signers.forEach { (signer, name) in
        _ = agent.loadKey(signer, aka: name, constraints: consts)
      }
    } else {
      for (signer, name) in bkConfig.defaultSigners() {
        _ = agent.loadKey(signer, aka: name, constraints: consts)
      }
    }

    var availableAuthMethods: [AuthMethod] = [AuthAgent(agent)]
    if let password = host.password, !password.isEmpty {
      availableAuthMethods.append(AuthPassword(with: password))
    }
    
    let log = BlinkLogger("SSH")
    let logger = PassthroughSubject<String, Never>()
    logger.sink {
      log.send($0)
      
    }.store(in: &logCancellables)


    return (host.hostName ?? title,
            host.sshClientConfig(authMethods: availableAuthMethods,
                                 agent: agent,
                                 logger: logger)
    )
  }
}
