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

import BlinkFiles
import FileProvider
import Combine

import SSH


public typealias TranslatorPublisher = AnyPublisher<Translator, Error>

public class FilesTranslatorConnection {
  private let providerPath: BlinkFileProviderPath
  private let configurator: any FileTranslatorFactory.Configurator
  private var _rootTranslator: Translator? = nil
  private var _rootTranslatorPublisher: TranslatorPublisher? = nil
  private let _rootTranslatorQueue = DispatchQueue(label: "sh.blink.FileProvider.FileTranslatorConnection.rootTranslatorQueue")

  var rootTranslatorPath: String!

  public var rootTranslator: TranslatorPublisher {
    return self._rootTranslatorQueue.sync {
      if let rootTranslatorPublisher = _rootTranslatorPublisher,
         // If we are connecting
        _rootTranslator == nil {
        print("Send current translator")
        return rootTranslatorPublisher
      } else if let rootTranslatorPublisher = _rootTranslatorPublisher,
        // If we are still connected
        let rootTranslator = _rootTranslator,
        rootTranslator.isConnected {
        print("Send current translator")
        return rootTranslatorPublisher
      }

      print("New translator")
      self._rootTranslator = nil
      self._rootTranslatorPublisher = nil

      let rootTranslatorPublisher = rootTranslatorPublisher()
      self._rootTranslatorPublisher = rootTranslatorPublisher
      return rootTranslatorPublisher
    }
  }

  public init(providerPath: BlinkFileProviderPath, configurator: any FileTranslatorFactory.Configurator) {
    self.providerPath = providerPath
    self.configurator = configurator
  }

  private func rootTranslatorPublisher() -> TranslatorPublisher {
    FileTranslatorFactory.rootTranslator(for: providerPath, configurator: configurator)
      .map { [weak self] t in
        self?._rootTranslatorQueue.sync(flags: .barrier) { [weak self] in
          guard let self = self else { return }
          self._rootTranslator = t
          self.rootTranslatorPath = t.current
        }
        return t
      }
    // It can happen that a FTC gets cancelled before the elements are passed down.
    // We need to subsequently nil the publisher as otherwise the previous map won't reset.
      .handleEvents(
        receiveCompletion: { [weak self] completion in
          guard let self = self else { return }
          self._rootTranslatorQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if case let .failure(error) = completion {
              print("Connection error - \(error)")
              self._rootTranslatorPublisher = nil
              self._rootTranslator = nil
            }
          }
        },
        receiveCancel: { [weak self] in
          guard let self = self else { return }
          self._rootTranslatorQueue.sync(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            print("TranslatorPublisher cancelled")
            self._rootTranslator = nil
            self._rootTranslatorPublisher = nil
          }
      })
      .shareReplay(maxValues: 1)
      .eraseToAnyPublisher()
  }
}

enum BlinkFilesProtocol: String {
  case local = "local"
  case sftp =  "sftp"
}

public struct BlinkFileProviderPath {
  private let fullPath: String

  var proto: BlinkFilesProtocol
  var hostPath: String? // user@host#port
  var filePath: String

  public init(_ fullPath: String) throws {
    self.fullPath = fullPath

    let components = self.fullPath.components(separatedBy: ":")

    switch components.count {
    case 1:
      // For a local path, we already have either absolute or relative to current
      let filePath = components[0]
      if filePath.starts(with: "/") {
        self.filePath = filePath
      } else if filePath.starts(with: "~") {
        self.filePath = ("/" as NSString).appendingPathComponent(filePath)
      } else {
        self.filePath = (FileManager.default.currentDirectoryPath as NSString)
          .appendingPathComponent(filePath)
      }

      self.proto = .local
    case 2:
      // For remote paths, we start with absolute / or relative to ~
      let filePath = components[1]
      if filePath.isEmpty {
        self.filePath = "/~"
      } else if filePath.starts(with: "/") {
        self.filePath = filePath
      } else if filePath.starts(with: "~") {
        self.filePath = "/\(filePath)"
      } else { // Relative
        self.filePath = "/~/\(filePath)"
      }

      var host = components[0]
      if host.starts(with: "/") {
        host.removeFirst()
      }
      self.hostPath = host
      self.proto = .sftp
    default:
      let filePath = components[2...].joined(separator: ":")
      if filePath.isEmpty {
        self.filePath = "/~"
      } else if filePath.starts(with: "/") {
        self.filePath = filePath
      } else if filePath.starts(with: "~") {
        self.filePath = "/\(filePath)"
      } else { // Relative
        self.filePath = "/~/\(filePath)"
      }

      self.hostPath = components[1]
      var protoString = components[0]
      if protoString.starts(with: "/") {
        protoString.removeFirst()
      }

      guard let proto = BlinkFilesProtocol(rawValue: protoString) else {
        throw NSFileProviderError.noDomainProvided
      }
      self.proto = proto
    }
  }
}

public enum FileTranslatorFactory {
  // The configurator gives us more flexibility on locations for configurations. So BlinkTests or others do not depend on
  // Blink locations.
  public protocol Configurator {
    func sshConfig(host title: String) throws -> (String, SSHClientConfig)
  }

  static func rootTranslator(for path: BlinkFileProviderPath, configurator: Configurator) -> AnyPublisher<Translator, Error> {
    // TODO The domain.pathRelativeToDocumentStorage shouldn't be used in new Replicated Extension.
    // TODO This should probably receive a string, or another object that simplifies the setup, instead of a Domain, which is an
    // object from another domain.

    switch path.proto {
    case .local:
      return Local().walkTo(path.filePath)
    case .sftp:
      guard let host = path.hostPath else {
        return .fail(error: NSFileProviderError(errorCode: 400, errorDescription: "Missing host in Translator route"))
      }

      return SSHClient.dialInThread(host, withConfigProvider: configurator.sshConfig)
        .print("dialInThread")
        .flatMap { conn -> AnyPublisher<SFTPClient, Error> in
          return conn.requestSFTP()
        }
        .tryMap { try SFTPTranslator(on: $0) }
        .flatMap { $0.walkTo(path.filePath) }
        .eraseToAnyPublisher()
    }
  }
}

public class BlinkConfigFactoryConfiguration : FileTranslatorFactory.Configurator {
  public init() {}
  
  public func sshConfig(host title: String) throws -> (String, SSH.SSHClientConfig) {
    try SSHClientConfigProvider.config(host: title)
  }
}
