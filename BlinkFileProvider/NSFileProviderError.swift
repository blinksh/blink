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

  static var doesntHaveReferenceToCopy: Self {
    _init(
      errorCode: 10,
      errorDescription: "The operation couldn't be completed",
      failureReason: "Does not have a reference to copy"
    )
  }

  static var wrongEncodedIdentifierForTranslator: Self {
    _init(
      errorCode: 11,
      errorDescription: "The operation couldn't be completed",
      failureReason: "Wrong encoded identifier for Translator"
    )
  }

  static var missingHostInTranslatorRoute: Self {
    _init(
      errorCode: 12,
      errorDescription: "The operation couldn't be completed",
      failureReason: "Missing host in Translator route"
    )
  }

  //    throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
  static var notImplemented: Self {
    _init(
      errorCode: 13,
      errorDescription: "The operation couldn't be completed",
      failureReason: "Not implemented"
    )
  }

  static var noDomainReceived: Self {
    _init(
      // Displayed:
//      errorCode: Code.serverUnreachable.rawValue,
//      errorCode: Code.notAuthenticated.rawValue,
      // Loop:
//      errorCode: Code.syncAnchorExpired.rawValue,
      errorCode: Code.insufficientQuota.rawValue,
      errorDescription: "The operation couldn't be completed",
      failureReason: "No domain received."
    )
  }
}


extension NSFileProviderError {

  private static func _init(
    errorCode: Int,
    errorDescription: String?,
    failureReason: String? = nil
  ) -> NSFileProviderError {
    var info = [String: Any]()
    if let errorDescription = errorDescription {
      info[NSLocalizedDescriptionKey] = errorDescription
    }
    if let failureReason = failureReason {
      info[NSLocalizedFailureReasonErrorKey] = failureReason
    }

    info[NSLocalizedRecoverySuggestionErrorKey] = "NSLocalizedRecoverySuggestionErrorKey"


    info[NSLocalizedFailureErrorKey] = "NSLocalizedFailureErrorKey"


    return NSFileProviderError(Code(rawValue: errorCode)!, userInfo: info)
  }
}
