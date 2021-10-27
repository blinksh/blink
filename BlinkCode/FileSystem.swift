import Combine
import Foundation
import Network

import BlinkFiles


enum CodeFileSystemAction: String, Codable {
  case stat
  case readDirectory
  case readFile
}

enum CodeFileSystemError: Error {
  case badRequest
}

struct CodeFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: String
  // let extraOptions: Enum
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
    // TODO Parse and call the corresponding operation
    // We always need jsonData, otherwise there will be no operation.
    // TODO Why not then just make the whole protocol depend on that. JSONSize|JSONContent|BinaryContent
    let request: CodeFileSystemRequest
    do {
      // TODO Decode to [String:Any] and take it from there
      // Any is not codable, so we need to figure out something else. We could do String:String
      request = try JSONDecoder().decode(CodeFileSystemRequest.self, from: encodedData)
    } catch {
      print(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: CodeFileSystemError.badRequest)
    }

    // TODO Keep a list of CodeFileSystem, as entry points / references each file system,
    // so things like connections can be persisted.
    // For now we will just go with new instances on Local system.
    let fs = CodeFileSystem(.just(Local()))
    // TODO Process the URI
    // sftp:host:route
    // code /
    let uri = request.uri.replacingOccurrences(of: "blink-fs:", with: "")
    
    switch request.op {
    case .stat:
      return fs.stat(uri)
    case .readDirectory:
      return fs.readDirectory(uri)
    case .readFile:
      return fs.readFile(uri)
    default:
      print(String(data: encodedData, encoding: .utf8) ?? "Error decoding data")
      return .fail(error: CodeFileSystemError.badRequest)
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
