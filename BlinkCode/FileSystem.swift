import Combine
import Foundation
import Network

import BlinkFiles
import System
import SwiftUI

struct MountEntry: Codable {
  let name: String
  let root: String
}


public class CodeFileSystemService: CodeSocketDelegate {
  let server: WebSocketServer
  
  public let port: UInt16
  var tokens: [Int: MountEntry] = [:]
  var tokenIdx = 0;

  private var translators: [String: (Translator, RunLoop)] = [:]
  
  public func registerMount(name: String, root: String) -> Int {
    tokenIdx += 1
    tokens[tokenIdx] = MountEntry(name: name, root: root)
    return tokenIdx
  }

  public init(listenOn port: NWEndpoint.Port, tls: Bool) throws {
    self.port = port.rawValue
    self.server = try WebSocketServer(listenOn: port, tls: tls)

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
      print(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: CodeFileSystemError.badRequest)
    }

    do {
      switch request.op {
      case .getRoot:
        let msg: GetRootRequest = try decode(encodedData)
        return getRoot(token: msg.token, version: msg.version)
      case .stat:
        let msg: StatFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.uri).stat()
      case .readDirectory:
        let msg: ReadDirectoryFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.uri).readDirectory()
      case .readFile:
        let msg: ReadFileFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.uri).readFile()
      case .writeFile:
        // TODO Change the other requests
        let msg: WriteFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.uri).writeFile(options: msg.options,
                                                  content: binaryData ?? Data())
      case .createDirectory:
        let msg: CreateDirectoryFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.uri).createDirectory()
      case .rename:
        let msg: RenameFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.oldUri).rename(newUri: msg.newUri,
                                                  options: msg.options)
      case .delete:
        let msg: DeleteFileSystemRequest = try decode(encodedData)
        return fileSystem(for: msg.uri).delete(options: msg.options)
      }
    } catch {
      print(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: CodeFileSystemError.badRequest)
    }
  }

  private func fileSystem(for uri: URI) -> CodeFileSystem {
    let rootPath = RootPath(from: uri)

    if let (t, _) = translators[rootPath.protocolIdentifier],
       t.isConnected {
      return CodeFileSystem(.just(t), uri: uri)
    }
    
    switch(rootPath.protocolIdentifier) {
    case "sftp":
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
        }
        thread.start()
      }
      
      let translator = threadIsReady
        .flatMap { builder.buildOn($0, rootPath: rootPath) }
        .map { t -> Translator in
          self.translators[rootPath.protocolIdentifier] = (t, runLoop!)
          return t
        }
        .eraseToAnyPublisher()

      return CodeFileSystem(translator, uri: uri)

    case "local":
      // The local one does not need to be saved.
      return CodeFileSystem(TranslatorFactories.local.build(rootPath), uri: uri)
    default:
      return CodeFileSystem(.fail(error: "Unknown protocol - \(rootPath.protocolIdentifier)"), uri: uri)
    }
    
    // Use a single thread for all the internal operations.
    // We need to have the RunLoop so we can control when the thread stops, to close the whole WebServer.
    // A thread for each SFTP connection seems excessive. But this one would be unused if only for local.
    // TODO An alternative would be to capture the "RunLoop" when we capture the Translator.
    // Then we could use that to wake it up and go.
    // TODO There is still the trick of cleaning up the objects, which requires to run the RunLoop again.
    // I was thinking we could actually make that as part of the "deinit" for LibSSH.
    // Because LibSSH already has stuff loaded at the RunLoop, the deinit could still be triggered and go through.
  }
  // TODO Process the URI
  // sftp:host:route
  // code /
  public func cancel() {
    // If the WebSocket is cancelled (no more connections to serve), we can cancel the shared Service
    //Self._shared = nil
  }
}

class CodeFileSystem {
  private let translator: AnyPublisher<Translator, Error>
  private let uri: URI
  private var path: String { uri.rootPath.filesAtPath }
  
  init(_ t: AnyPublisher<Translator, Error>, uri: URI) {
    self.translator = t
    self.uri = uri
  }

  func stat() -> WebSocketServer.ResponsePublisher {
    print("stat \(path)")

    return translator
      .flatMap {
        $0.cloneWalkTo(self.path)
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
    print("readDirectory \(self.path)")

    return translator
      .flatMap { $0.cloneWalkTo(self.path) }
      .flatMap { $0.directoryFilesAndAttributes() }
      .map { filesAttributes -> [DirectoryTuple] in
        filesAttributes.map {
          DirectoryTuple(name: $0[.name] as! String,
                         type: FileType(posixType: $0[.type] as? FileAttributeType))
        }
      }
      .tryMap { (try JSONEncoder().encode($0), nil) }
      .eraseToAnyPublisher()
  }

  func readFile() -> WebSocketServer.ResponsePublisher {
    print("readFile \(self.path)")
    return translator
      .flatMap { $0.cloneWalkTo(self.uri) }
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
    print("createDirectory \(path)")
    let parent  = (path as NSString).deletingLastPathComponent
    let dirName = (path as NSString).lastPathComponent

    return translator
      .flatMap {
        $0.cloneWalkTo(parent)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri:self.uri) }
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
              .mapError { _ in return CodeFileSystemError.noPermissions(uri: parent) }
              .eraseToAnyPublisher()
          }.eraseToAnyPublisher()
      }
      .map { _ in (nil, nil) }
      .eraseToAnyPublisher()
  }

  func rename(newUri: URI, options: FileSystemOperationOptions) -> WebSocketServer.ResponsePublisher {
    print("rename \(self.path)")
    
    // Walk to oldURI
    // Walk to new parent
    // Walk to file and apply overwrite
    // Stat to new location. Or fail.
    let newParent = (newUri.rootPath.filesAtPath as NSString).deletingLastPathComponent
    let newPath   = newUri.rootPath.filesAtPath
    
    return translator
      .flatMap {
        $0.cloneWalkTo(self.path)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri: self.uri) }
      }
      .flatMap { oldT in
        self.translator.flatMap {
            $0.cloneWalkTo(newParent)
            .mapError { _ in CodeFileSystemError.fileNotFound(uri: newUri) }
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
        $0.cloneWalkTo(self.path)
          .mapError { _ in CodeFileSystemError.fileNotFound(uri: self.path) }
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

extension URI {
  var rootPath: RootPath { RootPath(from: self) }
}

extension RootPath {
  init(from uri: URI) {
    self.init(uri.path)
  }
}
