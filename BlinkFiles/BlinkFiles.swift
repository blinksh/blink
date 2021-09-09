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


public typealias BlinkFilesAttributeKey = FileAttributeKey

// NOTE We are bending the compiler a bit here. If we just extend FileAttributeKey,
// whenever you export the package, you will get an execution time error because the extension
// may not have applied (and name does not exist). By applying this redirection, we get it
// to work while still respecting the proper interface everywhere.
public extension BlinkFilesAttributeKey {
  static let name: FileAttributeKey = FileAttributeKey("fileName")
}

public typealias FileAttributes = [BlinkFilesAttributeKey: Any]

public protocol Translator: CopierFrom {
  var fileType: FileAttributeType { get }
  var isDirectory: Bool { get }
  var current: String { get }
  var isConnected: Bool { get }
  
  func clone() -> Translator
  
  // The walk offers a way to traverse the remote filesystem, without dealing with internal formats.
  // It is responsible to extend paths and define objects along the way.
  func walkTo(_ path: String) -> AnyPublisher<Translator, Error>
  
  // Equivalent to a directory read, it returns all the elements and attrs from stating the containing objects
  func directoryFilesAndAttributes() -> AnyPublisher<[FileAttributes], Error>
  
  // Creates the file name at the current walked path with the given permissions.
  // Default mode  = S_IRWXU
  func create(name: String, flags: Int32, mode: mode_t) -> AnyPublisher<File, Error>
  // Creates the directory name at the current walked path with the given permissions.
  // Default mode =  S_IRWUX | S_IRWXG | S_IRWXO
  func mkdir(name: String, mode: mode_t) -> AnyPublisher<Translator, Error>
  
  // Opens a Stream to the object
  func open(flags: Int32) -> AnyPublisher<File, Error>
  
  // Remove the object
  func remove() -> AnyPublisher<Bool, Error>
  func rmdir() -> AnyPublisher<Bool, Error>
  
  // Change attributes
  func stat() -> AnyPublisher<FileAttributes, Error>
  func wstat(_ attrs: FileAttributes) -> AnyPublisher<Bool, Error>
}

// Could do it with a generic for types to read and write
public protocol Reader {
  // One time read or continuous? If it is one time, I would make it more explicit through Future,
  // or whatever the URLRequest also uses.
  func read(max length: Int) -> AnyPublisher<DispatchData, Error>
}

public protocol Writer {
  func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error>
}

public protocol WriterTo {
  // Or make it to Cancellable
  func writeTo(_ w: Writer) -> AnyPublisher<Int, Error>
}

public protocol ReaderFrom {
  // Or make it to Cancellable
  func readFrom(_ r: Reader) -> AnyPublisher<Int, Error>
}

public protocol File: Reader, Writer {
  func close() -> AnyPublisher<Bool, Error>
}

// The Copy algorithms will report the progress of each file as it gets copied.
// As they are recursive, we provide information on what file is being reported.
// Report progress as (name, total bytes written, length)
// FileAttributeKey.Size is an NSNumber with a UInt64. It is the standard.
public struct CopyProgressInfo {
  public let name: String
  public let written: UInt64
  public let size: UInt64
  
  public init(name: String, written: UInt64, size: UInt64) {
    self.name = name
    self.written = written
    self.size = size
  }
}
public typealias CopyProgressInfoPublisher = AnyPublisher<CopyProgressInfo, Error>

public protocol CopierFrom {
  func copy(from ts: [Translator], args: CopyArguments) -> CopyProgressInfoPublisher
}

public protocol CopierTo {
  func copy(to ts: Translator) -> CopyProgressInfoPublisher
}

extension AnyPublisher {
  @inlinable static func just(_ output: Output) -> Self {
    .init(Just(output).setFailureType(to: Failure.self))
  }
  
  @inlinable static func fail(error: Failure) -> Self {
    .init(Fail(error: error))
  }
}
//
//// Server side Copy and Rename are usually best when performing operations inside the Translator, but
//// not all protocols support them.
//public protocol Copier {
//    func copy(at dst: Translator) throws -> Translator
//}
//
//public protocol Renamer {
//    func rename(at dst: Translator, newName: String) throws -> Translator
//}
