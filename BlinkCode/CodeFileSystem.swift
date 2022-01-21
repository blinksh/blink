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


class CodeFileSystem {
  private let translator: AnyPublisher<Translator, Error>
  private let uri: URI
  private let log: BlinkLogger
  
  init(_ t: AnyPublisher<Translator, Error>, uri: URI) {
    self.translator = t
    self.uri = uri
    self.log = CodeFileSystemLogger.log("\(uri.rootPath.host)")
  }

  func stat() -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    self.log.debug("stat \(path)")

    return translator
      .flatMap {
        $0.cloneWalkTo(path)
          .mapError { _ in
            return CodeFileSystemError.fileNotFound(uri: self.uri)
          }
      }
      .flatMap { $0.stat() }
      .map { attrs -> FileStat in
        self.log.debug("stat \(path) called.")
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
    self.log.debug("readDirectory \(path)")

    return translator
      .flatMap { $0.cloneWalkTo(path) }
      .flatMap { $0.directoryFilesAndAttributesResolvingLinks() }
      .map { filesAttributes -> [DirectoryTuple] in
        self.log.debug("readDirectory \(path) called. \(filesAttributes.count) items.")

        return filesAttributes
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
    self.log.debug("readFile \(path)")
    
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
        self.log.debug("readFile \(path) completed. Read \(dd.count) bytes.")

        return (nil, result)
      }
      .eraseToAnyPublisher()
  }

  func writeFile(options: FileSystemOperationOptions, content: Data) -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    self.log.debug("writeFile \(path)")
    
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
            return fileT.open(flags: O_WRONLY | O_TRUNC)
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
              return file.close()
                .map { _ in
                  0 }
                .eraseToAnyPublisher()
            }
            return file.write(content.withUnsafeBytes { DispatchData(bytes: $0) }, max: content.count)
              .reduce(0, { count, written -> Int in
                           return count + written
              })
              .flatMap { wrote -> AnyPublisher<Int, Error> in
                self.log.debug("writeFile \(path) completed. Wrote \(wrote) bytes.")
                return file.close().map { _ in wrote }.eraseToAnyPublisher()
              }
              .eraseToAnyPublisher()
          }
        // 3. Resolve once everything copied. Just collect but output nothing.
          .map { _ in (nil, nil) }
          .eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }

  func createDirectory() -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    self.log.debug("createDirectory \(path)")
    
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
    self.log.debug("rename \(path)")
    
    // Walk to oldURI
    // Walk to new parent
    // Walk to file and apply overwrite
    // Stat to new location. Or fail.
    let newParent = newUri.rootPath.parent.filesAtPath
    let newName   = newUri.rootPath.url.lastPathComponent
    
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
        .flatMap { newParentT in
          oldT.wstat([.name: (newParentT.current as NSString).appendingPathComponent(newName)])
        }
      }
      .map { _ in (nil, nil) }
      .eraseToAnyPublisher()
  }

  func delete(options: FileSystemOperationOptions) -> WebSocketServer.ResponsePublisher {
    let path = self.uri.rootPath.filesAtPath
    self.log.debug("delete \(path)")
    
    let recursive = options.recursive ?? false

    func delete(_ translators: [Translator]) -> AnyPublisher<Void, Error> {
      translators.publisher
        .flatMap(maxPublishers: .max(1)) { t -> AnyPublisher<Void, Error> in
          print(t.current)
          if t.fileType == .typeDirectory {
            return [deleteDirectoryContent(t), AnyPublisher(t.rmdir().map {_ in})]
              .compactMap { $0 }
              .publisher
              .flatMap(maxPublishers: .max(1)) { $0 }
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
      .flatMap {
        t.cloneWalkTo($0[.name] as! String) }
      .collect()
      .flatMap {
        delete($0) }
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