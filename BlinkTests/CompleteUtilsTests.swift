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

extension String {
  func token(cursor: Int) -> CompleteToken {
    CompleteUtils.completeToken(self, cursor: cursor)
  }
  
  func encodeShell(quote: String.Element? = nil) -> String {
    CompleteUtils.encode(str: self, quote: quote)
  }
}

class CompletionTests: XCTestCase {
  
  func testEncode() {
    assert("".encodeShell(quote: nil) == "")
    assert(" ".encodeShell(quote: nil) == "\\ ")
    assert("''".encodeShell(quote: .init("'")) == "'\\'\\''")
    assert("''".encodeShell(quote: .init("\"")) == "\"''\"")
    assert("|".encodeShell(quote: .init("\"")) == "\"\\|\"")
  }
  
  func testInvalidInput() {
    for token in [
      "  ".token(cursor: -1),
      "".token(cursor: 0),
      "".token(cursor: 10),
      ] {
      assert(token.value == "")
      assert(token.cmd == nil)
      assert(token.prefix == "")
      assert(token.query == "")
      assert(token.isRedirect == false)
      assert(token.jsPos == 0)
      assert(token.jsLen == 0)
    }
  }
  
  func testSimpleCmd() {
    var token = "ssh ".token(cursor: 0)
    assert(token.value == "ssh")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 0)
    assert(token.jsLen == 3)
    
    token = "ssh -v".token(cursor: 1)
    assert(token.value == "ssh")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "s")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 0)
    assert(token.jsLen == 3)
    
    token = "ssh -v".token(cursor: 2)
    assert(token.value == "ssh")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "ss")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 0)
    assert(token.jsLen == 3)
    
    token = "ssh -v".token(cursor: 3)
    assert(token.value == "ssh")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "ssh")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 0)
    assert(token.jsLen == 3)
    
    token = "ssh -v".token(cursor: 4)
    assert(token.value == "ssh -v")
    assert(token.prefix == "ssh ")
    assert(token.cmd == "ssh")
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 4)
    assert(token.jsLen == 2)
    
    token = "ssh -v".token(cursor: 5)
    assert(token.value == "ssh -v")
    assert(token.prefix == "ssh ")
    assert(token.cmd == "ssh")
    assert(token.query == "-")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 4)
    assert(token.jsLen == 2)
    
    
    token = "ssh -v host".token(cursor: 4)
    assert(token.value == "ssh -v")
    assert(token.prefix == "ssh ")
    assert(token.cmd == "ssh")
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 4)
    assert(token.jsLen == 2)
    
    token = "ssh -v host".token(cursor: 5)
    assert(token.value == "ssh -v")
    assert(token.prefix == "ssh ")
    assert(token.cmd == "ssh")
    assert(token.query == "-")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 4)
    assert(token.jsLen == 2)
    
    token = "ssh -v host".token(cursor: 6)
    assert(token.value == "ssh -v")
    assert(token.prefix == "ssh ")
    assert(token.cmd == "ssh")
    assert(token.query == "-v")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 4)
    assert(token.jsLen == 2)
    
    token = "ssh -v host".token(cursor: 7)
    assert(token.value == "ssh -v host")
    assert(token.prefix == "ssh -v ")
    assert(token.cmd == "ssh")
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 7)
    assert(token.jsLen == 4)
    
    token = "ssh -v host".token(cursor: 8)
    assert(token.value == "ssh -v host")
    assert(token.prefix == "ssh -v ")
    assert(token.cmd == "ssh")
    assert(token.query == "h")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 7)
    assert(token.jsLen == 4)
  }
  
  func testPipe() {
    var token = "ssh -v host |".token(cursor: 12)
    
    assert(token.value == "ssh -v host ")
    assert(token.prefix == "ssh -v host ")
    assert(token.cmd == "ssh")
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 12)
    assert(token.jsLen == 0)
    
    token = "ssh -v host |".token(cursor: 13)
    assert(token.value == "")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 13)
    assert(token.jsLen == 0)

    token = "ssh -v host |".token(cursor: 1)
    assert(token.value == "ssh")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "s")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 0)
    assert(token.jsLen == 3)
    
    token = "ssh -v host | grep foo | cat foo".token(cursor: 30)
    assert(token.value == "cat foo")
    assert(token.prefix == "cat ")
    assert(token.cmd == "cat")
    assert(token.query == "f")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 29)
    assert(token.jsLen == 3)
    
    token = "ssh -v host | grep foo | cat foo".token(cursor: 7)
    assert(token.value == "ssh -v host")
    assert(token.prefix == "ssh -v ")
    assert(token.cmd == "ssh")
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 7)
    assert(token.jsLen == 4)
  }
  
  func testEscapes() {
    var token = "cd hello\\ world".token(cursor: 1)
    assert(token.value == "cd")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "c")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 0)
    assert(token.jsLen == 2)
    
    token = "cd hello\\ world".token(cursor: 4)
    assert(token.value == "cd hello\\ world")
    assert(token.prefix == "cd ")
    assert(token.cmd == "cd")
    assert(token.query == "h")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    assert(token.jsPos == 3)
    assert(token.jsLen == 12)
    
    token = "cd \"hello\\\" world".token(cursor: 4)
    assert(token.value == "cd \"hello\\\" world")
    assert(token.prefix == "cd ")
    assert(token.cmd == "cd")
    assert(token.query == "")
    assert(token.quote == Character("\""))
    assert(token.isRedirect == false)
    
    token = "cd \"hello\\\" world".token(cursor: 5)
    assert(token.value == "cd \"hello\\\" world")
    assert(token.prefix == "cd ")
    assert(token.cmd == "cd")
    assert(token.query == "h")
    assert(token.quote == Character("\""))
    assert(token.isRedirect == false)
    
    token = "cd \"hello world |".token(cursor: 4)
    assert(token.value == "cd \"hello world |")
    assert(token.prefix == "cd ")
    assert(token.cmd == "cd")
    assert(token.query == "")
    assert(token.quote == Character("\""))
    assert(token.isRedirect == false)
    assert(token.jsPos == 3)
    assert(token.jsLen == 14)
    
    // `echo "he\"llo, " world |`
    // `[    |    ^    ]        `
    token = "echo \"he\\\"llo, \" world |".token(cursor: 10)
    assert(token.value == "echo \"he\\\"llo, \"")
    assert(token.prefix == "echo ")
    assert(token.cmd == "echo")
    assert(token.query == "he\"") // he"
    assert(token.quote == Character("\""))
    assert(token.isRedirect == false)
    assert(token.jsPos == 5)
    assert(token.jsLen == 11)
  }
  
  func testRedirect() {
    var token = "ls > foo".token(cursor: 2)
    assert(token.value == "ls")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "ls")
    assert(token.quote == nil)
    assert(token.isRedirect == false)
    
    token = "ls > foo".token(cursor: 4)
    assert(token.value == "")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == true)
    
    token = "ls > foo".token(cursor: 5)
    assert(token.value == "foo")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "")
    assert(token.quote == nil)
    assert(token.isRedirect == true)
    
    token = "ls > foo".token(cursor: 6)
    assert(token.value == "foo")
    assert(token.prefix == "")
    assert(token.cmd == nil)
    assert(token.query == "f")
    assert(token.quote == nil)
    assert(token.isRedirect == true)

  }
  
}
