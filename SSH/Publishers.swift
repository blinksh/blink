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
import LibSSH


let libSSHBlockMode: RunLoop.Mode = RunLoop.Mode("LibSSHBlockRunLoop")
// https://stackoverflow.com/questions/60624851/combine-framework-retry-after-delay
// https://stackoverflow.com/questions/61557327/401-retry-mechanism-using-combine-publishers
extension Publisher {
  func tryOperation<T, U>(_ operation: @escaping (U) throws -> T)
  -> AnyPublisher<T, Error> where Self == AnyPublisher<U, Error> {
    var doTry = true
    
    Swift.print("Scheduling on: %p", String(format: "%p", RunLoop.current))
    return self.tryMap { p -> T in
      if RunLoop.current != RunLoop.main {
        Swift.print(String(format: "%p", RunLoop.current))
      }
      while doTry {
        do {
          return try operation(p)
        } catch SSHError.again {
          RunLoop.current.run(mode: libSSHBlockMode, before: Date(timeIntervalSinceNow: 0.5))
          //CFRunLoopRunInMode(libSSHBlockMode, 0.5, true)
          Swift.print("Retrying..")
          continue
        }
      }
      throw SSHError(title: "Operation cancelled")
    }
    .handleEvents(receiveCancel: {
      Swift.print("Cancelling on: %p", String(format: "%p", RunLoop.current))

      if RunLoop.current != RunLoop.main {
        Swift.print("?????????")
      }
      doTry = false
    })
    .eraseToAnyPublisher()
  }
  
  func tryChannel<T>(_ operation: @escaping (ssh_channel) throws -> T)
  -> AnyPublisher<T, Error> where Self == AnyPublisher<ssh_channel, Error> {
    
    var doTry = true
    
    return tryMap { chan -> T in
      
      while doTry {
        do {
          return try operation(chan)
        } catch SSHError.again {
          RunLoop.current.run(mode: libSSHBlockMode, before: Date(timeIntervalSinceNow: 0.5))
          continue
        } catch {
          ssh_channel_free(chan)
          throw error
        }
      }
      ssh_channel_free(chan)
      throw SSHError(title: "Operation cancelled")
    }
    .handleEvents(receiveCancel: {
      doTry = false
    })
    .eraseToAnyPublisher()
  }
  
//  func trySFTP<T>(_ operation: @escaping (sftp_session) throws -> T) ->
//  AnyPublisher<T, Error> where Self == AnyPublisher<sftp_session, Error> {
//    tryOperation(operation)
//  }
}

extension AnyPublisher where Output == ssh_session, Failure == Error {
  func tryAuth(_ operation: @escaping (ssh_session) throws -> AuthState)
  -> AnyPublisher<AuthState, Error> {
    var doTry = true
    
    return tryMap { session -> AuthState in
      while doTry {
        // Check we are still connected as sometimes authentication may close from one side.
        if ssh_is_connected(session) == SSH_OK {
          throw SSHError(title: "Disconnected", forSession: session)
        }
        
        do {
          return try operation(session)
        } catch SSHError.again {
          RunLoop.current.run(mode: libSSHBlockMode, before: Date(timeIntervalSinceNow: 0.5))
          continue
        }
      }
      
      throw SSHError(title: "Operation cancelled")
    }
    .flatMap(maxPublishers: .max(1)) { state -> AnyPublisher<AuthState, Error> in
      // If Auth needs to continue, use the provided
      // Publisher
      switch state {
      case .continue(let pub):
        return pub
      default:
        return .just(state)
      }
    }
    .handleEvents(receiveCancel: {
      doTry = false
    })
    .eraseToAnyPublisher()
  }
}

// TODO: Move to own module?
//public extension AnyPublisher {
//  @inlinable static func just(_ output: Output) -> Self {
//    .init(Just(output).setFailureType(to: Failure.self))
//  }
//  
//  @inlinable static func fail(error: Failure) -> Self {
//    .init(Fail(error: error))
//  }
//}

// A DemandingSubject helps create flows where the Demand needs to trigger
// an operation to start processing and sending values, while protecting that all
// such operations happen in the proper Scheduler.
extension AnyPublisher {
  @inlinable static func demandingSubject
  <S: Subject, X: Scheduler>(_ subject: S,
                             receiveRequest: @escaping (Subscribers.Demand) -> (),
                             receiveCancel: (() -> Void)? = nil,
                             on scheduler: X) -> AnyPublisher<S.Output, S.Failure> {
    // The buffer not just "buffers" the values, but isolates the PS subscription flow
    // from the rest. Without it, if you trigger on receiveRequest, the PS may still
    // not have received a Subscription or Demand, so it may dump the first values.
    // Previous versions where scheduling the function itself to handle the Demand, but
    // it was not clear and was very prone to errors.
    
    return .init(
      subject
    //.print("buffer")
      .buffer(size: .max, prefetch: .byRequest, whenFull: .dropOldest)
    //.print("handle")
      .handleEvents(
        receiveCancel: receiveCancel,
        receiveRequest: { receiveRequest($0) }
      )
      .subscribe(on: scheduler)
    )
  }
}
