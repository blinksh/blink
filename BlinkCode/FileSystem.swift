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

import BlinkFiles
import BlinkConfig
import System
import SwiftUI

struct MountEntry: Codable {
  let name: String
  let root: String
}

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

public class CodeFileSystemService: CodeSocketDelegate {
  
  let server: WebSocketServer
  let log: BlinkLogger
  
  public let port: UInt16
  var tokens: [Int: MountEntry] = [:]
  var tokenIdx = 0;

  private var translators: [String: TranslatorReference] = [:]

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
      let builder = TranslatorFactories.sftp
      var thread: Thread!
      var runLoop: RunLoop? = nil
      
      let threadIsReady = Future<RunLoop, Error> { promise in
        thread = Thread {
          let timer = Timer(timeInterval: TimeInterval(INT_MAX), repeats: true) { _ in
            print("timer")
          }
          runLoop = RunLoop.current
          RunLoop.current.add(timer, forMode: .default)
          promise(.success(RunLoop.current))
          CFRunLoopRun()
          // Wrap it up
          RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        }
        thread.start()
      }
      
      guard let hostAlias = rootPath.host else {
        throw WebSocketError(message: "Missing host on rootpath")
      }

      let translator = threadIsReady
        .flatMap { builder.buildOn($0, hostAlias: hostAlias) }
        .map { t -> Translator in
          self.translators[rootPath.host!] = TranslatorReference(t, cancel: {
            self.log.debug("Cancelling translator")
            let cfRunLoop = runLoop!.getCFRunLoop()
            CFRunLoopStop(cfRunLoop)
          })
          return t
        }
        .eraseToAnyPublisher()

      return CodeFileSystem(translator, uri: uri)

    case "blinkfs":
      // The local one does not need to be saved.
      return CodeFileSystem(TranslatorFactories.local.build(rootPath), uri: uri)
    default:
      throw WebSocketError(message: "Unknown protocol - \(rootPath.protocolIdentifier)")
    }        
  }  
}

class CodeFileSystem {
  private let translator: AnyPublisher<Translator, Error>
  private let uri: URI
  
  init(_ t: AnyPublisher<Translator, Error>, uri: URI) {
    self.translator = t
    self.uri = uri
  }

  func stat() -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("stat \(path)")

    return translator
      .flatMap {
        $0.cloneWalkTo(path)
          .mapError { _ in
            return CodeFileSystemError.fileNotFound(uri: self.uri)
          }
      }
      .flatMap { $0.stat() }
      .map { attrs -> FileStat in
        var mtimeMillis = 0
        var ctimeMillis = 0
        if let mtime = attrs[.modificationDate] as? NSDate {
          mtimeMillis = Int(mtime.timeIntervalSince1970)
        }
        if let createtime = attrs[.creationDate] as? NSDate {
          ctimeMillis = Int(createtime.timeIntervalSince1970)
        }
        return FileStat(type: FileType(posixType: attrs[.type] as? FileAttributeType),
                 ctime: ctimeMillis,
                 mtime: mtimeMillis,
                 size: attrs[.size] as? Int)
      }
      .tryMap { (try JSONEncoder().encode($0), nil) }
      .eraseToAnyPublisher()
  }

  func readDirectory() -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("readDirectory \(path)")

    return translator
      .flatMap { $0.cloneWalkTo(path) }
      .flatMap { $0.directoryFilesAndAttributesResolvingLinks() }
      .map { filesAttributes -> [DirectoryTuple] in
        filesAttributes
          .filter { ($0[.name] as! String != "." && $0[.name] as! String != "..") }
          .map {
          DirectoryTuple(name: $0[.name] as! String,
                         type: FileType(posixType: $0[.type] as? FileAttributeType))
        }
      }
      .tryMap { (try JSONEncoder().encode($0), nil) }
      .eraseToAnyPublisher()
  }

  func readFile() -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("readFile \(path)")
    
    return translator
      .flatMap {
        $0.cloneWalkTo(path)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri: self.uri) }
      }
      .flatMap { $0.open(flags: O_RDONLY) }
      .flatMap { file -> AnyPublisher<DispatchData, Error> in
        var content = DispatchData.empty
        return file
          .read(max: Int(INT32_MAX))
          .flatMap { dd -> AnyPublisher<Bool, Error> in
            content = dd
            return file.close()
          }
          .map { _ in content }.eraseToAnyPublisher()
      }
      .map { dd -> (Data?, Data?) in
        var result = Data(count: dd.count)
        result.withUnsafeMutableBytes { buf in
          _ = dd.copyBytes(to: buf)
        }
        return (nil, result)
      }
      .eraseToAnyPublisher()
  }

  func writeFile(options: FileSystemOperationOptions, content: Data) -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("writeFile \(path)")
    
    let parentDir = (path as NSString).deletingLastPathComponent
    let fileName  = (path as NSString).lastPathComponent

    return translator
      .flatMap { $0.cloneWalkTo(parentDir) }
      // 1. If the file exists, then check overwrite. Otherwise create if create flag is set.
      .flatMap { parentT -> WebSocketServer.ResponsePublisher in
        parentT.cloneWalkTo(fileName)
          .flatMap { fileT -> AnyPublisher<File, Error> in
            // [`FileExists`](#FileSystemError.FileExists) when `uri` already exists and `overwrite` is set.
            // NOTE From testing, looks like docs should say 'overwrite' is NOT set.
            if !(options.overwrite ?? false) {
              return .fail(error: CodeFileSystemError.fileExists(uri: self.uri))
            }
            return fileT.open(flags: O_RDWR | O_TRUNC)
          }
          .tryCatch { error -> AnyPublisher<BlinkFiles.File, Error> in
            if case CodeFileSystemError.fileExists = error {
              throw error
            }
            // [`FileNotFound`](#FileSystemError.FileNotFound) when `uri` doesn't exist and `create` is not set.
            if !(options.create ?? false) {
              return .fail(error: CodeFileSystemError.fileNotFound(uri: self.uri))
            }
            return parentT.create(name: fileName, flags: O_WRONLY, mode: 0o644)
          }
        // 2. Write the content to the file
          .flatMap { file -> AnyPublisher<Int, Error> in
            if content.isEmpty {
              return .just(0)
            }
            return file.write(content.withUnsafeBytes { DispatchData(bytes: $0) }, max: content.count)
              .reduce(0, { count, written -> Int in
                           print("Total Written \(count)")
                           return count + written
              }).eraseToAnyPublisher()
          }
        // 3. Resolve once everything copied. Just collect but output nothing.
          .map { _ in (nil, nil) }
          .eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }

  func createDirectory() -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("createDirectory \(path)")
    
    let parentUri = URI(rootPath: self.uri.rootPath.parent)
    let parent  = parentUri.rootPath.filesAtPath
    let dirName = (path as NSString).lastPathComponent

    return translator
      .flatMap {
        $0.cloneWalkTo(parent)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri: parentUri) }
      }
      .flatMap { parentT -> AnyPublisher<Translator, Error> in
        parentT.cloneWalkTo(dirName)
          .tryMap { _ in throw CodeFileSystemError.fileExists(uri:self.uri) }
          .tryCatch { error -> AnyPublisher<Translator, Error> in
            if case CodeFileSystemError.fileExists = error {
              throw error
            }
            return parentT
              .mkdir(name: dirName, mode: S_IRWXU | S_IRWXG | S_IRWXO)
              .mapError { _ in return CodeFileSystemError.noPermissions(uri: parentUri) }
              .eraseToAnyPublisher()
          }.eraseToAnyPublisher()
      }
      .map { _ in (nil, nil) }
      .eraseToAnyPublisher()
  }

  func rename(newUri: URI, options: FileSystemOperationOptions) -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("rename \(path)")
    
    // Walk to oldURI
    // Walk to new parent
    // Walk to file and apply overwrite
    // Stat to new location. Or fail.
    let newParent = newUri.rootPath.parent.filesAtPath
    let newPath   = newUri.rootPath.filesAtPath
    
    return translator
      .flatMap {
        $0.cloneWalkTo(path)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri: self.uri) }
      }
      .flatMap { oldT in
        self.translator.flatMap {
            $0.cloneWalkTo(newParent)
            .mapError { _ in CodeFileSystemError.fileNotFound(uri: URI(rootPath: newUri.rootPath.parent)) }
          }
        // Will take the easy route for now.
        // We try the stat, and will figure out if in case it is a file, we have to
        // remove it or what.
        .flatMap { _ in oldT.wstat([.name: newPath]) }
      }
      .map { _ in (nil, nil) }
      .eraseToAnyPublisher()
  }

  func delete(options: FileSystemOperationOptions) -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    print("rename \(path)")
    
    let recursive = options.recursive ?? false

    func delete(_ translators: [Translator]) -> AnyPublisher<Void, Error> {
      translators.publisher
        .flatMap { t -> AnyPublisher<Void, Error> in
          print(t.current)
          if t.fileType == .typeDirectory {
            return [deleteDirectoryContent(t), AnyPublisher(t.rmdir().map {_ in})]
              .compactMap { $0 }
              .publisher
              .flatMap { $0 }
              .collect()
              .map {_ in}
              .eraseToAnyPublisher()
          }

          return AnyPublisher(t.remove().map { _ in })
        }.eraseToAnyPublisher()
    }

    func deleteDirectoryContent(_ t: Translator) -> AnyPublisher<Void, Error>? {
      if recursive == false {
        return nil
      }

      return t.directoryFilesAndAttributes().flatMap {
        $0.compactMap { i -> FileAttributes? in
          if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
            return nil
          } else {
            return i
          }
        }.publisher
      }
      .flatMap { t.cloneWalkTo($0[.name] as! String) }
      .collect()
      .flatMap { delete($0) }
      .eraseToAnyPublisher()
    }

    return translator
      .flatMap {
        $0.cloneWalkTo(path)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri: self.uri) }
          .flatMap { delete([$0]) }
      }
      .map { _ in (nil, nil) }
      .eraseToAnyPublisher()
  }

}

extension CodeFileSystemService {
  func decode<T: Decodable>(_ encodedData: Data) throws -> T {
    try JSONDecoder().decode(T.self, from: encodedData)
  }
}

extension RootPath {
  public var parent: RootPath {
    RootPath([protocolIdentifier,
              host,
              (filesAtPath as NSString).deletingLastPathComponent]
              .compactMap { $0 }
              .joined(separator: ":"))
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
            try $0.format {
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
