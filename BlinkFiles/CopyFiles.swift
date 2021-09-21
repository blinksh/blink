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
      t.fileType == .typeDirectory || t.fileType == .typeRegular ? t : nil
    }.flatMap(maxPublishers: .max(1)) { t in
      copyElement(from: t, args: args)
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
}

fileprivate enum FileState {
  case copy(File)
  case attributes(File)
}

extension Translator {
  fileprivate func copyFile(from t: Translator,
                            name: String,
                            size: NSNumber,
                            attributes: FileAttributes) -> CopyProgressInfoPublisher {

    let fullFile = (self.current as NSString).appendingPathComponent(name)
    
    return self.create(name: name, flags: O_WRONLY, mode: S_IRWXU)
      .flatMap { destination -> CopyProgressInfoPublisher in
        if size == 0 {
          return .just(CopyProgressInfo(name: fullFile, written:0, size: 0))
        }
        
        return t.open(flags: O_RDONLY)
          .flatMap { [FileState.copy($0), FileState.attributes($0)].publisher }
          .flatMap(maxPublishers: .max(1)) { state -> CopyProgressInfoPublisher in
            switch state {
            case .copy(let source):
              return (source as! WriterTo)
                .writeTo(destination)
                .map { CopyProgressInfo(name: fullFile, written: UInt64($0), size: size.uint64Value) }
                .eraseToAnyPublisher()
            case .attributes(let source):
              return Publishers.Zip(source.close(), destination.close())
                // TODO From the File, we could offer the Translator itself.
                .flatMap { _ in self.cloneWalkTo(name).flatMap { $0.wstat(attributes) } }
                .map { _ in CopyProgressInfo(name: fullFile, written: 0, size: size.uint64Value) }
                .eraseToAnyPublisher()
            }
          }.eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }
}
