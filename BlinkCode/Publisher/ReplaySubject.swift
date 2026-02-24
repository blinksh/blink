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


private final class ShareReplayPublisher<Upstream: Publisher>: Publisher {
    typealias Output = Upstream.Output
    typealias Failure = Upstream.Failure

    private let upstream: Upstream
    private let subject: ReplaySubject<Output, Failure>
    private let lock = NSLock()
    private var connection: Cancellable?
    private var refCount = 0

    init(upstream: Upstream, maxValues: Int) {
        self.upstream = upstream
        self.subject = ReplaySubject<Output, Failure>(maxValues: maxValues)
    }

    func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Failure {
        lock.lock()
        let shouldConnect = (refCount == 0)
        refCount += 1

        if shouldConnect {
            connection = upstream
                .subscribe(subject)
        }
        lock.unlock()

        subject.subscribe(subscriber)
    }
}

extension Publisher {
    func shareReplay(maxValues: Int = 0) -> AnyPublisher<Output, Failure> {
        ShareReplayPublisher(upstream: self, maxValues: maxValues).eraseToAnyPublisher()
    }
}

final class ReplaySubject<Input, Failure: Error>: Subject {
    typealias Output = Input
    private var recording = Record<Input, Failure>.Recording()
    private let stream = PassthroughSubject<Input, Failure>()
    private let maxValues: Int
    private let lock = NSRecursiveLock()
    private var completed = false
  
    init(maxValues: Int = 0) {
        self.maxValues = maxValues
    }
    func send(subscription: Subscription) {
        subscription.request(maxValues == 0 ? .unlimited : .max(maxValues))
    }
    func send(_ value: Input) {
      lock.lock(); defer { lock.unlock() }
      guard !completed else { return }
        recording.receive(value)
        stream.send(value)
        if recording.output.count == maxValues {
            send(completion: .finished)
        }
    }
    func send(completion: Subscribers.Completion<Failure>) {
      lock.lock(); defer { lock.unlock() }
      guard !completed else { return }
      if !completed {
        completed = true
        recording.receive(completion: completion)
      }
      stream.send(completion: completion)
    }
    func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Input == S.Input {
      lock.lock(); defer { lock.unlock() }
        Record(recording: self.recording)
            .append(self.stream)
            .receive(subscriber: subscriber)
    }
}
