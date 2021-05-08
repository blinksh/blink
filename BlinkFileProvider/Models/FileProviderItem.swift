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


import FileProvider
import UniformTypeIdentifiers
import MobileCoreServices

import BlinkFiles

final class FileProviderItem: NSObject {
  let reference: BlinkItemReference
  
  init(reference: BlinkItemReference) {
    self.reference = reference
  }

//  let attributes: BlinkFiles.FileAttributes

//  init(attributes: BlinkFiles.FileAttributes) {
//    self.attributes = attributes
//  }
  
//  var itemIdentifier: NSFileProviderItemIdentifier {
//    return NSFileProviderItemIdentifier(attributes[.name] as! String)
//  }
//
//  var parentItemIdentifier: NSFileProviderItemIdentifier {
//    // It is important that parents match, otherwise we will receive it empty
//    return .rootContainer
//  }
//
//  var capabilities: NSFileProviderItemCapabilities {
//    return .allowsAll
//  }
//
//  var filename: String {
//    return attributes[.name] as! String
//  }
//
//  // TODO We should do contentType too
//  var typeIdentifier: String {
//    guard let type = attributes[.type] as? FileAttributeType else {
//      return ""
//    }
//    if type == .typeDirectory {
//      return kUTTypeFolder as String
//    }
//
//    let fileSplit = (attributes[.name] as! String).split(separator: ".")
//    return String(fileSplit.count == 2 ? fileSplit[1] : "")
//  }
//

//  init(reference: BlinkItemReference) {
//    self.reference = reference
//    super.init()
//  }
}

// MARK: - NSFileProviderItem

extension FileProviderItem: NSFileProviderItem {

  var itemIdentifier: NSFileProviderItemIdentifier {
    return reference.itemIdentifier
  }

  var parentItemIdentifier: NSFileProviderItemIdentifier {
    return reference.parentReference?.itemIdentifier ?? itemIdentifier
  }


  var filename: String {
    return reference.filename
  }

  var typeIdentifier: String {
    return reference.typeIdentifier
  }

  var capabilities: NSFileProviderItemCapabilities {
    if reference.isDirectory {
      return [.allowsReading, .allowsContentEnumerating]
    } else {
      return [.allowsReading]
    }
  }

  var documentSize: NSNumber? {
    return nil
  }

}
