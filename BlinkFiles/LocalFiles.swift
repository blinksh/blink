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

// Use as generic error for Translators.
public struct LocalFileError: Error {
  public let msg: String
  public var description: String {
    return msg
  }
}

public class Local : Translator {
  public var isDirectory: Bool
  
  static let files = FileManager()
  static let queue = DispatchQueue(label: "LocalFS")
  
  // isDirectory if it can be traversed. Note it can be a symbolic link pointing to a directory.
  public private(set) var fileType: FileAttributeType = .typeUnknown
  let root: String
  public private(set) var current: String
  
  public init() {
    // Default local path
    self.root    = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    self.fileType = .typeDirectory
    self.isDirectory = true
    self.current = root
  }
  
  public func clone() -> Translator {
    let cl = Local()
    cl.current  = self.current
    cl.fileType = self.fileType
    
    return cl
  }
  
  func publisher() -> AnyPublisher<Translator, Error> {
    return Just(self).mapError { $0 as Error }.eraseToAnyPublisher()
  }
  
  func fail<T>(msg: String) -> AnyPublisher<T, Error> {
    return Fail(error: LocalFileError(msg: msg)).eraseToAnyPublisher()
  }
  
  func fileManager() -> AnyPublisher<FileManager, Error> {
    return Just(Local.files).receive(on: Local.queue).mapError { $0 as Error }.eraseToAnyPublisher()
  }
  
  public func walkTo(_ path: String) -> AnyPublisher<Translator, Error> {
    var absPath = (path as NSString).standardizingPath
    if !path.starts(with: "/") {
      absPath = (current as NSString).appendingPathComponent(absPath)
    }
    
    return fileManager().flatMap { fm -> AnyPublisher<Translator, Error> in
      if !fm.fileExists(atPath: absPath) {
        return self.fail(msg: "No such file or directory.")
      }
      
      do {
        let attrs = try fm.attributesOfItem(atPath: absPath)
        self.fileType = attrs[.type] as! FileAttributeType
      } catch {
        return self.fail(msg: "Could not obtain attributes of file.")
      }
      
      if self.fileType == .typeDirectory {
        if !fm.isReadableFile(atPath: absPath) {
          return self.fail(msg: "Permission denied.")
        }
        self.current = absPath
        return self.publisher()
      } else {
        self.current = absPath
        return self.publisher()
      }
    }.eraseToAnyPublisher()
  }
  
  func fileAttributes(atPath path: String) -> AnyPublisher<FileAttributes, Error> {
    return fileManager().tryMap { fm -> FileAttributes in
      var attrs = try fm.attributesOfItem(atPath: path)
      attrs[.name] = (path as NSString).lastPathComponent
      return attrs
    }.mapError { _ in LocalFileError(msg: "Could not get attributes of item.") }
    .eraseToAnyPublisher()
  }
  
  public func directoryFilesAndAttributes() -> AnyPublisher<[FileAttributes], Error> {
    if fileType != .typeDirectory {
      return fileAttributes(atPath: current).map { [$0] }.eraseToAnyPublisher()
    }
    
    return fileManager().tryMap { try $0.contentsOfDirectory(atPath: self.current) }
      .mapError { _ in LocalFileError(msg: "Could not get contents of directory") }
      .flatMap { fileNames -> AnyPublisher<[FileAttributes], Error> in
        return fileNames.publisher.flatMap {
          self.fileAttributes(atPath: (self.current as NSString).appendingPathComponent($0))
        }.collect().eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }
  
  //    // TODO Change permissions to more generic open options
  public func create(name: String, flags: Int32, mode: mode_t = S_IRWXU) -> AnyPublisher<File, Error> {
    if fileType != .typeDirectory {
      return fail(msg: "Not a directory.")
    }
    
    return fileManager().tryMap { fm -> File in
      let absPath = (self.current as NSString).appendingPathComponent(name)
      let attrs: FileAttributes = [.posixPermissions: mode]
      
      if !fm.createFile(atPath: absPath, contents: nil, attributes: attrs) {
        throw LocalFileError(msg: "Could not create file.")
      }
      
      return try LocalFile(at: absPath, flags: flags)
    }.eraseToAnyPublisher()
  }
  
  public func mkdir(name: String, mode: mode_t = S_IRWXU | S_IRWXG | S_IRWXO) -> AnyPublisher<Translator, Error> {
    if fileType != .typeDirectory {
      return fail(msg: "Not a directory")
    }
    
    return fileManager().tryMap { fm -> Translator in
      let absPath = (self.current as NSString).appendingPathComponent(name)
      
      let attrs = [FileAttributeKey.posixPermissions: mode]
      
      try fm.createDirectory(atPath: absPath, withIntermediateDirectories: false,
                             attributes: attrs)
      
      self.current = absPath
      return self
    }
    .mapError { error in LocalFileError(msg: "Could not create directory. \(error.localizedDescription)") }
    .eraseToAnyPublisher()
  }
  
  public func open(flags: Int32) -> AnyPublisher<File, Error> {
    if fileType != .typeRegular {
      return fail(msg: "Is a directory.")
    }
    
    return Just(current).tryMap { path in
      return try LocalFile(at: path, flags: flags)
    }.eraseToAnyPublisher()
  }
  
  public func remove() -> AnyPublisher<Bool, Error> {
    if fileType == .typeDirectory {
      return fail(msg: "Is a directory")
    }
    
    return fileManager().tryMap { fm -> Bool in
      try fm.removeItem(atPath: self.current)
      return true
    }
    .mapError { LocalFileError(msg: "Could not delete file. \($0.localizedDescription)") }
    .eraseToAnyPublisher()
  }
  
  public func rmdir() -> AnyPublisher<Bool, Error> {
    if fileType != .typeDirectory {
      return fail(msg: "Not a directory")
    }
    
    return self.directoryFilesAndAttributes().flatMap { items -> AnyPublisher<Bool, Error> in
      if items.count > 0 {
        return self.fail(msg: "Directory is not empty")
      }
      
      return self.fileManager().tryMap { fm in
        try fm.removeItem(atPath: self.current)
        return true
      }
      .mapError { LocalFileError(msg: "Could not remove directory. \($0.localizedDescription)") }
      .eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }
  
  public func stat() -> AnyPublisher<FileAttributes, Error> {
    return fileAttributes(atPath: current)
  }
  
  public func wstat(_ attrs: FileAttributes) -> AnyPublisher<Bool, Error> {
    return fileManager().tryMap { fm -> FileManager in
      try fm.setAttributes(attrs, ofItemAtPath: self.current)
      return fm
    }.mapError { LocalFileError(msg: "Cannot change attributes of file. \($0.localizedDescription)") }
    .flatMap { fm -> AnyPublisher<Bool, Error> in
      // Relative path or from root
      guard let newName = attrs[.name] as? String else {
        return Just(true).mapError { $0 as Error }.eraseToAnyPublisher()
      }
      // We do this 9p style
      // https://github.com/kubernetes/minikube/pull/3047/commits/a37faa7c7868ca49b4e8abf92985ab2de3c85cf3
      var newPath = ""
      if newName.starts(with: "/") {
        // Full new path
        newPath = newName
      } else {
        // Change name
        newPath = (self.current as NSString).deletingLastPathComponent
        newPath = (newPath as NSString).appendingPathComponent(newName)
      }
      
      return self.moveItem(atPath: self.current, toPath: newPath)
    }
    .eraseToAnyPublisher()
  }
  
  func moveItem(atPath src: String, toPath dst: String) -> AnyPublisher<Bool, Error> {
    return fileManager().tryMap { fm in
      try fm.moveItem(atPath:src, toPath: dst)
      self.current = dst
      return true
    }.mapError { LocalFileError(msg: "Could not move item. \($0.localizedDescription)") }
    .eraseToAnyPublisher()
  }
}

public class LocalFile : File {
  let channel: DispatchIO
  let blockSize = 1024 * 1024
  var offset: Int64 = 0
  let queue: DispatchQueue
  
  init(at path: String, flags: Int32) throws {
    // Not sure if this can be nil, while errno is not
    let queue = DispatchQueue(label: "LocalFile-\(path)")
    
    guard let channel = DispatchIO(type: .random,
                                   path: path,
                                   oflag: flags,
                                   mode: 0,
                                   queue: queue,
                                   cleanupHandler: { (_)  in // errno
                                    return
                                   }) else {
      throw LocalFileError(msg: "Could not initialize channel")
    }
    
    self.channel = channel
    self.queue = queue
    
    // Avoid small local reads or writes.
    self.channel.setLimit(lowWater: blockSize)
  }
  
  public func close() -> AnyPublisher<Bool, Error> {
    // TODO We should pass the errors from cleanupHandler
    self.channel.close(flags: .stop)
    return Just(true).mapError { $0 as Error }.eraseToAnyPublisher()
  }
}

extension LocalFile: Reader, WriterTo {
  // Lock once the demand has been satistied, and unlock once there is new demand
  // If demand is unlimited, you will never lock.
  public func read(max length: Int) -> AnyPublisher<DispatchData, Error> {
    return readLoop(max: length)
      .reduce(DispatchData.empty) { prevValue, newValue -> DispatchData in
        var n = prevValue
        n.append(newValue)
        return n
      }.eraseToAnyPublisher()
  }
  
  public func writeTo(_ w: Writer) -> AnyPublisher<Int, Error> {
    // TODO It blocks with big files, and it may block with the Dispatch streams too
    // A new block may be received, before the readLoop goes to send downstream.
    // The new block will block the queue, and hence it will never go down.
    // We cannot just simply remove the semaphore, because then the EOF may be received before all other
    // operations are even processed.
    return readLoop(max: SSIZE_MAX)
      .print("writing to...")
      .flatMap(maxPublishers: .max(1)) { data in
        return w.write(data, max: data.count)
      }.eraseToAnyPublisher()
  }
  
  func readLoop(max length: Int) -> AnyPublisher<DispatchData, Error> {
    let io = self.channel
    let subj = PassthroughSubject<DispatchData, Error>()
    
    var sema: DispatchSemaphore? = nil
    
    func wakeThread() {
      // .signal() returns non-zero if a thread is woken. Otherwise, zero is returned.
      while sema?.signal() == 0 { }
    }
    
    var canceled = false
    func onCancel() {
      canceled = true
      io.close(flags: .stop)
      wakeThread()
    }
    
    func ioHandler(_ done: Bool, data: DispatchData?, err: Int32) {
      // termination events are sent without demand
      // https://developer.apple.com/documentation/dispatch/dispatchio/1780666-close
      if err == POSIXErrorCode.ECANCELED.rawValue {
        return
      }
      
      if err != 0 {
        let e = NSError(domain: NSPOSIXErrorDomain, code: Int(err), userInfo: nil)
        subj.send(completion: .failure(LocalFileError(msg: "Error reading file: \(e.localizedDescription)")))
        return
      }
      
      // guard err == noErr else {
      //     if err != POSIXErrorCode.ECANCELED.rawValue  {
      //         subj.send(completion: .failure(.unknown))
      //     }
      //     return
      // }
      
      guard let data = data else {
        return assertionFailure()
      }
      
      // done and data.count == 0 is indicator of EOF with no more data, so finish.
      // TODO I think there is a bug here. It can be done and still have data.
      let eof = done && data.count == 0
      guard !eof else {
        print("Completed - EOF")
        return subj.send(completion: .finished)
      }
      
      print("Sending \(data.count)")
      subj.send(data)
      
      if done {
        print("Completed")
        return subj.send(completion: .finished)
      }
      
      print("Awaiting semaphore...")
      sema?.wait()
      guard !canceled else {
        return
      }
    }
    
    func applyDemand(demand: Subscribers.Demand) {
      print("Received demand")
      if demand == Subscribers.Demand.unlimited {
        sema = nil
        return
      }
      
      let limit = demand.max!
      
      if sema == nil {
        // If we initiate the semaphore with a specific value, it has to be balanced to that value, and that is complicated.
        // So start with 0 and work from there.
        // https://lists.apple.com/archives/cocoa-dev/2014/Apr/msg00484.html
        sema = DispatchSemaphore(value: limit - 1)
      } else {
        // increment currentSema by new limit
        for _ in 0..<limit  {
          print("New signals")
          sema!.signal()
        }
      }
    }
    
    var scheduled = false
    func onRequest(_ demand: Subscribers.Demand) {
      // Create a semaphore if necessary for the specified demand
      // No demand, no scheduling.
      // Switch between max and defined, defined to max.
      if demand == Subscribers.Demand.none {
        return
      }
      
      applyDemand(demand: demand)
      
      if !scheduled {
        scheduled = true
        io.read(offset: 0, length: length, queue: self.queue, ioHandler: ioHandler)
      }
    }
    
    // Put a buffer just in case the semaphore lifts the thread before the subject has received the demand.
    return subj.buffer(size: 1, prefetch: .byRequest, whenFull: .customError({LocalFileError(msg: "Buffer full")})).handleEvents(
      receiveCancel: onCancel,
      receiveRequest: onRequest
    ).eraseToAnyPublisher()
  }
}

extension LocalFile: Writer {
  public func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error> {
    let subj = PassthroughSubject<Int, Error>()
    
    let writeOffset = offset
    offset += Int64(length)
    
    return subj.handleEvents(
      receiveCancel: {
        print("Cancelling write")
        self.channel.close(flags: .stop)
      }, receiveRequest: { _ in
        self.channel.write(offset: writeOffset,
                           data: buf,
                           queue: self.queue) { (done, bytes, error) -> Void in
          if error == POSIXErrorCode.ECANCELED.rawValue {
            return
          }
          
          if error != 0 {
            let e = NSError(domain: NSPOSIXErrorDomain, code: Int(error), userInfo: nil)
            subj.send(completion: .failure(LocalFileError(msg: "Error writing to file: \(e.localizedDescription)")))
            
            return
          }
          
          if done {
            subj.send(length)
            subj.send(completion: .finished)
            return
          }
          
          // bytes is nil if there is no data remaining
          //                    guard let remainingData = bytes else {
          //                        subj.send(completion: .failure(FileError.IO(msg: "Nothing written to file")))
          //                        return
          //                    }
          
        }
      }).eraseToAnyPublisher()
  }
}
