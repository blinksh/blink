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

import XCTest
import Combine

extension XCTestCase {
  func waitPublisher<P: Publisher>(
    _ publisher: P,
    timeout: TimeInterval = 5,
    receiveCompletion: @escaping ((Subscribers.Completion<P.Failure>) -> Void),
    receiveValue: @escaping (P.Output) -> Void
  ) {
    let expectation = self.expectation(description: "Publisher completes or cancel")
    let c = publisher.handleEvents(
      receiveCompletion: { _ in
        expectation.fulfill()
      },
      receiveCancel: {
        expectation.fulfill()
      }
    )
    .sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
    
    wait(for: [expectation], timeout: timeout)
    c.cancel()
  }
}

extension Publisher {
  func sink(
    test: XCTestCase,
    timeout: TimeInterval = 5,
    receiveCompletion: @escaping ((Subscribers.Completion<Self.Failure>) -> Void) = { _ in },
    receiveValue: @escaping ((Self.Output) -> Void) = {_ in } )
  {
    test.waitPublisher(self, timeout: timeout, receiveCompletion: receiveCompletion, receiveValue: receiveValue)
  }
  
  func lastOutput(
    test: XCTestCase,
    timeout: TimeInterval = 5,
    receiveCompletion: @escaping ((Subscribers.Completion<Self.Failure>) -> Void) = { _ in }
  ) -> Self.Output? {
    var lastValue: Self.Output?
    sink(test: test, timeout: timeout, receiveCompletion: receiveCompletion) { v in
      lastValue = v
    }
    return lastValue
  }
  
  func exactOneOutput(
    test: XCTestCase,
    timeout: TimeInterval = 5,
    receiveCompletion: @escaping ((Subscribers.Completion<Self.Failure>) -> Void) = { _ in }
  ) -> Self.Output! {
    var value: Self.Output? = nil
    sink(test: test, timeout: timeout, receiveCompletion: receiveCompletion) { v in
      XCTAssertNil(value)
      value = v
    }
    
    XCTAssertNotNil(value)
    return value
  }
}
