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

class SessionParamsTests: XCTestCase {
  
  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testSerialization() {
    let mcpParams = MCPParams()
    mcpParams.rows = 10
    mcpParams.cols = 20
    mcpParams.boldAsBright = true
    mcpParams.childSessionType = "test"
    mcpParams.viewSize = CGSize(width: 10, height: 10)
    mcpParams.layoutLockedFrame = CGRect(x: 10, y: 10, width: 10, height: 10)
    
    
    let moshParams = MoshParams()
    moshParams.ip = "192.168.1.1"
    
    mcpParams.childSessionParams = moshParams
    
    let copy = _dumpAndRestore(params: mcpParams)
    XCTAssertEqual(mcpParams.cols, copy?.cols)
    XCTAssertEqual(mcpParams.rows, copy?.rows)
    XCTAssertEqual(mcpParams.boldAsBright, copy?.boldAsBright)
    XCTAssertEqual(mcpParams.childSessionType, copy?.childSessionType)
    XCTAssertEqual(mcpParams.viewSize, copy?.viewSize)
    XCTAssertEqual(mcpParams.layoutLockedFrame, copy?.layoutLockedFrame)
    XCTAssertEqual(moshParams.ip, (copy?.childSessionParams as? MoshParams)?.ip)
  }
  
  func _dumpAndRestore(params: MCPParams) -> MCPParams? {
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    archiver.encode(params, forKey: "params")
    let data = archiver.encodedData
    
    let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data)
    return unarchiver?.decodeObject(of: MCPParams.self, forKey: "params")
  }
  
  func testPerformanceExample() {
    // This is an example of a performance test case.
    self.measure {
      // Put the code you want to measure the time of here.
    }
  }
  
}
