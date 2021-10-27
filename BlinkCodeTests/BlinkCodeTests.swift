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

@testable import BlinkCode


class BlinkCodeTests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testStat() throws {
    let expectation = XCTestExpectation(description: "Message received")

    let service = try CodeFileSystemService(listenOn: 8000, tls: false)
    let serviceURL = URL(string: "ws://localhost:8000")!
    
    // TODO Create the message
    let task = URLSession.shared.webSocketTask(with: serviceURL)
    task.resume()

    let statRequest = CodeFileSystemRequest(op: .stat, uri: "/Users/carloscabanero/build.token")
    let statPayload = CodeSocketMessagePayload(encodedData: try JSONEncoder().encode(statRequest))
    let statMessage =
    CodeSocketMessageHeader(type: statPayload.type, operationId: 1, referenceId: 1).encoded + statPayload.encoded

    task.send(.data(statMessage)) { error in if let error = error { XCTFail("\(error)") }}
    // TODO Wrap this into a different Result, we can use just for tests.
    task.receive { result in
      switch result {
      case .success(let response):
        switch response {
        case .data(let data):
          // TODO Validate data here. We could check response type, and response IDs.
          // AssertResponseHeader
          // Check IDs for response
          // Check content
          var buffer = data
          guard let respHeader = CodeSocketMessageHeader(buffer[0..<CodeSocketMessageHeader.encodedSize]) else {
            XCTFail("Could not parse response header")
            return
          }
          // TODO Note Yury's protocol still has a response ID
          print(respHeader)
          
          buffer = buffer.advanced(by: CodeSocketMessageHeader.encodedSize)
          guard let respContent = try? JSONDecoder().decode(FileStat.self, from: buffer) else {
            XCTFail("Could not decode JSON")
            return
          }
          print(respContent)
          break
        default:
          XCTFail("Wrong response type")
        }
        case .failure(let error):
          XCTFail("\(error)")
      }
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }
  
  func testReadDirectory() throws {
    let expectation = XCTestExpectation(description: "Message received")

    let service = try CodeFileSystemService(listenOn: 8000, tls: false)
    let serviceURL = URL(string: "ws://localhost:8000")!
    
    // TODO Create the message
    let task = URLSession.shared.webSocketTask(with: serviceURL)
    task.resume()

    let statRequest = CodeFileSystemRequest(op: .readDirectory, uri: "/Users/carloscabanero")
    let statPayload = CodeSocketMessagePayload(encodedData: try JSONEncoder().encode(statRequest))
    let statMessage =
    CodeSocketMessageHeader(type: statPayload.type, operationId: 1, referenceId: 1).encoded + statPayload.encoded

    task.send(.data(statMessage)) { error in if let error = error { XCTFail("\(error)") }}
    // TODO Wrap this into a different Result, we can use just for tests.
    task.receive { result in
      switch result {
      case .success(let response):
        switch response {
        case .data(let data):
          // TODO Validate data here. We could check response type, and response IDs.
          // AssertResponseHeader
          // Check IDs for response
          // Check content
          var buffer = data
          guard let respHeader = CodeSocketMessageHeader(buffer[0..<CodeSocketMessageHeader.encodedSize]) else {
            XCTFail("Could not parse response header")
            return
          }
          // TODO Note Yury's protocol still has a response ID
          print(respHeader)
          
          buffer = buffer.advanced(by: CodeSocketMessageHeader.encodedSize)
          guard let respContent = try? JSONDecoder().decode([String:FileType].self, from: buffer) else {
            XCTFail("Could not decode JSON")
            return
          }
          print(respContent)
          break
        default:
          XCTFail("Wrong response type")
        }
        case .failure(let error):
          XCTFail("\(error)")
      }
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
  }
}
