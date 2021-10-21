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
import FileProvider

extension NSFileProviderError {
  static func couldNotConnect(dueTo error: Error) -> Self {
    // NOTE We can show the error itself, but it is not providing any extra information.
    self.init(.notAuthenticated, userInfo: [//NSLocalizedFailureErrorKey: error,
                                            NSLocalizedFailureReasonErrorKey: "Could not connect."])
  }
  static var noDomainProvided: Self {
    self.init(.notAuthenticated, userInfo: [NSLocalizedFailureReasonErrorKey: "No location provided"])
  }
  
  static func operationError(dueTo error: Error) -> Self {
    self.init(errorCode: 100,
              errorDescription: "Operation Error",
              failureReason: "\(error)")
  }
}

extension NSFileProviderError {
  init(
    errorCode: Int,
    errorDescription: String?,
    failureReason: String? = nil
  ) {
    var info = [String:Any]()
    if let errorDescription = errorDescription {
      info[NSLocalizedDescriptionKey] = errorDescription
    }
    if let failureReason = failureReason {
      info[NSLocalizedFailureReasonErrorKey] = failureReason
    }

    //info[NSLocalizedRecoverySuggestionErrorKey] = "NSLocalizedRecoverySuggestionErrorKey"


    //info[NSLocalizedFailureErrorKey] = "NSLocalizedFailureErrorKey"

    self.init(Code(rawValue: errorCode)!, userInfo: info)
  }
}
