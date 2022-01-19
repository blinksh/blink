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

import BlinkFiles


class TranslatorReference {
  let translator: Translator
  let cancel: () -> Void

  init(_ translator: Translator, cancel: @escaping (() -> Void)) {
    self.translator = translator
    self.cancel = cancel
  }
  
  deinit {
    cancel()
  }
}

final class FileTranslatorCache {
  static let shared = FileTranslatorCache()
  private var translators: [String: TranslatorReference] = [:]
  private var references: [String: BlinkItemReference] = [:]
  private var fileList:   [String: [BlinkItemReference]] = [:]
  private var backgroundThread: Thread? = nil
  private var backgroundRunLoop: RunLoop = RunLoop.current


  private init() {
    // self.backgroundThread = Thread {
    //   self.backgroundRunLoop = RunLoop.current
    //   // TODO Probably need a timer. This may exit immediately
    //   RunLoop.current.run()
    // }

    // self.backgroundThread!.start()
  }

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
      return Local().walkTo(pathAtFiles)
    case .sftp:
      guard let host = host else {
        return .fail(error: "Missing host in Translator route")
      }
      return sftp(host: host, path: pathAtFiles)
        .map { tr -> Translator in
          shared.translators[encodedRootPath] = tr
          return tr.translator
        }.eraseToAnyPublisher()
    default:
      return .fail(error: "Not implemented")
    }
  }

  static func store(reference: BlinkItemReference) {
    print("storing File BlinkItemReference : \(reference.itemIdentifier.rawValue)")
//    let parent = reference.parentIdentifier.rawValue
//    if shared.fileList[parent] == nil {
//      shared.fileList[parent] = []
//    }
//    shared.fileList[parent]!.append(reference)
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
