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

import Combine
import Foundation
import BlinkFiles
import LibSSH

public struct SCPError : Error {
  let msg: String
}

public struct SCPMode: OptionSet {
  public let rawValue: Int
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  
  // This should be byte flags
  public static let Sink      = SCPMode(rawValue: 1 << 0)
  public static let Source    = SCPMode(rawValue: 1 << 1)
  public static let Recursive = SCPMode(rawValue: 1 << 2)
  
  // Transform the mode into a libssh Int
  func scpMode() -> Int {
    var m = 0
    if contains(.Sink) {
      m |= SSH_SCP_WRITE
    } else {
      m |= SSH_SCP_READ
    }
    
    if contains(.Recursive) {
      m |= SSH_SCP_RECURSIVE
    }
    
    return m
  }
}

public class SCPClient: CopierFrom, CopierTo {
  let ssh: SSHClient
  let scp: ssh_scp
  var channel: ssh_channel?
  // The SCP algorithm traverses directories and keeps internally the state,
  // we use this as a way to know how deep in the structure we are, so we can go back.
  var currentDirectoryLevel = 0
  
  init(_ scp: ssh_scp, client: SSHClient) {
    self.ssh = client
    self.scp = scp
  }
  
  // Execute a SCPClient on top of the provided SSHClient.
  // SCP can run as Sink (write to) or Source (read from).
  // Quoted Path of the source or target path. Note this path is executed on the
  // remote shell, so it should be properly escaped.
  // https://stackoverflow.com/questions/4754619/objective-c-shell-escaping
  public static func execute(using ssh: SSHClient,
                             as mode: SCPMode,
                             root quotedPath: String) -> AnyPublisher<SCPClient, Error> {
    guard let scp = ssh_scp_new(ssh.session, Int32(mode.scpMode()), quotedPath)
    else {
      return .fail(error: SSHError(-1, forSession: ssh.session))
    }
    
    let client = SCPClient(scp, client: ssh)
    
    return ssh.newChannel()
      .tryChannel { channel in
        let rc = ssh_channel_open_session(channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: ssh.session)
        }
        
        client.channel = channel
        
        return channel
      }.tryChannel { channel in
        let flag      = mode.contains(.Sink) ? "-t":"-f"
        let recursive = mode.contains(.Recursive) ? "-r":""
        
        let rc = ssh_channel_request_exec(channel, "scp \(flag) \(recursive) \(quotedPath)")
        if rc != SSH_OK {
          throw SSHError(rc, forSession: ssh.session)
        }
        
        return channel
      }.tryChannel { channel in
        let rc = ssh_scp_init_channel(scp, channel)
        if rc != SSH_OK {
          throw SSHError(rc, forSession: ssh.session)
        }
        
        return client
      }
  }
  
  public func close() {
    ssh_scp_close(scp)
  }
  
  // Wrap each scp call so we are sure it is running in the proper place.
  func connection() -> AnyPublisher<ssh_scp, Error> {
    AnyPublisher.just(scp).subscribe(on: self.ssh.rloop).eraseToAnyPublisher()
  }
}


extension SCPClient {
  // Perform copy with SCPClient as Sink, Translator as Source
  public func copy(from ts: [Translator]) -> CopyProgressInfo {
    var directoryLevel = self.currentDirectoryLevel
    
    return ts.publisher.compactMap { t in
      return t.fileType == .typeDirectory || t.fileType == .typeRegular ? t : nil
    }
    // Process items one by one, because the directories have a state on SCP.
    .flatMap(maxPublishers: .max(1)) { t -> CopyProgressInfo in
      return self.connection().tryMap { scp -> ssh_scp in
        while directoryLevel < self.currentDirectoryLevel {
          // Go up to the proper level
          let rc = ssh_scp_leave_directory(scp)
          if rc != SSH_OK {
            // TODO Change all these to SSHError after merge
            throw FileError(title: "Could not leave directory", in: self.ssh.session)
          }
          self.currentDirectoryLevel -= 1
        }
        return scp
      }.flatMap { scp -> AnyPublisher<(String, NSNumber, NSNumber), Error> in
        return t.stat().tryMap { attrs in
          guard let name = attrs[FileAttributeKey.name] as? String else {
            throw SCPError(msg: "No name provided")
          }
          let mode = attrs[FileAttributeKey.posixPermissions] as? NSNumber ??
            (t.fileType == .typeDirectory ? NSNumber(value: Int16(0o755)) : NSNumber(value: Int16(0o644)))
          
          guard let size = attrs[FileAttributeKey.size] as? NSNumber else {
            throw SCPError(msg: "No size provided")
          }
          
          return (name, mode, size)
        }.eraseToAnyPublisher()
      }.flatMap { (name, mode, size) -> CopyProgressInfo in
        if t.fileType == .typeDirectory {
          return self.connection().tryMap { scp -> Translator in
            let rc = ssh_scp_push_directory(scp, name, mode.int32Value)
            if rc != SSH_OK {
              throw FileError(title: "Could not push directory", in: self.ssh.session)
            }
            self.currentDirectoryLevel += 1
            return t
          }.flatMap { self.copyDirectoryFrom($0) }
          .eraseToAnyPublisher()
        } else {
          return self.connection().tryMap { scp -> Translator in
            let rc = ssh_scp_push_file64(self.scp, name, size.uint64Value, Int32(S_IRWXU))
            if rc < 0 {
              throw FileError(title: "Could not push file", in: self.ssh.session)
            }
            return t
          }.flatMap { t -> CopyProgressInfo in
            // On empty file, just report, nothing to copy
            if size == 0 {
              return .just((name, 0, 0))
            }
            return self.copyFileFrom(t, name: name, size: size)
          }
          .eraseToAnyPublisher()
        }
      }.eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }
  
  // Schedule a copy of all the elements in a directory.
  fileprivate func copyDirectoryFrom(_ t: Translator) -> CopyProgressInfo {
    return t.directoryFilesAndAttributes().flatMap {
      $0.compactMap { i -> FileAttributes? in
        if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
          return nil
        } else { return i }
      }.publisher
    }
    .flatMap { t.cloneWalkTo($0[.name] as! String) }
    .collect()
    .flatMap { self.copy(from: $0) }
    .eraseToAnyPublisher()
  }
  
  fileprivate func copyFileFrom(_ t: Translator, name: String, size: NSNumber) -> CopyProgressInfo {
    // TODO pass other properties like mtime
    var totalWritten = 0
    
    return t.open(flags: O_RDONLY)
      .tryMap { file -> BlinkFiles.WriterTo in
        guard let file = file as? WriterTo else {
          throw SCPError(msg: "Not the proper file type")
        }
        return file
      }
      .flatMap { file -> CopyProgressInfo in
        return file.writeTo(self).flatMap { written -> CopyProgressInfo in
          totalWritten += written
          let report = Just((name, size.uint64Value, UInt64(written)))
            .mapError { $0 as Error }.eraseToAnyPublisher()
          
          if totalWritten == size.int64Value {
            // Close and send the final report
            return (file as! BlinkFiles.File).close()
              .flatMap { _ in report }.eraseToAnyPublisher()
          }
          
          return report
        }.eraseToAnyPublisher()
      }.eraseToAnyPublisher()
  }
}

extension SCPClient: Writer {
  public func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error> {
    let pb = PassthroughSubject<Int, Error>()
    
    func write(_ data: DispatchData) {
      let window = Int(ssh_channel_window_size(self.channel))
      if window == 0 {
        self.ssh.rloop.perform { write(data) }
        return
      }
      
      let size = min(data.count, window)
      
      let rc = data.withUnsafeBytes { bytes -> Int32 in
        return ssh_scp_write(self.scp, bytes, size)
      }
      
      // Should never be SSH_AGAIN
      if rc < 0 {
        pb.send(completion: .failure(SSHError(rc, forSession: self.ssh.session)))
        return
      }
      
      pb.send(size)
      let nextData = data.subdata(in: size..<data.count)
      
      if size == data.count {
        pb.send(completion: .finished)
        return
      }
      
      // Schedule next write in the rloop, so we can let it perform
      return self.ssh.rloop.perform { write(nextData) }
    }
    
    func writeBlock(_ data: DispatchData) {
      self.ssh.rloop.perform { write(data) }
    }
    
    return pb.handleEvents(receiveRequest: { _ in writeBlock(buf) })
      .eraseToAnyPublisher()
  }
}

extension SCPClient {
  // Perform a copy where SCPClient is the Source, and the Translator is the Sink.
  // In this scenario the Source is driving the operation, so we do not know
  // what we will receive to copy.
  public func copy(to t: Translator) -> CopyProgressInfo {
    // This could potentially block. We are assuming this won't be an issue with a well behaved SCP provider.
    // We could poll before, as the function just reads char by char.
    // ssh_channel_poll(channel, window)
    // Retry if <= 0
    // The read was non-blocking, and it returned a rc = 0. Would the same happen here?
    var currentDir = t
    var dirsFifo: [Translator] = []
    
    // Ensure we pull actions one by one.
    return pullSourceAction().flatMap(maxPublishers: .max(1)) { req -> CopyProgressInfo in
      // We nest the publisher so that we don't pull another action until the current one
      // has been processed by the underneath flow.
      return Just(req).flatMap { req -> AnyPublisher<ssh_scp_request_types, Error> in
        switch req {
        case SSH_SCP_REQUEST_NEWDIR:
          // Walk to the directory, and create if it does not exist.
          let name = String(cString: ssh_scp_request_get_filename(self.scp))
          let mode = mode_t(ssh_scp_request_get_permissions(self.scp))
          
          // walk and capture the error
          return currentDir.cloneWalkTo(name)
            .catch { err -> AnyPublisher<Translator, Error> in
              // If directory does not exist, try to create it.
              return currentDir.mkdir(name: name, mode: mode)
                .flatMap { _ in currentDir.cloneWalkTo(name) }.eraseToAnyPublisher()
            }
            .flatMap { dir -> AnyPublisher<ssh_scp_request_types, Error> in
              dirsFifo.insert(currentDir, at: 0)
              currentDir = dir
              return self.connection().tryMap { scp -> ssh_scp_request_types in
                let rc = ssh_scp_accept_request(scp)
                if rc != SSH_OK {
                  // TODO Deny request to remote side
                  throw FileError(title: "Could not accept new directory request", in: self.ssh.session)
                }
                return req
              }.eraseToAnyPublisher()
            }.eraseToAnyPublisher()
        case SSH_SCP_REQUEST_ENDDIR:
          currentDir = dirsFifo[0]
          dirsFifo.removeFirst()
          return .just(req)
        default:
          return .just(req)
        }
      }
      .filter { $0 == SSH_SCP_REQUEST_NEWFILE }
      .flatMap(maxPublishers: .max(1)) { req -> CopyProgressInfo in
        let size: UInt64 = ssh_scp_request_get_size64(self.scp)
        let name = String(cString: ssh_scp_request_get_filename(self.scp))
        let mode = mode_t(ssh_scp_request_get_permissions(self.scp))
        
        return self.copyFileTo(translator: currentDir, usingName: name, length: size, mode: mode)
      }.eraseToAnyPublisher()
    }.eraseToAnyPublisher()
    
    // TODO How do you stop it? On cancel, you could close scp.
    // You could provide a flag for cancellation.
  }
  
  // Pull actions and finish when there are no more.
  // Note the action is served in the rloop, so everything following will be there.
  // The function limits Demand to one, so it expects to be called multiple times.
  func pullSourceAction() -> AnyPublisher<ssh_scp_request_types, Error> {
    let pb = PassthroughSubject<ssh_scp_request_types, Error>()
    
    func pull() {
      let req = ssh_scp_pull_request(scp)
      
      // Switch has some type issues here
      if req == SSH_SCP_REQUEST_EOF.rawValue {
        pb.send(completion: .finished)
        return
      } else if req == SSH_ERROR {
        pb.send(completion: .failure(SSHError(req, forSession: self.ssh.session)))
      } else {
        pb.send(ssh_scp_request_types(UInt32(req)))
      }
    }
    
    // Buffer to make sure we do not lose requests (as the pull may be called
    // before the pb has demand).
    return pb.buffer(size: 1, prefetch: .byRequest, whenFull: .dropOldest)
      .handleEvents(receiveRequest: { _ in pull() })
      .subscribe(on: self.ssh.rloop)
      .eraseToAnyPublisher()
  }
  
  // Flow when receiving a file to copy. Create on Translator and then Write to it.
  func copyFileTo(translator: Translator, usingName name: String, length: UInt64, mode: mode_t) -> CopyProgressInfo {
    return translator.create(name: name, flags: O_RDWR, mode: mode).flatMap { file -> CopyProgressInfo in
      var totalWritten: UInt64 = 0
      
      return self.writeTo(file, length: length).map { written in
        totalWritten += UInt64(written)
        return (name, length, totalWritten)
      }.eraseToAnyPublisher()
    }.eraseToAnyPublisher()
  }
  
  func writeTo(_ t: Writer, length: UInt64) -> AnyPublisher<Int, Error> {
    let pb = PassthroughSubject<DispatchData, Error>()
    var totalWritten = 0
    
    func readNonBlock() {
      // Won't block, as the read can return 0.
      // We may want to know better the size of the window
      
      // Operations may need a write before we can receive anything.
      var windowAvail = 65536
      
      if totalWritten > 0 {
        windowAvail = Int(ssh_channel_poll(self.channel, 0))
        
        if windowAvail == 0 {
          // Schedule another read if not ready yet
          self.ssh.rloop.schedule(after: .init(Date(timeIntervalSinceNow: 0.01))) {
            readNonBlock()
          }
          return
        } else if windowAvail < 0 {
          pb.send(completion: .failure(SSHError(Int32(windowAvail), forSession: self.ssh.session)))
          return
        }
      }
      
      let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(windowAvail), alignment: MemoryLayout<CUnsignedChar>.alignment)
      let rc = ssh_scp_read(scp, buf.baseAddress, Int(windowAvail))
      if rc == SSH_ERROR {
        pb.send(completion: .failure(SSHError(rc, forSession: self.ssh.session)))
        return
      }
      
      let shrk = buf[0..<Int(rc)]
      let buffer = UnsafeRawBufferPointer(rebasing: shrk)
      let data = DispatchData(bytesNoCopy: buffer, deallocator: .custom(nil){ buf.deallocate() })
      pb.send(data)
      
      totalWritten += data.count
      if totalWritten == length {
        pb.send(completion: .finished)
        return
      }
      // No need to reloop, next will come from demand.
    }
    
    return pb.handleEvents(receiveRequest: { _ in
      // We may either put the buffer, or we need the perform in rloop. I opted for this here as it does both,
      // schedule the read at the rloop so the pb will receive the demand,
      // and remove a subscriber as the operation will obviously be done at the rloop.
      self.ssh.rloop.perform { readNonBlock() }
    })
    .flatMap(maxPublishers: .max(1)) { data -> AnyPublisher<Int, Error> in
      if data.count == 0 {
        return .just(0)
      }
      return t.write(data, max: data.count)
    }
    .eraseToAnyPublisher()
  }
}
