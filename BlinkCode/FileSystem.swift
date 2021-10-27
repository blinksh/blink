import Combine
import Foundation
import Network

import BlinkFiles


enum CodeFileSystemAction: String, Codable {
  case stat
  case readDirectory
}

enum CodeFileSystemError: Error {
  case badRequest
}

struct CodeFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: String
  // let extraOptions: Enum
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
      request = try JSONDecoder().decode(CodeFileSystemRequest.self, from: encodedData)
    } catch {
      return .fail(error: CodeFileSystemError.badRequest)
    }

    // TODO Keep a list of CodeFileSystem, as entry points / references each file system,
    // so things like connections can be persisted.
    // For now we will just go with new instances on Local system.
    let fs = CodeFileSystem(.just(Local()))

    switch request.op {
    case .stat:
      return fs.stat(request.uri)
    case .readDirectory:
      return fs.readDirectory(request.uri)
    default:
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
    return translator
      .flatMap { $0.cloneWalkTo(uri) }
      .flatMap { $0.stat() }
      .map {
        FileStat(type: FileType(posixType: $0[.type] as? FileAttributeType),
                 ctime: $0[.creationDate] as? Int,
                 mtime: $0[.modificationDate] as? Int,
                 size: $0[.size] as? Int)
      }
      .tryMap { (try JSONEncoder().encode($0), nil) }
      .eraseToAnyPublisher()
  }
  
  func readDirectory(_ uri: String) -> WebSocketServer.ResponsePublisher {
    return translator
      .flatMap { $0.cloneWalkTo(uri) }
      .flatMap { $0.directoryFilesAndAttributes() }
      .map { filesAttributes -> [String:FileType] in
        filesAttributes.reduce(into: [String:FileType]()) { (result, attrs) in
          result[attrs[.name] as! String] = FileType(posixType: attrs[.type] as? FileAttributeType)
        }
      }
      .tryMap { (try JSONEncoder().encode($0), nil) }
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
