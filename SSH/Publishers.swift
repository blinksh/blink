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

import Atomics
import Combine
import Foundation
import LibSSH



// https://stackoverflow.com/questions/60624851/combine-framework-retry-after-delay
// https://stackoverflow.com/questions/61557327/401-retry-mechanism-using-combine-publishers
extension Publisher {
  func tryOperation<T, U>(_ operation: @escaping (U) throws -> T)
  -> AnyPublisher<T, Error> where Self == AnyPublisher<U, Error> {
    let stop = ManagedAtomic<Bool>(false)
    
    func loop(_ session: U) -> AnyPublisher<T, Error> {
      return Just(session).tryMap { session in
        let val = try operation(session)
        if stop.load(ordering: .relaxed) {
          throw SSHError(title: "Operation cancelled")
        }
        return val
      }
      .tryCatch { error -> AnyPublisher<T, Error> in
        if stop.load(ordering: .relaxed) {
          throw SSHError(title: "Operation cancelled")
        }
        switch error {
        case SSHError.again:
          Swift.print("tryOperation AGAIN")
          // NOTE We let the RunLoop run, instead of using a Delayed publisher. The Delayed publisher
          // will schedule another block, and the socket on libssh sometimes lets other blocks run as well.
          // This makes Combine process the "finished" messages before the current block is done,
          // slicing and stopping the flows.
          RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
          if stop.load(ordering: .relaxed) {
            throw SSHError(title: "Operation cancelled")
          }
          return loop(session)
        default:
          throw error
        }
      }.eraseToAnyPublisher()
    }
    
    // Wrap in a loop so that only the specific operation is re-executed,
    // otherwise the whole flow will get up and cancelled.
    return self.flatMap { loop ($0) }.handleEvents(receiveCancel: {
      stop.store(true, ordering: .relaxed)
      usleep(505000)
    }).eraseToAnyPublisher()
  }
  
  func tryChannel<T>(_ operation: @escaping (ssh_channel) throws -> T)
  -> AnyPublisher<T, Error> where Self == AnyPublisher<ssh_channel, Error> {
    let stop = ManagedAtomic<Bool>(false)

    func loop(_ channel: ssh_channel) -> AnyPublisher<T, Error> {
      return Just(channel).tryMap { chan in
        let val = try operation(chan)
        if stop.load(ordering: .relaxed) {
          throw SSHError(title: "Operation cancelled")
        }
        return val
      }
      .tryCatch { error -> AnyPublisher<T, Error> in
        if stop.load(ordering: .relaxed) {
          throw SSHError(title: "Operation cancelled")
        }
        switch error {
        case SSHError.again:
          Swift.print("tryChannel AGAIN")
          RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
          if stop.load(ordering: .relaxed) {
            throw SSHError(title: "Operation cancelled")
          }
          return loop(channel)
        default:
          return self.tryMap { chan in
            ssh_channel_free(chan)
            throw error
          }.eraseToAnyPublisher()
        }
      }.eraseToAnyPublisher()
    }
    
    return self.flatMap { loop ($0) }.handleEvents(receiveCancel: {
      stop.store(true, ordering: .relaxed)
      usleep(505000)
    }).eraseToAnyPublisher()
  }
  
  func trySFTP<T>(_ operation: @escaping (sftp_session) throws -> T) ->
  AnyPublisher<T, Error> where Self == AnyPublisher<sftp_session, Error> {
    return tryOperation(operation)
  }
}

extension AnyPublisher where Output == ssh_session, Failure == Error {
  func tryAuth(_ operation: @escaping (ssh_session) throws -> AuthState)
  -> AnyPublisher<AuthState, Error> {
    let stop = ManagedAtomic<Bool>(false)

    func loop(_ session: ssh_session) -> AnyPublisher<AuthState, Error> {
      return Just(session).tryMap { session in
        // Check we are still connected as sometimes authentication may close from one side.
        if ssh_is_connected(session) == 0 {
          throw SSHError(title: "Disconnected", forSession: session)
        }

        let val = try operation(session)
        if stop.load(ordering: .relaxed) {
          throw SSHError(title: "Operation cancelled")
        }
        return val
      }
      .tryCatch { error -> AnyPublisher<AuthState, Error> in
        if stop.load(ordering: .relaxed) {
          throw SSHError(title: "Operation cancelled")
        }
        switch error {
        case SSHError.again:
          Swift.print("tryAuth AGAIN")
          RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
          if stop.load(ordering: .relaxed) {
            throw SSHError(title: "Operation cancelled")
          }
          return loop(session)
        default:
          throw error
        }
      }.eraseToAnyPublisher()
    }
    
    return self.flatMap(maxPublishers: .max(1)) { loop($0) }
                .flatMap { state -> AnyPublisher<AuthState, Error> in
                  // If Auth needs to continue, use the provided
                  // Publisher
                  switch state {
                  case .continue(let pub):
                    return pub
                  default:
                    return .just(state)
                  }
                }.handleEvents(receiveCancel: {
                  stop.store(true, ordering: .relaxed)
                  // The cancel process thread cannot move up, otherwise we get a recursive unfair_lock abort.
                  usleep(505000)
                }).eraseToAnyPublisher()
  }
}

// TODO: Move to own module?
public extension AnyPublisher {
  @inlinable static func just(_ output: Output) -> Self {
    .init(Just(output).setFailureType(to: Failure.self))
  }
  
  @inlinable static func fail(error: Failure) -> Self {
    .init(Fail(error: error))
  }
}
