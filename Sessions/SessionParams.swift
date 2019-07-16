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


import Foundation
import UIKit

@objc class SessionParams: NSObject, Codable {
  @objc var encodedState: Data? = nil
  
  @objc func cleanEncodedState() {
    encodedState = nil
  }
}

@objc class MoshParams: SessionParams {
  @objc var ip: String? = nil
  @objc var port: String? = nil
  @objc var key: String? = nil
  @objc var predictionMode: String? = nil
  @objc var startupCmd: String? = nil
  @objc var serverPath: String? = nil
}

@objc class MCPParams: SessionParams {
  @objc var childSessionType: String? = nil
  @objc var childSessionParams: SessionParams? = nil
  @objc var viewSize: CGSize = .zero
  @objc var rows: Int = 0
  @objc var cols: Int = 0
  @objc var themeName: String? = nil
  @objc var fontName: String? = nil
  @objc var fontSize: Int = 16
  @objc var layoutMode: BKLayoutMode = .safeFit
  @objc var boldAsBright: Bool = false
  @objc var enableBold: UInt = 0
  @objc var layoutLocked: Bool = false
  @objc var layoutLockedFrame: CGRect = .zero
  
  @objc func hasEncodedState() -> Bool {
    childSessionParams?.encodedState != nil
  }
  
  override func cleanEncodedState() {
    childSessionParams?.cleanEncodedState()
    super.cleanEncodedState()
  }
}
