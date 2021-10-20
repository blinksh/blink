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

class BlinkLoggingTests: XCTestCase {

  override func setUpWithError() throws {

  }

  // Generic logger, separated shared handler.
  func testLogging() throws {
    let logLines = ["hello", "world"]

    BlinkLogging.handle({
      $0.sink { log in
        guard let message = log[.message] as? String else {
          XCTFail("Message not a string")
          return
        }
        Swift.print(message)
        XCTAssert(logLines.contains(message))
      }
    })

    let log = BlinkLogger()
    logLines.forEach { log.send($0) }
  }

  // Loggers can bootstrap with shared information.
  // Loggers can have multiple handlers.
  func testLogger() throws {
    let message = "foo"
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = formatter.string(from: Date())

    let formattedHandler: BlinkLogging.LogHandlerFactory = {
      $0.map {
        $0.merging(zip([BlinkLogKeys.message], ["\($0[.extra]!) - \($0[.message]!)"]))
        { (_, new) in new }
      }.sink {
        let line = $0[.message] as! String
        print(line)
        XCTAssert(line == "\(timestamp) - \(message)")
      }
    }
    let hashedHandler: BlinkLogging.LogHandlerFactory = {
      $0.sink {
        XCTAssert($0[.message] as? String == message)
        XCTAssert($0[BlinkLogKeys.extra] as? String == timestamp)
      }
    }

    let log = BlinkLogger(
      bootstrap: {
        $0.map { $0.merging([BlinkLogKeys.extra: timestamp])
          { (_, new) in new } }.eraseToAnyPublisher()
      },
      handlers: [formattedHandler, hashedHandler]
    )

    log.send(message)
  }

  func testFileLogger() throws {
    let message = ["line1", "line2"]

    let tmpDir = NSTemporaryDirectory()
    let fileName = NSUUID().uuidString
    let fileURL = NSURL.fileURL(withPathComponents: [tmpDir, fileName])!
    let file = try FileLogging(to: fileURL)
    let log = BlinkLogger(handlers: [ { try $0.sinkToFile(file) } ])
    
    log.send(message[0])
    log.send(message[1])

    let result = try String(contentsOf: fileURL)
    XCTAssert(result == "\(message[0])\n\(message[1])\n", "TestFileLogger got \n\(result)")
  }

  func testLogLevel() throws {
    let filteredMessages = ["info", "warn"]

    let log = BlinkLogger(
      bootstrap: { $0.filter(logLevel: .info) },
      handlers: [{ $0.sink {
                     XCTAssert(filteredMessages.contains($0[.message] as! String))
                   } }]
    )
    log.info("info")
    log.debug("debug")
    log.warn("warn")
  }
}

extension BlinkLogKeys {
  static let extra = BlinkLogKeys("testsComponent")
}
