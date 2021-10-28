import Combine
import Foundation
import Network

import BlinkFiles


enum CodeFileSystemAction: String, Codable {
  case stat
  case readDirectory
  case readFile
  case writeFile
}

enum CodeFileSystemError: Error {
  case badRequest
  case fileExists
  case fileNotFound
}

struct CodeFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: String
}

struct WriteFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: String
  let options: Options

  struct Options: Codable {
    let overwrite: Bool
    let create: Bool
  }
  
  init(uri: String, options: Options) {
    self.op = .writeFile
    self.uri = uri
    self.options = options
  }
}

struct DirectoryTuple: Codable {
  let name: String
  let type: FileType

  init(name: String, type: FileType) {
    self.name = name
    self.type = type
  }
  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(name)
    try container.encode(type)
  }
}

// We may create a new FS per base URI. And then all of them into a singleton
// We may just group all that here.
class CodeFileSystemService: CodeSocketDelegate {
  let server: WebSocketServer

  init(listenOn port: NWEndpoint.Port, tls: Bool) throws {
    self.server = try WebSocketServer(listenOn: port, tls: tls)
    self.server.delegate = self
  }

  public func handleMessage(encodedData: Data, binaryData: Data?) -> WebSocketServer.ResponsePublisher {
    guard let request = decodeFileSystemRequest(encodedData) else {
      print(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: CodeFileSystemError.badRequest)
    }

    // We need the URI
    let fs = CodeFileSystem(.just(Local()))

    do {
      let uri = request.uri.replacingOccurrences(of: "blink-fs:", with: "")

      // TODO I want this to be objects as otherwise it becomes messy to change a name or reference.
      switch request.op {
      case .stat:
        return fs.stat(uri)
      case .readDirectory:
        return fs.readDirectory(uri)
      case .readFile:
        return fs.readFile(uri)
      case .writeFile:
        let msg = try JSONDecoder().decode(WriteFileSystemRequest.self, from: encodedData)
        return fs.writeFile(uri, options: msg.options, content: binaryData ?? Data())
      default:
        print(String(data: encodedData, encoding: .utf8) ?? "Unknown operation")
        return .fail(error: CodeFileSystemError.badRequest)
      }
    } catch {
      print(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: CodeFileSystemError.badRequest)
    }
  }
    // TODO Process the URI
    // sftp:host:route
    // code /

  func decodeFileSystemRequest(_ encoded: Data) -> CodeFileSystemRequest? {
    if let request: CodeFileSystemRequest = try? JSONDecoder().decode(CodeFileSystemRequest.self, from: encoded)
       //let opCode = CodeFileSystemAction(rawValue: request["op"] ?? ""),
       //let uri = request["uri"]
    {
      return request //CodeFileSystemRequest(op: opCode, uri: uri)
    } else {
      return nil
    }
  }
}

class CodeFileSystem {
  let translator: AnyPublisher<Translator, Error>

  init(_ t: AnyPublisher<Translator, Error>) {
    self.translator = t
  }

  func stat(_ uri: String) -> WebSocketServer.ResponsePublisher {
    print("stat \(uri)")

    return translator
      .flatMap { $0.cloneWalkTo(uri) }
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

  func readDirectory(_ uri: String) -> WebSocketServer.ResponsePublisher {
    print("readDirectory \(uri)")

    return translator
      .flatMap { $0.cloneWalkTo(uri) }
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

  func readFile(_ uri: String) -> WebSocketServer.ResponsePublisher {
    print("readFile \(uri)")
    return translator
      .flatMap { $0.cloneWalkTo(uri) }
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

  func writeFile(_ uri: String, options: WriteFileSystemRequest.Options, content: Data) -> WebSocketServer.ResponsePublisher {
    print("writeFile \(uri)")
    let parentDir = (uri as NSString).deletingLastPathComponent
    let fileName  = (uri as NSString).lastPathComponent

    return translator
      .flatMap { $0.cloneWalkTo(parentDir) }
      // 1. If the file exists, then check overwrite. Otherwise create if create flag is set.
      .flatMap { parentT -> WebSocketServer.ResponsePublisher in
        parentT.cloneWalkTo(fileName)
          .flatMap { fileT -> AnyPublisher<File, Error> in
            // [`FileExists`](#FileSystemError.FileExists) when `uri` already exists and `overwrite` is set.
            // NOTE From testing, looks like docs should say 'overwrite' is NOT set.
            if !options.overwrite {
              return .fail(error: CodeFileSystemError.fileExists)
            }
            return fileT.open(flags: O_RDWR | O_TRUNC)
          }
          .tryCatch { error -> AnyPublisher<BlinkFiles.File, Error> in
            if case CodeFileSystemError.fileExists = error {
              throw error
            }
            // [`FileNotFound`](#FileSystemError.FileNotFound) when `uri` doesn't exist and `create` is not set.
            if !options.create {
              return .fail(error: CodeFileSystemError.fileNotFound)
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
}

enum FileType: Int, Codable {
  case Unknown = 0
  case File = 1
  case Directory = 2
  case SymbolicLink = 64

  init(posixType: FileAttributeType?) {
    guard let posixType = posixType else {
      self = .Unknown
      return
    }

    switch posixType {
    case .typeRegular:
      self = .File
    case .typeDirectory:
      self = .Directory
    case .typeSymbolicLink:
      self = .SymbolicLink
    default:
      self = .Unknown
    }
  }
}

struct FileStat: Codable {
  let type: FileType
  let ctime: Int?
  let mtime: Int?
  let size: Int?

  init(type: FileType?, ctime: Int?, mtime: Int?, size: Int?) {
    self.type = type ?? .Unknown
    self.ctime = ctime
    self.mtime = mtime
    self.size = size
  }
}

struct WriteFileOptions: Codable {
  let create: Bool
  let overwrite: Bool
}
