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


import Foundation


enum CodeFileSystemAction: String, Codable {
  case stat
  case readDirectory
  case readFile
  case writeFile
  case createDirectory
  case delete
  case rename
}

struct BaseFileSystemRequest: Codable {
  let op: CodeFileSystemAction
}

struct StatFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: URI
  
  init(uri: URI) {
    self.op = .stat
    self.uri = uri
  }
}

struct ReadDirectoryFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: URI
  
  init(uri: URI) {
    self.op = .readDirectory
    self.uri = uri
  }

}

struct ReadFileFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: URI
  
  init(uri: URI) {
    self.op = .readFile
    self.uri = uri
  }

}

struct WriteFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: URI
  let options: FileSystemOperationOptions

  init(uri: String, options: FileSystemOperationOptions) {
    self.op = .writeFile
    self.uri = uri
    self.options = options
  }
}

struct RenameFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let oldUri: URI
  let newUri: URI
  let options: FileSystemOperationOptions
  
  init(oldUri: String, newUri: String, options: FileSystemOperationOptions) {
    self.op = .rename
    self.oldUri = oldUri
    self.newUri = newUri
    self.options = options
  }
}

struct DeleteFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: URI
  let options: FileSystemOperationOptions
  
  init(uri: String, options: FileSystemOperationOptions) {
    self.op = .delete
    self.uri = uri
    self.options = options
  }
}

struct CreateDirectoryFileSystemRequest: Codable {
  let op: CodeFileSystemAction
  let uri: URI
  
  init(uri: URI) {
    self.op = .createDirectory
    self.uri = uri
  }
}

typealias URI = String

extension URI {
  var path: String { self.replacingOccurrences(of: "blink-fs:", with: "") }
}

struct FileSystemOperationOptions: Codable {
  let overwrite: Bool?
  let create: Bool?
  let recursive: Bool?
  
  init(overwrite: Bool? = nil, create: Bool? = nil, recursive: Bool? = nil) {
    self.overwrite = overwrite
    self.create = create
    self.recursive = recursive
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
  
  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    self.name = try container.decode(String.self)
    self.type = try container.decode(FileType.self)
  }
}

enum CodeFileSystemError: Error, Encodable {
  case badRequest
  case fileExists(uri: URI)
  case fileNotFound(uri: URI)
  case noPermissions(uri: URI)

  var info: (String, URI) {
    switch self {
    case .badRequest:
      return ("BadRequest", "Bad request error")
    case .fileExists(let uri):
      return ("FileExists", uri)
    case .fileNotFound(let uri):
      return ("FileNotFound", uri)
    case .noPermissions(let uri):
      return ("NoPermissions", uri)
    }
  }

  enum CodingKeys: String, CodingKey { case errorCode; case uri; }

  func encode(to encoder: Encoder) throws {
    let (errorCode, uri) = self.info
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(errorCode, forKey: .errorCode)
    try container.encode(uri, forKey: .uri)
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
