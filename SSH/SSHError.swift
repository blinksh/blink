//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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
import LibSSH

public enum SSHError: Error, Equatable {
  public static func == (lhs: SSHError, rhs: SSHError) -> Bool {
    switch (lhs,rhs) {
    case (.again, .again):
      return true
    case (.connError(msg: _),.connError(msg: _)):
      return true
    case (.notImplemented(let message1),.notImplemented(let message2)):
      if message1 == message2 {
        return true
      }
      return true
    case (.authFailed(methods: let methods1), .authFailed(methods: let methods2)):
      if methods1.elementsEqual(methods2, by: { $0.name() == $1.name() }) {
        return true
      }
      return false
    case (.authError(msg: _), .authError(msg: _)):
      return true
    default:
      return false
    }
  }
  
  case again
  /// Errors related to the connection and may have state from the session attached.
  case connError(msg: String)
  /// Errors related to operations in the library, no communication involved
  case operationError(msg: String)
  case notImplemented(_: String)
  /// Fails either when the username or password are incorrect
  case authFailed(methods: [AuthMethod])
  /// Tried to authenticate using a method that's not allowed
  case authError(msg: String)
  
  public var description: String {
    switch self {
    case .again:
      return "Retry"
    case .connError(let msg):
      return "Connection Error: \(msg)"
    case .operationError(let msg):
      return "Operation Error: \(msg)"
    case .notImplemented(let msg):
      return "Not implemented: \(msg)"
    case .authFailed(let methods):
      let names = Set(methods.map { $0.name() })
      return "Could not authenticate. Tried \(names.joined(separator: ", "))"
    case .authError(let msg):
      return "Authentication error: \(msg)"
    }
  }
}

extension SSHError {
  init(title: String, forSession session: ssh_session?=nil) {
    if let session = session {
      let error = SSHError.getErrorDescription(session)
      self = .connError(msg: "\(title) - \(error)")
    } else {
      self = .operationError(msg: title)
    }
  }
  
  // Should we permit nil too?
  init(_ rc: Int32, forSession session: ssh_session) {
    switch rc {
    case SSH_AGAIN:
      self = .again
    default:
      let msg = SSHError.getErrorDescription(session)
      self = .connError(msg: msg)
    }
  }
  
  init(auth rc: ssh_auth_e, forSession session: ssh_session?=nil, message: String="Auth Error") {
    switch rc {
    case SSH_AUTH_AGAIN:
      self = .again
    default:
      if let session = session {
        let msg = SSHError.getErrorDescription(session)
        self = .authError(msg: msg)
      } else {
        self = .authError(msg: message)
      }
    }
  }
  
  static func getErrorDescription(_ session: ssh_session) -> String {
    let pErr = UnsafeMutableRawPointer(session)
    guard let pErrMsg = ssh_get_error(pErr) else {
      return "Unknown Error"
    }
    
    let errMsg = String(cString: pErrMsg)
    return errMsg
  }
}
