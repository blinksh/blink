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

import Dispatch
import Foundation
import Combine


public enum DispatchStreamError: Error {
  case read(msg: String)
  case write(msg: String)
  public var description: String {
    switch self {
    case .read(let msg):
      return "Read Error: \(msg)"
    case .write(let msg):
      return "Write Error: \(msg)"
    }
  }
}

public class DispatchOutputStream: Writer {
  let stream: DispatchIO
  let queue: DispatchQueue
  
  public init(stream: Int32) {
    self.queue = DispatchQueue(label: "file-\(stream)")
    self.stream = DispatchIO(type: .stream, fileDescriptor: stream, queue: self.queue, cleanupHandler: { error in
      print("Dispatch closed with \(error)")
    })
    self.stream.setLimit(lowWater: 0)
  }
  
  public func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error> {
    let pub = PassthroughSubject<Int, Error>()
    
    return pub.handleEvents(receiveRequest: { _ in
      self.stream.write(offset: 0, data: buf, queue: self.queue) { (done, bytes, error) in
        if error == POSIXErrorCode.ECANCELED.rawValue {
          return pub.send(completion: .finished)
        }
        
        if error != 0 {
          pub.send(completion: .failure(DispatchStreamError.write(msg: String(validatingUTF8: strerror(errno)) ?? "")))
          return
        }
        
        if done {
          pub.send(length)
          pub.send(completion: .finished)
        }
      }
    }).eraseToAnyPublisher()
  }
  
  public func close() {
    stream.close(flags: .stop)
  }
}

public class DispatchInputStream {
  let stream: DispatchIO
  let queue: DispatchQueue
  
  public init(stream: Int32) {
    self.queue = DispatchQueue(label: "file-\(stream)")
    self.stream = DispatchIO(type: .stream, fileDescriptor: stream, queue: self.queue, cleanupHandler: { error in
      print("Dispatch \(error)")
    })
    self.stream.setLimit(lowWater: 0)
  }
  
  public func close() {
    stream.close(flags: .stop)
  }
}


// Create DispatchStreams, reader and writers that we can use for this scenarios.
extension DispatchInputStream: WriterTo {
  public func writeTo(_ w: Writer) -> AnyPublisher<Int, Error> {
    let pub = PassthroughSubject<DispatchData, Error>()
    
    return pub.handleEvents(receiveRequest: { _ in
      self.stream.read(offset: 0, length: Int(UINT32_MAX), queue: self.queue) { (done, data, error) in
        if error == POSIXErrorCode.ECANCELED.rawValue {
          return pub.send(completion: .finished)
        }
        
        if error != 0 {
          pub.send(completion: .failure(DispatchStreamError.read(msg: String(validatingUTF8: strerror(errno)) ?? "")))
          return
        }
        
        guard let data = data else {
          return assertionFailure()
        }
        
        let eof = done && data.count == 0
        guard !eof else {
          return pub.send(completion: .finished)
        }
        
        pub.send(data)
        
        if done {
          return pub.send(completion: .finished)
        }
      }
    })
    .flatMap { data in
      return w.write(data, max: data.count)
    }.eraseToAnyPublisher()
  }
}
