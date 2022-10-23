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

@testable import Blink

final class WhatsNewModelTests: XCTestCase {

  override func setUpWithError() throws {
      // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
      // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testDecode() throws {
// I think here, it would be interesting to do something other than just
// feature, as maybe we want to have "feature" and "banner"
      let data = """
{
"ver": "1",
"rows":
[
  {
      "oneCol": {
          
              "title" : "Your terminal, your way",
              "description": "You can rock your own terminal and roll your own themes beyond our included ones.",
              "image": ["http://blink.sh/whatsnew/test.png"],
              "color": "blue",
              "symbol": "globe",
              "link": "https://blink.sh"
      }
  },
  {
      "versionInfo": {
          "number": "1.0.0",
          "link": "https://blink.sh"
      }
  },
  {
      "twoCol": [
          [{
              "title" : "Passkeys",
              "description": "Cool keys on your phone.",
              "image": ["http://blink.sh/whatsnew/test.png"],
              "color": "orange",
              "symbol": "person.badge.key.fill"
          }],
          [{
          
                  "title" : "Other Passkeys",
                  "description": "Even cololer keys on your phone.",
                  "color": "orange",
                  "symbol": "globe"
              },
          {
                  "title" : "More Passkeys",
                  "description": "Even cololer keys on your phone.",
                  "color": "orange",
                  "symbol": "globe",
                  "availability": "early_access",
              }
          ]
      ]
  }
]
}
""".data(using: .utf8)!
      let doc = try! JSONDecoder().decode(WhatsNewDoc.self, from: data)
      print(doc.rows)
  }

}
