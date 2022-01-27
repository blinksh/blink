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


public class BlinkLogging {
  public typealias LogHandlerFactory = ((Publishers.Share<AnyPublisher<[BlinkLogKeys:Any], Never>>) throws -> AnyCancellable)
  fileprivate static var handlers = [LogHandlerFactory]()
  
  public static func handle(_ handler: @escaping LogHandlerFactory) {
    self.handlers.append(handler)
  }
}

// BlinkLogging.handler { $0.map {}.sinkTo }
public struct BlinkLogKeys: Hashable {
  private let rawValue: String
  
  static let message    = BlinkLogKeys("message")
  static let logLevel   = BlinkLogKeys("logLevel")
  static let component  = BlinkLogKeys("component")
  
  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }
}

public enum BlinkLogLevel: Int, Comparable {
  case trace
  case debug
  case info
  case warn
  case error
  case fatal
  // Skips or overrides.
  case log
  
  public static func < (lhs: BlinkLogLevel, rhs: BlinkLogLevel) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

class BlinkLogger: Subject {
  typealias Output = [BlinkLogKeys:Any]
  typealias Failure = Never
  
  private let sub = PassthroughSubject<Output, Never>()
  private var logger = Set<AnyCancellable>()

  public func send(_ value: Output) {
    sub.send(value)
  }
  
  func send(completion: Subscribers.Completion<Failure>) {
    sub.send(completion: completion)
  }
  
  func send(subscription: Subscription) {
    sub.send(subscription: subscription)
  }
  
  func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, [BlinkLogKeys : Any] == S.Input {
    sub.receive(subscriber: subscriber)
  }
  
  public init(bootstrap: ((AnyPublisher<Output, Never>) -> (AnyPublisher<Output, Never>))? = nil,
              handlers: [BlinkLogging.LogHandlerFactory]? = nil) {
    var publisher = sub.eraseToAnyPublisher()
    if let bootstrap = bootstrap {
      publisher = bootstrap(publisher)
    }

    let handlers = handlers ?? BlinkLogging.handlers
    handlers.forEach { handle in
      do {
        try handle(publisher.share()).store(in: &logger)
      } catch {
        Swift.print("Error initializing logging handler - \(error)")
      }
    }
  }
}

extension BlinkLogger {
  public func send(_ message: String)   { self.send([.logLevel: BlinkLogLevel.log,
                                                   .message: message,]) }

  public func trace(_ message: String)  { self.send([.logLevel: BlinkLogLevel.trace,
                                                   .message: message,]) }
  public func debug(_ message: String)  { self.send([.logLevel: BlinkLogLevel.debug,
                                                   .message: message,]) }
  public func info(_ message: String)   { self.send([.logLevel: BlinkLogLevel.info,
                                                   .message: message,]) }
  public func warn(_ message: String)   { self.send([.logLevel: BlinkLogLevel.warn,
                                                   .message: message,]) }
  public func error(_ message: String)  { self.send([.logLevel: BlinkLogLevel.error,
                                                   .message: message,]) }
  public func fatal(_ message: String)  { self.send([.logLevel: BlinkLogLevel.fatal,
                                                   .message: message,]) }
}

extension BlinkLogger {
  convenience init(_ component: String,  
                   handlers: [BlinkLogging.LogHandlerFactory]? = nil) {
    self.init(bootstrap: {
      $0.map { $0.merging([BlinkLogKeys.component: component], uniquingKeysWith: { (_, new) in new }) }
        .eraseToAnyPublisher()
    }, handlers: handlers)
  }
}
