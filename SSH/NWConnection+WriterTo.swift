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


extension NWConnection: WriterTo {
  public func writeTo(_ w: Writer) -> AnyPublisher<Int, Error> {
    let pub = PassthroughSubject<DispatchData, Error>()
    
    func receiveData(demand: Subscribers.Demand) {
      // TODO: handle demand?
      
      self.receive(
        minimumIncompleteLength: 1,
        maximumLength: Int(UINT32_MAX),
        completion: receiveDataCompletion
      )
    }
    
    func receiveDataCompletion(data: Data?, ctxt: ContentContext?, isComplete: Bool, rcvError: NWError?) {
      if let data = data {
        // Swift 5, Data is contiguous
        let dd = data.withUnsafeBytes {
          DispatchData(bytes: $0)
        }
        pub.send(dd)
      }
      
      if isComplete {
        pub.send(completion: .finished)
        return
      }
      
      if let error = rcvError {
        pub.send(completion: .failure(SSHPortForwardError(title: "Connection Reading error", error)))
      }
    }
    
    return pub.handleEvents(
      receiveRequest: receiveData(demand:)
    ).flatMap(maxPublishers: .max(1)) { data in
      return w.write(data, max: data.count)
    }.eraseToAnyPublisher()
  }
}

extension Data {
  
  init(copying dd: DispatchData) {
    var result = Data(count: dd.count)
    result.withUnsafeMutableBytes { buf in
      _ = dd.copyBytes(to: buf)
    }
    self = result
  }
}

extension NWConnection: Writer {
  public func write(_ buf: DispatchData, max length: Int) -> AnyPublisher<Int, Error> {
    let pub = PassthroughSubject<Int, Error>()
    
    let data = Data(copying: buf)
    return pub.handleEvents(
      receiveRequest: { _ in
        self.send(content: data, completion: SendCompletion.contentProcessed( { error in
          if let error = error {
            pub.send(completion: .failure(SSHPortForwardError(title: "Could not send data over Connection", error)))
            return
          }
          pub.send(data.count)
          pub.send(completion: .finished)
        }))
      }
    ).eraseToAnyPublisher()
  }
}
