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

var OperationId: UInt32 = 0
let ServiceURL = URL(string: "ws://localhost:8000")!

class BlinkCodeTests: XCTestCase {
  var service: CodeFileSystemService? = nil

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    OperationId = 0
    service = try CodeFileSystemService(listenOn: 10015, tls: false)
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testVSCode() throws {
    //throw XCTSkip("Comment if running VSCode integration")
    let expectation = expectation(description: "Holding up for VSCode")
    wait(for: [expectation], timeout: 50000)
  }
  
  func testStat() throws {
    let task = URLSession.shared.webSocketTask(with: ServiceURL)
    task.resume()

    let req = StatFileSystemRequest(uri: URI("blink-fs:/Users/carloscabanero/build.token"))
    
    let (response, responseContent) = try task.sendCodeFileSystemRequest(req,
                                                                         test: self)
    
    XCTAssert(!response.isEmpty)
    XCTAssertNil(responseContent)
    
    guard let fileStat = try? JSONDecoder().decode(FileStat.self, from: response) else {
      XCTFail("Could not decode JSON")
      return
    }
    print(fileStat)
    XCTAssertTrue(fileStat.type == FileType.File)
  }

  func testReadDirectory() throws {
    let task = URLSession.shared.webSocketTask(with: ServiceURL)
    task.resume()

    let req = ReadDirectoryFileSystemRequest(uri: URI("blink-fs:local:/Users/carloscabanero"))
    
    let (response, responseContent) = try task.sendCodeFileSystemRequest(req, test: self)
    
    XCTAssertTrue(!response.isEmpty)
    XCTAssertNil(responseContent)
    
    print(String(data: response, encoding: .utf8))
    guard let items = try? JSONDecoder().decode([DirectoryTuple].self, from: response) else {
      XCTFail("Could not decode JSON")
      return
    }
    print(items)
    XCTAssertTrue(items.count > 0)
  }

  // TODO Test. Fail if no create. Create file. Overwrite file. Fail if overwrite.
  func testWriteFile() throws {
    let task = URLSession.shared.webSocketTask(with: ServiceURL)
    task.resume()

    let uri = URI("blink-fs:local:/Users/carloscabanero/createtest")
    let filePath = uri.rootPath.filesAtPath
    let req = WriteFileSystemRequest(uri: uri, options: .init(overwrite: true, create: false))
    let content = "Hello world".data(using: .utf8)

    let (response, responseContent) = try task.sendCodeFileSystemRequest(req,
                                                                         binaryData: content,
                                                                         test: self)
    XCTAssertTrue(response.isEmpty)
    XCTAssertTrue(responseContent == nil)

    let readContent = try String(contentsOfFile: filePath).data(using: .utf8)
    XCTAssertTrue(content == readContent)
  }

  // TODO Try to recreate and check error
  func testCreateDirectory() throws {
    let task = URLSession.shared.webSocketTask(with: ServiceURL)
    task.resume()

    let uri = URI("blink-fs:local:/Users/carloscabanero/newdir")
    let path = uri.rootPath.filesAtPath
    let req  = CreateDirectoryFileSystemRequest(uri: uri)

    let (response, responseContent) = try task.sendCodeFileSystemRequest(req,
                                                                         binaryData: nil,
                                                                         test: self)
    XCTAssertTrue(response.isEmpty)
    XCTAssertTrue(responseContent == nil)

    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
    XCTAssertTrue(exists)
    XCTAssertTrue(isDir.boolValue)
  }

  func testRename() throws {
    let task = URLSession.shared.webSocketTask(with: ServiceURL)
    task.resume()

    let uri     = URI("blink-fs:local:/Users/carloscabanero/newdir")
    let path    = uri.rootPath.filesAtPath
    let newUri  = URI("blink-fs:local:/Users/carloscabanero/newpathdir")
    let newPath = newUri.rootPath.filesAtPath
    let req  = RenameFileSystemRequest(oldUri: uri,
                                       newUri: newUri,
                                       options: .init(overwrite:false))

    let (response, responseContent) = try task.sendCodeFileSystemRequest(req,
                                                                         binaryData: nil,
                                                                         test: self)

    XCTAssertTrue(response.isEmpty)
    XCTAssertTrue(responseContent == nil)

    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: newPath, isDirectory: &isDir)
    XCTAssertTrue(exists)
    XCTAssertTrue(isDir.boolValue)
  }

  func testDelete() throws {
    let task = URLSession.shared.webSocketTask(with: ServiceURL)
    task.resume()

    let uri = URI("blink-fs:local:/Users/carloscabanero/newdir")
    let path = uri.rootPath.filesAtPath
    let req  = DeleteFileSystemRequest(uri: uri,
                                       options: .init(recursive: true))

    let (response, responseContent) = try task.sendCodeFileSystemRequest(req,
                                                                         binaryData: nil,
                                                                         test: self)

    XCTAssertTrue(response.isEmpty)
    XCTAssertTrue(responseContent == nil)

    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
    XCTAssertFalse(exists)
  }
}

extension URLSessionWebSocketTask {
  fileprivate func sendCodeFileSystemRequest<T: Codable>(_ req: T, binaryData: Data? = nil, test: XCTestCase) throws -> (Data, Data?) {
    let expectation = XCTestExpectation(description: "File System Request fulfilled")

    let payload = CodeSocketMessagePayload(encodedData: try JSONEncoder().encode(req),
                                           binaryData: binaryData)
    let header = CodeSocketMessageHeader(type: payload.type,
                                         operationId: OperationId,
                                         referenceId: 1)
    let message = header.encoded + payload.encoded
    self.send(.data(message)) { error in if let error = error { XCTFail("\(error)") }}

    var responseEncodedData: Data = Data()
    var responseBinaryData:  Data? = nil

    self.receive { result in
      switch result {
      case .success(let response):
        switch response {
        case .data(let data):
          var buffer = data

          guard let respHeader = CodeSocketMessageHeader(buffer[0..<CodeSocketMessageHeader.encodedSize]) else {
            XCTFail("Could not parse response header")
            return
          }
          print(respHeader)

          XCTAssertTrue(respHeader.referenceId == header.operationId)

          buffer = buffer.advanced(by: CodeSocketMessageHeader.encodedSize)
          print(String(data: buffer, encoding: .utf8))

          guard let respPayload = CodeSocketMessagePayload(buffer, type: respHeader.type) else {
            XCTFail("Could not parse response payload")
            return
          }
          responseEncodedData = respPayload.encodedData
          responseBinaryData  = respPayload.binaryData

        default:
          XCTFail("Wrong response type")
        }
        case .failure(let error):
          XCTFail("\(error)")
      }
      expectation.fulfill()
    }

    test.wait(for: [expectation], timeout: 5.0)

    return (responseEncodedData, responseBinaryData)
  }
}

extension URI {
  // The URI always comes from decoding messages, so we add a helper to simulate that.
  init(_ str: String) {
    let out = try! JSONEncoder().encode(str)
    self = try! JSONDecoder().decode(URI.self, from: out)
  }
}
