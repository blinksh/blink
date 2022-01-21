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
import Network
import System
import SwiftUI

import BlinkFiles
import BlinkConfig
import SSH


struct MountEntry: Codable {
  let name: String
  let root: String
}

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

public class CodeFileSystemService: CodeSocketDelegate {
  
  let server: WebSocketServer
  let log: BlinkLogger
  
  public let port: UInt16
  var tokens: [Int: MountEntry] = [:]
  var tokenIdx = 0;

  private var translators: [String: TranslatorControl] = [:]

  private let finishedCallback: ((Error?) -> ())
  func finished(_ error: Error?) { finishedCallback(error) }
  
  public var state: NWListener.State {
    server.listener.state
  }
  
  public func registerMount(name: String, root: String) -> Int {
    tokenIdx += 1
    tokens[tokenIdx] = MountEntry(name: name, root: root)
    log.info("Registered mount \(tokenIdx) for \(name) at \(root)")
    return tokenIdx
  }

  public func deregisterMount(_ token: Int) {
    log.info("De-registering mount \(tokenIdx)")
    // If no other token is using the same translator, trash it
    guard let token = tokens.removeValue(forKey: tokenIdx) else {
      return
    }
    let root = URL(string: token.root)!

    // If we have no host, there is no remote translator
    guard let host = root.host,
          let _ = translators[host] else {
      return
    }

    // Remove the Translator if no other mounts use it.
    if let _ = tokens.first(where: { (_, tk) in
                                   let url = URL(string: tk.root)!
                                   return host == url.host
                                 }) {
      return
    }

    translators.removeValue(forKey: host)
  }

  public init(listenOn port: NWEndpoint.Port, tls: Bool, finished: @escaping ((Error?) -> ()))  throws {
    self.port = port.rawValue
    self.server = try WebSocketServer(listenOn: port, tls: tls)
    self.finishedCallback = finished
    
    self.log = CodeFileSystemLogger.log("FileSystem")
    
    self.server.delegate = self
  }
  
  func getRoot(token: Int, version: Int) -> WebSocketServer.ResponsePublisher {
    if let mount = self.tokens[token] {
      return .just((try! JSONEncoder().encode(mount), nil)).eraseToAnyPublisher()
    } else {
      return .just((nil, nil)).eraseToAnyPublisher()
    }
  }

  public func handleMessage(encodedData: Data, binaryData: Data?) -> WebSocketServer.ResponsePublisher {
    guard let request = try? JSONDecoder().decode(BaseFileSystemRequest.self, from: encodedData) else {
      log.error(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: WebSocketError(message: "Bad request"))
    }

    do {
      switch request.op {
      case .getRoot:
        let msg: GetRootRequest = try decode(encodedData)
        return try getRoot(token: msg.token, version: msg.version)
      case .stat:
        let msg: StatFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.uri).stat()
      case .readDirectory:
        let msg: ReadDirectoryFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.uri).readDirectory()
      case .readFile:
        let msg: ReadFileFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.uri).readFile()
      case .writeFile:
        let msg: WriteFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.uri).writeFile(options: msg.options,
                                                      content: binaryData ?? Data())
      case .createDirectory:
        let msg: CreateDirectoryFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.uri).createDirectory()
      case .rename:
        let msg: RenameFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.oldUri).rename(newUri: msg.newUri,
                                                     options: msg.options)
      case .delete:
        let msg: DeleteFileSystemRequest = try decode(encodedData)
        return try fileSystem(for: msg.uri).delete(options: msg.options)
      }
    } catch {
      log.error("\(error)")
      log.error("Processing request \(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")")
      return .fail(error: error)
    }
  }

  private func fileSystem(for uri: URI) throws -> CodeFileSystem {
    let rootPath = uri.rootPath

    if let host = rootPath.host,
       let tRef = translators[host],
       tRef.translator.isConnected {
      return CodeFileSystem(.just(tRef.translator), uri: uri)
    }
    
    switch(rootPath.protocolIdentifier) {
    case "blinksftp":
      guard let hostAlias = rootPath.host else {
        throw WebSocketError(message: "Missing host on rootpath")
      }

      let translator = AnyPublisher(SSHClient
        .dial(hostAlias, withConfigProvider: SSHClientFileProviderConfig.config)
        .flatMap { connControl in
          Just(connControl.connection)
            .flatMap { $0.requestSFTP() }
            .tryMap  { try SFTPTranslator(on: $0) }
            .map     { t -> Translator in
              self.translators[hostAlias]  = TranslatorControl(t, connectionControl: connControl)
              return t
            }
        })
      
      return CodeFileSystem(translator, uri: uri)

    case "blinkfs":
      // The local one does not need to be saved.
      return CodeFileSystem(.just(BlinkFiles.Local()), uri: uri)
    default:
      throw WebSocketError(message: "Unknown protocol - \(rootPath.protocolIdentifier)")
    }        
  }  
}

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

  public var parent: RootPath {
    return RootPath(url.deletingLastPathComponent())
  }
}

// A special FileProvider configuration that skips over user input configurations.
class SSHClientFileProviderConfig {

  static func config(host title: String) throws -> (String, SSHClientConfig) {

    let bkConfig = try BKConfig()
    let agent = SSHAgent()

    let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]

    let host = try bkConfig.bkSSHHost(title)
    let hostName = host.hostName
    
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

    return (hostName ?? title,
            host.sshClientConfig(authMethods: availableAuthMethods,
                                  agent: agent))
  }
}

extension CodeFileSystemService {
  func decode<T: Decodable>(_ encodedData: Data) throws -> T {
    try JSONDecoder().decode(T.self, from: encodedData)
  }
}

struct CodeFileSystemLogger {
  static var handler = [BlinkLogging.LogHandlerFactory]()
  static func log(_ component: String) -> BlinkLogger {
    if handler.isEmpty {
      handler.append(
        {
          $0.format { [ $0[.component] as? String ?? "global",
                      $0[.message] as? String ?? ""
                    ].joined(separator: " ") }
          .sinkToOutput()
        }
      )
      
      let dateFormatter = DateFormatter()
      dateFormatter.dateFormat = "MMM dd YYYY, HH:mm:ss"
      if let file = try? FileLogging(to: BlinkPaths.blinkCodeErrorLogURL()) {
        handler.append(
          {
            try $0
            .filter(logLevel: .debug)
            .format {
              [ "[\($0[.logLevel]!)]",
                dateFormatter.string(from: Date()),
                $0[.component] as? String ?? "global",
                $0[.message] as? String ?? ""
              ].joined(separator: " ") }
            .sinkToFile(file)
          }
        )
      } else {
        print("File logging not working")
      }
    }

    return BlinkLogger(component, handlers: handler)
  }
}
