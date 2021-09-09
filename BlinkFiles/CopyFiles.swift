//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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
import Combine
import Dispatch

public struct CopyError : Error {
  public let msg: String
}


public struct CopyAttributesFlag: OptionSet {
  public var rawValue: UInt
  
  public static let none = CopyAttributesFlag(rawValue: 0)
  public static let timestamp = CopyAttributesFlag(rawValue: 1 << 0)
  public static let permissions = CopyAttributesFlag(rawValue: 1 << 1)
  
  public init(rawValue: UInt) {
    self.rawValue = rawValue
  }
  
  func filter(_ attrs: FileAttributes) -> FileAttributes {
    var newAttrs: FileAttributes = [:]
    
    if self.contains(.timestamp) {
      newAttrs[.creationDate] = attrs[.creationDate]
      newAttrs[.modificationDate] = attrs[.modificationDate]
    }
    if self.contains(.permissions) {
      newAttrs[.posixPermissions] = attrs[.posixPermissions]
    }
    
    return newAttrs
  }
}

public struct CopyArguments {
  public let inplace: Bool
  public var preserve: CopyAttributesFlag // attributes. Check how FileManager passes this.
  public let checkTimes: Bool
  
  public init(inplace: Bool = true,
              preserve: CopyAttributesFlag = [.permissions],
              checkTimes: Bool = false) {
    self.inplace = inplace
    self.preserve = preserve
    self.checkTimes = checkTimes
    
    if checkTimes {
      self.preserve.insert(.timestamp)
    }
  }
}

extension Translator {
  public func copy(from ts: [Translator], args: CopyArguments = CopyArguments()) -> CopyProgressInfoPublisher {
    print("Copying \(ts.count) elements")
    return ts.publisher.compactMap { t in
      return t.fileType == .typeDirectory || t.fileType == .typeRegular ? t : nil
    }.flatMap(maxPublishers: .max(1)) { t -> CopyProgressInfoPublisher in
      return copyElement(from: t, args: args)
    }.eraseToAnyPublisher()
  }
  
  fileprivate func copyElement(from t: Translator, args: CopyArguments) -> CopyProgressInfoPublisher {
    return Just(t)
      .flatMap() { $0.stat() }
      .tryMap { attrs -> (String, NSNumber, FileAttributes) in
        guard let name = attrs[FileAttributeKey.name] as? String else {
          throw CopyError(msg: "No name provided")
        }
        
        let passingAttributes = args.preserve.filter(attrs)
        // TODO Two ways to set permissions. Should be part of the CopyArguments
        // The equivalent of -P is simpler for now.
        // https://serverfault.com/questions/639042/does-openssh-sftp-server-use-umask-or-preserve-client-side-permissions-after-put
        // let mode = attrs[FileAttributeKey.posixPermissions] as? NSNumber ??
        // (t.fileType == .typeDirectory ? NSNumber(value: Int16(0o755)) : NSNumber(value: Int16(0o644)))
        
        guard let size = attrs[FileAttributeKey.size] as? NSNumber else {
          throw CopyError(msg: "No size provided")
        }
        
        return (name, size, passingAttributes)
      }.flatMap { (name, size, passingAttributes) -> CopyProgressInfoPublisher in
        print("Processing \(name)")
        switch t.fileType {
        case .typeDirectory:
          let mode = passingAttributes[FileAttributeKey.posixPermissions] as? NSNumber ?? NSNumber(value: Int16(0o755))
          return self.copyDirectory(as: name, from: t, mode: mode)
        default:
          let copyFilePublisher = self.copyFile(from: t, name: name, size: size, attributes: passingAttributes)
          
          // When checkTimes, copy the file only if the modificationDate is different
          if args.checkTimes {
            return self.cloneWalkTo(name)
              .flatMap { $0.stat() }
              .catch { _ in Just([:]) }
              .flatMap { localAttributes -> CopyProgressInfoPublisher in
                if let localModificationDate = localAttributes[.modificationDate] as? NSDate,
                   localModificationDate == (passingAttributes[.modificationDate] as? NSDate) {
                  return .just(CopyProgressInfo(name: name, written: 0, size: size.uint64Value))
                }
                return copyFilePublisher
              }.eraseToAnyPublisher()
          }
          
          return copyFilePublisher
        }
      }.eraseToAnyPublisher()
  }
  
  fileprivate func copyDirectory(as name: String, from t: Translator, mode: NSNumber) -> CopyProgressInfoPublisher {
    print("Copying directory \(t.current)")
    return self.clone().mkdir(name: name, mode: mode_t(truncating: mode))
      .flatMap { dir -> CopyProgressInfoPublisher in
        t.directoryFilesAndAttributes().flatMap {
          $0.compactMap { i -> FileAttributes? in
            if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
              return nil
            } else {
              return i
            }
          }.publisher
        }.flatMap { t.cloneWalkTo($0[.name] as! String) }
        .collect()
        .flatMap { dir.copy(from: $0) }.eraseToAnyPublisher()
      }.eraseToAnyPublisher()
    
//    return t.directoryFilesAndAttributes().flatMap {
//      $0.compactMap { i -> FileAttributes? in
//        if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
//          return nil
//        } else {
//          return i
//        }
//      }.publisher
//    }.flatMap { t.cloneWalkTo($0[.name] as! String) }
//    .collect()
//    .flatMap { self.copy(from: $0) }.eraseToAnyPublisher()
  }
  
  fileprivate func copyFile(from t: Translator,
                            name: String,
                            size: NSNumber,
                            attributes: FileAttributes) -> CopyProgressInfoPublisher {
    var file: BlinkFiles.File!
    var totalWritten: UInt64 = 0

    return self.create(name: name, flags: O_WRONLY, mode: S_IRWXU)
      .flatMap { f -> CopyProgressInfoPublisher in
        file = f
        if size == 0 {
          return .just(CopyProgressInfo(name: name, written:0, size: 0))
        }
        return f.copyFile(from: t, name: name, size: size)
      }.flatMap { report -> CopyProgressInfoPublisher in
        totalWritten += report.written
        if report.size == totalWritten {
          print("Closing file...")
          return file.close()
            .flatMap { _ in
              // TODO From the File, we could offer the Translator itself.
              return self.cloneWalkTo(name).flatMap { $0.wstat(attributes) }
            }
            .map { _ in report }.eraseToAnyPublisher()
        }
        return .just(report)
      }.eraseToAnyPublisher()
  }
}

extension File {
  fileprivate func copyFile(from t: Translator,
                            name: String,
                            size: NSNumber) -> CopyProgressInfoPublisher {
    let fileSize = size.uint64Value
    var totalWritten: UInt64 = 0
    print("Copying file \(name)")
    
    return t.open(flags: O_RDONLY)
      .tryMap { file -> BlinkFiles.WriterTo in
        guard let file = file as? WriterTo else {
          throw CopyError(msg: "Not the proper file type")
        }
        return file
      }
      .flatMap { file -> CopyProgressInfoPublisher in
        return file.writeTo(self).print("WRITE").flatMap { w -> CopyProgressInfoPublisher in
          let written = UInt64(w)
          print("File Copied bytes \(totalWritten)")
          totalWritten += written
          let report: AnyPublisher<CopyProgressInfo, Error> =
            .just(CopyProgressInfo(name: name, written: written, size: fileSize))
          
          // TODO We could offer a flag for EOF inside the File, and only close in that case.
          // We could also close on WriterTo, but the interface is too generic for that.
          // In that case, w could be zero.
          if totalWritten == fileSize {
            // Close and send the final report
            // NOTE We are closing a file for an active operation (the writeTo).
            // We have no other point to close and also emit progress. Future ideas may change that.
            // - We could enforce writeTo to close on EOF.
            // - We could communicate when the file is EOF, and send a written = 0 to capture.
            return (file as! File).close().flatMap { _ -> CopyProgressInfoPublisher in
                print("File finished copying")
                return report
              }.eraseToAnyPublisher()
          }
          
          return report
        }
        .tryCatch { error -> CopyProgressInfoPublisher in
          // Closing the file while reading may provoke an error. Capture it here and if we are done, we ignore it.
          if totalWritten == fileSize {
            print("Ignoring error as file finished copy")
            return .just(CopyProgressInfo(name: name, written: totalWritten, size: fileSize))
          } else {
            throw error
          }
        }
        .eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }
}
