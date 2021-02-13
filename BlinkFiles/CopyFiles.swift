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

extension Translator {
  public func copy(from ts: [Translator]) -> CopyProgressInfo {
    print("Copying \(ts.count) elements")
    return ts.publisher.compactMap { t in
      return t.fileType == .typeDirectory || t.fileType == .typeRegular ? t : nil
    }.flatMap(maxPublishers: .max(1)) { t -> CopyProgressInfo in
      return copyElement(from: t)
    }.eraseToAnyPublisher()
  }
  
  fileprivate func copyElement(from t: Translator) -> CopyProgressInfo {
    return Just(t)
      .flatMap(maxPublishers: .max(1)) { $0.stat() }
      .tryMap { attrs -> (String, mode_t, NSNumber) in
        guard let name = attrs[FileAttributeKey.name] as? String else {
          throw CopyError(msg: "No name provided")
        }
        let mode = attrs[FileAttributeKey.posixPermissions] as? NSNumber ??
          (t.fileType == .typeDirectory ? NSNumber(value: Int16(0o755)) : NSNumber(value: Int16(0o644)))
        
        guard let size = attrs[FileAttributeKey.size] as? NSNumber else {
          throw CopyError(msg: "No size provided")
        }
        
        return (name, mode_t(truncating: mode), size)
      }.flatMap { (name, mode, size) -> CopyProgressInfo in
        print("Processing \(name)")
        switch t.fileType {
        case .typeDirectory:
          return self.clone().mkdir(name: name, mode: mode)
            .flatMap { $0.copyDirectory(from: t) }
            .eraseToAnyPublisher()
        default:
          // TODO Create with generic permissions, and then later if a flag is specified, preserve them.
          return self.create(name: name, flags: O_WRONLY, mode: S_IRWXU)
            .flatMap { f -> CopyProgressInfo in
              if size == 0 {
                return Just((name, 0, 0)).mapError { $0 as Error }.eraseToAnyPublisher()
              }
              return f.copyFile(from: t, name: name, size: size)
            }.eraseToAnyPublisher()
        }
      }.eraseToAnyPublisher()
  }
  
  fileprivate func copyDirectory(from t: Translator) -> CopyProgressInfo {
    print("Copying directory \(t.current)")
    return t.directoryFilesAndAttributes().flatMap {
      $0.compactMap { i -> FileAttributes? in
        if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
          return nil
        } else {
          return i
        }
      }.publisher
    }.flatMap { t.cloneWalkTo($0[.name] as! String) }
    .collect()
    .flatMap { self.copy(from: $0) }.eraseToAnyPublisher()
  }
}

extension File {
  fileprivate func copyFile(from t: Translator, name: String, size: NSNumber) -> CopyProgressInfo {
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
      .flatMap { file -> CopyProgressInfo in
        return file.writeTo(self).print("WRITE").flatMap { w -> CopyProgressInfo in
          let written = UInt64(w)
          print("File Copied bytes \(totalWritten)")
          totalWritten += written
          let report = Just((name, fileSize, written))
            .mapError { $0 as Error }.eraseToAnyPublisher()
          
          if totalWritten == fileSize {
            // Close and send the final report
            // NOTE We are closing a file for an active operation (the writeTo).
            // We have no other point to close and also emit progress. Future ideas may change that.
            return (file as! BlinkFiles.File).close()
              .flatMap { result -> CopyProgressInfo in
                print("File finished copying")
                return report
              }.eraseToAnyPublisher()
          }
          
          return report
        }
        .tryCatch { error -> CopyProgressInfo in
          // Closing the file while reading may provoke an error. Capture it here and if we are done, we ignore it.
          if totalWritten == fileSize {
            return Just((name, fileSize, 0)).mapError {$0 as Error}.eraseToAnyPublisher()
          } else {
            throw error
          }
        }
        .eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }
}
