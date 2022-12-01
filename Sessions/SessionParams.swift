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


@objc class SessionParams: NSObject, NSSecureCoding {

  @objc var encodedState: Data? = nil
  
  @objc func cleanEncodedState() {
    encodedState = nil
  }
  
  override init() {
    super.init()
  }
  
  private enum Key: CodingKey {
    case encodedState
  }
  
  func encode(with coder: NSCoder) {
    coder.bk_encode(encodedState, for: Key.encodedState)
  }
  
  required init?(coder: NSCoder) {
    super.init()
    encodedState = coder.bk_decode(for: Key.encodedState)
  }
  
  static var secureCoding1 = true
  class var supportsSecureCoding: Bool { return secureCoding1 }
}

@objc class MoshParams: SessionParams {
  @objc var ip: String? = nil
  @objc var port: String? = nil
  @objc var key: String? = nil
  @objc var predictionMode: String? = nil
  @objc var predictOverwrite: String? = nil
  @objc var startupCmd: String? = nil
  @objc var serverPath: String? = nil
  @objc var experimentalRemoteIp: String? = nil
  
  override init() {
    super.init()
  }
  
  private enum Key: CodingKey {
    case ip
    case port
    case key
    case predictionMode
    case predictOverwrite
    case startupCmd
    case serverPath
    case experimentalRemoteIp
  }
  
  override func encode(with coder: NSCoder) {
    super.encode(with: coder)
    
    coder.bk_encode(ip, for: Key.ip)
    coder.bk_encode(port, for: Key.port)
    coder.bk_encode(key, for: Key.key)
    coder.bk_encode(predictionMode, for: Key.predictionMode)
    coder.bk_encode(predictOverwrite, for: Key.predictOverwrite)
    coder.bk_encode(startupCmd, for: Key.startupCmd)
    coder.bk_encode(serverPath, for: Key.serverPath)
    coder.bk_encode(experimentalRemoteIp, for: Key.experimentalRemoteIp)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    
    self.ip = coder.bk_decode(for: Key.ip)
    self.port = coder.bk_decode(for: Key.port)
    self.key = coder.bk_decode(for: Key.key)
    self.predictionMode = coder.bk_decode(for: Key.predictionMode)
    self.predictOverwrite = coder.bk_decode(for: Key.predictOverwrite)
    self.startupCmd = coder.bk_decode(for: Key.startupCmd)
    self.serverPath = coder.bk_decode(for: Key.serverPath)
    self.experimentalRemoteIp = coder.bk_decode(for: Key.experimentalRemoteIp)
  }
  
  
  static var secureCoding2 = true
  override class var supportsSecureCoding: Bool { secureCoding2 }
}

@objc class MCPParams: SessionParams {
  @objc var childSessionType: String? = nil
  @objc var childSessionParams: SessionParams? = nil
  
  // TODO: Move to UIState?
  @objc var viewSize: CGSize = .zero
  @objc var rows: Int = 0
  @objc var cols: Int = 0
  @objc var themeName: String? = nil
  @objc var fontName: String? = nil
  @objc var fontSize: Int = 16
  @objc var layoutMode: Int = 0
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
  
  override init() {
    super.init()
  }
  
  private enum Key: CodingKey {
    case childSessionType
    case childSessionParams
    case viewSize
    case rows
    case cols
    case themeName
    case fontName
    case fontSize
    case layoutMode
    case boldAsBright
    case enableBold
    case layoutLocked
    case u
  }
  
  override func encode(with coder: NSCoder) {
    super.encode(with: coder)

    coder.bk_encode(childSessionType, for: Key.childSessionType)
    coder.bk_encode(childSessionParams, for: Key.childSessionParams)
    coder.bk_encode(viewSize, for: Key.viewSize)
    coder.bk_encode(rows, for: Key.rows)
    coder.bk_encode(cols, for: Key.cols)
    coder.bk_encode(themeName, for: Key.themeName)
    coder.bk_encode(fontName, for: Key.fontName)
    coder.bk_encode(fontSize, for: Key.fontSize)
    coder.bk_encode(layoutMode, for: Key.layoutMode)
    coder.bk_encode(boldAsBright, for: Key.boldAsBright)
    coder.bk_encode(enableBold, for: Key.enableBold)
    coder.bk_encode(layoutLocked, for: Key.layoutLocked)
    coder.bk_encode(layoutLockedFrame, for: Key.u)
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    self.childSessionType = coder.bk_decode(for: Key.childSessionType)
    self.childSessionParams = coder.bk_decode(of: [MoshParams.self, SessionParams.self], for: Key.childSessionParams)
    self.viewSize = coder.bk_decode(for: Key.viewSize)
    self.rows = coder.bk_decode(for: Key.rows)
    self.cols = coder.bk_decode(for: Key.cols)
    self.themeName = coder.bk_decode(for: Key.themeName)
    self.fontName = coder.bk_decode(for: Key.fontName)
    self.fontSize = coder.bk_decode(for: Key.fontSize)
    self.layoutMode = coder.bk_decode(for: Key.layoutMode)
    self.boldAsBright = coder.bk_decode(for: Key.boldAsBright)
    self.enableBold = coder.bk_decode(for: Key.enableBold)
    self.layoutLocked = coder.bk_decode(for: Key.layoutLocked)
    self.layoutLockedFrame = coder.bk_decode(for: Key.u)
  }
  
  static var secureCoding2 = true
  override class var supportsSecureCoding: Bool { secureCoding2 }
}
